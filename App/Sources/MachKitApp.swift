import AppKit
import SwiftUI

@MainActor
enum MachKitAppLifecycle {
    static let mainWindowSceneID = "main"
    static let mainWindowInterfaceID = NSUserInterfaceItemIdentifier("MachKit.MainWindow")
    static let mainWindowAutosaveName = "MachKit.MainWindow.v4"

    private static weak var registeredMainWindow: NSWindow?
    private static var mainWindowVisibilityHandler: ((Bool) -> Void)?

    static func showInForeground() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func registerMainWindow(_ window: NSWindow) {
        window.identifier = mainWindowInterfaceID
        registeredMainWindow = window
    }

    static func setMainWindowVisibilityHandler(_ handler: @escaping (Bool) -> Void) {
        mainWindowVisibilityHandler = handler
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

    static func machKitMainWindow() -> NSWindow? {
        if let registeredMainWindow {
            return registeredMainWindow
        }
        return NSApp.windows.first { window in
            window.identifier == mainWindowInterfaceID
                && !(window is ScreenshotOverlayWindowMarker)
        }
    }

    static func isMachKitMainWindowFrontmost() -> Bool {
        guard let window = machKitMainWindow() else { return false }
        return window.isVisible
            && !window.isMiniaturized
            && window.occlusionState.contains(.visible)
            && (window.isKeyWindow || window.isMainWindow)
            && NSApp.isActive
    }

    static func hideMachKitMainWindow() {
        guard let window = machKitMainWindow() else { return }
        window.orderOut(nil)
        // Don't wait for occlusion notifications before pausing dashboard work.
        mainWindowVisibilityHandler?(false)
        moveToBackgroundIfNeeded()
    }

    static func bringMainWindowToFront() {
        showInForeground()
        Task { @MainActor in
            for _ in 0..<12 {
                await Task.yield()
                showInForeground()
                if let window = machKitMainWindow(), window.canBecomeKey {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    static func toggleToolList(
        isShowingTools: Bool,
        showTools: () -> Void,
        openMainWindow: () -> Void
    ) {
        if isShowingTools, isMachKitMainWindowFrontmost() {
            hideMachKitMainWindow()
            return
        }
        showTools()
        showInForeground()
        openMainWindow()
        bringMainWindowToFront()
    }

    static func toolWindowInterfaceID(for toolID: String) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("MachKit.WebTool.\(toolID)")
    }

    static func toolWindow(for toolID: String) -> NSWindow? {
        let interfaceID = toolWindowInterfaceID(for: toolID)
        return NSApp.windows.first { $0.identifier == interfaceID }
    }

    static func isToolWindowFrontmost(toolID: String) -> Bool {
        guard let window = toolWindow(for: toolID) else { return false }
        return window.isVisible
            && !window.isMiniaturized
            && window.occlusionState.contains(.visible)
            && (window.isKeyWindow || window.isMainWindow)
            && NSApp.isActive
    }

    static func hideToolWindow(toolID: String) {
        guard let window = toolWindow(for: toolID) else { return }
        window.orderOut(nil)
        moveToBackgroundIfNeeded()
    }

    static func bringToolWindowToFront(toolID: String, titled title: String) {
        showInForeground()
        Task { @MainActor in
            let interfaceID = toolWindowInterfaceID(for: toolID)
            for _ in 0..<12 {
                await Task.yield()
                showInForeground()
                if let target = NSApp.windows.first(where: {
                    $0.identifier == interfaceID && $0.canBecomeKey
                }) ?? NSApp.windows.first(where: {
                    $0.isVisible && $0.canBecomeKey && $0.title == title
                }) {
                    if target.isMiniaturized {
                        target.deminiaturize(nil)
                    }
                    target.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    static func toggleTool(
        toolID: String,
        titled title: String,
        open: () -> Void
    ) {
        if isToolWindowFrontmost(toolID: toolID) {
            hideToolWindow(toolID: toolID)
            return
        }
        open()
        bringToolWindowToFront(toolID: toolID, titled: title)
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
                    if ScreenshotAction.allIDs.contains(targetID) {
                        ScreenshotController.shared.handleHotKey(targetID)
                    } else if targetID == ToolShortcutStore.toolListID {
                        MachKitAppLifecycle.toggleToolList(
                            isShowingTools: model.mode == .tools,
                            showTools: { model.changeMode(.tools) },
                            openMainWindow: { openWindow(id: MachKitAppLifecycle.mainWindowSceneID) }
                        )
                    } else if let tool = DeveloperToolRegistry.tool(id: targetID) {
                        MachKitAppLifecycle.toggleTool(
                            toolID: tool.id,
                            titled: tool.localizedTitle
                        ) {
                            MachKitAppLifecycle.showInForeground()
                            openWindow(id: "web-tool", value: tool.id)
                        }
                    }
                }
            }
    }
}

private struct MainWindowConfigurator: NSViewRepresentable {
    let defaultSize: CGSize
    let minimumSize: CGSize
    let onVisibilityChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(window: view.window, context: context) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.onVisibilityChange = onVisibilityChange
        MachKitAppLifecycle.setMainWindowVisibilityHandler(onVisibilityChange)
        DispatchQueue.main.async { configure(window: view.window, context: context) }
    }

    private func configure(window: NSWindow?, context: Context) {
        guard let window else { return }
        if context.coordinator.configuredWindow !== window {
            context.coordinator.tearDown()
            context.coordinator.configuredWindow = window
            context.coordinator.onVisibilityChange = onVisibilityChange
            MachKitAppLifecycle.setMainWindowVisibilityHandler(onVisibilityChange)
            MachKitAppLifecycle.registerMainWindow(window)
            context.coordinator.installObservers(on: window)
            window.contentMinSize = minimumSize

            let autosaveName = MachKitAppLifecycle.mainWindowAutosaveName
            let restoredPreviousFrame = window.setFrameUsingName(autosaveName)
            window.setFrameAutosaveName(autosaveName)
            if !restoredPreviousFrame {
                window.setContentSize(defaultSize)
                window.center()
            }
        } else {
            MachKitAppLifecycle.registerMainWindow(window)
        }
        context.coordinator.publishVisibility()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        weak var configuredWindow: NSWindow?
        var onVisibilityChange: ((Bool) -> Void)?
        /// Mutated only on the main actor (installObservers / tearDown); deinit
        /// reads it to unregister tokens, and NotificationCenter.removeObserver
        /// is safe to call from any thread.
        nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
        private var lastPublishedVisibility: Bool?

        func installObservers(on window: NSWindow) {
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.willCloseNotification,
            ]
            for name in names {
                observers.append(
                    center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                        // addObserver's closure is nonisolated; hop back so the
                        // MainActor Coordinator and NSWindow state are read safely.
                        Task { @MainActor [weak self] in
                            self?.publishVisibility()
                        }
                    }
                )
            }
        }

        func publishVisibility() {
            guard let window = configuredWindow else {
                publish(false)
                return
            }
            let visible = window.isVisible
                && !window.isMiniaturized
                && window.occlusionState.contains(.visible)
            publish(visible)
        }

        private func publish(_ visible: Bool) {
            guard lastPublishedVisibility != visible else { return }
            lastPublishedVisibility = visible
            onVisibilityChange?(visible)
        }

        func tearDown() {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
            configuredWindow = nil
            lastPublishedVisibility = nil
        }

        deinit {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
        }
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
        ) { notification in
            guard !(notification.object is ScreenshotOverlayWindowMarker) else { return }
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
        Window("MachKit", id: MachKitAppLifecycle.mainWindowSceneID) {
            ContentView(model: model)
                .frame(minWidth: 740, minHeight: 680)
                .background(GlobalShortcutBridge(model: model))
                .background(
                    MainWindowConfigurator(
                        defaultSize: CGSize(width: 880, height: 680),
                        minimumSize: CGSize(width: 740, height: 680),
                        onVisibilityChange: { model.setMainWindowVisible($0) }
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
            height: WebToolWidthClass.compact.height
        )

        MenuBarExtra(
            "MachKit",
            image: "MenuBarMark",
            isInserted: $showMenuBar
        ) {
            StatusBarMenuView(monitor: statusBarMonitor, model: model)
                .background(GlobalShortcutBridge(model: model))
                .environment(\.locale, language.locale)
        }
        .menuBarExtraStyle(.window)
    }
}
