import AppKit
import Foundation
import SwiftUI

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
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(.system(size: 18, weight: .semibold))
                    Text("Manage language, appearance, and other preferences")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            settingsContent
        }
        .environment(\.locale, language.locale)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Interface and display".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    settingRow(
                        icon: "character.bubble",
                        color: .blue,
                        title: "Language",
                        detail: "Select the interface language used by Sift"
                    ) {
                        Picker("Language", selection: $languageRawValue) {
                            ForEach(AppLanguage.allCases) { option in
                                Text(verbatim: option.title).tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 168, idealWidth: 190, maxWidth: 220)
                    }

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "circle.lefthalf.filled",
                        color: .indigo,
                        title: "Display Mode",
                        detail: "Follow macOS, or stick to light or dark colors"
                    ) {
                        Picker("Appearance", selection: $appearanceRawValue) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.title.localized).tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(minWidth: 180, idealWidth: 270, maxWidth: 340)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
                }

                Label("Changes are applied immediately.".localized, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingRow<Control: View>(
        icon: String,
        color: Color,
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 14) {
            settingsIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(detail.localized).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            control()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
            Image(systemName: systemName).foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }
}
