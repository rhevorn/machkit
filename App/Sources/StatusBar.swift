import AppKit
import SwiftUI

struct StatusBarMenuView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open MachKit") {
            MachKitAppLifecycle.showInForeground()
            openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
            MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
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
                Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                model.changeMode(.settings)
                MachKitAppLifecycle.showInForeground()
                openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
                MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
