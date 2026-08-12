import Foundation
import SwiftUI

enum AppPreferenceKey {
    static let language = "appLanguage"
    static let appearance = "appAppearance"
    static let showMenuBar = "showMenuBar"
    static let menuBarCloseBehaviorRepair = "menuBarCloseBehaviorRepairV1"
}

enum AppDataResetter {
    private static let resetMarkerName = ".dev.sift.app-reset-on-launch"

    static func scheduleReset(fileManager: FileManager = .default) throws {
        let markerURL = resetMarkerURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: markerURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: markerURL, options: .atomic)
    }

    static func performScheduledResetIfNeeded(fileManager: FileManager = .default) {
        let markerURL = resetMarkerURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: markerURL.path) else { return }
        do {
            try clear(fileManager: fileManager)
            try fileManager.removeItem(at: markerURL)
        } catch {
            // Keep the marker so the reset is retried on the next launch.
        }
    }

    static func clear(fileManager: FileManager = .default, defaults: UserDefaults = .standard) throws {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "dev.sift.app"
        let home = fileManager.homeDirectoryForCurrentUser
        let paths = [
            home.appending(path: "Library/Application Support/Sift"),
            home.appending(path: "Library/Caches/\(bundleIdentifier)"),
            home.appending(path: "Library/WebKit/\(bundleIdentifier)"),
            home.appending(path: "Library/HTTPStorages/\(bundleIdentifier)"),
            home.appending(path: "Library/Saved Application State/\(bundleIdentifier).savedState"),
            home.appending(path: "Library/Cookies/\(bundleIdentifier).binarycookies"),
            home.appending(path: "Library/Logs/Sift")
        ]

        for url in paths where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()
    }

    private static func resetMarkerURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return base.appending(path: resetMarkerName)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case brazilianPortuguese = "pt-BR"
    case russian = "ru"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Follow System".localized
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .brazilianPortuguese: "Português (Brasil)"
        case .russian: "Русский"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .traditionalChinese: Locale(identifier: "zh-Hant")
        case .english: Locale(identifier: "en")
        case .japanese: Locale(identifier: "ja")
        case .korean: Locale(identifier: "ko")
        case .spanish: Locale(identifier: "es")
        case .french: Locale(identifier: "fr")
        case .german: Locale(identifier: "de")
        case .brazilianPortuguese: Locale(identifier: "pt-BR")
        case .russian: Locale(identifier: "ru")
        }
    }

    static var selected: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferenceKey.language) ?? system.rawValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
