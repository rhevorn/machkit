import Darwin
import Foundation
import Security

public enum ConnectionTraceMode: String, Sendable {
    case dns
    case full
}

public struct ConnectionTraceTarget: Equatable, Sendable {
    public let input: String
    public let host: String
    public let port: Int
    public let scheme: String
    public let url: URL?
    public let isIPLiteral: Bool
}

public enum ConnectionTraceError: Error, LocalizedError, Equatable {
    case empty
    case invalidTarget
    case unsupportedScheme(String)
    case invalidPort
    case hostTooLong

    public var errorDescription: String? {
        switch self {
        case .empty: "Enter a host or URL"
        case .invalidTarget: "Invalid host or URL"
        case .unsupportedScheme(let scheme): "Unsupported scheme: \(scheme)"
        case .invalidPort: "Port must be between 1 and 65535"
        case .hostTooLong: "Host is too long"
        }
    }

    public var code: String {
        switch self {
        case .empty: "empty"
        case .invalidTarget: "invalid-target"
        case .unsupportedScheme: "unsupported-scheme"
        case .invalidPort: "invalid-port"
        case .hostTooLong: "host-too-long"
        }
    }
}

public enum ConnectionTrace {
    public static let defaultTimeout: TimeInterval = 12

    public static func parseTarget(_ raw: String, mode: ConnectionTraceMode) throws -> ConnectionTraceTarget {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ConnectionTraceError.empty }
        guard trimmed.count <= 2_048 else { throw ConnectionTraceError.invalidTarget }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return try makeTarget(from: url, input: trimmed, mode: mode)
        }

        if trimmed.contains("://") {
            throw ConnectionTraceError.invalidTarget
        }

        // host, host:port, or [ipv6]:port
        let synthesized: URL?
        if mode == .full {
            let candidate = trimmed.hasPrefix("[") || trimmed.contains(":") && isLikelyHostPort(trimmed)
                ? "https://\(normalizeHostPort(trimmed))"
                : "https://\(trimmed)"
            synthesized = URL(string: candidate)
        } else if let asURL = URL(string: "https://\(normalizeHostPort(trimmed))") {
            synthesized = asURL
        } else {
            synthesized = nil
        }

        guard let url = synthesized, url.host != nil else {
            throw ConnectionTraceError.invalidTarget
        }
        return try makeTarget(from: url, input: trimmed, mode: mode)
    }

    public static func probe(
        target raw: String,
        mode rawMode: String,
        timeout: TimeInterval = defaultTimeout
    ) async -> [String: Any] {
        let mode = ConnectionTraceMode(rawValue: rawMode.lowercased()) ?? .full
        do {
            let target = try parseTarget(raw, mode: mode)
            if mode == .dns {
                return await probeDNS(target: target, timeout: timeout).asDictionary()
            }
            return await probeFull(target: target, timeout: timeout).asDictionary()
        } catch let error as ConnectionTraceError {
            return [
                "ok": false,
                "mode": mode.rawValue,
                "input": raw.trimmingCharacters(in: .whitespacesAndNewlines),
                "error": error.code,
                "message": error.localizedDescription,
                "steps": [] as [Any],
            ]
        } catch {
            return [
                "ok": false,
                "mode": mode.rawValue,
                "input": raw.trimmingCharacters(in: .whitespacesAndNewlines),
                "error": "failed",
                "message": error.localizedDescription,
                "steps": [] as [Any],
            ]
        }
    }

    private static func makeTarget(from url: URL, input: String, mode: ConnectionTraceMode) throws -> ConnectionTraceTarget {
        let scheme = (url.scheme ?? "https").lowercased()
        if mode == .full, scheme != "http", scheme != "https" {
            throw ConnectionTraceError.unsupportedScheme(scheme)
        }
        guard let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            throw ConnectionTraceError.invalidTarget
        }
        guard host.count <= 253 else { throw ConnectionTraceError.hostTooLong }

        let defaultPort = scheme == "http" ? 80 : 443
        let port = url.port ?? defaultPort
        guard (1...65_535).contains(port) else { throw ConnectionTraceError.invalidPort }

        var components = URLComponents()
        components.scheme = scheme == "http" ? "http" : "https"
        components.host = host
        if port != defaultPort { components.port = port }
        components.path = url.path.isEmpty ? "/" : url.path
        components.query = url.query
        let normalized = components.url

        return ConnectionTraceTarget(
            input: input,
            host: host,
            port: port,
            scheme: components.scheme ?? "https",
            url: normalized,
            isIPLiteral: isIPAddress(host)
        )
    }

    private static func isLikelyHostPort(_ value: String) -> Bool {
        if value.hasPrefix("[") { return value.contains("]:") }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let port = Int(parts[1]) else { return false }
        return (1...65_535).contains(port) && !parts[0].isEmpty
    }

    private static func normalizeHostPort(_ value: String) -> String {
        if value.hasPrefix("["), value.contains("]:") { return value }
        if isLikelyHostPort(value) { return value }
        return value
    }

    private static func isIPAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        if host.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 { return true }
        let bare = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
        return bare.withCString { inet_pton(AF_INET6, $0, &ipv6) } == 1
    }

    private static func probeDNS(target: ConnectionTraceTarget, timeout: TimeInterval) async -> TracePayload {
        if target.isIPLiteral {
            let family = target.host.contains(":") ? "ipv6" : "ipv4"
            let dnsInfo = DNSInfo(
                durationMs: 0,
                addresses: [["address": stripBrackets(target.host), "family": family]]
            )
            return TracePayload(
                ok: true,
                mode: .dns,
                target: target,
                steps: [
                    TraceStep(id: "dns", ok: true, durationMs: 0, detail: "literal"),
                ],
                dns: dnsInfo,
                http: nil,
                tls: nil,
                timings: Timings(dnsMs: 0, tcpMs: nil, tlsMs: nil, ttfbMs: nil, totalMs: 0),
                verbose: VerboseBuilder.dns(target: target, dns: dnsInfo, error: nil),
                error: nil,
                message: nil
            )
        }

        let resolved = await resolveHost(target.host, timeout: min(timeout, 8))
        let step = TraceStep(
            id: "dns",
            ok: resolved.error == nil && !resolved.addresses.isEmpty,
            durationMs: resolved.durationMs,
            detail: resolved.error
        )
        let dnsInfo = DNSInfo(durationMs: resolved.durationMs, addresses: resolved.addresses)
        return TracePayload(
            ok: step.ok,
            mode: .dns,
            target: target,
            steps: [step],
            dns: dnsInfo,
            http: nil,
            tls: nil,
            timings: Timings(dnsMs: resolved.durationMs, tcpMs: nil, tlsMs: nil, ttfbMs: nil, totalMs: resolved.durationMs),
            verbose: VerboseBuilder.dns(target: target, dns: dnsInfo, error: resolved.error),
            error: step.ok ? nil : (resolved.error ?? "dns-failed"),
            message: step.ok ? nil : (resolved.error ?? "DNS lookup failed")
        )
    }

    private static func probeFull(target: ConnectionTraceTarget, timeout: TimeInterval) async -> TracePayload {
        guard let url = target.url else {
            return TracePayload(
                ok: false,
                mode: .full,
                target: target,
                steps: [],
                dns: nil,
                http: nil,
                tls: nil,
                timings: Timings(dnsMs: nil, tcpMs: nil, tlsMs: nil, ttfbMs: nil, totalMs: nil),
                verbose: ["* Invalid URL"],
                error: "invalid-target",
                message: "Invalid URL"
            )
        }

        async let resolvedTask = resolveDNS(for: target, timeout: timeout)
        let runner = HTTPTraceRunner(url: url, timeout: timeout)
        let outcome = await runner.run()
        let resolved = await resolvedTask

        let dnsMs = outcome.timings.dnsMs ?? resolved.durationMs
        let dnsInfo = DNSInfo(
            durationMs: dnsMs,
            addresses: resolved.addresses.isEmpty
                ? (outcome.remoteAddress.map { [["address": $0, "family": $0.contains(":") ? "ipv6" : "ipv4"]] } ?? [])
                : resolved.addresses
        )
        let timings = Timings(
            dnsMs: dnsMs,
            tcpMs: outcome.timings.tcpMs,
            tlsMs: outcome.timings.tlsMs,
            ttfbMs: outcome.timings.ttfbMs,
            totalMs: outcome.timings.totalMs
        )

        var steps: [TraceStep] = []
        let dnsOK = resolved.error == nil && !dnsInfo.addresses.isEmpty
        steps.append(
            TraceStep(
                id: "dns",
                ok: dnsOK || outcome.timings.dnsMs != nil || target.isIPLiteral,
                durationMs: dnsMs,
                detail: target.isIPLiteral ? "literal" : resolved.error
            )
        )

        if let tcpMs = timings.tcpMs {
            steps.append(TraceStep(id: "tcp", ok: true, durationMs: tcpMs, detail: outcome.remoteAddress))
        } else if outcome.reachedConnect || outcome.error != nil {
            steps.append(TraceStep(id: "tcp", ok: false, durationMs: nil, detail: outcome.error))
        }

        if url.scheme?.lowercased() == "https" {
            if let tlsMs = timings.tlsMs {
                steps.append(TraceStep(id: "tls", ok: true, durationMs: tlsMs, detail: outcome.tls?.protocolName))
            } else if outcome.reachedTLS || outcome.error != nil {
                steps.append(TraceStep(id: "tls", ok: false, durationMs: nil, detail: outcome.error))
            }
        }

        if let status = outcome.http?.status {
            steps.append(
                TraceStep(
                    id: "http",
                    ok: (200..<500).contains(status),
                    durationMs: timings.ttfbMs,
                    detail: "HTTP \(status)"
                )
            )
        } else if outcome.reachedHTTP || outcome.error != nil {
            steps.append(TraceStep(id: "http", ok: false, durationMs: nil, detail: outcome.error))
        }

        let ok = outcome.http?.status != nil
        return TracePayload(
            ok: ok,
            mode: .full,
            target: target,
            steps: steps,
            dns: dnsInfo,
            http: outcome.http,
            tls: outcome.tls,
            timings: timings,
            verbose: VerboseBuilder.full(
                target: target,
                dns: dnsInfo,
                http: outcome.http,
                tls: outcome.tls,
                timings: timings,
                error: ok ? nil : outcome.error,
                message: ok ? nil : outcome.message
            ),
            error: ok ? nil : (outcome.error ?? "failed"),
            message: ok ? nil : (outcome.message ?? outcome.error)
        )
    }

    private static func resolveDNS(
        for target: ConnectionTraceTarget,
        timeout: TimeInterval
    ) async -> (addresses: [[String: String]], durationMs: Double, error: String?) {
        if target.isIPLiteral {
            let family = target.host.contains(":") ? "ipv6" : "ipv4"
            return ([["address": stripBrackets(target.host), "family": family]], 0, nil)
        }
        return await resolveHost(target.host, timeout: min(timeout, 8))
    }

    private static func resolveHost(
        _ host: String,
        timeout: TimeInterval
    ) async -> (addresses: [[String: String]], durationMs: Double, error: String?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let started = Date()
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var resultPointer: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &resultPointer)
                let durationMs = Date().timeIntervalSince(started) * 1_000
                defer {
                    if let resultPointer {
                        freeaddrinfo(resultPointer)
                    }
                }

                guard status == 0, let first = resultPointer else {
                    let message = String(cString: gai_strerror(status))
                    continuation.resume(returning: ([], durationMs, message))
                    return
                }

                var addresses: [[String: String]] = []
                var seen = Set<String>()
                var current: UnsafeMutablePointer<addrinfo>? = first
                while let item = current {
                    if let address = numericHost(from: item.pointee) {
                        let family = item.pointee.ai_family == AF_INET6 ? "ipv6" : "ipv4"
                        let key = "\(family)|\(address)"
                        if seen.insert(key).inserted {
                            addresses.append(["address": address, "family": family])
                        }
                    }
                    current = item.pointee.ai_next
                }
                _ = timeout
                continuation.resume(returning: (addresses, durationMs, addresses.isEmpty ? "No addresses" : nil))
            }
        }
    }

    private static func numericHost(from info: addrinfo) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            info.ai_addr,
            socklen_t(info.ai_addrlen),
            &buffer,
            socklen_t(buffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func stripBrackets(_ host: String) -> String {
        if host.hasPrefix("["), host.hasSuffix("]") {
            return String(host.dropFirst().dropLast())
        }
        return host
    }
}

private struct TraceStep {
    let id: String
    let ok: Bool
    let durationMs: Double?
    let detail: String?
}

private struct DNSInfo {
    let durationMs: Double
    let addresses: [[String: String]]
}

private struct HTTPInfo {
    let method: String
    let status: Int?
    let statusText: String?
    let httpVersion: String?
    let remoteAddress: String?
    let remotePort: Int?
    let localAddress: String?
    let localPort: Int?
    let requestHeaders: [(String, String)]
    let responseHeaders: [(String, String)]
    let reusedConnection: Bool?
    let proxyConnection: Bool?
}

private struct TLSInfo {
    let protocolName: String?
    let cipher: String?
    let subject: String?
    let issuer: String?
    let notBefore: String?
    let notAfter: String?
    let san: [String]
}

private struct Timings {
    let dnsMs: Double?
    let tcpMs: Double?
    let tlsMs: Double?
    let ttfbMs: Double?
    let totalMs: Double?
}

private struct TracePayload {
    let ok: Bool
    let mode: ConnectionTraceMode
    let target: ConnectionTraceTarget
    let steps: [TraceStep]
    let dns: DNSInfo?
    let http: HTTPInfo?
    let tls: TLSInfo?
    let timings: Timings
    let verbose: [String]
    let error: String?
    let message: String?

    func asDictionary() -> [String: Any] {
        var payload: [String: Any] = [
            "ok": ok,
            "mode": mode.rawValue,
            "input": target.input,
            "host": target.host,
            "port": target.port,
            "scheme": target.scheme,
            "verbose": verbose,
            "steps": steps.map { step -> [String: Any] in
                var item: [String: Any] = [
                    "id": step.id,
                    "ok": step.ok,
                ]
                if let durationMs = step.durationMs { item["durationMs"] = durationMs }
                if let detail = step.detail { item["detail"] = detail }
                return item
            },
        ]
        if let url = target.url?.absoluteString {
            payload["url"] = url
        }
        var timingPayload: [String: Any] = [:]
        if let value = timings.dnsMs { timingPayload["dnsMs"] = value }
        if let value = timings.tcpMs { timingPayload["tcpMs"] = value }
        if let value = timings.tlsMs { timingPayload["tlsMs"] = value }
        if let value = timings.ttfbMs { timingPayload["ttfbMs"] = value }
        if let value = timings.totalMs { timingPayload["totalMs"] = value }
        payload["timings"] = timingPayload
        if let dns {
            payload["dns"] = [
                "durationMs": dns.durationMs,
                "addresses": dns.addresses,
            ] as [String: Any]
        }
        if let http {
            var httpPayload: [String: Any] = [
                "method": http.method,
                "requestHeaders": http.requestHeaders.map { ["name": $0.0, "value": $0.1] },
                "responseHeaders": http.responseHeaders.map { ["name": $0.0, "value": $0.1] },
            ]
            if let status = http.status { httpPayload["status"] = status }
            if let statusText = http.statusText { httpPayload["statusText"] = statusText }
            if let httpVersion = http.httpVersion { httpPayload["httpVersion"] = httpVersion }
            if let remoteAddress = http.remoteAddress { httpPayload["remoteAddress"] = remoteAddress }
            if let remotePort = http.remotePort { httpPayload["remotePort"] = remotePort }
            if let localAddress = http.localAddress { httpPayload["localAddress"] = localAddress }
            if let localPort = http.localPort { httpPayload["localPort"] = localPort }
            if let reusedConnection = http.reusedConnection { httpPayload["reusedConnection"] = reusedConnection }
            if let proxyConnection = http.proxyConnection { httpPayload["proxyConnection"] = proxyConnection }
            payload["http"] = httpPayload
        }
        if let tls {
            var tlsPayload: [String: Any] = [:]
            if let protocolName = tls.protocolName { tlsPayload["protocol"] = protocolName }
            if let cipher = tls.cipher { tlsPayload["cipher"] = cipher }
            if let subject = tls.subject { tlsPayload["subject"] = subject }
            if let issuer = tls.issuer { tlsPayload["issuer"] = issuer }
            if let notBefore = tls.notBefore { tlsPayload["notBefore"] = notBefore }
            if let notAfter = tls.notAfter { tlsPayload["notAfter"] = notAfter }
            if !tls.san.isEmpty { tlsPayload["san"] = tls.san }
            if !tlsPayload.isEmpty { payload["tls"] = tlsPayload }
        }
        if let error { payload["error"] = error }
        if let message { payload["message"] = message }
        return payload
    }
}

private enum VerboseBuilder {
    static func dns(target: ConnectionTraceTarget, dns: DNSInfo, error: String?) -> [String] {
        var lines: [String] = []
        if target.isIPLiteral {
            lines.append("* Host \(target.host) is an IP literal")
        } else {
            lines.append("* Host \(target.host) was resolved.")
        }
        for item in dns.addresses {
            let family = item["family"] == "ipv6" ? "IPv6" : "IPv4"
            if let address = item["address"] {
                lines.append("* \(family): \(address)")
            }
        }
        if let error, !error.isEmpty {
            lines.append("* DNS error: \(error)")
        } else {
            lines.append(String(format: "* DNS lookup finished in %.1f ms", dns.durationMs))
        }
        return lines
    }

    static func full(
        target: ConnectionTraceTarget,
        dns: DNSInfo,
        http: HTTPInfo?,
        tls: TLSInfo?,
        timings: Timings,
        error: String?,
        message: String?
    ) -> [String] {
        var lines = Self.dns(target: target, dns: dns, error: nil as String?)
        let remote = http?.remoteAddress ?? dns.addresses.first?["address"]
        let remotePort = http?.remotePort ?? target.port

        if let remote {
            lines.append("* Trying \(formatEndpoint(remote, port: remotePort))...")
        }

        if let remote, http?.remoteAddress != nil {
            lines.append("* Connected to \(target.host) (\(remote)) port \(remotePort)")
        }
        if let local = http?.localAddress, let localPort = http?.localPort {
            lines.append("* Local address: \(formatEndpoint(local, port: localPort))")
        }
        if http?.reusedConnection == true {
            lines.append("* Connection was reused")
        }
        if http?.proxyConnection == true {
            lines.append("* Connection used a proxy")
        }

        if target.scheme == "https" {
            if let protocolName = tls?.protocolName, let cipher = tls?.cipher {
                lines.append("* SSL connection using \(protocolName) / \(cipher)")
            } else if let protocolName = tls?.protocolName {
                lines.append("* SSL connection using \(protocolName)")
            }
            if tls != nil {
                lines.append("* Server certificate:")
                if let subject = tls?.subject { lines.append("*  subject: \(subject)") }
                if let notBefore = tls?.notBefore { lines.append("*  start date: \(notBefore)") }
                if let notAfter = tls?.notAfter { lines.append("*  expire date: \(notAfter)") }
                if let issuer = tls?.issuer { lines.append("*  issuer: \(issuer)") }
                if let san = tls?.san, !san.isEmpty {
                    lines.append("*  subjectAltName: \(san.joined(separator: ", "))")
                }
            }
        }

        let pathQuery: String = {
            guard let url = target.url else { return "/" }
            var value = url.path.isEmpty ? "/" : url.path
            if let query = url.query, !query.isEmpty {
                value += "?\(query)"
            }
            return value
        }()
        let version = http?.httpVersion ?? "HTTP/1.1"
        let method = http?.method ?? "HEAD"
        lines.append("> \(method) \(pathQuery) \(version)")
        for (name, value) in http?.requestHeaders ?? [] {
            lines.append("> \(name): \(value)")
        }
        lines.append(">")

        if let status = http?.status {
            let text = http?.statusText.map { " \($0)" } ?? ""
            lines.append("< \(version) \(status)\(text)")
            for (name, value) in http?.responseHeaders ?? [] {
                lines.append("< \(name): \(value)")
            }
        } else if let message {
            lines.append("* \(message)")
        } else if let error {
            lines.append("* error: \(error)")
        }

        var timingBits: [String] = []
        if let ms = timings.dnsMs { timingBits.append(String(format: "DNS %.1fms", ms)) }
        if let ms = timings.tcpMs { timingBits.append(String(format: "TCP %.1fms", ms)) }
        if let ms = timings.tlsMs { timingBits.append(String(format: "TLS %.1fms", ms)) }
        if let ms = timings.ttfbMs { timingBits.append(String(format: "TTFB %.1fms", ms)) }
        if let ms = timings.totalMs { timingBits.append(String(format: "total %.1fms", ms)) }
        if !timingBits.isEmpty {
            lines.append("* Timing: \(timingBits.joined(separator: " · "))")
        }
        return lines
    }

    private static func formatEndpoint(_ host: String, port: Int) -> String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}

private final class HTTPTraceRunner: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let url: URL
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var metrics: URLSessionTaskMetrics?
    private var tls: TLSInfo?
    private var statusCode: Int?
    private var statusText: String?
    private var responseHeaders: [(String, String)] = []
    private var finished = false

    struct Outcome {
        var error: String?
        var message: String?
        var dns: DNSInfo?
        var http: HTTPInfo?
        var tls: TLSInfo?
        var timings: Timings
        var remoteAddress: String?
        var reachedConnect = false
        var reachedTLS = false
        var reachedHTTP = false
    }

    init(url: URL, timeout: TimeInterval) {
        self.url = url
        self.timeout = timeout
    }

    func run() async -> Outcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            config.waitsForConnectivity = false
            config.httpAdditionalHeaders = [
                "Accept": "*/*",
                "User-Agent": "MachKit-ConnectionTrace/1.0",
            ]
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
            request.httpMethod = "HEAD"
            request.setValue("MachKit-ConnectionTrace/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            if let host = url.host {
                let port = url.port
                if let port, port != 80, port != 443 {
                    request.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
                } else {
                    request.setValue(host, forHTTPHeaderField: "Host")
                }
            }
            session.dataTask(with: request).resume()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            tls = extractTLS(from: trust)
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            statusCode = http.statusCode
            statusText = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            responseHeaders = normalizedHeaders(http.allHeaderFields)
        }
        completionHandler(.cancel)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(session: session, task: task, error: error)
    }

    private func finish(session: URLSession, task: URLSessionTask, error: Error?) {
        guard !finished else { return }
        finished = true
        defer { session.finishTasksAndInvalidate() }

        let transaction = metrics?.transactionMetrics.last
        let dnsMs = durationMs(from: transaction?.domainLookupStartDate, to: transaction?.domainLookupEndDate)
        let tcpMs = durationMs(from: transaction?.connectStartDate, to: transaction?.connectEndDate)
        let tlsMs = durationMs(from: transaction?.secureConnectionStartDate, to: transaction?.secureConnectionEndDate)
        let ttfbMs = durationMs(from: transaction?.requestStartDate, to: transaction?.responseStartDate)
        let totalMs = durationMs(from: transaction?.fetchStartDate, to: transaction?.responseEndDate)
            ?? durationMs(from: transaction?.fetchStartDate, to: Date())

        let remote = transaction?.remoteAddress
        let cancelled = (error as? URLError)?.code == .cancelled
        let failed = error != nil && !cancelled
        let status = statusCode ?? (task.response as? HTTPURLResponse)?.statusCode
        if responseHeaders.isEmpty, let http = task.response as? HTTPURLResponse {
            responseHeaders = normalizedHeaders(http.allHeaderFields)
        }

        var tlsInfo = tls
        if tlsInfo != nil || url.scheme?.lowercased() == "https" {
            let protocolName = tlsProtocolName(transaction?.negotiatedTLSProtocolVersion) ?? tlsInfo?.protocolName
            let cipher = tlsCipherName(transaction?.negotiatedTLSCipherSuite) ?? tlsInfo?.cipher
            tlsInfo = TLSInfo(
                protocolName: protocolName,
                cipher: cipher,
                subject: tlsInfo?.subject,
                issuer: tlsInfo?.issuer,
                notBefore: tlsInfo?.notBefore,
                notAfter: tlsInfo?.notAfter,
                san: tlsInfo?.san ?? []
            )
        }

        let request = task.originalRequest ?? task.currentRequest
        let requestHeaders = normalizedHeaders(request?.allHTTPHeaderFields ?? [:])
        let httpInfo = HTTPInfo(
            method: request?.httpMethod ?? "HEAD",
            status: status,
            statusText: status.map { HTTPURLResponse.localizedString(forStatusCode: $0) },
            httpVersion: transaction?.networkProtocolName,
            remoteAddress: remote,
            remotePort: transaction?.remotePort,
            localAddress: transaction?.localAddress,
            localPort: transaction?.localPort,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            reusedConnection: transaction?.isReusedConnection,
            proxyConnection: transaction?.isProxyConnection
        )

        var outcome = Outcome(
            error: nil,
            message: nil,
            dns: dnsMs.map { DNSInfo(durationMs: $0, addresses: remote.map { [["address": $0, "family": $0.contains(":") ? "ipv6" : "ipv4"]] } ?? []) },
            http: httpInfo,
            tls: tlsInfo,
            timings: Timings(dnsMs: dnsMs, tcpMs: tcpMs, tlsMs: tlsMs, ttfbMs: ttfbMs, totalMs: totalMs),
            remoteAddress: remote,
            reachedConnect: transaction?.connectStartDate != nil,
            reachedTLS: transaction?.secureConnectionStartDate != nil,
            reachedHTTP: status != nil || transaction?.responseStartDate != nil
        )

        if failed {
            outcome.error = "request-failed"
            outcome.message = error?.localizedDescription ?? "Request failed"
        } else if status == nil {
            outcome.error = "no-response"
            outcome.message = "No HTTP response"
        }

        continuation?.resume(returning: outcome)
        continuation = nil
    }

    private func durationMs(from start: Date?, to end: Date?) -> Double? {
        guard let start, let end else { return nil }
        return max(0, end.timeIntervalSince(start) * 1_000)
    }

    private func normalizedHeaders(_ raw: [AnyHashable: Any]) -> [(String, String)] {
        raw.compactMap { key, value in
            guard let name = key as? String else { return nil }
            return (name, String(describing: value))
        }
        .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private func normalizedHeaders(_ raw: [String: String]) -> [(String, String)] {
        raw.map { ($0.key, $0.value) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private func extractTLS(from trust: SecTrust) -> TLSInfo {
        guard #available(macOS 12.0, *),
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return TLSInfo(protocolName: nil, cipher: nil, subject: nil, issuer: nil, notBefore: nil, notAfter: nil, san: [])
        }

        let subject = SecCertificateCopySubjectSummary(leaf) as String?
        let issuer = chain.count > 1 ? (SecCertificateCopySubjectSummary(chain[1]) as String?) : certificateIssuer(leaf)
        let dates = certificateDates(leaf)
        return TLSInfo(
            protocolName: nil,
            cipher: nil,
            subject: subject,
            issuer: issuer,
            notBefore: dates.notBefore,
            notAfter: dates.notAfter,
            san: certificateSAN(leaf)
        )
    }

    private func certificateIssuer(_ certificate: SecCertificate) -> String? {
        guard let values = SecCertificateCopyValues(certificate, [kSecOIDX509V1IssuerName] as CFArray, nil) as? [CFString: Any],
              let issuer = values[kSecOIDX509V1IssuerName] as? [CFString: Any],
              let nameTree = issuer[kSecPropertyKeyValue] else {
            return nil
        }
        return flattenDirectoryName(nameTree)
    }

    private func certificateDates(_ certificate: SecCertificate) -> (notBefore: String?, notAfter: String?) {
        guard let values = SecCertificateCopyValues(
            certificate,
            [kSecOIDX509V1ValidityNotBefore, kSecOIDX509V1ValidityNotAfter] as CFArray,
            nil
        ) as? [CFString: Any] else {
            return (nil, nil)
        }
        return (
            formatCertDate(values[kSecOIDX509V1ValidityNotBefore]),
            formatCertDate(values[kSecOIDX509V1ValidityNotAfter])
        )
    }

    private func certificateSAN(_ certificate: SecCertificate) -> [String] {
        guard let values = SecCertificateCopyValues(certificate, [kSecOIDSubjectAltName] as CFArray, nil) as? [CFString: Any],
              let san = values[kSecOIDSubjectAltName] as? [CFString: Any],
              let list = san[kSecPropertyKeyValue] as? [[CFString: Any]] else {
            return []
        }
        return list.compactMap { item in
            (item[kSecPropertyKeyValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private func flattenDirectoryName(_ value: Any) -> String? {
        if let text = value as? String { return text }
        guard let items = value as? [[CFString: Any]] else { return nil }
        let parts = items.compactMap { item -> String? in
            guard let label = item[kSecPropertyKeyLabel] as? String,
                  let content = item[kSecPropertyKeyValue] as? String else { return nil }
            return "\(label)=\(content)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func formatCertDate(_ raw: Any?) -> String? {
        guard let entry = raw as? [CFString: Any],
              let number = entry[kSecPropertyKeyValue] as? NSNumber else { return nil }
        // Absolute time used by Security framework is seconds since 2001-01-01.
        let date = Date(timeIntervalSinceReferenceDate: number.doubleValue)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func tlsProtocolName(_ value: tls_protocol_version_t?) -> String? {
        guard let value else { return nil }
        switch value {
        case .TLSv10: return "TLSv1.0"
        case .TLSv11: return "TLSv1.1"
        case .TLSv12: return "TLSv1.2"
        case .TLSv13: return "TLSv1.3"
        case .DTLSv10: return "DTLSv1.0"
        case .DTLSv12: return "DTLSv1.2"
        default: return String(format: "TLS(0x%04x)", value.rawValue)
        }
    }

    private func tlsCipherName(_ value: tls_ciphersuite_t?) -> String? {
        guard let value else { return nil }
        switch value {
        case .AES_128_GCM_SHA256: return "TLS_AES_128_GCM_SHA256"
        case .AES_256_GCM_SHA384: return "TLS_AES_256_GCM_SHA384"
        case .CHACHA20_POLY1305_SHA256: return "TLS_CHACHA20_POLY1305_SHA256"
        case .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256: return "ECDHE-ECDSA-AES128-GCM-SHA256"
        case .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384: return "ECDHE-ECDSA-AES256-GCM-SHA384"
        case .ECDHE_RSA_WITH_AES_128_GCM_SHA256: return "ECDHE-RSA-AES128-GCM-SHA256"
        case .ECDHE_RSA_WITH_AES_256_GCM_SHA384: return "ECDHE-RSA-AES256-GCM-SHA384"
        case .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE-ECDSA-CHACHA20-POLY1305"
        case .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE-RSA-CHACHA20-POLY1305"
        default: return String(format: "0x%04x", value.rawValue)
        }
    }
}
