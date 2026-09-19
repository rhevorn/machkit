import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        string(key, language: AppLanguage.selected)
    }

    static func string(_ key: String, language: AppLanguage) -> String {
        if language == .system {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// English source key plus every explicit app language translation (for search).
    static func allVariants(for key: String) -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { return }
            values.append(trimmed)
        }
        append(key)
        for language in AppLanguage.allCases where language != .system {
            append(string(key, language: language))
        }
        return values
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: AppLanguage.selected.locale, arguments: arguments)
    }

    /// Locale-aware percent string (e.g. `42%` / `42 %`) for embedding as `%@`.
    /// Pass values already on a 0…100 scale. The sign is placed by the locale,
    /// so callers must not append or prepend `%` themselves.
    static func percent(_ value: Double, fractionDigits: Int = 0) -> String {
        (value / 100).formatted(
            .percent
                .precision(.fractionLength(fractionDigits))
                .locale(AppLanguage.selected.locale)
        )
    }

    static func percent<Value: BinaryInteger>(_ value: Value, fractionDigits: Int = 0) -> String {
        percent(Double(value), fractionDigits: fractionDigits)
    }

    static func diagnostic(_ message: String) -> String {
        let dynamicPrefixes: [(prefix: String, key: String)] = [
            ("Unable to read active connections: ", "Unable to read active connections: %@"),
            ("Per-process traffic is unavailable: ", "Per-process traffic is unavailable: %@"),
            ("Unable to run system port tool: ", "Unable to run system port tool: %@"),
            ("Failed to read port: ", "Failed to read port: %@"),
            ("Unable to delete residue from Trash: ", "Unable to delete residue from Trash: %@")
        ]
        for item in dynamicPrefixes where message.hasPrefix(item.prefix) {
            return format(item.key, String(message.dropFirst(item.prefix.count)))
        }
        return string(message)
    }
}

extension String {
    var localized: String { L10n.string(self) }
}
