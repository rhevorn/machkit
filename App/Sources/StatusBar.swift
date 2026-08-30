import AppKit
import SwiftUI

struct StatusBarMenuView: View {
    let model: CleanerViewModel
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Depend on the stored language so MenuBarExtra rebuilds localized titles.
        let _ = languageRawValue

        Button("MachKit".localized) {
            presentMainWindow()
        }

        Divider()

        featureButton(.performance)
        featureButton(.junk)
        toolsButton
        featureButton(.settings)

        Divider()

        Button("Check for Updates…".localized) {
            AppUpdateChecker.shared.checkForUpdates()
        }

        Divider()

        Button("Quit MachKit".localized) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func featureButton(_ mode: FeatureMode) -> some View {
        Button(mode.rawValue.localized) {
            model.changeMode(mode)
            presentMainWindow()
        }
    }

    private var toolsButton: some View {
        Button(FeatureMode.tools.rawValue.localized) {
            MachKitAppLifecycle.toggleToolList(
                isShowingTools: model.mode == .tools,
                showTools: { model.changeMode(.tools) },
                openMainWindow: { openWindow(id: MachKitAppLifecycle.mainWindowSceneID) }
            )
        }
        .toolShortcut(shortcutStore.shortcut(for: ToolShortcutStore.toolListID))
    }

    private func presentMainWindow() {
        MachKitAppLifecycle.presentMainWindow {
            openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
        }
    }
}

struct MachKitCommands: Commands {
    let model: CleanerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                AppUpdateChecker.shared.checkForUpdates()
            } label: {
                Label("Check for Updates…".localized, systemImage: "arrow.triangle.2.circlepath")
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button {
                model.changeMode(.settings)
                MachKitAppLifecycle.presentMainWindow {
                    openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
                }
            } label: {
                Label("Settings".localized, systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
