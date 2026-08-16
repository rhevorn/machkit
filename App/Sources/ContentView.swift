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
    var id: String { rawValue }
}

enum StorageBrowseTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case categories = "Categories"
    case largeFiles = "Large Files"
    case folders = "Folders"

    var id: String { rawValue }
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
    @State var showingMemoryHelp = false
    @State var cleanupPhaseHelpID: String?
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
        .confirmationDialog("Uninstall this app?", isPresented: $model.showAppRemovalConfirmation) {
            Button("Move to Trash", role: .destructive, action: model.uninstallConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app and selected related files will be moved to Trash.")
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
                    Text("Used").font(.system(size: 9)).foregroundStyle(.secondary)
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
        let snapshot = model.performanceSnapshot
        let transferRate = model.networkTransferRate
        let memoryColor = snapshot.map { memoryPressureColor($0.memoryPressureLevel) } ?? .secondary
        let thermalColor = snapshot.map { thermalStateColor($0.thermalState) } ?? .secondary
        return HStack(spacing: 10) {
            homeMetricCard(
                title: "CPU",
                value: snapshot.map { "\(Int($0.cpuPercent.rounded()))%" } ?? "—",
                detail: "System Usage",
                icon: "cpu",
                color: .blue
            )
            homeMetricCard(
                title: "Memory",
                value: snapshot.map { "\(Int(($0.memoryPressure * 100).rounded()))%" } ?? "—",
                detail: snapshot.map { $0.memoryPressureLevel.rawValue } ?? "Loading",
                icon: "memorychip",
                color: memoryColor
            )
            homeNetworkMetricCard(transferRate)
            homeMetricCard(
                title: "Thermal",
                value: snapshot.map { thermalStateShortText($0.thermalState) } ?? "—",
                detail: snapshot == nil ? "Loading" : "Live",
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
        if model.selectedCount > 0 { return "Clean Selected" }
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
                            compactScanButton
                        }
                    }
                )
            )
                .padding(18)
            if model.isCleanupScanning {
                scanningView
            } else if model.items.isEmpty {
                junkEmptyView
            } else {
                junkDetailList
                Divider()
                HStack(spacing: 10) {
                    Text("\(model.selectedCount) items selected, \(formatted(model.selectedBytes))")
                    junkSelectionControls
                    Spacer(minLength: 8)
                    cleanSelectionButton
                }.padding(12)
            }
        }
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

    var junkEmptyView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.16), Color.cyan.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                Circle()
                    .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                    .frame(width: 124, height: 124)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.22))
                    .font(.system(size: 52, weight: .light))
            }
            .padding(.bottom, 24)

            Text("Give your Mac a light cleanup")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Scan caches, logs, and developer leftovers; review before cleaning")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 7)

            HStack(spacing: 18) {
                scanPromise(icon: "lock.shield", text: "Local Scan")
                scanPromise(icon: "checkmark.circle", text: "Review Each Item")
                scanPromise(icon: "arrow.uturn.backward.circle", text: "Recoverable from Trash")
            }
            .padding(.vertical, 22)

            Button(action: scanJunk) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Scan")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 214, height: 46)
                .background {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.12, green: 0.43, blue: 0.96), Color(red: 0.18, green: 0.58, blue: 0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 12, y: 5)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func scanPromise(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    var compactScanButton: some View {
        Button(action: scanJunk) {
            Label("Scan Again", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(Color.accentColor.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    var cleanSelectionButton: some View {
        Button(action: model.requestClean) {
            HStack(spacing: 7) {
                Image(systemName: "trash")
                Text("Clean Selected")
                Text(formatted(model.selectedBytes))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(height: 34)
            .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.selectedIDs.isEmpty)
        .opacity(model.selectedIDs.isEmpty ? 0.45 : 1)
    }

    var scanningView: some View {
        let phases = model.visibleCleanupScanPhases

        return ZStack {
            scanningAmbientBackground

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                ZStack {
                    scanningWaterGauge(progress: model.scanProgress)
                    VStack(spacing: 3) {
                        Text(formatted(model.discoveredBytes))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Found".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 88)
                }
                .animation(.easeInOut(duration: 0.35), value: model.scanProgress)
                .animation(.easeInOut(duration: 0.2), value: model.discoveredBytes)

                Text(model.currentScanCategory)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .padding(.top, 18)
                    .contentTransition(.opacity)

                Text("Reads file metadata only; contents are never read or uploaded")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                scanningPhaseAxis(phases: phases)
                    .padding(.horizontal, 36)
                    .padding(.top, 28)
                    .animation(.easeInOut(duration: 0.2), value: model.completedCleanupPhases)
                    .animation(.easeInOut(duration: 0.2), value: model.activeCleanupPhaseID)
                    .animation(.easeInOut(duration: 0.15), value: model.activeCleanupPhaseProgress)
                    .animation(.easeInOut(duration: 0.15), value: model.scanProgress)

                scanningCancelButton
                    .padding(.top, 32)

                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.22), value: model.currentScanCategory)
        .animation(.easeInOut(duration: 0.16), value: cleanupPhaseHelpID)
    }

    func scanningWaterGauge(progress: Double) -> some View {
        let fill = max(0, min(1, progress))
        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.14), lineWidth: 1.5)
                    .frame(width: 118, height: 118)

                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 110, height: 110)

                Canvas { canvas, size in
                    let level = size.height * (1 - fill)
                    var wave = Path()
                    wave.move(to: CGPoint(x: 0, y: size.height))
                    wave.addLine(to: CGPoint(x: 0, y: level))
                    let steps = 24
                    for i in 0...steps {
                        let x = size.width * CGFloat(i) / CGFloat(steps)
                        let y = level
                            + sin((CGFloat(i) / 3.2) + t * 2.6) * 3.2
                            + sin((CGFloat(i) / 1.7) + t * 1.5) * 1.6
                        wave.addLine(to: CGPoint(x: x, y: y))
                    }
                    wave.addLine(to: CGPoint(x: size.width, y: size.height))
                    wave.closeSubpath()
                    canvas.fill(
                        wave,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.accentColor.opacity(0.35),
                                Color.accentColor.opacity(0.72),
                            ]),
                            startPoint: CGPoint(x: size.width / 2, y: level),
                            endPoint: CGPoint(x: size.width / 2, y: size.height)
                        )
                    )
                }
                .frame(width: 110, height: 110)
                .clipShape(Circle())

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.55),
                                Color.accentColor.opacity(0.18),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.accentColor.opacity(0.22), radius: 10, y: 0)
            }
            .frame(width: 118, height: 118)
        }
    }

    var scanningAmbientBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 1.4)
            ZStack {
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(0.10 + 0.04 * pulse),
                        Color.accentColor.opacity(0.03),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
                .blur(radius: 8)

                Canvas { context, size in
                    let step: CGFloat = 28
                    for x in stride(from: 0, through: size.width, by: step) {
                        for y in stride(from: 0, through: size.height, by: step) {
                            let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                            context.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.045)))
                        }
                    }
                }
                .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
    }

    var scanningCancelButton: some View {
        Button(action: model.cancelScan) {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Cancel Scan")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.primary.opacity(0.78))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.45),
                                        Color.primary.opacity(0.12),
                                        Color.accentColor.opacity(0.28),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.12), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .help("Cancel Scan".localized)
    }

    func scanningPhaseAxis(phases: [CleanerViewModel.CleanupScanPhase]) -> some View {
        let overallFill = max(0, min(1, model.scanProgress))
        let activeProgress = max(0, min(1, model.activeCleanupPhaseProgress))
        let phaseCount = max(phases.count, 1)

        return VStack(spacing: 12) {
            ZStack {
                GeometryReader { geo in
                    let inset = geo.size.width / CGFloat(phaseCount * 2)
                    let trackWidth = max(0, geo.size.width - inset * 2)
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.16))
                        .frame(width: trackWidth, height: 2)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.55),
                                    Color.accentColor,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: trackWidth * overallFill, height: 2)
                        .position(
                            x: inset + trackWidth * overallFill / 2,
                            y: geo.size.height / 2
                        )
                        .shadow(color: Color.accentColor.opacity(0.45), radius: 4, y: 0)
                }

                HStack(spacing: 0) {
                    ForEach(Array(phases.enumerated()), id: \.element.id) { _, phase in
                        let isDone = model.completedCleanupPhases.contains(phase.id)
                        let isActive = !isDone && model.activeCleanupPhaseID == phase.id
                        let phaseProgress = isDone
                            ? 1.0
                            : (isActive ? activeProgress : 0)
                        axisNode(isDone: isDone, isActive: isActive, progress: phaseProgress)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 28)

            HStack(alignment: .top, spacing: 0) {
                ForEach(phases) { phase in
                    let isDone = model.completedCleanupPhases.contains(phase.id)
                    let isActive = !isDone && model.activeCleanupPhaseID == phase.id
                    let reached = isDone || isActive
                    let helpShown = cleanupPhaseHelpID == phase.id

                    HStack(spacing: 3) {
                        Text(phase.title.localized)
                            .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(reached ? Color.primary : Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        phaseHelpButton(phase: phase, helpShown: helpShown)
                    }
                    .frame(maxWidth: .infinity)
                    .zIndex(helpShown ? 20 : 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.22),
                                    Color.primary.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.accentColor.opacity(0.08), radius: 16, y: 4)
        )
        // Leave room so hover tips can sit above labels without feeling clipped.
        .padding(.top, 4)
    }

    func phaseHelpButton(phase: CleanerViewModel.CleanupScanPhase, helpShown: Bool) -> some View {
        Button {
            cleanupPhaseHelpID = helpShown ? nil : phase.id
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(helpShown ? Color.accentColor : Color.secondary.opacity(0.85))
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(phase.summary.localized)
        .overlay {
            if helpShown {
                phaseHelpTooltip(phase)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: -36)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom))
                    )
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                if hovering {
                    cleanupPhaseHelpID = phase.id
                } else if cleanupPhaseHelpID == phase.id {
                    cleanupPhaseHelpID = nil
                }
            }
        }
        .zIndex(helpShown ? 30 : 0)
    }

    func phaseHelpTooltip(_ phase: CleanerViewModel.CleanupScanPhase) -> some View {
        Text(phase.summary.localized)
            .font(.system(size: 11))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .frame(maxWidth: 220, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 1)
            )
            .allowsHitTesting(false)
    }

    func axisNode(isDone: Bool, isActive: Bool, progress: Double) -> some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 24.0 : 120, paused: !isActive)) { context in
            let pulse = isActive
                ? 0.55 + 0.45 * sin(context.date.timeIntervalSinceReferenceDate * 3.2)
                : 1.0
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16 * pulse))
                        .frame(width: 28, height: 28)
                        .scaleEffect(0.9 + 0.18 * pulse)
                }
                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 2.5)
                    .frame(width: 22, height: 22)
                Circle()
                    .trim(from: 0, to: max(isActive || isDone ? 0.04 : 0, progress))
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                    .shadow(color: isActive ? Color.accentColor.opacity(0.45) : .clear, radius: 4)
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 12, height: 12)
                if isDone {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                } else if isActive {
                    Circle()
                        .fill(Color.accentColor.opacity(0.95))
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.85 + 0.2 * pulse)
                }
            }
            .frame(width: 28, height: 28)
        }
    }

    var junkDetailList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                cleanupResultOverview
                ForEach(model.junkGroups) { group in
                    DisclosureGroup(isExpanded: expansionBinding(group.id)) {
                        groupDetails(group)
                    } label: {
                        HStack(spacing: 11) {
                            Toggle(isOn: groupSelectionBinding(group)) { EmptyView() }.labelsHidden()
                            Image(systemName: group.risk == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(group.risk == .safe ? .green : .orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.title.localized).font(.system(size: 14, weight: .semibold))
                                Text(L10n.format(
                                    "%lld locations · %@",
                                    Int64(group.totalCount),
                                    group.explanation.localized
                                ))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(formatted(group.bytes)).monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .padding(14)
                    .background { RoundedRectangle(cornerRadius: 9).fill(Color(nsColor: .controlBackgroundColor)) }
                }
            }.padding(14)
        }
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

    var cleanupResultOverview: some View {
        return HStack(spacing: 10) {
            cleanupSummaryMetric(
                title: "Found",
                value: formatted(model.totalBytes),
                detail: L10n.format("%lld locations", Int64(model.items.count)),
                icon: "sparkles.rectangle.stack",
                color: .blue
            )
            cleanupSummaryMetric(
                title: "Safe to Clean",
                value: formatted(model.safeCleanableBytes),
                detail: L10n.format("%lld selected by default", Int64(model.safeItemCount)),
                icon: "checkmark.shield.fill",
                color: .green
            )
            cleanupSummaryMetric(
                title: "Review",
                value: formatted(model.reviewCleanableBytes),
                detail: L10n.format("%lld not selected", Int64(model.reviewItemCount)),
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 14).padding(.top, 14)
    }

    func cleanupSummaryMetric(
        title: String,
        value: String,
        detail: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func groupDetails(_ group: JunkScanGroup) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 44)
            ForEach(group.items) { item in
                junkFileRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 72) }
            }
        }
    }

    func junkFileRow(_ item: ScanItem) -> some View {
        let isDirectory = item.fileCount > 1 || item.url.pathExtension.isEmpty
        return HStack(spacing: 10) {
            Toggle(isOn: selectionBinding(item)) { EmptyView() }.labelsHidden()
            Image(systemName: isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(isDirectory ? Color.accentColor.opacity(0.85) : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).lineLimit(1)
                Text(item.url.path)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                Text(L10n.format("%lld files", Int64(item.fileCount)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = item.modifiedAt {
                Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Text(formatted(item.bytes)).font(.caption).monospacedDigit().frame(width: 72, alignment: .trailing)
        }.padding(.vertical, 8).padding(.horizontal, 4)
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
