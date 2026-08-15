import AppKit
import Foundation
import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKey.showMenuBar) private var showMenuBar = true
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @State private var showingToolsShortcut = false
    @State private var showingClearDataConfirmation = false
    @State private var clearDataError: String?

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
                        detail: "Select the interface language used by MachKit"
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

                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "menubar.rectangle",
                        color: .cyan,
                        title: "Keep in Menu Bar",
                        detail: "Show CPU, memory, network speed, and quick actions in the menu bar"
                    ) {
                        Toggle(isOn: $showMenuBar) { EmptyView() }
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }


                    Divider().padding(.leading, 64)

                    settingRow(
                        icon: "keyboard",
                        color: .orange,
                        title: "Tool List Shortcut",
                        detail: "Open the tool list with a keyboard shortcut"
                    ) {
                        Button {
                            showingToolsShortcut = true
                        } label: {
                            if let shortcut = shortcutStore.shortcut(for: ToolShortcutStore.toolListID) {
                                Text(shortcut.displayText)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 9)
                                    .frame(minWidth: 34, minHeight: 27)
                                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                            } else {
                                Text("Set Shortcut".localized)
                            }
                        }
                        .buttonStyle(.plain)
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

                Text("Data".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 18)

                settingRow(
                    icon: "trash",
                    color: .red,
                    title: "Clear App Data",
                    detail: "Remove MachKit's saved settings, shortcuts, tool data, and window state"
                ) {
                    Button("Clear Data…".localized, role: .destructive) {
                        showingClearDataConfirmation = true
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingToolsShortcut) {
            ToolShortcutEditor(
                targetID: ToolShortcutStore.toolListID,
                title: "Tools".localized,
                store: shortcutStore
            )
        }
        .alert("Clear All App Data?".localized, isPresented: $showingClearDataConfirmation) {
            Button("Cancel".localized, role: .cancel) {}
            Button("Clear and Quit".localized, role: .destructive) { clearAppData() }
        } message: {
            Text("This removes all data saved by MachKit on this Mac and then quits the app. System files and scan targets are not deleted.".localized)
        }
        .alert("Could Not Clear App Data".localized, isPresented: Binding(
            get: { clearDataError != nil },
            set: { if !$0 { clearDataError = nil } }
        )) {
            Button("OK".localized, role: .cancel) {}
        } message: {
            Text(clearDataError ?? "")
        }
    }

    private func clearAppData() {
        do {
            try AppDataResetter.scheduleReset()
            NSApp.terminate(nil)
        } catch {
            clearDataError = error.localizedDescription
        }
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
