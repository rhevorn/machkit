import AppKit
import SwiftUI

final class SiftAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: AppPreferenceKey.showMenuBar)
    }
}

@main
struct SiftApp: App {
    @NSApplicationDelegateAdaptor(SiftAppDelegate.self) private var appDelegate
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKey.showMenuBar) private var showMenuBar = true
    @State private var menuBarInserted: Bool
    @StateObject private var model = CleanerViewModel()
    @StateObject private var statusBarMonitor = StatusBarMonitor()

    init() {
        UserDefaults.standard.register(defaults: [AppPreferenceKey.showMenuBar: true])
        _menuBarInserted = State(initialValue: UserDefaults.standard.bool(forKey: AppPreferenceKey.showMenuBar))
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some Scene {
        Window("Sift", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 720)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
                .task { statusBarMonitor.setEnabled(showMenuBar) }
                .onChange(of: showMenuBar) { _, enabled in
                    menuBarInserted = enabled
                    statusBarMonitor.setEnabled(enabled)
                }
                .onChange(of: menuBarInserted) { _, inserted in
                    showMenuBar = inserted
                    statusBarMonitor.setEnabled(inserted)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 820)
        .commands {
            SiftCommands(model: model)
        }

        MenuBarExtra(
            "Sift",
            image: "MenuBarMark",
            isInserted: $menuBarInserted
        ) {
            StatusBarMenuView(monitor: statusBarMonitor)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}
