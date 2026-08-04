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
}

extension String {
    var localized: String { L10n.string(self) }
}
