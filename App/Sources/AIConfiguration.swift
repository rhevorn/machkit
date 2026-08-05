import Foundation
import Security

enum AIKeychainError: LocalizedError {
    case operationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            return L10n.format("Unable to save API Key (error %d).", status)
        }
    }
}

@MainActor
enum AIKeychain {
    private static let service = "dev.sift.app.ai"
    private static let account = "api-key"
    private static var cachedValue: String?

    static func load() -> String {
        if let cachedValue { return cachedValue }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            cachedValue = ""
            return ""
        }
        cachedValue = value
        return value
    }

    static func save(_ value: String) -> Result<Void, AIKeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status: OSStatus
        if value.isEmpty {
            let deletionStatus = SecItemDelete(query as CFDictionary)
            status = deletionStatus == errSecItemNotFound ? errSecSuccess : deletionStatus
        } else {
            let attributes = [kSecValueData as String: Data(value.utf8)]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = Data(value.utf8)
                status = SecItemAdd(item as CFDictionary, nil)
            } else {
                status = updateStatus
            }
        }
        guard status == errSecSuccess else { return .failure(.operationFailed(status)) }
        cachedValue = value
        return .success(())
    }
}

struct AIConfiguration: Sendable {
    let baseURL: String
    let apiKey: String
    let model: String

    @MainActor
    static var current: AIConfiguration {
        let defaults = UserDefaults.standard
        return AIConfiguration(
            baseURL: defaults.string(forKey: AppPreferenceKey.aiBaseURL) ?? "https://api.openai.com/v1",
            apiKey: AIKeychain.load(),
            model: defaults.string(forKey: AppPreferenceKey.aiModel) ?? ""
        )
    }

    var isReady: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.isEmpty
            && !model.isEmpty
    }
}
