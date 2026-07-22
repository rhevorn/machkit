import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        switch AppLanguage.selected {
        case .simplifiedChinese:
            return key
        case .english:
            guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return key }
            return bundle.localizedString(forKey: key, value: key, table: nil)
        case .system:
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: AppLanguage.selected.locale, arguments: arguments)
    }
}

extension String {
    var localized: String { L10n.string(self) }
}
