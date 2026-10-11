import AppKit
import Charts
import MachKitCore
import SwiftUI

enum SoftwareTab: String, CaseIterable, Identifiable {
    case all = "All"
    case appStore = "App Store"
    case thirdParty = "Third Party"
    case user = "User"
    case system = "System"
    case commandLine = "Command Line"
    var id: String { rawValue }
}

enum PerformanceSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    var id: String { rawValue }
}

enum StorageBrowseTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case categories = "Categories"
    case largeFiles = "Large Files"
    case folders = "Folders"

    var id: String { rawValue }
}

struct JunkScanPreview: Identifiable {
    let id: String
    let title: String
    let icon: String
    let detail: String
    let color: Color
}

enum PortFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case tcp = "TCP"
    case udp = "UDP"
    case exposed = "Exposed"
    var id: String { rawValue }
}

enum NetworkTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case traffic = "App Traffic"
    case activeConnections = "Active Connections"
    case listeningPorts = "Listening Ports"
    case routing = "Routing"
    var id: String { rawValue }
}

struct LoginItemGroup: Identifiable {
    let domain: LoginItemDomain
    let items: [LoginItem]
    var id: LoginItemDomain { domain }
}

struct ExtensionGroup: Identifiable {
    let kind: InstalledExtensionKind
    let items: [InstalledExtension]
    var id: InstalledExtensionKind { kind }
}

struct ContentView: View {
    @AppStorage(AppPreferenceKey.language) var languageRawValue = AppLanguage.system.rawValue
    @ObservedObject var model: CleanerViewModel
    @StateObject var permissions = PermissionManager()
    @State var expandedGroups: Set<String> = []
    @State var applicationSearch = ""
    @State var softwareTab: SoftwareTab = .all
    @State var selectedCommandLineTool: CommandLineTool?
    @State var hoveredSoftwareID: String?
    @State var inventorySearch = ""
    @State var performanceSort: PerformanceSort = .cpu
    @State var storageTab: StorageBrowseTab = .overview
    @State var junkScrollTarget: String?
    @State var showingMemoryHelp = false
    @State var portSearch = ""
    @State var portFilter: PortFilter = .all
    @State var selectedPort: ListeningPort?
    @State var networkTab: NetworkTab = .overview
    @State var networkSearch = ""
    @State var routeQuery = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch model.mode {
                case .home: homeView
                case .junk: junkView
                case .uninstall: uninstallView
                case .files: filesView
                case .performance: performanceView
                case .network: networkView
                case .tools: ToolsView()
                case .loginItems: loginItemsView
                case .backgroundActivity: backgroundActivityView
                case .extensions: extensionsView
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea(.container, edges: .top)
        .confirmationDialog(cleanConfirmationTitle, isPresented: $model.showCleanConfirmation) {
            Button(cleanConfirmationActionTitle, role: .destructive, action: model.cleanConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(cleanConfirmationMessage)
        }
        .sheet(item: $model.uninstallCandidate) { app in
            applicationDetails(app)
                .confirmationDialog("Uninstall this app?", isPresented: $model.showAppRemovalConfirmation) {
                    Button("Move to Trash", role: .destructive, action: model.uninstallConfirmed)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The app and selected related files will be moved to Trash.")
                }
        }
        .sheet(item: $selectedCommandLineTool) { tool in
            commandLineToolDetails(tool)
        }
        .sheet(item: $selectedPort) { port in
            portDetails(port)
        }
        .sheet(item: $model.operationReport) { report in
            OperationResultView(report: report) { model.operationReport = nil }
        }
        .confirmationDialog("Remove this login item?", isPresented: $model.showLoginApplicationRemovalConfirmation) {
            Button("Remove", role: .destructive, action: model.removeLoginApplicationConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(loginApplicationRemovalMessage)
        }
        .confirmationDialog("Remove this background item?", isPresented: $model.showBackgroundItemRemovalConfirmation) {
            Button("Move to Trash", role: .destructive, action: model.removeBackgroundItemConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(backgroundItemRemovalMessage)
        }
        .confirmationDialog("Permanently remove this background leftover?", isPresented: $model.showRegisteredBackgroundTaskRemovalConfirmation) {
            Button("Remove Permanently", role: .destructive, action: model.removeRegisteredBackgroundTaskConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(registeredBackgroundTaskRemovalMessage)
        }
        .confirmationDialog("Rebuild the entire background task database?", isPresented: $model.showBackgroundDatabaseResetConfirmation) {
            Button("Rebuild Database", role: .destructive, action: model.resetBackgroundTaskDatabaseConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this when an app was uninstalled but still appears under Background Activity or Login Items. macOS often cannot remove a single leftover record. Rebuilding resets all login and background records; installed apps register again after restart, and some allowed or blocked states may need confirmation.")
        }
        .confirmationDialog("Remove this extension?", isPresented: $model.showExtensionRemovalConfirmation) {
            Button("Move to Trash", role: .destructive, action: model.removeExtensionConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(extensionRemovalMessage)
        }
        .confirmationDialog("Quit this process?", isPresented: $model.showPortTerminationConfirmation) {
            Button("Quit Gracefully", role: .destructive) { model.terminatePortProcess(force: false) }
            Button("Force Quit", role: .destructive) { model.terminatePortProcess(force: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(portTerminationMessage)
        }
        .alert("Operation Failed", isPresented: $model.showRemovalFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.removalFailureMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            DispatchQueue.main.async {
                permissions.refresh()
                model.applicationDidBecomeActive()
            }
        }
        .onChange(of: languageRawValue) { _, _ in
            model.refreshLocalizedStatus()
        }
    }
}
