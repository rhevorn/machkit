import Foundation
import SiftCore

enum AIClientError: LocalizedError {
    case incompleteConfiguration
    case invalidBaseURL
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration:
            "Configure Base URL, API Key, and a model in Settings first.".localized
        case .invalidBaseURL:
            "The configured Base URL is invalid.".localized
        case .invalidResponse:
            "The AI service returned an unreadable response.".localized
        case .requestFailed(let message):
            message
        }
    }
}

struct AIClient: Sendable {
    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct Request: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            let message: Message
        }
        let choices: [Choice]
    }

    @MainActor
    func cleanupInsight(summary: String, language: String) async throws -> String {
        let configuration = AIConfiguration.current
        guard configuration.isReady else { throw AIClientError.incompleteConfiguration }
        guard let endpoint = AIEndpointBuilder.chatCompletionsURL(baseURL: configuration.baseURL) else {
            throw AIClientError.invalidBaseURL
        }

        let systemPrompt = """
        You are Sift's cleanup advisor for macOS. Explain the scan in concise, practical language. Separate safe-to-clean items from items that deserve review. Never claim that AI can delete files, bypass Sift safety checks, or inspect file contents. Respond in \(language).
        """
        let userPrompt = """
        Review this aggregate cleanup scan. It contains category names, counts, sizes, and deterministic risk labels only; no file contents are included.

        \(summary)
        """
        let payload = Request(
            model: configuration.model,
            messages: [Message(role: "system", content: systemPrompt), Message(role: "user", content: userPrompt)],
            temperature: 0.2
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AIClientError.requestFailed(String(body.prefix(500)))
        }
        guard let content = try JSONDecoder().decode(Response.self, from: data).choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
