import Darwin
import Foundation

public actor NetworkScanner {
    private static let maximumPublishedRoutes = 1_000

    private struct ByteSample {
        let received: UInt64
        let sent: UInt64
        let sampledAt: Date
    }

    private struct InterfaceAccumulator {
        var isUp = false
        var addresses = Set<String>()
        var received: UInt64 = 0
        var sent: UInt64 = 0
    }

    private var previousInterfaces: [String: ByteSample] = [:]
    private var previousProcesses: [Int32: ByteSample] = [:]
    private var cachedDefaultInterfaceName: String?
    private var defaultInterfaceSampledAt: Date?

    public init() {}

    public func sampleTransferRate() -> NetworkTransferRate {
        let now = Date()
        let interfaces = sampleInterfaces(at: now, hardwareNames: [:])
        let interfaceName = defaultInterfaceName(at: now)
        let primary = interfaces.first { $0.name == interfaceName }
            ?? interfaces.first { $0.kind == .wifi || $0.kind == .ethernet }
            ?? interfaces.first { $0.kind == .tunnel }
        return NetworkTransferRate(
            sampledAt: now,
            interfaceName: primary?.name,
            downloadBytesPerSecond: primary?.downloadBytesPerSecond ?? 0,
            uploadBytesPerSecond: primary?.uploadBytesPerSecond ?? 0
        )
    }

    public func sampleProcessTrafficRates() -> [Int32: (download: Double, upload: Double)] {
        let now = Date()
        do {
            let output = try run(
                executable: "/usr/bin/nettop",
                arguments: ["-P", "-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]
            )
            guard output.status == 0 || !output.text.isEmpty else { return [:] }
            let records = Self.parseProcessTrafficOutput(output.text)
            var nextSamples: [Int32: ByteSample] = [:]
            var rates: [Int32: (download: Double, upload: Double)] = [:]
            for record in records {
                let sample = ByteSample(received: record.received, sent: record.sent, sampledAt: now)
                nextSamples[record.processIdentifier] = sample
                let delta = Self.rates(current: sample, previous: previousProcesses[record.processIdentifier])
                rates[record.processIdentifier] = (delta.received, delta.sent)
            }
            previousProcesses = nextSamples
            return rates
        } catch {
            return [:]
        }
    }

    public func scan() -> NetworkSnapshot {
        let now = Date()
        let hardwareNames = loadHardwareNames()
        let interfaces = sampleInterfaces(at: now, hardwareNames: hardwareNames)
        var addressToInterface: [String: String] = [:]
        for item in interfaces {
            for address in item.addresses where addressToInterface[address] == nil {
                addressToInterface[address] = item.name
            }
        }

        var errors: [String] = []
        let sampledConnections: [NetworkConnection]
        do {
            let output = try run(
                executable: "/usr/sbin/lsof",
                arguments: ["-nP", "-iTCP", "-iUDP", "-FpcuPnT"]
            )
            sampledConnections = Self.parseConnections(output.text, addressToInterface: addressToInterface)
            if output.status != 0, sampledConnections.isEmpty, !output.text.isEmpty {
                errors.append("Unable to read active connections.")
            }
        } catch {
            sampledConnections = []
            errors.append("Unable to read active connections: \(error.localizedDescription)")
        }

        let connectionCounts = Dictionary(grouping: sampledConnections, by: \.processIdentifier).mapValues(\.count)
        let processes: [NetworkProcessUsage]
        do {
            let output = try run(
                executable: "/usr/bin/nettop",
                arguments: ["-P", "-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]
            )
            processes = parseProcessTraffic(output.text, at: now, connectionCounts: connectionCounts)
            if output.status != 0, processes.isEmpty {
                errors.append("Per-process traffic is unavailable.")
            }
        } catch {
            processes = []
            errors.append("Per-process traffic is unavailable: \(error.localizedDescription)")
        }

        let routes = Array(loadRoutes().prefix(Self.maximumPublishedRoutes))
        let defaultRoute = lookupRoute(query: "default")
        cachedDefaultInterfaceName = defaultRoute.interfaceName
        defaultInterfaceSampledAt = now
        let proxy = loadProxyConfiguration(connections: sampledConnections, interfaces: interfaces)
        let connections = sampledConnections
        return NetworkSnapshot(
            sampledAt: now,
            interfaces: interfaces,
            processes: processes,
            connections: connections,
            routes: routes,
            defaultRoute: defaultRoute,
            proxy: proxy,
            errors: errors
        )
    }

    public func route(to query: String) -> NetworkRouteLookup {
        lookupRoute(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func sampleInterfaces(at now: Date, hardwareNames: [String: String]) -> [NetworkInterfaceUsage] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        var accumulators: [String: InterfaceAccumulator] = [:]
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            let value = item.pointee
            let name = String(cString: value.ifa_name)
            var accumulator = accumulators[name, default: InterfaceAccumulator()]
            accumulator.isUp = accumulator.isUp || (value.ifa_flags & UInt32(IFF_UP)) != 0

            if let address = value.ifa_addr {
                switch Int32(address.pointee.sa_family) {
                case AF_INET, AF_INET6:
                    if let text = Self.numericAddress(address) {
                        accumulator.addresses.insert(text)
                    }
                case AF_LINK:
                    if let data = value.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                        accumulator.received = UInt64(data.ifi_ibytes)
                        accumulator.sent = UInt64(data.ifi_obytes)
                    }
                default:
                    break
                }
            }
            accumulators[name] = accumulator
            current = value.ifa_next
        }

        var nextSamples: [String: ByteSample] = [:]
        let usages = accumulators.map { name, value -> NetworkInterfaceUsage in
            let sample = ByteSample(received: value.received, sent: value.sent, sampledAt: now)
            nextSamples[name] = sample
            let rates = Self.rates(current: sample, previous: previousInterfaces[name])
            let hardwareName = hardwareNames[name]
            return NetworkInterfaceUsage(
                name: name,
                displayName: hardwareName ?? Self.fallbackDisplayName(for: name),
                kind: Self.interfaceKind(name: name, hardwareName: hardwareName),
                isUp: value.isUp,
                addresses: value.addresses.sorted(),
                receivedBytes: value.received,
                sentBytes: value.sent,
                downloadBytesPerSecond: rates.received,
                uploadBytesPerSecond: rates.sent
            )
        }
        previousInterfaces = nextSamples
        return usages
            .filter { $0.isUp && (!$0.addresses.isEmpty || $0.receivedBytes > 0 || $0.sentBytes > 0) }
            .sorted { lhs, rhs in
                let lhsRank = Self.interfaceRank(lhs.kind)
                let rhsRank = Self.interfaceRank(rhs.kind)
                return lhsRank == rhsRank ? lhs.name < rhs.name : lhsRank < rhsRank
            }
    }

    private func parseProcessTraffic(
        _ output: String,
        at now: Date,
        connectionCounts: [Int32: Int]
    ) -> [NetworkProcessUsage] {
        let records = Self.parseProcessTrafficOutput(output)
        var nextSamples: [Int32: ByteSample] = [:]
        let result = records.map { record -> NetworkProcessUsage in
            let sample = ByteSample(received: record.received, sent: record.sent, sampledAt: now)
            nextSamples[record.processIdentifier] = sample
            let rates = Self.rates(current: sample, previous: previousProcesses[record.processIdentifier])
            return NetworkProcessUsage(
                processIdentifier: record.processIdentifier,
                name: record.name,
                receivedBytes: record.received,
                sentBytes: record.sent,
                downloadBytesPerSecond: rates.received,
                uploadBytesPerSecond: rates.sent,
                connectionCount: connectionCounts[record.processIdentifier, default: 0]
            )
        }
        previousProcesses = nextSamples
        return result.sorted {
            let lhsRate = $0.downloadBytesPerSecond + $0.uploadBytesPerSecond
            let rhsRate = $1.downloadBytesPerSecond + $1.uploadBytesPerSecond
            if lhsRate != rhsRate { return lhsRate > rhsRate }
            return $0.receivedBytes + $0.sentBytes > $1.receivedBytes + $1.sentBytes
        }
    }

    static func parseProcessTrafficOutput(_ output: String) -> [(processIdentifier: Int32, name: String, received: UInt64, sent: UInt64)] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let columns = rawLine.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 3,
                  columns[0] != "",
                  let separator = columns[0].lastIndex(of: "."),
                  let processIdentifier = Int32(columns[0][columns[0].index(after: separator)...]),
                  let received = UInt64(columns[1]),
                  let sent = UInt64(columns[2]) else { return nil }
            let name = String(columns[0][..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (processIdentifier, name.isEmpty ? "Process \(processIdentifier)" : name, received, sent)
        }
    }

    static func parseConnections(_ output: String, addressToInterface: [String: String]) -> [NetworkConnection] {
        struct ProcessFields {
            var processIdentifier: Int32?
            var processName = "unknown process"
        }
        struct SocketFields {
            var transport: NetworkTransport?
            var endpoint: String?
            var state: String?
        }

        var process = ProcessFields()
        var socket = SocketFields()
        var results: [NetworkConnection] = []
        var identifiers = Set<String>()

        func appendSocket() {
            guard let processIdentifier = process.processIdentifier,
                  let transport = socket.transport,
                  let endpoint = socket.endpoint,
                  let parsed = parseConnectionEndpoint(endpoint) else { return }
            let listener = transport == .tcp ? socket.state == "LISTEN" : parsed.remoteAddress == nil
            let connection = NetworkConnection(
                processIdentifier: processIdentifier,
                processName: process.processName,
                transport: transport,
                localAddress: parsed.localAddress,
                localPort: parsed.localPort,
                remoteAddress: parsed.remoteAddress,
                remotePort: parsed.remotePort,
                state: socket.state,
                interfaceName: addressToInterface[parsed.localAddress] ?? (Self.isLoopback(parsed.localAddress) ? "lo0" : nil),
                isListener: listener
            )
            guard identifiers.insert(connection.id).inserted else { return }
            results.append(connection)
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard let prefix = rawLine.first else { continue }
            let value = PortScanner.decodeEscapedUTF8(String(rawLine.dropFirst()))
            switch prefix {
            case "p":
                appendSocket()
                socket = SocketFields()
                process = ProcessFields(processIdentifier: Int32(value), processName: "unknown process")
            case "c": process.processName = value
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
        return results.sorted {
            if $0.isListener != $1.isListener { return !$0.isListener }
            if $0.processName != $1.processName { return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
            return ($0.localPort ?? 0) < ($1.localPort ?? 0)
        }
    }

    static func parseConnectionEndpoint(
        _ endpoint: String
    ) -> (localAddress: String, localPort: UInt16?, remoteAddress: String?, remotePort: UInt16?)? {
        let parts = endpoint.components(separatedBy: "->")
        guard let local = parseHostAndPort(parts[0]) else { return nil }
        let remote = parts.count > 1 ? parseHostAndPort(parts[1]) : nil
        return (local.host, local.port, remote?.host, remote?.port)
    }

    static func parseRoutes(_ output: String, family: String) -> [NetworkRoute] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let columns = rawLine.split(whereSeparator: \.isWhitespace).map(String.init)
            guard columns.count >= 4 else { return nil }
            let destination = columns[0]
            if destination == "Destination" || destination == "Routing" || destination == "Internet:" || destination == "Internet6:" {
                return nil
            }
            return NetworkRoute(
                destination: destination,
                gateway: columns[1],
                flags: columns[2],
                interfaceName: columns[3],
                family: family
            )
        }
    }

    static func parseProxyConfiguration(_ output: String) -> NetworkProxyConfiguration {
        var values: [String: String] = [:]
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
        var services: [String] = []
        func appendProxy(enable: String, host: String, port: String, label: String) {
            guard values[enable] == "1", let address = values[host] else { return }
            let endpoint = values[port].map { "\(address):\($0)" } ?? address
            services.append("\(label) \(endpoint)")
        }
        appendProxy(enable: "HTTPEnable", host: "HTTPProxy", port: "HTTPPort", label: "HTTP")
        appendProxy(enable: "HTTPSEnable", host: "HTTPSProxy", port: "HTTPSPort", label: "HTTPS")
        appendProxy(enable: "SOCKSEnable", host: "SOCKSProxy", port: "SOCKSPort", label: "SOCKS")
        if values["ProxyAutoConfigEnable"] == "1", let url = values["ProxyAutoConfigURLString"] {
            services.append("PAC \(url)")
        }
        if values["ProxyAutoDiscoveryEnable"] == "1" {
            services.append("Auto Discovery")
        }
        return NetworkProxyConfiguration(services: services)
    }

    static func parseRouteLookup(_ output: String, query: String, status: Int32) -> NetworkRouteLookup {
        var values: [String: String] = [:]
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            values[key] = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        }
        if status != 0 {
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return NetworkRouteLookup(
                query: query,
                destination: query,
                gateway: nil,
                interfaceName: nil,
                errorMessage: message.isEmpty ? "No route found." : message
            )
        }
        return NetworkRouteLookup(
            query: query,
            destination: values["route to"] ?? values["destination"] ?? query,
            gateway: values["gateway"],
            interfaceName: values["interface"]
        )
    }

    private func loadHardwareNames() -> [String: String] {
        guard let output = try? run(executable: "/usr/sbin/networksetup", arguments: ["-listallhardwareports"]) else {
            return [:]
        }
        var hardwarePort: String?
        var result: [String: String] = [:]
        for rawLine in output.text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix("Hardware Port: ") {
                hardwarePort = String(line.dropFirst("Hardware Port: ".count))
            } else if line.hasPrefix("Device: "), let hardwarePort {
                result[String(line.dropFirst("Device: ".count))] = hardwarePort
            }
        }
        return result
    }

    private func loadRoutes() -> [NetworkRoute] {
        var routes: [NetworkRoute] = []
        if let output = try? run(executable: "/usr/sbin/netstat", arguments: ["-rn", "-f", "inet"]) {
            routes += Self.parseRoutes(output.text, family: "IPv4")
        }
        if let output = try? run(executable: "/usr/sbin/netstat", arguments: ["-rn", "-f", "inet6"]) {
            routes += Self.parseRoutes(output.text, family: "IPv6")
        }
        return routes
    }

    private func loadProxyConfiguration(
        connections: [NetworkConnection],
        interfaces: [NetworkInterfaceUsage]
    ) -> NetworkProxyConfiguration {
        let systemProxy: NetworkProxyConfiguration
        if let output = try? run(executable: "/usr/sbin/scutil", arguments: ["--proxy"]) {
            systemProxy = Self.parseProxyConfiguration(output.text)
        } else {
            systemProxy = NetworkProxyConfiguration(services: [])
        }
        return Self.augmentProxyConfiguration(systemProxy, connections: connections, interfaces: interfaces)
    }

    static func augmentProxyConfiguration(
        _ systemProxy: NetworkProxyConfiguration,
        connections: [NetworkConnection],
        interfaces: [NetworkInterfaceUsage]
    ) -> NetworkProxyConfiguration {
        let knownProxyFragments = ["clash", "mihomo", "surge", "v2ray", "xray", "sing-box", "shadowsocks"]
        let proxyProcesses = Set(connections.compactMap { connection -> String? in
            let name = connection.processName.lowercased()
            return knownProxyFragments.contains(where: name.contains) ? connection.processName : nil
        }).sorted()
        let tunnelNames = interfaces.filter { $0.kind == .tunnel }.map(\.name).sorted()
        var services = systemProxy.services
        services += proxyProcesses.map { "Detected \($0)" }
        if !tunnelNames.isEmpty {
            services.append("TUN \(tunnelNames.joined(separator: ", "))")
        }
        var seen = Set<String>()
        return NetworkProxyConfiguration(services: services.filter { seen.insert($0).inserted })
    }

    private func lookupRoute(query: String) -> NetworkRouteLookup {
        guard !query.isEmpty else {
            return NetworkRouteLookup(query: query, destination: query, gateway: nil, interfaceName: nil, errorMessage: "Enter a host or IP address.")
        }
        do {
            let output = try run(executable: "/sbin/route", arguments: ["-n", "get", query])
            return Self.parseRouteLookup(output.text, query: query, status: output.status)
        } catch {
            return NetworkRouteLookup(query: query, destination: query, gateway: nil, interfaceName: nil, errorMessage: error.localizedDescription)
        }
    }

    private func defaultInterfaceName(at now: Date) -> String? {
        if let sampledAt = defaultInterfaceSampledAt,
           now.timeIntervalSince(sampledAt) < 30,
           let cachedDefaultInterfaceName {
            return cachedDefaultInterfaceName
        }
        let route = lookupRoute(query: "default")
        cachedDefaultInterfaceName = route.interfaceName
        defaultInterfaceSampledAt = now
        return route.interfaceName
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(address.pointee.sa_len)
        guard getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        let end = host.firstIndex(of: 0) ?? host.endIndex
        let value = String(decoding: host[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return value.components(separatedBy: "%").first
    }

    private static func parseHostAndPort(_ endpoint: String) -> (host: String, port: UInt16?)? {
        if endpoint.hasPrefix("["), let closingBracket = endpoint.lastIndex(of: "]") {
            let host = String(endpoint[endpoint.index(after: endpoint.startIndex)..<closingBracket])
            let suffix = endpoint[endpoint.index(after: closingBracket)...]
            let port = suffix.first == ":" ? UInt16(suffix.dropFirst()) : nil
            return (host, port)
        }
        guard let separator = endpoint.lastIndex(of: ":") else { return (endpoint, nil) }
        let host = String(endpoint[..<separator])
        let portText = endpoint[endpoint.index(after: separator)...]
        return (host.isEmpty ? "*" : host, UInt16(portText))
    }

    private static func rates(current: ByteSample, previous: ByteSample?) -> (received: Double, sent: Double) {
        guard let previous else { return (0, 0) }
        let elapsed = current.sampledAt.timeIntervalSince(previous.sampledAt)
        let rates = PerformanceSamplingMath.transferRate(
            currentFirst: current.received,
            currentSecond: current.sent,
            previousFirst: previous.received,
            previousSecond: previous.sent,
            elapsed: elapsed
        )
        return (rates.first, rates.second)
    }

    private static func fallbackDisplayName(for name: String) -> String {
        if name.hasPrefix("utun") { return "VPN / TUN" }
        if name == "lo0" { return "Loopback" }
        if name.hasPrefix("bridge") { return "Bridge" }
        return name
    }

    private static func interfaceKind(name: String, hardwareName: String?) -> NetworkInterfaceKind {
        let display = hardwareName?.lowercased() ?? ""
        if name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") { return .tunnel }
        if name == "lo0" { return .loopback }
        if name.hasPrefix("bridge") { return .bridge }
        if display.contains("wi-fi") || display.contains("airport") { return .wifi }
        if display.contains("ethernet") || display.contains("lan") { return .ethernet }
        return .other
    }

    private static func interfaceRank(_ kind: NetworkInterfaceKind) -> Int {
        switch kind {
        case .wifi: 0
        case .ethernet: 1
        case .tunnel: 2
        case .bridge: 3
        case .other: 4
        case .loopback: 5
        }
    }

    private static func isLoopback(_ address: String) -> Bool {
        address == "::1" || address == "localhost" || address.hasPrefix("127.")
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
