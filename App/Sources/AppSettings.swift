import AppKit
import Foundation
import SwiftUI

enum AppPreferenceKey {
    static let language = "appLanguage"
    static let appearance = "appAppearance"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .simplifiedChinese: "简体中文"
        case .english: "英文"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
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
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
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

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("设置").font(.title3.weight(.semibold))
                    Text("调整 Sift 的语言和外观")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 16) {
                GridRow {
                    Label("语言", systemImage: "character.bubble")
                        .frame(width: 92, alignment: .leading)
                    Picker("语言", selection: $languageRawValue) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.title.localized).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                GridRow {
                    Label("外观", systemImage: "circle.lefthalf.filled")
                        .frame(width: 92, alignment: .leading)
                    Picker("外观", selection: $appearanceRawValue) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title.localized).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                }
            }

            Text("更改会立即应用到所有 Sift 窗口。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.locale, language.locale)
        .preferredColorScheme(appearance.colorScheme)
    }
}
