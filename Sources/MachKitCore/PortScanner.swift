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
    public init() {}

    public func scan() -> PortScanResult {
        let output: SystemCommandOutput
        do {
            output = try run(
                executable: "/usr/sbin/lsof",
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-iUDP", "-FpcuPnT"]
            )
        } catch {
            return PortScanResult(ports: [], errorMessage: "Unable to run system port tool: \(error.localizedDescription)")
        }

        let records = Self.parseLSOFOutput(output.text)
        if output.status != 0, records.isEmpty, !output.text.isEmpty {
            return PortScanResult(ports: [], errorMessage: "Failed to read port: \(output.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        let processIDs = Array(Set(records.map(\.processIdentifier))).sorted()
        let workingDirectories = loadWorkingDirectories(processIDs: processIDs)
        let commandLines = loadCommandLines(processIDs: processIDs)
        let currentUserID = getuid()
        let currentProcessID = getpid()

        let ports = records.map { record in
            let executableURL = executableURL(processIdentifier: record.processIdentifier)
            let workingDirectoryURL = workingDirectories[record.processIdentifier]
            let commandLine = commandLines[record.processIdentifier]
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
                processDescription: Self.processDescription(
                    processName: record.processName,
                    executablePath: executableURL?.path,
                    commandLine: commandLine,
                    port: record.port
                ),
                ownerUserID: record.ownerUserID,
                transport: record.transport,
                localAddress: record.localAddress,
                port: record.port,
                exposure: Self.exposure(for: record.localAddress),
                executableURL: executableURL,
                workingDirectoryURL: workingDirectoryURL,
                commandLine: commandLine,
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
        guard port.processIdentifier > 1 else { return "Core system processes are protected." }
        guard port.processIdentifier != getpid() else { return "MachKit cannot quit its own process." }
        guard let currentOwner = processOwnerUserID(processIdentifier: port.processIdentifier) else {
            return "The process has exited, or process information cannot be read."
        }
        guard currentOwner == getuid(), currentOwner == port.ownerUserID else {
            return "Only processes owned by the current user can be quit."
        }

        let currentExecutable = executableURL(processIdentifier: port.processIdentifier)
        if let expected = port.executableURL, let currentExecutable,
           expected.standardizedFileURL != currentExecutable.standardizedFileURL {
            return "The PID has been reused by other processes, please refresh and try again."
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
            var processName = "unknown process"
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
            let value = decodeEscapedUTF8(String(rawLine.dropFirst()))
            switch prefix {
            case "p":
                appendSocket()
                socket = SocketFields()
                process = ProcessFields(processIdentifier: Int32(value), processName: "unknown process", ownerUserID: nil)
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
            let value = Self.decodeEscapedUTF8(String(rawLine.dropFirst()))
            if prefix == "p" { currentProcessID = Int32(value) }
            if prefix == "n", let currentProcessID {
                result[currentProcessID] = URL(fileURLWithPath: value, isDirectory: true)
            }
        }
        return result
    }

    private func loadCommandLines(processIDs: [Int32]) -> [Int32: String] {
        guard !processIDs.isEmpty else { return [:] }
        var result: [Int32: String] = [:]
        for processIdentifier in processIDs {
            if let commandLine = commandLine(processIdentifier: processIdentifier) {
                result[processIdentifier] = String(commandLine.prefix(500))
            }
        }
        return result
    }

    private func commandLine(processIdentifier: Int32) -> String? {
        var query = [Int32(CTL_KERN), Int32(KERN_PROCARGS2), processIdentifier]
        var size = 0
        guard sysctl(&query, UInt32(query.count), nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)
        let status = buffer.withUnsafeMutableBytes { bytes in
            sysctl(&query, UInt32(query.count), bytes.baseAddress, &size, nil, 0)
        }
        guard status == 0, size > MemoryLayout<Int32>.size else { return nil }

        let argumentCount = buffer.withUnsafeBytes {
            Int($0.loadUnaligned(as: Int32.self))
        }
        guard argumentCount > 0 else { return nil }

        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        for _ in 0..<argumentCount where index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            let argument = String(decoding: buffer[start..<index], as: UTF8.self)
            arguments.append(Self.displayArgument(argument))
            index += 1
        }
        let command = arguments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }

    private static func displayArgument(_ argument: String) -> String {
        guard argument.contains(where: { $0.isWhitespace || $0 == "\"" }) else { return argument }
        let escaped = argument
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func decodeEscapedUTF8(_ value: String) -> String {
        let bytes = Array(value.utf8)
        var decoded: [UInt8] = []
        var index = 0
        var decodedExtendedByte = false
        while index < bytes.count {
            if index + 3 < bytes.count,
               bytes[index] == 0x5C,
               bytes[index + 1] == 0x78,
               let high = hexValue(bytes[index + 2]),
               let low = hexValue(bytes[index + 3]) {
                let byte = high << 4 | low
                decoded.append(byte)
                decodedExtendedByte = decodedExtendedByte || byte >= 0x80
                index += 4
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        guard decodedExtendedByte, let result = String(bytes: decoded, encoding: .utf8) else { return value }
        return result
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 55
        case 97...102: byte - 87
        default: nil
        }
    }

    static func processDescription(
        processName: String,
        executablePath: String?,
        commandLine: String?,
        port: UInt16
    ) -> String {
        let name = processName.lowercased()
        let command = commandLine?.lowercased() ?? ""
        let executable = executablePath?.lowercased() ?? ""
        let combined = "\(name) \(command) \(executable)"

        if combined.contains("vite") { return "Vite Development Server" }
        if combined.contains("next-server") || combined.contains("next dev") || combined.contains("next start") {
            return "Next.js Development Server"
        }
        if combined.contains("nuxt") { return "Nuxt Development Server" }
        if combined.contains("webpack") { return "Webpack Development Server" }
        if name == "node" || executable.hasSuffix("/node") { return "Node.js Network Service" }
        if name == "bun" || executable.hasSuffix("/bun") { return "Bun Development Service" }

        if combined.contains("uvicorn") { return "Uvicorn / FastAPI Service" }
        if combined.contains("flask") { return "Flask Development Server" }
        if combined.contains("manage.py runserver") { return "Django Development Server" }
        if combined.contains("-m http.server") { return "Python HTTP Server" }
        if name.hasPrefix("python") || executable.contains("/python") { return "Python Network Service" }

        if name == "air" || combined.contains("/air ") { return "Go Live Reload Service" }
        if combined.contains("go run") || executable.contains("/go-build/") { return "Go Development Service" }
        if combined.contains("rails server") || name == "puma" { return "Ruby on Rails Service" }
        if combined.contains("spring-boot") || combined.contains("org.springframework") { return "Spring Boot Service" }

        if name == "docker-proxy" { return "Docker Container Port Proxy" }
        if combined.contains("com.docker.backend") { return "Docker Desktop Background Service" }
        if name.hasPrefix("postgres") { return "PostgreSQL Database" }
        if name == "mysqld" || name == "mariadbd" { return "MySQL / MariaDB Database" }
        if name.hasPrefix("redis") { return "Redis Database" }
        if name == "mongod" { return "MongoDB Database" }
        if name == "nginx" { return "Nginx Web Server" }
        if name == "caddy" { return "Caddy Web Server" }
        if name == "httpd" || name == "apache2" { return "Apache Web Server" }
        if name == "rapportd" { return "Apple Device Communication Service" }
        if name == "sharingd" { return "macOS Sharing Service" }

        switch port {
        case 22: return "SSH Remote Login Service"
        case 53: return "DNS Service"
        case 80, 443: return "Web Server"
        case 3306: return "MySQL Database"
        case 5432: return "PostgreSQL Database"
        case 6379: return "Redis Database"
        case 27017: return "MongoDB Database"
        case 3000, 3001, 4000, 4200, 5000, 5173, 8000, 8080, 8888: return "Local Development Service"
        default: return "Network Service Process"
        }
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
        if processIdentifier <= 1 { return "Core system processes cannot be quit here." }
        if processIdentifier == currentProcessID { return "MachKit cannot quit its own process." }
        if ownerUserID != currentUserID { return "Only processes owned by the current user can be quit." }
        guard let executablePath else { return "The executable could not be verified, so this process cannot be quit." }
        let path = URL(fileURLWithPath: executablePath).standardizedFileURL.path
        let protectedPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"]
        if protectedPrefixes.contains(where: path.hasPrefix) {
            return "Processes managed by macOS cannot be quit here."
        }
        return nil
    }

    private func run(executable: String, arguments: [String]) throws -> SystemCommandOutput {
        try SystemCommandRunner.run(
            executable: executable,
            arguments: arguments,
            timeout: 10,
            environment: [
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8"
            ]
        )
    }
}
