import AppKit
import SwiftUI

final class SiftAppDelegate: NSObject, NSApplicationDelegate {
    override init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [AppPreferenceKey.showMenuBar: true])
        if !defaults.bool(forKey: AppPreferenceKey.menuBarCloseBehaviorRepair) {
            defaults.set(true, forKey: AppPreferenceKey.showMenuBar)
            defaults.set(true, forKey: AppPreferenceKey.menuBarCloseBehaviorRepair)
        }
        super.init()
    }

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
    @StateObject private var model = CleanerViewModel()
    @StateObject private var hostsManager = HostsManagerViewModel()
    @StateObject private var statusBarMonitor = StatusBarMonitor()

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
                    statusBarMonitor.setEnabled(enabled)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 820)
        .commands {
            SiftCommands(model: model)
        }

        Window("Hosts Manager", id: "hosts-manager") {
            HostsManagerView(model: hostsManager)
                .frame(minWidth: 760, minHeight: 620)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 720)

        MenuBarExtra(
            "Sift",
            image: "MenuBarMark",
            isInserted: $showMenuBar
        ) {
            StatusBarMenuView(monitor: statusBarMonitor)
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}
