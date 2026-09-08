import Darwin
import Foundation
import Network

public enum TCPPortScanError: Error, LocalizedError, Equatable, Sendable {
    case emptyHost
    case invalidHost
    case hostTooLong
    case emptyPorts
    case invalidPort(String)
    case invalidRange(String)

    public var errorDescription: String? {
        switch self {
        case .emptyHost: "Enter a host"
        case .invalidHost: "Invalid host"
        case .hostTooLong: "Host is too long"
        case .emptyPorts: "Enter one or more ports"
        case .invalidPort(let value): "Invalid port: \(value)"
        case .invalidRange(let value): "Invalid port range: \(value)"
        }
    }

    public var code: String {
        switch self {
        case .emptyHost: "empty-host"
        case .invalidHost: "invalid-host"
        case .hostTooLong: "host-too-long"
        case .emptyPorts: "empty-ports"
        case .invalidPort: "invalid-port"
        case .invalidRange: "invalid-range"
        }
    }
}

public enum TCPPortProbeStatus: String, Sendable {
    case open
    case closed
    case timeout
    case cancelled
}

public struct TCPPortProbeResult: Equatable, Sendable {
    public let port: Int
    public let status: TCPPortProbeStatus
    public let latencyMs: Double?
    public let service: String?

    public init(port: Int, status: TCPPortProbeStatus, latencyMs: Double?, service: String?) {
        self.port = port
        self.status = status
        self.latencyMs = latencyMs
        self.service = service
    }

    public func asDictionary() -> [String: Any] {
        var value: [String: Any] = [
            "port": port,
            "status": status.rawValue,
        ]
        if let latencyMs { value["latencyMs"] = latencyMs }
        if let service { value["service"] = service }
        return value
    }
}

public struct TCPPortScanSummary: Sendable {
    public let host: String
    public let total: Int
    public let completed: Int
    public let closed: Int
    public let timedOut: Int
    public let openPorts: [TCPPortProbeResult]
    public let durationMs: Double
    public let cancelled: Bool
}

public enum TCPPortScan {
    public static let minimumPort = 1
    public static let maximumPort = 65_535
    public static let defaultTimeoutMilliseconds = 300
    public static let defaultConcurrency = 256
    public static let maximumConcurrency = 512

    private static let probeQueue = DispatchQueue(
        label: "app.machkit.tcp-port-scan",
        qos: .utility,
        attributes: .concurrent
    )

    private static let services: [Int: String] = [
        20: "ftp-data", 21: "ftp", 22: "ssh", 23: "telnet", 25: "smtp",
        53: "dns", 67: "dhcp", 68: "dhcp", 69: "tftp", 80: "http",
        110: "pop3", 123: "ntp", 135: "msrpc", 137: "netbios", 138: "netbios",
        139: "netbios", 143: "imap", 161: "snmp", 389: "ldap", 443: "https",
        445: "smb", 465: "smtps", 514: "syslog", 587: "submission", 631: "ipp",
        636: "ldaps", 873: "rsync", 993: "imaps", 995: "pop3s", 1080: "socks",
        1433: "mssql", 1521: "oracle", 1883: "mqtt", 2049: "nfs", 2375: "docker",
        2376: "docker-tls", 3000: "dev", 3306: "mysql", 3389: "rdp", 4000: "dev",
        4200: "dev", 5000: "dev", 5432: "postgresql", 5672: "amqp", 5900: "vnc",
        5984: "couchdb", 6379: "redis", 6443: "kubernetes", 8000: "http-alt",
        8080: "http-alt", 8443: "https-alt", 8888: "http-alt", 9000: "dev",
        9090: "prometheus", 9200: "elasticsearch", 11211: "memcached", 27017: "mongodb",
    ]

    public static func normalizeHost(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TCPPortScanError.emptyHost }
        guard trimmed.count <= 2_048 else { throw TCPPortScanError.invalidHost }

        if let url = URL(string: trimmed), url.scheme != nil, let host = url.host {
            return try validateHost(host)
        }

        let unwrapped: String
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            unwrapped = String(trimmed.dropFirst().dropLast())
        } else {
            unwrapped = trimmed
        }

        var ipv6 = in6_addr()
        if unwrapped.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            return try validateHost(unwrapped)
        }

        guard !trimmed.contains("/"),
              !trimmed.contains(where: { $0.isWhitespace }),
              let host = URL(string: "tcp://\(trimmed)")?.host else {
            throw TCPPortScanError.invalidHost
        }
        return try validateHost(host)
    }

    public static func parsePorts(_ raw: String) throws -> [Int] {
        let normalized = raw
            .replacingOccurrences(of: "，", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TCPPortScanError.emptyPorts }
        guard normalized.utf8.count <= 131_072 else { throw TCPPortScanError.invalidRange("too long") }

        var selected = Set<Int>()
        let pieces = normalized.split(separator: ",", omittingEmptySubsequences: false)
        for rawPiece in pieces {
            let piece = rawPiece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { throw TCPPortScanError.invalidPort(piece) }

            if piece.contains("-") {
                let bounds = piece.split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2,
                      let lower = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
                      let upper = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
                      isValidPort(lower), isValidPort(upper), lower <= upper else {
                    throw TCPPortScanError.invalidRange(piece)
                }
                for port in lower...upper { selected.insert(port) }
            } else {
                guard let port = Int(piece), isValidPort(port) else {
                    throw TCPPortScanError.invalidPort(piece)
                }
                selected.insert(port)
            }
        }

        guard !selected.isEmpty else { throw TCPPortScanError.emptyPorts }
        return selected.sorted()
    }

    public static func serviceName(for port: Int) -> String? {
        services[port]
    }

    public static func scan(
        host rawHost: String,
        portExpression: String,
        timeoutMilliseconds: Int = defaultTimeoutMilliseconds,
        concurrency: Int = defaultConcurrency,
        onResult: @escaping @Sendable (TCPPortProbeResult) async -> Void = { _ in }
    ) async throws -> TCPPortScanSummary {
        let host = try normalizeHost(rawHost)
        let ports = try parsePorts(portExpression)
        let timeout = min(2_000, max(100, timeoutMilliseconds))
        let workerCount = min(maximumConcurrency, max(1, concurrency), ports.count)
        let startedAt = DispatchTime.now().uptimeNanoseconds

        var nextIndex = 0
        var completed = 0
        var closed = 0
        var timedOut = 0
        var openPorts: [TCPPortProbeResult] = []

        await withTaskGroup(of: TCPPortProbeResult.self) { group in
            func enqueueNext() {
                guard nextIndex < ports.count else { return }
                let port = ports[nextIndex]
                nextIndex += 1
                group.addTask {
                    await probe(host: host, port: port, timeoutMilliseconds: timeout)
                }
            }

            for _ in 0..<workerCount { enqueueNext() }

            while let result = await group.next() {
                completed += 1
                switch result.status {
                case .open: openPorts.append(result)
                case .timeout: timedOut += 1
                case .closed, .cancelled: closed += 1
                }
                await onResult(result)

                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    enqueueNext()
                }
            }
        }

        let durationMs = elapsedMilliseconds(since: startedAt)
        return TCPPortScanSummary(
            host: host,
            total: ports.count,
            completed: completed,
            closed: closed,
            timedOut: timedOut,
            openPorts: openPorts.sorted { $0.port < $1.port },
            durationMs: durationMs,
            cancelled: Task.isCancelled || completed < ports.count
        )
    }

    private static func validateHost(_ host: String) throws -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TCPPortScanError.invalidHost }
        guard trimmed.count <= 253 else { throw TCPPortScanError.hostTooLong }
        guard !trimmed.contains(where: { $0.isWhitespace || $0 == "/" }) else {
            throw TCPPortScanError.invalidHost
        }
        return trimmed
    }

    private static func isValidPort(_ port: Int) -> Bool {
        (minimumPort...maximumPort).contains(port)
    }

    private static func probe(host: String, port: Int, timeoutMilliseconds: Int) async -> TCPPortProbeResult {
        if Task.isCancelled {
            return TCPPortProbeResult(port: port, status: .cancelled, latencyMs: nil, service: serviceName(for: port))
        }

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return TCPPortProbeResult(port: port, status: .closed, latencyMs: nil, service: serviceName(for: port))
        }

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let gate = CompletionGate()
            let startedAt = DispatchTime.now().uptimeNanoseconds
            let complete: @Sendable (TCPPortProbeStatus) -> Void = { status in
                guard gate.claim() else { return }
                let latency = status == .open ? elapsedMilliseconds(since: startedAt) : nil
                continuation.resume(
                    returning: TCPPortProbeResult(
                        port: port,
                        status: status,
                        latencyMs: latency,
                        service: serviceName(for: port)
                    )
                )
                connection.cancel()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: complete(.open)
                case .failed: complete(.closed)
                case .cancelled: complete(.cancelled)
                default: break
                }
            }
            connection.start(queue: probeQueue)
            probeQueue.asyncAfter(deadline: .now() + .milliseconds(timeoutMilliseconds)) {
                complete(.timeout)
            }
        }
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = DispatchTime.now().uptimeNanoseconds
        return (Double(end - start) / 1_000_000).rounded(toPlaces: 2)
    }
}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}
