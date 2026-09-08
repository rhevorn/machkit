import Foundation

public struct CurlLabRunResult: Sendable {
    public let ok: Bool
    public let statusCode: Int?
    public let durationMs: Double?
    public let effectiveURL: String?
    public let headers: String
    public let body: String
    public let bodyTruncated: Bool
    public let curlExitCode: Int32?
    public let error: String?

    public func asDictionary() -> [String: Any] {
        [
            "ok": ok,
            "statusCode": statusCode as Any? ?? NSNull(),
            "durationMs": durationMs as Any? ?? NSNull(),
            "effectiveURL": effectiveURL as Any? ?? NSNull(),
            "headers": headers,
            "body": body,
            "bodyTruncated": bodyTruncated,
            "curlExitCode": curlExitCode as Any? ?? NSNull(),
            "error": error as Any? ?? NSNull()
        ]
    }
}

/// Executes a structured cURL Lab request via `/usr/bin/curl` (argument array, never a shell string).
public enum CurlLabRunner {
    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let maxResponseBytes = 512 * 1_024
    public static let maxUploadBytes = 50 * 1_024 * 1_024

    public static func run(
        payloadJSON: Data,
        timeout: TimeInterval = defaultTimeoutSeconds
    ) async -> CurlLabRunResult {
        do {
            guard let object = try JSONSerialization.jsonObject(with: payloadJSON) as? [String: Any] else {
                throw RunnerError.invalidURL
            }
            let request = try Request(payload: object)
            return try await execute(request, timeout: max(5, min(timeout, 120)))
        } catch let error as RunnerError {
            return CurlLabRunResult(
                ok: false,
                statusCode: nil,
                durationMs: nil,
                effectiveURL: nil,
                headers: "",
                body: "",
                bodyTruncated: false,
                curlExitCode: nil,
                error: error.code
            )
        } catch {
            return CurlLabRunResult(
                ok: false,
                statusCode: nil,
                durationMs: nil,
                effectiveURL: nil,
                headers: "",
                body: "",
                bodyTruncated: false,
                curlExitCode: nil,
                error: error.localizedDescription
            )
        }
    }

    public static func run(
        payload: [String: Any],
        timeout: TimeInterval = defaultTimeoutSeconds
    ) async -> CurlLabRunResult {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return CurlLabRunResult(
                ok: false,
                statusCode: nil,
                durationMs: nil,
                effectiveURL: nil,
                headers: "",
                body: "",
                bodyTruncated: false,
                curlExitCode: nil,
                error: "invalid-url"
            )
        }
        return await run(payloadJSON: data, timeout: timeout)
    }

    private enum RunnerError: Error {
        case emptyURL
        case invalidURL
        case unsupportedScheme
        case invalidMethod
        case missingFile(String)
        case fileTooLarge(String)

        var code: String {
            switch self {
            case .emptyURL: "empty-url"
            case .invalidURL: "invalid-url"
            case .unsupportedScheme: "unsupported-scheme"
            case .invalidMethod: "invalid-method"
            case .missingFile: "missing-file"
            case .fileTooLarge: "file-too-large"
            }
        }
    }

    private struct FormField {
        let key: String
        let value: String
        let kind: String
    }

    private struct Request {
        let method: String
        let url: URL
        let headers: [(String, String)]
        let bodyMode: String
        let body: String
        let formFields: [FormField]
        let insecure: Bool
        let followRedirects: Bool
        let compressed: Bool

        init(payload: [String: Any]) throws {
            let methodRaw = String(payload["method"] as? String ?? "GET").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let allowedMethods: Set<String> = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
            guard allowedMethods.contains(methodRaw) else { throw RunnerError.invalidMethod }
            method = methodRaw

            let urlText = String(payload["url"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !urlText.isEmpty else { throw RunnerError.emptyURL }
            guard let parsed = URL(string: urlText), let scheme = parsed.scheme?.lowercased() else {
                throw RunnerError.invalidURL
            }
            guard scheme == "http" || scheme == "https" else { throw RunnerError.unsupportedScheme }
            guard parsed.host != nil else { throw RunnerError.invalidURL }
            var url = parsed

            let queryItems = (payload["query"] as? [[String: Any]] ?? []).compactMap { item -> URLQueryItem? in
                let key = String(item["key"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return nil }
                return URLQueryItem(name: key, value: String(item["value"] as? String ?? ""))
            }
            if !queryItems.isEmpty, var components = URLComponents(url: parsed, resolvingAgainstBaseURL: false) {
                var existing = components.queryItems ?? []
                existing.append(contentsOf: queryItems)
                components.queryItems = existing
                if let withQuery = components.url {
                    url = withQuery
                }
            }
            self.url = url

            headers = (payload["headers"] as? [[String: Any]] ?? []).compactMap { item in
                let key = String(item["key"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return nil }
                return (key, String(item["value"] as? String ?? ""))
            }

            let mode = String(payload["bodyMode"] as? String ?? "none")
            bodyMode = ["none", "raw", "urlencoded", "formdata"].contains(mode) ? mode : "none"
            body = String(payload["body"] as? String ?? "")
            formFields = (payload["formFields"] as? [[String: Any]] ?? []).compactMap { item in
                let key = String(item["key"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return nil }
                let kind = String(item["kind"] as? String ?? "text") == "file" ? "file" : "text"
                return FormField(key: key, value: String(item["value"] as? String ?? ""), kind: kind)
            }
            insecure = payload["insecure"] as? Bool ?? false
            followRedirects = payload["followRedirects"] as? Bool ?? true
            compressed = payload["compressed"] as? Bool ?? false
        }
    }

    private static func execute(_ request: Request, timeout: TimeInterval) async throws -> CurlLabRunResult {
        let headerFile = FileManager.default.temporaryDirectory
            .appending(path: "machkit-curl-headers-\(UUID().uuidString).txt")
        let bodyFile = FileManager.default.temporaryDirectory
            .appending(path: "machkit-curl-body-\(UUID().uuidString).bin")
        defer {
            try? FileManager.default.removeItem(at: headerFile)
            try? FileManager.default.removeItem(at: bodyFile)
        }

        var arguments = [
            "--silent",
            "--show-error",
            "--dump-header", headerFile.path,
            "--output", bodyFile.path,
            "--write-out", "%{http_code}\n%{time_total}\n%{url_effective}",
            "--max-time", String(Int(timeout.rounded(.up))),
            "--request", request.method
        ]
        if request.insecure { arguments.append("--insecure") }
        if request.followRedirects { arguments.append("--location") }
        if request.compressed { arguments.append("--compressed") }

        for (key, value) in request.headers {
            if request.bodyMode == "formdata", key.lowercased() == "content-type" { continue }
            arguments.append(contentsOf: ["--header", "\(key): \(value)"])
        }

        switch request.bodyMode {
        case "raw":
            if !request.body.isEmpty, request.method != "GET", request.method != "HEAD" {
                arguments.append(contentsOf: ["--data-binary", request.body])
            }
        case "urlencoded":
            let fields = request.formFields.filter { $0.kind == "text" }
            if !fields.isEmpty, request.method != "GET", request.method != "HEAD" {
                let encoded = fields
                    .map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }
                    .joined(separator: "&")
                arguments.append(contentsOf: ["--data", encoded])
            }
        case "formdata":
            for field in request.formFields {
                if field.kind == "file" {
                    let path = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !path.isEmpty else { continue }
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                          !isDirectory.boolValue else {
                        throw RunnerError.missingFile(path)
                    }
                    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
                    if size > maxUploadBytes {
                        throw RunnerError.fileTooLarge(path)
                    }
                    arguments.append(contentsOf: ["--form", "\(field.key)=@\(path)"])
                } else {
                    arguments.append(contentsOf: ["--form", "\(field.key)=\(field.value)"])
                }
            }
        default:
            break
        }

        arguments.append(request.url.absoluteString)

        let output: SystemCommandOutput
        do {
            output = try SystemCommandRunner.run(
                executable: "/usr/bin/curl",
                arguments: arguments,
                timeout: timeout + 2
            )
        } catch let error as SystemCommandRunnerError {
            return CurlLabRunResult(
                ok: false,
                statusCode: nil,
                durationMs: nil,
                effectiveURL: request.url.absoluteString,
                headers: "",
                body: "",
                bodyTruncated: false,
                curlExitCode: nil,
                error: error == .cancelled ? "canceled" : "timeout"
            )
        }

        let writeOut = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = writeOut.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // write-out is last 3 lines when curl succeeds; stderr may prepend errors into the pipe.
        let trailing = Array(lines.suffix(3))
        let statusCode = trailing.count >= 1 ? Int(trailing[0]) : nil
        let durationSeconds = trailing.count >= 2 ? Double(trailing[1]) : nil
        let effectiveURL = trailing.count >= 3 ? trailing[2] : request.url.absoluteString

        let headersText = (try? String(contentsOf: headerFile, encoding: .utf8)) ?? ""
        let bodyData = (try? Data(contentsOf: bodyFile)) ?? Data()
        let truncated = bodyData.count > maxResponseBytes
        let clipped = truncated ? bodyData.prefix(maxResponseBytes) : bodyData
        let bodyText = decodeBody(clipped)

        let failed = output.status != 0 && statusCode == nil
        let error: String?
        if failed {
            let message = writeOut.trimmingCharacters(in: .whitespacesAndNewlines)
            error = message.isEmpty ? "curl-failed" : message
        } else {
            error = nil
        }

        return CurlLabRunResult(
            ok: !failed,
            statusCode: statusCode,
            durationMs: durationSeconds.map { $0 * 1_000 },
            effectiveURL: effectiveURL,
            headers: headersText.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText,
            bodyTruncated: truncated,
            curlExitCode: output.status,
            error: error
        )
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func decodeBody(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        return data.base64EncodedString()
    }
}
