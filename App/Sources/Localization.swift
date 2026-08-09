import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        let language = AppLanguage.selected
        if language == .system {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: AppLanguage.selected.locale, arguments: arguments)
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
