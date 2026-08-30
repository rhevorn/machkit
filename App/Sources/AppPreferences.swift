import AppKit
import Foundation
import SwiftUI

enum AppPreferenceKey {
    static let language = "appLanguage"
    static let appearance = "appAppearance"
    static let showMenuBar = "showMenuBar"
    static let menuBarCloseBehaviorRepair = "menuBarCloseBehaviorRepairV1"
}

enum AppDataResetter {
    private static let resetMarkerName = ".app.machkit.mac-reset-on-launch"

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
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app.machkit.mac"
        let home = fileManager.homeDirectoryForCurrentUser
        let paths = [
            home.appending(path: "Library/Application Support/MachKit"),
            home.appending(path: "Library/Caches/\(bundleIdentifier)"),
            home.appending(path: "Library/WebKit/\(bundleIdentifier)"),
            home.appending(path: "Library/HTTPStorages/\(bundleIdentifier)"),
            home.appending(path: "Library/Saved Application State/\(bundleIdentifier).savedState"),
            home.appending(path: "Library/Cookies/\(bundleIdentifier).binarycookies"),
            home.appending(path: "Library/Logs/MachKit")
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

    /// Never return `nil` for SwiftUI `.preferredColorScheme`. Passing `nil` after an
    /// explicit light/dark override often leaves the window stuck until focus changes.
    @MainActor
    var resolvedColorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            // Read the OS preference directly. `NSApp.effectiveAppearance` can still
            // reflect a previous light/dark override during the same update cycle.
            return Self.systemPrefersDark ? .dark : .light
        }
    }

    private static var systemPrefersDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Clear AppKit overrides so System can follow macOS. Light/Dark set an explicit app appearance.
    @MainActor
    func applyToApplication() {
        switch self {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
            for window in NSApp.windows {
                window.appearance = nil
            }
        }
    }

    @MainActor
    static func applyStoredPreference(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: AppPreferenceKey.appearance) ?? AppAppearance.system.rawValue
        (AppAppearance(rawValue: raw) ?? .system).applyToApplication()
    }
}

/// Tracks macOS light/dark changes while the app preference is System.
@MainActor
final class SystemAppearanceObserver: ObservableObject {
    @Published private(set) var refreshToken = 0
    /// Mutation only happens on the main actor; deinit may tear the token down.
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshToken &+= 1
                let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.appearance) ?? ""
                if (AppAppearance(rawValue: raw) ?? .system) == .system {
                    AppAppearance.system.applyToApplication()
                }
            }
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
