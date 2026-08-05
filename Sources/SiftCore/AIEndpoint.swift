import Foundation

public enum AIEndpointBuilder {
    public static func chatCompletionsURL(baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased() else { return nil }
        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard components.scheme == "https" || (components.scheme == "http" && isLoopback) else { return nil }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.hasSuffix("chat/completions") {
            path = path.isEmpty ? "chat/completions" : "\(path)/chat/completions"
        }
        components.path = "/\(path)"
        return components.url
    }
}
