import AppKit
import Foundation
import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKey.showMenuBar) private var showMenuBar = true
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @State private var showingToolsShortcut = false
    @State private var editingScreenshotAction: ScreenshotAction?
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
            .padding(MachKitLayout.pageMargin)

            settingsContent
        }
        .environment(\.locale, language.locale)
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
                        .frame(width: 168, alignment: .trailing)
                    }

                    Divider().padding(.leading, 52)

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
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    Divider().padding(.leading, 52)

                    settingRow(
                        icon: "menubar.rectangle",
                        color: .cyan,
                        title: "Keep in Menu Bar",
                        detail: "Keep MachKit available from the menu bar"
                    ) {
                        Toggle(isOn: $showMenuBar) { EmptyView() }
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().padding(.leading, 52)

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
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Screenshot".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, MachKitLayout.pageMargin)

                VStack(spacing: 0) {
                    ForEach(ScreenshotAction.allCases) { action in
                        settingRow(
                            icon: action.icon,
                            color: .pink,
                            title: action.title,
                            detail: action.detail
                        ) {
                            HStack(spacing: 8) {
                                Button("Capture".localized) {
                                    ScreenshotController.shared.start()
                                }
                                .buttonStyle(.bordered)
                                .help(action.localizedTitle)

                                shortcutButton(
                                    targetID: action.rawValue,
                                    action: { editingScreenshotAction = action }
                                )
                            }
                        }

                        if action != ScreenshotAction.allCases.last {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Data".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, MachKitLayout.pageMargin)

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
            }
            .padding(.horizontal, MachKitLayout.pageMargin)
            .padding(.top, MachKitLayout.bannerPadding)
            .padding(.bottom, MachKitLayout.pageMargin)
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
        .sheet(item: $editingScreenshotAction) { action in
            ToolShortcutEditor(
                targetID: action.rawValue,
                title: action.localizedTitle,
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

    private func shortcutButton(
        targetID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if let shortcut = shortcutStore.shortcut(for: targetID) {
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

    private func settingRow<Control: View>(
        icon: String,
        color: Color,
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            settingsIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(detail.localized).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            control()
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
            Image(systemName: systemName).foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
    }
}
