import AppKit
import SwiftUI

@MainActor
enum MachKitAppLifecycle {
    static func showInForeground() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func bringWindowToFront(titled title: String) {
        showInForeground()
        Task { @MainActor in
            for _ in 0..<12 {
                await Task.yield()
                showInForeground()
                if let target = NSApp.windows.first(where: {
                    $0.isVisible && $0.canBecomeKey && $0.title == title
                }) {
                    target.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    static func moveToBackgroundIfNeeded() {
        guard UserDefaults.standard.bool(forKey: AppPreferenceKey.showMenuBar),
              !hasVisibleAppWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private static var hasVisibleAppWindow: Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.canBecomeMain && !window.isMiniaturized
        }
    }
}

private struct GlobalShortcutBridge: View {
    @ObservedObject var model: CleanerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                GlobalHotKeyManager.shared.configure { targetID in
                    if targetID == ToolShortcutStore.toolListID {
                        model.changeMode(.tools)
                        MachKitAppLifecycle.showInForeground()
                        openWindow(id: "main")
                        MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
                    } else if let tool = DeveloperToolRegistry.tool(id: targetID) {
                        MachKitAppLifecycle.showInForeground()
                        openWindow(id: "web-tool", value: tool.id)
                        MachKitAppLifecycle.bringWindowToFront(titled: tool.localizedTitle)
                    }
                }
            }
    }
}

private struct MainWindowConfigurator: NSViewRepresentable {
    let defaultSize: CGSize
    let minimumSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(window: view.window, context: context) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(window: view.window, context: context) }
    }

    private func configure(window: NSWindow?, context: Context) {
        guard let window, context.coordinator.configuredWindow !== window else { return }
        context.coordinator.configuredWindow = window
        window.contentMinSize = minimumSize

        let autosaveName = "MachKit.MainWindow.v4"
        let restoredPreviousFrame = window.setFrameUsingName(autosaveName)
        window.setFrameAutosaveName(autosaveName)
        if !restoredPreviousFrame {
            window.setContentSize(defaultSize)
            window.center()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }
}

final class MachKitAppDelegate: NSObject, NSApplicationDelegate {
    private var windowCloseObserver: NSObjectProtocol?

    override init() {
        AppDataResetter.performScheduledResetIfNeeded()
        let defaults = UserDefaults.standard
        defaults.register(defaults: [AppPreferenceKey.showMenuBar: true])
        if !defaults.bool(forKey: AppPreferenceKey.menuBarCloseBehaviorRepair) {
            defaults.set(true, forKey: AppPreferenceKey.showMenuBar)
            defaults.set(true, forKey: AppPreferenceKey.menuBarCloseBehaviorRepair)
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        GlobalHotKeyManager.shared.start()
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MachKitAppLifecycle.moveToBackgroundIfNeeded()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: AppPreferenceKey.showMenuBar)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
    }
}

@main
struct MachKitApp: App {
    @NSApplicationDelegateAdaptor(MachKitAppDelegate.self) private var appDelegate
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppPreferenceKey.showMenuBar) private var showMenuBar = true
    @StateObject private var model = CleanerViewModel()
    @StateObject private var statusBarMonitor = StatusBarMonitor()

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some Scene {
        Window("MachKit", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 740, minHeight: 680)
                .background(GlobalShortcutBridge(model: model))
                .background(
                    MainWindowConfigurator(
                        defaultSize: CGSize(width: 880, height: 680),
                        minimumSize: CGSize(width: 740, height: 680)
                    )
                )
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
                .task { statusBarMonitor.setEnabled(showMenuBar) }
                .onChange(of: showMenuBar) { _, enabled in
                    statusBarMonitor.setEnabled(enabled)
                    if !enabled { MachKitAppLifecycle.showInForeground() }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 880, height: 680)
        .commands {
            MachKitCommands(model: model)
            DeveloperToolCommands(model: model)
        }

        WindowGroup(Text(verbatim: "Web Tool"), id: "web-tool", for: String.self) { $toolID in
            if let toolID, let tool = DeveloperToolRegistry.tool(id: toolID) {
                WebToolView(tool: tool)
                    .frame(
                        minWidth: tool.minimumWindowSize.width,
                        minHeight: tool.minimumWindowSize.height
                    )
                    .background(GlobalShortcutBridge(model: model))
                    .environment(\.locale, language.locale)
                    .preferredColorScheme(appearance.colorScheme)
            } else {
                ContentUnavailableView(
                    "Web tool not found".localized,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(
            width: WebToolWidthClass.compact.width,
            height: WebToolWidthClass.initialHeight
        )

        MenuBarExtra(
            "MachKit",
            image: "MenuBarMark",
            isInserted: $showMenuBar
        ) {
            StatusBarMenuView(monitor: statusBarMonitor)
                .background(GlobalShortcutBridge(model: model))
                .environment(\.locale, language.locale)
                .preferredColorScheme(appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}
