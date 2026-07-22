import Darwin
import Foundation

struct LSOFPortRecord: Sendable, Equatable {
    let processIdentifier: Int32
    let processName: String
    let ownerUserID: UInt32
    let transport: NetworkTransport
    let localAddress: String
    let port: UInt16
}

public actor PortScanner {
    private struct CommandOutput {
        let status: Int32
        let text: String
    }

    public init() {}

    public func scan() -> PortScanResult {
        let output: CommandOutput
        do {
            output = try run(
                executable: "/usr/sbin/lsof",
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-iUDP", "-FpcuPnT"]
            )
        } catch {
            return PortScanResult(ports: [], errorMessage: "无法运行系统端口工具：\(error.localizedDescription)")
        }

        let records = Self.parseLSOFOutput(output.text)
        if output.status != 0, records.isEmpty, !output.text.isEmpty {
            return PortScanResult(ports: [], errorMessage: "读取端口失败：\(output.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        let processIDs = Array(Set(records.map(\.processIdentifier))).sorted()
        let workingDirectories = loadWorkingDirectories(processIDs: processIDs)
        let commandLines = loadCommandLines(processIDs: processIDs)
        let currentUserID = getuid()
        let currentProcessID = getpid()

        let ports = records.map { record in
            let executableURL = executableURL(processIdentifier: record.processIdentifier)
            let protectionReason = Self.protectionReason(
                processIdentifier: record.processIdentifier,
                ownerUserID: record.ownerUserID,
                executablePath: executableURL?.path,
                currentUserID: currentUserID,
                currentProcessID: currentProcessID
            )
            return ListeningPort(
                processIdentifier: record.processIdentifier,
                processName: record.processName,
                ownerUserID: record.ownerUserID,
                transport: record.transport,
                localAddress: record.localAddress,
                port: record.port,
                exposure: Self.exposure(for: record.localAddress),
                executableURL: executableURL,
                workingDirectoryURL: workingDirectories[record.processIdentifier],
                commandLine: commandLines[record.processIdentifier],
                canTerminate: protectionReason == nil,
                protectionReason: protectionReason
            )
        }.sorted { lhs, rhs in
            if lhs.port != rhs.port { return lhs.port < rhs.port }
            if lhs.transport != rhs.transport { return lhs.transport.rawValue < rhs.transport.rawValue }
            if lhs.processName != rhs.processName { return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending }
            return lhs.localAddress < rhs.localAddress
        }

        return PortScanResult(ports: ports)
    }

    public func terminate(_ port: ListeningPort, force: Bool = false) -> String? {
        guard port.processIdentifier > 1 else { return "不会结束系统核心进程。" }
        guard port.processIdentifier != getpid() else { return "Sift 不能结束自身进程。" }
        guard let currentOwner = processOwnerUserID(processIdentifier: port.processIdentifier) else {
            return "进程已经退出，或无法读取进程信息。"
        }
        guard currentOwner == getuid(), currentOwner == port.ownerUserID else {
            return "只能结束当前用户拥有的进程。"
        }

        let currentExecutable = executableURL(processIdentifier: port.processIdentifier)
        if let expected = port.executableURL, let currentExecutable,
           expected.standardizedFileURL != currentExecutable.standardizedFileURL {
            return "PID 已被其他进程复用，请刷新后重试。"
        }
        if let reason = Self.protectionReason(
            processIdentifier: port.processIdentifier,
            ownerUserID: currentOwner,
            executablePath: currentExecutable?.path,
            currentUserID: getuid(),
            currentProcessID: getpid()
        ) {
            return reason
        }

        let signal = force ? SIGKILL : SIGTERM
        guard Darwin.kill(port.processIdentifier, signal) == 0 else {
            return String(cString: strerror(errno))
        }
        return nil
    }

    static func parseLSOFOutput(_ output: String) -> [LSOFPortRecord] {
        struct ProcessFields {
            var processIdentifier: Int32?
            var processName = "未知进程"
            var ownerUserID: UInt32?
        }
        struct SocketFields {
            var transport: NetworkTransport?
            var endpoint: String?
            var state: String?
        }

        var process = ProcessFields()
        var socket = SocketFields()
        var records: [LSOFPortRecord] = []
        var identifiers = Set<String>()

        func appendSocket() {
            guard let processIdentifier = process.processIdentifier,
                  let ownerUserID = process.ownerUserID,
                  let transport = socket.transport,
                  let endpoint = socket.endpoint,
                  let parsedEndpoint = parseEndpoint(endpoint) else { return }
            if transport == .tcp, socket.state != "LISTEN" { return }
            if transport == .udp, endpoint.contains("->") { return }

            let identifier = "\(processIdentifier)|\(transport.rawValue)|\(parsedEndpoint.address)|\(parsedEndpoint.port)"
            guard identifiers.insert(identifier).inserted else { return }
            records.append(LSOFPortRecord(
                processIdentifier: processIdentifier,
                processName: process.processName,
                ownerUserID: ownerUserID,
                transport: transport,
                localAddress: parsedEndpoint.address,
                port: parsedEndpoint.port
            ))
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch prefix {
            case "p":
                appendSocket()
                socket = SocketFields()
                process = ProcessFields(processIdentifier: Int32(value), processName: "未知进程", ownerUserID: nil)
            case "c": process.processName = value
            case "u": process.ownerUserID = UInt32(value)
            case "f":
                appendSocket()
                socket = SocketFields()
            case "P": socket.transport = NetworkTransport(rawValue: value)
            case "n": socket.endpoint = value
            case "T" where value.hasPrefix("ST="): socket.state = String(value.dropFirst(3))
            default: break
            }
        }
        appendSocket()
        return records
    }

    private static func parseEndpoint(_ endpoint: String) -> (address: String, port: UInt16)? {
        let localEndpoint = endpoint.split(separator: "->", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? endpoint
        let address: String
        let portText: String
        if localEndpoint.hasPrefix("["), let closingBracket = localEndpoint.lastIndex(of: "]") {
            address = String(localEndpoint[localEndpoint.index(after: localEndpoint.startIndex)..<closingBracket])
            let suffix = localEndpoint[localEndpoint.index(after: closingBracket)...]
            guard suffix.first == ":" else { return nil }
            portText = String(suffix.dropFirst())
        } else {
            guard let separator = localEndpoint.lastIndex(of: ":") else { return nil }
            address = String(localEndpoint[..<separator])
            portText = String(localEndpoint[localEndpoint.index(after: separator)...])
        }
        guard let port = UInt16(portText), port > 0 else { return nil }
        return (address.isEmpty ? "*" : address, port)
    }

    private static func exposure(for address: String) -> PortExposure {
        if address == "*" || address == "0.0.0.0" || address == "::" { return .allInterfaces }
        if address == "localhost" || address == "::1" || address.hasPrefix("127.") { return .loopback }
        return .network
    }

    private func loadWorkingDirectories(processIDs: [Int32]) -> [Int32: URL] {
        guard !processIDs.isEmpty else { return [:] }
        let processList = processIDs.map(String.init).joined(separator: ",")
        guard let output = try? run(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-p", processList, "-d", "cwd", "-Fn"]
        ) else { return [:] }

        var currentProcessID: Int32?
        var result: [Int32: URL] = [:]
        for rawLine in output.text.split(whereSeparator: \.isNewline) {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            if prefix == "p" { currentProcessID = Int32(value) }
            if prefix == "n", let currentProcessID {
                result[currentProcessID] = URL(fileURLWithPath: value, isDirectory: true)
            }
        }
        return result
    }

    private func loadCommandLines(processIDs: [Int32]) -> [Int32: String] {
        guard !processIDs.isEmpty else { return [:] }
        let processList = processIDs.map(String.init).joined(separator: ",")
        guard let output = try? run(
            executable: "/bin/ps",
            arguments: ["-ww", "-p", processList, "-o", "pid=", "-o", "command="]
        ) else { return [:] }

        var result: [Int32: String] = [:]
        for rawLine in output.text.split(whereSeparator: \.isNewline) {
            let line = rawLine.drop(while: \.isWhitespace)
            guard let separator = line.firstIndex(where: \.isWhitespace),
                  let processIdentifier = Int32(line[..<separator]) else { continue }
            let command = line[separator...].drop(while: \.isWhitespace)
            if !command.isEmpty { result[processIdentifier] = String(command.prefix(500)) }
        }
        return result
    }

    private func executableURL(processIdentifier: Int32) -> URL? {
        var buffer = [CChar](repeating: 0, count: 4_096)
        let length = proc_pidpath(processIdentifier, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = String(
            decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        return URL(fileURLWithPath: path)
    }

    private func processOwnerUserID(processIdentifier: Int32) -> UInt32? {
        var information = proc_bsdinfo()
        let size = proc_pidinfo(
            processIdentifier,
            PROC_PIDTBSDINFO,
            0,
            &information,
            Int32(MemoryLayout<proc_bsdinfo>.stride)
        )
        guard size == MemoryLayout<proc_bsdinfo>.stride else { return nil }
        return information.pbi_uid
    }

    static func protectionReason(
        processIdentifier: Int32,
        ownerUserID: UInt32,
        executablePath: String?,
        currentUserID: UInt32,
        currentProcessID: Int32
    ) -> String? {
        if processIdentifier <= 1 { return "系统核心进程不会在这里结束。" }
        if processIdentifier == currentProcessID { return "Sift 不能结束自身进程。" }
        if ownerUserID != currentUserID { return "只能结束当前用户拥有的进程。" }
        guard let executablePath else { return "无法确认可执行文件，不会结束这个进程。" }
        let path = URL(fileURLWithPath: executablePath).standardizedFileURL.path
        let protectedPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"]
        if protectedPrefixes.contains(where: path.hasPrefix) {
            return "macOS 系统管理的进程不会在这里结束。"
        }
        return nil
    }

    private func run(executable: String, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandOutput(
            status: process.terminationStatus,
            text: String(decoding: data, as: UTF8.self)
        )
    }
}
