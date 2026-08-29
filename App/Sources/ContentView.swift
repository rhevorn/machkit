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
                case .settings: AppSettingsView()
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

    var sidebar: some View {
        VStack(spacing: 6) {
            brandMark.padding(.top, 52).padding(.bottom, 6)
            sideButton(.home, icon: "house.fill")
            sideButton(.junk, icon: "paintbrush.fill")
            sideButton(.uninstall, icon: "app.badge.checkmark")
            sideButton(.files, icon: "chart.pie.fill")
            sideButton(.performance, icon: "gauge.with.dots.needle.67percent")
            sideButton(.network, icon: "network")
            sideButton(.tools, icon: "wrench.and.screwdriver.fill")
            systemInventorySideButton
            Spacer()
            if model.isStorageAnalyzing {
                Button { model.changeMode(.files) } label: {
                    VStack(spacing: 2) {
                        ProgressView().controlSize(.mini)
                        sidebarLabel("Analyzing", size: 9, weight: .medium)
                    }
                    .frame(width: 52, height: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Storage analysis is running in the background")
            }
            sideButton(.settings, icon: "gearshape.fill")
            Button(action: openFeedback) {
                VStack(spacing: 2) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 16))
                    sidebarLabel("Feedback")
                }
                .frame(width: 52, height: 48)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.bottom, 10)
        }
        .frame(width: 72)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    func openFeedback() {
        if let url = URL(string: "https://github.com/rhevorn/machkit/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    var brandMark: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
            .help("MachKit")
    }

    func sideButton(_ mode: FeatureMode, icon: String) -> some View {
        Button {
            inventorySearch = ""
            model.changeMode(mode)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                sidebarLabel(mode.sidebarTitle)
            }
            .foregroundStyle(model.mode == mode ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 48)
            .background {
                if model.mode == mode {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if model.mode == mode {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    var systemInventorySideButton: some View {
        let isSelected = [.loginItems, .backgroundActivity, .extensions].contains(model.mode)
        return Button {
            inventorySearch = ""
            if !isSelected { model.changeMode(.loginItems) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "switch.2").font(.system(size: 17, weight: .medium))
                sidebarLabel("System", size: 10.5)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 48)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func sidebarLabel(
        _ title: String,
        size: CGFloat = 10.5,
        weight: Font.Weight = .regular
    ) -> some View {
        Text(title.localized)
            .font(.system(size: size, weight: weight))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 60)
    }

    var homeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header(title: "Overview", subtitle: "Live status and everyday tools for this Mac")
                homeStorageOverview
                if !permissions.hasFullDiskAccess {
                    permissionCard
                }

                Text("Live Status").font(.system(size: 14, weight: .semibold))

                homeMetrics
                homeQuickAction

                Text("Common Tools").font(.system(size: 14, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    homeToolTile(
                        title: "Cleanup", subtitle: "Scan caches, logs, uninstall leftovers, and developer junk",
                        icon: "paintbrush.fill", color: .blue, mode: .junk
                    )
                    homeToolTile(
                        title: "Storage", subtitle: "Analyze disk categories, folder usage, large files, and free space",
                        icon: "chart.pie.fill", color: .indigo, mode: .files
                    )
                    homeToolTile(
                        title: "Apps", subtitle: "Uninstall apps, remove related files, and manage command-line tools",
                        icon: "app.badge.checkmark", color: .purple, mode: .uninstall
                    )
                    homeToolTile(
                        title: "Performance", subtitle: "Monitor CPU, memory pressure, thermal state, and resource-heavy apps",
                        icon: "gauge.with.dots.needle.67percent", color: .mint, mode: .performance
                    )
                    homeToolTile(
                        title: "Network", subtitle: L10n.string("Inspect live traffic, connections, ports, routes, and proxies"),
                        icon: "network", color: .orange, mode: .network
                    )
                    homeToolTile(
                        title: "Tools", subtitle: "Hosts, timestamps, JSON, codecs, and other developer utilities",
                        icon: "wrench.and.screwdriver.fill", color: .cyan, mode: .tools
                    )
                }
            }
            .padding(18)
        }
    }

    var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 20))
                .foregroundStyle(permissions.hasFullDiskAccess ? .green : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text((permissions.hasFullDiskAccess ? "Full Disk Access granted" : "Full Disk Access Required").localized)
                    .font(.system(size: 13, weight: .semibold))
                Text((permissions.hasFullDiskAccess
                     ? "Allows protected user folders to be scanned. File contents are never uploaded."
                     : "Used to find app caches and leftovers. Enable it manually in System Settings.").localized)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !permissions.hasFullDiskAccess {
                Button("Open System Settings", action: permissions.openFullDiskAccessSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background { RoundedRectangle(cornerRadius: 9).fill((permissions.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.08)) }
    }

    var homeStorageOverview: some View {
        let storage = model.systemStorage
        let color = homeStorageColor(storage.usedFraction)
        let percent = Int((storage.usedFraction * 100).rounded())
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: storage.totalCapacity > 0 ? max(0.015, storage.usedFraction) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(storage.totalCapacity > 0 ? "\(percent)%" : "—")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Used".localized).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: homeStorageIcon(storage.usedFraction))
                        .foregroundStyle(color)
                    Text(homeStorageTitle(storage).localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(homeStorageDescription(storage))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label(L10n.format("%@ Used", formatted(storage.usedCapacity)), systemImage: "internaldrive.fill")
                    Label(L10n.format("%@ Available", formatted(storage.availableCapacity)), systemImage: "checkmark.circle")
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            Button("View Storage", action: { model.changeMode(.files) })
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.13), lineWidth: 1)
        }
    }

    var homeMetrics: some View {
        let metrics = model.dashboardMetrics
        let transferRate = model.networkTransferRate
        let memoryColor = metrics.map { memoryPressureColor($0.memoryPressureLevel) } ?? .secondary
        let thermalColor = metrics.map { thermalStateColor($0.thermalState) } ?? .secondary
        return HStack(spacing: 10) {
            homeMetricCard(
                title: "CPU",
                value: metrics.map { "\(Int($0.cpuPercent.rounded()))%" } ?? "—",
                detail: "System Usage",
                icon: "cpu",
                color: .blue
            )
            homeMetricCard(
                title: "Memory",
                value: metrics.map { "\(Int(($0.memoryPressure * 100).rounded()))%" } ?? "—",
                detail: metrics.map { $0.memoryPressureLevel.rawValue } ?? "Loading",
                icon: "memorychip",
                color: memoryColor
            )
            homeNetworkMetricCard(transferRate)
            homeMetricCard(
                title: "Thermal",
                value: metrics.map { thermalStateShortText($0.thermalState) } ?? "—",
                detail: metrics == nil ? "Loading" : "Live",
                icon: "thermometer.medium",
                color: thermalColor
            )
        }
    }

    func homeMetricCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(detail.localized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 38, alignment: .leading)
            .layoutPriority(1)
            Spacer(minLength: 5)
            Text(verbatim: value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func homeNetworkMetricCard(_ transferRate: NetworkTransferRate?) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cyan)
                .frame(width: 26, height: 26)
                .background(Color.cyan.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Network".localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text((transferRate == nil ? "Checking" : "Live").localized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 38, alignment: .leading)
            .layoutPriority(1)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                homeNetworkRate(
                    icon: "arrow.down",
                    value: transferRate.map { formatNetworkRate($0.downloadBytesPerSecond) } ?? "—",
                    color: .blue
                )
                homeNetworkRate(
                    icon: "arrow.up",
                    value: transferRate.map { formatNetworkRate($0.uploadBytesPerSecond) } ?? "—",
                    color: .mint
                )
            }
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func homeNetworkRate(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    var homeQuickAction: some View {
        HStack(spacing: 13) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Quick Cleanup").font(.system(size: 13, weight: .semibold))
                Text(homeQuickActionDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: performQuickAction) {
                HStack(spacing: 6) {
                    if model.isCleanupScanning { ProgressView().controlSize(.small) }
                    Text(homeQuickActionButtonTitle.localized)
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.isCleanupScanning)
        }
        .padding(13)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }

    var homeQuickActionDescription: String {
        if model.isCleanupScanning { return L10n.string("Looking for caches and logs that are safe to clean…") }
        guard let cleanableBytes = model.cleanableBytes else {
            return L10n.string("Scan caches, logs, and regenerable developer tool files")
        }
        if cleanableBytes == 0 { return L10n.string("The latest scan found nothing to clean") }
        return L10n.format("The latest scan found %@ of cleanable content", formatted(cleanableBytes))
    }

    var homeQuickActionButtonTitle: String {
        if model.isCleanupScanning { return "Scanning" }
        if model.selectedCount > 0 { return "Review Cleanup" }
        return model.cleanableBytes == nil ? "Start Scan" : "Scan Again"
    }

    func homeToolTile(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        mode: FeatureMode
    ) -> some View {
        Button { model.changeMode(mode) } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle.localized).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func homeStorageColor(_ fraction: Double) -> Color {
        if fraction >= 0.93 { return .red }
        if fraction >= 0.84 { return .orange }
        return .green
    }

    func homeStorageIcon(_ fraction: Double) -> String {
        if fraction >= 0.93 { return "exclamationmark.triangle.fill" }
        if fraction >= 0.84 { return "externaldrive.badge.exclamationmark" }
        return "checkmark.circle.fill"
    }

    func homeStorageTitle(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return "Reading storage status…" }
        if storage.usedFraction >= 0.93 { return "Your Mac is low on storage" }
        if storage.usedFraction >= 0.84 { return "Storage space is getting tight" }
        return "Mac storage looks good"
    }

    func homeStorageDescription(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return L10n.string("Reading system disk capacity") }
        return L10n.format(
            "%@ available of %@ total",
            formatted(storage.availableCapacity),
            formatted(storage.totalCapacity)
        )
    }

    var junkView: some View {
        VStack(spacing: 0) {
            header(
                title: "Cleanup",
                subtitle: "Caches, logs, installers, and developer junk",
                trailing: AnyView(
                    Group {
                        if !model.isCleanupScanning, !model.items.isEmpty {
                            Button("Back to Cleanup Home".localized, action: returnToJunkHome)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                )
            )
            .padding(18)

            Group {
                if model.isCleanupScanning {
                    junkScanningView
                } else if model.items.isEmpty {
                    junkEmptyView
                } else {
                    VStack(spacing: 0) {
                        junkDetailList
                        Divider()
                        junkActionBar
                    }
                }
            }
        }
    }

    func focusJunkGroup(_ groupID: String) {
        expandedGroups.insert(groupID)
        junkScrollTarget = groupID
    }

    var junkSelectionControls: some View {
        HStack(spacing: 6) {
            Button("Select All", action: model.selectAllJunkItems)
                .disabled(model.items.isEmpty || model.selectedCount == model.items.count)
            Button("Deselect All", action: model.deselectAllJunkItems)
                .disabled(model.selectedIDs.isEmpty)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .controlSize(.small)
    }

    var junkActionBar: some View {
        let selectionFraction = model.totalBytes > 0
            ? min(1, Double(model.selectedBytes) / Double(model.totalBytes))
            : 0

        return VStack(spacing: 10) {
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(4, geometry.size.width * selectionFraction))
                    }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.22), value: model.selectedBytes)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format("%lld items selected", Int64(model.selectedCount)))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.format("%@ of %@", formatted(model.selectedBytes), formatted(model.totalBytes)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                junkSelectionControls
                Spacer(minLength: 8)
                Button("Scan Again", action: scanJunk)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.isCleaning)
                Button(action: model.requestClean) {
                    if model.isCleaning {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text(cleaningProgressTitle)
                        }
                    } else {
                        Label("Clean Selected", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(model.selectedIDs.isEmpty || model.isCleaning)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var cleaningProgressTitle: String {
        if model.cleaningTotalCount > 0 {
            return L10n.format(
                "Cleaning %lld of %lld…",
                Int64(model.cleaningProcessedCount),
                Int64(model.cleaningTotalCount)
            )
        }
        return L10n.string("Cleaning…")
    }

    var junkPermissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18))
                .foregroundStyle(Color.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Full Disk Access Required".localized)
                    .font(.system(size: 12, weight: .semibold))
                Text("Some caches may be missed without Full Disk Access. Enable it in System Settings for more complete results.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Open System Settings".localized, action: permissions.openFullDiskAccessSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    var junkFreedBanner: some View {
        Group {
            if let freed = model.lastCleanupFreedBytes, freed > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.format("Released %@ of disk space", formatted(freed)))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .padding(12)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var junkEmptyView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                junkFreedBanner
                if !permissions.hasFullDiskAccess {
                    junkPermissionBanner
                }
                junkEmptyHeroCard

                Text("What We Scan".localized).font(.system(size: 14, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(junkScanPreviews) { preview in
                        junkScanPreviewTile(preview)
                    }
                }

                junkSafetyBanner

                Button(action: scanJunk) {
                    Label("Start Scan".localized, systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(18)
        }
    }

    var junkEmptyHeroCard: some View {
        let storage = model.systemStorage
        let color = homeStorageColor(storage.usedFraction)
        let percent = Int((storage.usedFraction * 100).rounded())

        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: storage.totalCapacity > 0 ? max(0.015, storage.usedFraction) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(storage.totalCapacity > 0 ? "\(percent)%" : "—")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Used".localized).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Give your Mac a light cleanup".localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                if let cleanable = model.cleanableBytes, cleanable > 0 {
                    Text(L10n.format(
                        "A previous scan found %@ of cleanable content. Run again to refresh results.",
                        formatted(cleanable)
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Scan caches, logs, installers, and developer leftovers. Review each group before cleaning.".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 14) {
                    Label(L10n.format("%@ Available", formatted(storage.availableCapacity)), systemImage: "internaldrive.fill")
                    Label("Local Scan".localized, systemImage: "lock.shield")
                    if let lastScan = model.lastJunkScanText {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(L10n.format("Last scanned %@", lastScan))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        }
    }

    var junkScanPreviews: [JunkScanPreview] {
        [
            .init(id: "trash", title: "Trash", icon: "trash", detail: "Items already in Trash", color: .red),
            .init(id: "caches", title: "Caches", icon: "internaldrive", detail: "App, browser, and tool caches", color: .blue),
            .init(id: "downloads", title: "Downloads & Mail", icon: "tray.and.arrow.down", detail: "Old installers and mail attachments", color: .cyan),
            .init(id: "backups", title: "Device Backups", icon: "iphone", detail: "Local iPhone and iPad backups", color: .purple),
            .init(id: "developer", title: "Developer Files", icon: "hammer", detail: "Xcode, simulators, and package caches", color: .mint),
            .init(id: "leftovers", title: "Uninstall Leftovers", icon: "app.badge.minus", detail: "Support files from removed apps", color: .orange),
        ]
    }

    func junkScanPreviewTile(_ preview: JunkScanPreview) -> some View {
        HStack(spacing: 11) {
            Image(systemName: preview.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(preview.color)
                .frame(width: 34, height: 34)
                .background(preview.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.title.localized)
                    .font(.system(size: 13, weight: .semibold))
                Text(preview.detail.localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    var junkSafetyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Review before cleaning".localized).font(.system(size: 12, weight: .semibold))
                Text("MachKit only reads file metadata locally. Selected items move to Trash unless they are already in Trash.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    func scanPromise(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    var junkScanningView: some View {
        let phases = model.visibleCleanupScanPhases
        let progress = max(0, min(1, model.scanProgress))
        let percent = Int((progress * 100).rounded())

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: max(0.02, progress))
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(percent)%")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("Scanning".localized).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.currentScanCategory.isEmpty
                             ? L10n.string("Scanning for cleanable files…")
                             : model.currentScanCategory)
                            .font(.system(size: 17, weight: .semibold))
                            .contentTransition(.opacity)
                        Text("Reads file metadata only; contents are never read or uploaded".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            junkScanInlineStat(
                                title: "Found",
                                value: formatted(model.discoveredBytes),
                                icon: "sparkles",
                                color: .blue
                            )
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            junkScanInlineStat(
                                title: "Locations",
                                value: "\(model.discoveredFileCount)",
                                icon: "folder",
                                color: .mint
                            )
                        }
                        Button("Cancel Scan".localized, role: .cancel, action: model.cancelScan)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.10), Color(nsColor: .controlBackgroundColor)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                }

                Text("Scan Progress".localized).font(.system(size: 14, weight: .semibold))
                ScrollViewReader { proxy in
                    junkScanPhaseTimeline(phases: phases)
                        .onChange(of: model.activeCleanupPhaseID) { _, phaseID in
                            guard let phaseID else { return }
                            // Instant jump — animated scroll thrashing during a fast
                            // re-scan (warm filesystem cache) makes the timeline flicker.
                            proxy.scrollTo(phaseID, anchor: .center)
                        }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Animate only discrete category changes — never the high-frequency scanProgress
        // stream, or the whole panel re-layouts and flickers on every progress tick.
        .animation(.easeInOut(duration: 0.2), value: model.currentScanCategory)
        .animation(.easeInOut(duration: 0.2), value: model.activeCleanupPhaseID)
    }

    func junkScanInlineStat(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    func junkScanPhaseTimeline(phases: [CleanerViewModel.CleanupScanPhase]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                let isDone = model.completedCleanupPhases.contains(phase.id)
                let isActive = !isDone && model.activeCleanupPhaseID == phase.id
                let phaseColor = phaseStripColor(isDone: isDone, isActive: isActive)

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(phaseColor.opacity(0.14))
                                .frame(width: 30, height: 30)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.green)
                            } else if isActive {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: phase.icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if index < phases.count - 1 {
                            Rectangle()
                                .fill(isDone ? Color.green.opacity(0.35) : Color.secondary.opacity(0.16))
                                .frame(width: 2, height: 28)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 30)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(phase.title.localized)
                                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            Spacer()
                            if isDone {
                                Text("Done".localized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else if isActive {
                                Text("Scanning".localized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        Text(phase.summary.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if isActive {
                            ProgressView(value: model.activeCleanupPhaseProgress, total: 1)
                                .tint(Color.accentColor)
                        }
                    }
                    .padding(.bottom, index < phases.count - 1 ? 14 : 10)
                }
                .padding(.horizontal, 14)
                .padding(.top, index == 0 ? 12 : 0)
                .id(phase.id)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func phaseStripColor(isDone: Bool, isActive: Bool) -> Color {
        if isDone { return .green }
        if isActive { return Color.accentColor }
        return .secondary
    }

    var junkDetailList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !permissions.hasFullDiskAccess {
                        junkPermissionBanner
                    }
                    junkResultHeroCard
                    junkDistributionBar
                    ForEach(model.junkGroups) { group in
                        junkGroupSection(group)
                            .id(group.id)
                    }
                    Text("Selected items move to Trash unless they are already in Trash. Review orange groups before cleaning.".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: junkScrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                junkScrollTarget = nil
            }
        }
    }

    var junkResultHeroCard: some View {
        let selectionFraction = model.totalBytes > 0
            ? min(1, Double(model.selectedBytes) / Double(model.totalBytes))
            : 0
        let percent = Int((selectionFraction * 100).rounded())

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: max(0.015, selectionFraction))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.22), value: model.selectedBytes)
                    VStack(spacing: 1) {
                        Text("\(percent)%")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("Selected".localized).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                        Text("Ready to clean".localized)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(L10n.format(
                        "%@ selected of %@ total · %lld locations",
                        formatted(model.selectedBytes),
                        formatted(model.totalBytes),
                        Int64(model.items.count)
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Label(L10n.format("%@ safe", formatted(model.safeCleanableBytes)), systemImage: "checkmark.shield")
                        if model.reviewItemCount > 0 {
                            Label(L10n.format("%lld to review", Int64(model.reviewItemCount)), systemImage: "exclamationmark.triangle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(4, geometry.size.width * selectionFraction))
                            .animation(.easeOut(duration: 0.22), value: model.selectedBytes)
                    }
            }
            .frame(height: 5)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        }
    }

    var junkDistributionBar: some View {
        let groups = model.junkGroups.filter { $0.bytes > 0 }
        let total = max(Int64(1), groups.reduce(Int64(0)) { $0 + $1.bytes })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Size Breakdown".localized).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.format("%lld groups", Int64(groups.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(groups) { group in
                        let width = max(4, geometry.size.width * CGFloat(Double(group.bytes) / Double(total)))
                        Button {
                            focusJunkGroup(group.id)
                        } label: {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(junkGroupChartColor(group))
                                .frame(width: width, height: 10)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.format("%@ · %@", group.title.localized, formatted(group.bytes)))
                    }
                }
            }
            .frame(height: 10)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(groups.prefix(6)) { group in
                    Button {
                        focusJunkGroup(group.id)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(junkGroupChartColor(group))
                                .frame(width: 7, height: 7)
                            Text(group.title.localized)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(formatted(group.bytes))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func junkGroupChartColor(_ group: JunkScanGroup) -> Color {
        switch group.id {
        case "trash": .red
        case "user-caches": .blue
        case "browser-caches": .cyan
        case "xdg-caches": .teal
        case "temporary-files": .mint
        case "language-support-caches": .indigo
        case "downloads-archives": .purple
        case "mail-downloads": .pink
        case "device-backups": .orange
        case "user-logs": .brown
        case "developer-home-caches": .green
        case "xcode-artifacts": .blue
        case "simulator-cache": .cyan
        case "unavailable-simulator-devices": .orange
        case "uninstall-leftovers": .yellow
        default: .accentColor
        }
    }

    func junkGroupSection(_ group: JunkScanGroup) -> some View {
        let chartColor = junkGroupChartColor(group)

        return VStack(spacing: 0) {
            DisclosureGroup(isExpanded: expansionBinding(group.id)) {
                VStack(spacing: 0) {
                    ForEach(group.items) { item in
                        junkFileRow(item)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 66)
                        }
                    }
                    if group.totalCount > group.items.count {
                        HStack {
                            Spacer()
                            Text(L10n.format(
                                "Showing %lld of %lld locations",
                                Int64(group.items.count),
                                Int64(group.totalCount)
                            ))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Toggle(isOn: groupSelectionBinding(group)) { EmptyView() }.labelsHidden()
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(chartColor.opacity(0.12))
                        Image(systemName: group.risk == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(chartColor)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title.localized)
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.format(
                            "%lld locations · %@",
                            Int64(group.totalCount),
                            group.explanation.localized
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                    Text(formatted(group.bytes))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    var cleanConfirmationTitle: String {
        if model.selectedIncludesTrashContents && !model.selectedIncludesNonTrashContents {
            return L10n.string("Permanently delete selected Trash items?")
        }
        if model.selectedIncludesTrashContents {
            return L10n.string("Clean selected items?")
        }
        return L10n.string("Move selected files to Trash?")
    }

    var cleanConfirmationActionTitle: String {
        if model.selectedIncludesTrashContents && !model.selectedIncludesNonTrashContents {
            return L10n.string("Delete Permanently")
        }
        return L10n.string("Move to Trash")
    }

    var cleanConfirmationMessage: String {
        let totals = L10n.format(
            "%lld items, %@ total.",
            Int64(model.selectedCount),
            formatted(model.selectedBytes)
        )
        if model.selectedIncludesTrashContents && model.selectedIncludesNonTrashContents {
            return totals + " " + L10n.string("Trash items will be permanently deleted; other items will be moved to Trash.")
        }
        if model.selectedIncludesTrashContents {
            return totals + " " + L10n.string("This permanently deletes files already in Trash and cannot be undone.")
        }
        return totals
    }

    func junkFileRow(_ item: ScanItem) -> some View {
        let isDirectory = item.fileCount > 1 || item.url.pathExtension.isEmpty
        let isEstimated = item.fileCount > 1
        return HStack(spacing: 12) {
            Toggle(isOn: selectionBinding(item)) { EmptyView() }.labelsHidden()
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((isDirectory ? Color.accentColor : Color.secondary).opacity(0.11))
                Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDirectory ? Color.accentColor : .secondary)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if isEstimated {
                        Text("Estimated size".localized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10), in: Capsule())
                    }
                }
                Text(item.url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(L10n.format("%lld files", Int64(item.fileCount)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let date = item.modifiedAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(formatted(item.bytes))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            Image(systemName: "arrow.forward.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { revealJunkItem(item) }
        .contextMenu {
            Button("Show in Finder".localized) { revealJunkItem(item) }
        }
    }

    func revealJunkItem(_ item: ScanItem) {
        let isDirectory = item.fileCount > 1 || item.url.pathExtension.isEmpty
        reveal(isDirectory ? item.url : item.url.deletingLastPathComponent())
    }

    func expansionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(id) },
            set: { expanded in
                if expanded { expandedGroups.insert(id) }
                else { expandedGroups.remove(id) }
            }
        )
    }

    func groupSelectionBinding(_ group: JunkScanGroup) -> Binding<Bool> {
        Binding(
            get: { model.isGroupSelected(group) },
            set: { model.setGroup(group, selected: $0) }
        )
    }
}
