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

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "通用"
    case appearance = "外观"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "circle.lefthalf.filled"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "语言与地区"
        case .appearance: "显示模式"
        }
    }
}

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var selectedCategory: SettingsCategory = .general

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("设置").font(.system(size: 18, weight: .semibold))
                    Text("管理语言、外观与其他偏好设置")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            HStack(spacing: 0) {
                categoryList
                Divider()
                settingsDetail
            }
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue.localized)
                                .font(.system(size: 12, weight: .semibold))
                            Text(category.subtitle.localized)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 48)
                    .background {
                        if selectedCategory == category {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.11))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 172)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private var settingsDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch selectedCategory {
                case .general:
                    generalSettings
                case .appearance:
                    appearanceSettings
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeading(
                title: "通用",
                subtitle: "设置 Sift 使用的界面语言"
            )

            settingsCard {
                HStack(spacing: 14) {
                    settingsIcon("character.bubble", color: .blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("语言").font(.system(size: 13, weight: .semibold))
                        Text("选择跟随系统，或为 Sift 单独指定语言")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("语言", selection: $languageRawValue) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.title.localized).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
            }

            settingsNote("语言切换会立即应用，当前扫描结果和选择不会丢失。")
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeading(
                title: "外观",
                subtitle: "选择窗口使用的显示模式"
            )

            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        settingsIcon("circle.lefthalf.filled", color: .indigo)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("显示模式").font(.system(size: 13, weight: .semibold))
                            Text("可以跟随 macOS，也可以固定为浅色或深色")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

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
        }
    }

    private func settingsHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.localized).font(.system(size: 17, weight: .semibold))
            Text(subtitle.localized).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
            Image(systemName: systemName).foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
    }

    private func settingsNote(_ text: String) -> some View {
        Label(text.localized, systemImage: "info.circle")
            .font(.caption).foregroundStyle(.secondary)
    }
}
