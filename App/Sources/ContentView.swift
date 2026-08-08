import AppKit
import Charts
import SiftCore
import SwiftUI

private enum SoftwareTab: String, CaseIterable, Identifiable {
    case all = "All"
    case appStore = "App Store"
    case thirdParty = "Third Party"
    case user = "User"
    case system = "System"
    case commandLine = "Command Line"
    var id: String { rawValue }
}

private enum PerformanceSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    var id: String { rawValue }
}

private enum PortFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case tcp = "TCP"
    case udp = "UDP"
    case exposed = "Exposed"
    var id: String { rawValue }
}

private struct LoginItemGroup: Identifiable {
    let domain: LoginItemDomain
    let items: [LoginItem]
    var id: LoginItemDomain { domain }
}

private struct ExtensionGroup: Identifiable {
    let kind: InstalledExtensionKind
    let items: [InstalledExtension]
    var id: InstalledExtensionKind { kind }
}

struct ContentView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @StateObject private var model = CleanerViewModel()
    @StateObject private var permissions = PermissionManager()
    @State private var expandedGroups: Set<String> = []
    @State private var applicationSearch = ""
    @State private var softwareTab: SoftwareTab = .all
    @State private var selectedCommandLineTool: CommandLineTool?
    @State private var hoveredSoftwareID: String?
    @State private var inventorySearch = ""
    @State private var performanceSort: PerformanceSort = .cpu
    @State private var showingMemoryHelp = false
    @State private var portSearch = ""
    @State private var portFilter: PortFilter = .all
    @State private var selectedPort: ListeningPort?

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
                case .ports: portsView
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
        .confirmationDialog("Move selected files to Trash?", isPresented: $model.showCleanConfirmation) {
            Button("Move to Trash", role: .destructive, action: model.cleanConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(model.selectedCount) items, \(formatted(model.selectedBytes)) total.")
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
            Text("This resets all login item and background activity records, not just the current leftover. Installed apps will register again, and some allowed or blocked states may need confirmation. Restart your Mac afterward.")
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
            permissions.refresh()
        }
        .onChange(of: languageRawValue) { _, _ in
            model.refreshLocalizedStatus()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            brandMark.padding(.top, 52).padding(.bottom, 18)
            sideButton(.home, icon: "house.fill")
            sideButton(.junk, icon: "paintbrush.fill")
            sideButton(.uninstall, icon: "app.badge.checkmark")
            sideButton(.files, icon: "chart.pie.fill")
            sideButton(.performance, icon: "gauge.with.dots.needle.67percent")
            sideButton(.ports, icon: "network")
            systemInventorySideButton
            Spacer()
            if model.isStorageAnalyzing {
                Button { model.changeMode(.files) } label: {
                    VStack(spacing: 4) {
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
                VStack(spacing: 5) {
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

    private func openFeedback() {
        if let url = URL(string: "https://github.com/rhevorn/sift/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    private var brandMark: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
            .help("Sift")
    }

    private func sideButton(_ mode: FeatureMode, icon: String) -> some View {
        Button {
            inventorySearch = ""
            model.changeMode(mode)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                sidebarLabel(mode.rawValue.localized)
            }
            .foregroundStyle(model.mode == mode ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 52)
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

    private var systemInventorySideButton: some View {
        let isSelected = [.loginItems, .backgroundActivity, .extensions].contains(model.mode)
        return Button {
            inventorySearch = ""
            if !isSelected { model.changeMode(.loginItems) }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "switch.2").font(.system(size: 17, weight: .medium))
                sidebarLabel("System", size: 10.5)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 52)
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

    private func sidebarLabel(
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

    private var homeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header(title: "Overview", subtitle: "Live status and everyday tools for this Mac")
                homeStorageOverview
                if !permissions.hasFullDiskAccess {
                    permissionCard
                }

                HStack {
                    Text("Live Status").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Auto Updating").font(.caption).foregroundStyle(.secondary)
                    }
                }

                homeMetrics
                homeQuickAction

                HStack(alignment: .firstTextBaseline) {
                    Text("Common Tools").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("Processed locally, never uploaded").font(.caption).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    homeToolTile(
                        title: "Cleanup", subtitle: "Caches, logs, and developer tool junk",
                        icon: "paintbrush.fill", color: .blue, mode: .junk
                    )
                    homeToolTile(
                        title: "Storage", subtitle: "Disk categories, folder usage, and large files",
                        icon: "chart.pie.fill", color: .indigo, mode: .files
                    )
                    homeToolTile(
                        title: "Apps", subtitle: "Installed apps and command-line tools",
                        icon: "app.badge.checkmark", color: .purple, mode: .uninstall
                    )
                    homeToolTile(
                        title: "Performance", subtitle: "CPU, memory pressure, and resource-heavy apps",
                        icon: "gauge.with.dots.needle.67percent", color: .mint, mode: .performance
                    )
                    homeToolTile(
                        title: "Ports", subtitle: "Find and stop forgotten development services",
                        icon: "network", color: .orange, mode: .ports
                    )
                    homeToolTile(
                        title: "System", subtitle: "Startup items, background activity, and app extensions",
                        icon: "switch.2", color: .cyan, mode: .loginItems
                    )
                }
            }
            .padding(18)
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 20))
                .foregroundStyle(permissions.hasFullDiskAccess ? .green : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(permissions.hasFullDiskAccess ? "Full Disk Access granted" : "Full Disk Access Required")
                    .font(.system(size: 13, weight: .semibold))
                Text(permissions.hasFullDiskAccess
                     ? "Allows protected user folders to be scanned. File contents are never uploaded."
                     : "Used to find app caches and leftovers. Enable it manually in System Settings.")
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

    private var homeStorageOverview: some View {
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
                    Label("\(formatted(storage.usedCapacity)) Used", systemImage: "internaldrive.fill")
                    Label("\(formatted(storage.availableCapacity)) Available", systemImage: "checkmark.circle")
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

    private var homeMetrics: some View {
        let snapshot = model.performanceSnapshot
        let exposedPorts = model.listeningPorts.filter { $0.exposure != .loopback }.count
        let memoryColor = snapshot.map { memoryPressureColor($0.memoryPressureLevel) } ?? .secondary
        return HStack(spacing: 10) {
            homeMetricCard(
                title: "CPU",
                value: snapshot.map { "\(Int($0.cpuPercent.rounded()))%" } ?? "—",
                detail: "System Usage",
                icon: "cpu",
                color: .blue
            )
            homeMetricCard(
                title: "Memory Usage",
                value: snapshot.map { "\(Int(($0.memoryPressure * 100).rounded()))%" } ?? "—",
                detail: snapshot.map { L10n.format("Memory Pressure %@", $0.memoryPressureLevel.rawValue.localized) } ?? "Loading",
                icon: "memorychip",
                color: memoryColor
            )
            homeMetricCard(
                title: "Exposed Ports",
                value: model.hasLoadedPortSnapshot ? String(exposedPorts) : "—",
                detail: model.hasLoadedPortSnapshot ? "Currently Listening" : "Checking",
                icon: "network",
                color: exposedPorts > 0 ? .orange : .green
            )
            homeMetricCard(
                title: "Cleanable Space",
                value: model.cleanableBytes.map(formatted) ?? "—",
                detail: model.cleanableBytes == nil ? "Waiting to Scan" : "Latest Result",
                icon: "sparkles",
                color: .purple
            )
        }
    }

    private func homeMetricCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
                    .background(color.opacity(0.11), in: Circle())
                Spacer(minLength: 4)
                Text(title.localized).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(verbatim: value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            Text(detail.localized).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var homeQuickAction: some View {
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

    private var homeQuickActionDescription: String {
        if model.isCleanupScanning { return L10n.string("Looking for caches and logs that are safe to clean…") }
        guard let cleanableBytes = model.cleanableBytes else {
            return L10n.string("Scan caches, logs, and regenerable developer tool files")
        }
        if cleanableBytes == 0 { return L10n.string("The latest scan found nothing to clean") }
        return L10n.format("The latest scan found %@ of cleanable content", formatted(cleanableBytes))
    }

    private var homeQuickActionButtonTitle: String {
        if model.isCleanupScanning { return "Scanning" }
        if model.selectedCount > 0 { return "Clean Selected" }
        return model.cleanableBytes == nil ? "Start Scan" : "Scan Again"
    }

    private func homeToolTile(
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

    private func homeStorageColor(_ fraction: Double) -> Color {
        if fraction >= 0.93 { return .red }
        if fraction >= 0.84 { return .orange }
        return .green
    }

    private func homeStorageIcon(_ fraction: Double) -> String {
        if fraction >= 0.93 { return "exclamationmark.triangle.fill" }
        if fraction >= 0.84 { return "externaldrive.badge.exclamationmark" }
        return "checkmark.circle.fill"
    }

    private func homeStorageTitle(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return "Reading storage status…" }
        if storage.usedFraction >= 0.93 { return "Your Mac is low on storage" }
        if storage.usedFraction >= 0.84 { return "Storage space is getting tight" }
        return "Mac storage looks good"
    }

    private func homeStorageDescription(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return L10n.string("Reading system disk capacity") }
        return L10n.format(
            "%@ available of %@ total",
            formatted(storage.availableCapacity),
            formatted(storage.totalCapacity)
        )
    }

    private var junkView: some View {
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
                HStack {
                    Text("\(model.selectedCount) items selected, \(formatted(model.selectedBytes))")
                    Spacer()
                    cleanSelectionButton
                }.padding(12)
            }
        }
    }

    private var cleanupScanFocusAreas: [(icon: String, title: String)] {
        [
            ("internaldrive", "App caches"),
            ("doc.text", "Developer logs"),
            ("shippingbox", "Dependency libraries"),
            ("hammer", "Build caches"),
            ("app.badge", "Leftover app data")
        ]
    }

    private var activeCleanupFocusIndex: Int {
        let phase = model.currentScanCategory.lowercased()
        if phase.contains("log") { return 1 }
        if phase.contains("dependenc") || phase.contains("installer") { return 2 }
        if phase.contains("build") || phase.contains("simulator") { return 3 }
        if phase.contains("leftover") { return 4 }
        if phase.contains("cache") { return 0 }
        let step = min(max(Int(model.scanProgress * Double(cleanupScanFocusAreas.count)), 0), cleanupScanFocusAreas.count - 1)
        return step
    }

    private var junkEmptyView: some View {
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

    private func scanPromise(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var compactScanButton: some View {
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

    private var cleanSelectionButton: some View {
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

    private var scanningView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.cyan.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                    .frame(width: 108, height: 108)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.25))
                    .font(.system(size: 46, weight: .light))
                    .symbolEffect(.pulse, options: .repeating, value: model.isCleanupScanning)
            }
            .padding(.bottom, 22)

            Text(model.currentScanCategory)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .contentTransition(.opacity)

            Text("Reads file metadata only; contents are never read or uploaded")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 7)

            VStack(spacing: 10) {
                ProgressView(value: model.scanProgress)
                HStack {
                    Text("\(Int(model.scanProgress * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text("\(formatted(model.discoveredBytes)) found so far")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 360)
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(cleanupScanFocusAreas.enumerated()), id: \.offset) { index, area in
                    let isActive = index == activeCleanupFocusIndex
                    let isDone = index < activeCleanupFocusIndex
                    HStack(spacing: 10) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : (isActive ? area.icon : "circle"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDone || isActive ? Color.accentColor : Color.secondary.opacity(0.55))
                            .frame(width: 18)
                        Text(area.title.localized)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        Spacer(minLength: 0)
                        if isActive {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
                }
            }
            .frame(width: 360)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.top, 26)
            .animation(.easeInOut(duration: 0.22), value: activeCleanupFocusIndex)

            Button("Cancel Scan", role: .cancel, action: model.cancelScan)
                .padding(.top, 22)
            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: model.currentScanCategory)
    }

    private var junkDetailList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                cleanupResultOverview
                ForEach(model.junkGroups) { group in
                    DisclosureGroup(isExpanded: expansionBinding(group.id)) {
                        groupDetails(group)
                    } label: {
                        HStack(spacing: 11) {
                            Toggle("", isOn: groupSelectionBinding(group)).labelsHidden()
                            Image(systemName: group.risk == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(group.risk == .safe ? .green : .orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.title.localized).font(.system(size: 14, weight: .semibold))
                                Text("\(group.items.count) files · \(group.explanation.localized)")
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

    private var cleanupResultOverview: some View {
        let safeItems = model.items.filter { $0.rule.risk == .safe }
        let reviewItems = model.items.filter { $0.rule.risk == .review }
        return HStack(spacing: 10) {
            cleanupSummaryMetric(
                title: "Found",
                value: formatted(model.totalBytes),
                detail: L10n.format("%lld files", Int64(model.items.count)),
                icon: "sparkles.rectangle.stack",
                color: .blue
            )
            cleanupSummaryMetric(
                title: "Safe to Clean",
                value: formatted(safeItems.reduce(0) { $0 + $1.bytes }),
                detail: L10n.format("%lld selected by default", Int64(safeItems.count)),
                icon: "checkmark.shield.fill",
                color: .green
            )
            cleanupSummaryMetric(
                title: "Review",
                value: formatted(reviewItems.reduce(0) { $0 + $1.bytes }),
                detail: L10n.format("%lld not selected", Int64(reviewItems.count)),
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 14).padding(.top, 14)
    }

    private func cleanupSummaryMetric(
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

    private func groupDetails(_ group: JunkScanGroup) -> some View {
        let visibleItems = Array(group.items.prefix(100))
        return VStack(spacing: 0) {
            Divider().padding(.leading, 44)
            ForEach(visibleItems) { item in
                junkFileRow(item)
                if item.id != visibleItems.last?.id { Divider().padding(.leading, 72) }
            }
            if group.items.count > visibleItems.count {
                HStack {
                    Image(systemName: "info.circle")
                    Text("For performance, only the 100 largest items are shown; selecting the group still includes all \(group.items.count) items.")
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
    }

    private func junkFileRow(_ item: ScanItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selectionBinding(item)).labelsHidden()
            Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).lineLimit(1)
                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            if let date = item.modifiedAt {
                Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Text(formatted(item.bytes)).font(.caption).monospacedDigit().frame(width: 72, alignment: .trailing)
        }.padding(.vertical, 8).padding(.horizontal, 4)
    }

    private func expansionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(id) },
            set: { expanded in
                if expanded { expandedGroups.insert(id) }
                else { expandedGroups.remove(id) }
            }
        )
    }

    private func groupSelectionBinding(_ group: JunkScanGroup) -> Binding<Bool> {
        Binding(
            get: { model.isGroupSelected(group) },
            set: { model.setGroup(group, selected: $0) }
        )
    }

    private var uninstallView: some View {
        VStack(spacing: 0) {
            header(
                title: "Apps",
                subtitle: "Apps on this Mac were detected automatically",
                trailing: AnyView(
                    HStack(spacing: 12) {
                        Text(L10n.format("%lld apps", Int64(model.applications.count)))
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        refreshControl(for: .uninstall, action: model.scanInstalledApplications)
                    }
                )
            )
                .padding(18)
            if model.applications.isEmpty && model.isLoading(.uninstall) {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("Reading installed apps…").font(.system(size: 13, weight: .medium))
                    Text("Usually takes only a few seconds").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search apps", text: $applicationSearch).textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 9)

                    softwareCategoryTabs

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if softwareTab != .commandLine {
                                ForEach(filteredApplicationGroups) { group in applicationSection(group) }
                            }
                            if softwareTab == .all || softwareTab == .commandLine {
                                ForEach(filteredCommandLineGroups, id: \.manager) { group in
                                    commandLineSection(manager: group.manager, tools: group.tools)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private var softwareCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(SoftwareTab.allCases) { tab in
                    Button { withAnimation(.easeOut(duration: 0.16)) { softwareTab = tab } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: softwareTabIcon(tab))
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue.localized).font(.system(size: 11, weight: .semibold))
                            Text("\(softwareTabCount(tab))")
                                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                                .padding(.horizontal, 5).frame(height: 17)
                                .background(
                                    softwareTab == tab ? Color.white.opacity(0.18) : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .foregroundStyle(softwareTab == tab ? Color.white : Color.primary.opacity(0.72))
                        .padding(.horizontal, 10).frame(height: 32)
                        .background {
                            Capsule(style: .continuous)
                                .fill(softwareTab == tab ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        }
                        .overlay {
                            if softwareTab != tab {
                                Capsule().stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    private func softwareTabIcon(_ tab: SoftwareTab) -> String {
        switch tab {
        case .all: "square.grid.2x2"
        case .appStore: "bag"
        case .thirdParty: "shippingbox"
        case .user: "person.crop.circle"
        case .system: "apple.logo"
        case .commandLine: "terminal"
        }
    }

    private func softwareTabCount(_ tab: SoftwareTab) -> Int {
        switch tab {
        case .all: model.applications.count + model.commandLineTools.count
        case .appStore: model.applicationGroups.first(where: { $0.category == .appStore })?.applications.count ?? 0
        case .thirdParty: model.applicationGroups.first(where: { $0.category == .thirdParty })?.applications.count ?? 0
        case .user: model.applicationGroups.first(where: { $0.category == .user })?.applications.count ?? 0
        case .system: model.applicationGroups.first(where: { $0.category == .system })?.applications.count ?? 0
        case .commandLine: model.commandLineTools.count
        }
    }

    private var filteredApplicationGroups: [ApplicationGroup] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = model.applicationGroups.filter { group in
            switch softwareTab {
            case .all: true
            case .appStore: group.category == .appStore
            case .thirdParty: group.category == .thirdParty
            case .user: group.category == .user
            case .system: group.category == .system
            case .commandLine: false
            }
        }
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let matches = group.applications.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return matches.isEmpty ? nil : ApplicationGroup(category: group.category, applications: matches)
        }
    }

    private var filteredCommandLineGroups: [(manager: CommandLineToolManager, tools: [CommandLineTool])] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let tools = query.isEmpty ? model.commandLineTools : model.commandLineTools.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.manager.rawValue.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: tools, by: \.manager)
        return CommandLineToolManager.allCases.compactMap { manager in
            guard let matches = grouped[manager], !matches.isEmpty else { return nil }
            return (manager, matches)
        }
    }

    private func applicationSection(_ group: ApplicationGroup) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.category.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text(group.category.subtitle.localized).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(group.applications.count) · \(formatted(group.bytes))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(group.applications) { app in
                applicationRow(app)
                if app.id != group.applications.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func applicationRow(_ app: InstalledApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if let version = app.version { Text("Version \(version)") }
                    Text(app.bundleURL.deletingLastPathComponent().path)
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(app.bytes > 0 ? formatted(app.bytes) : "—")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 62, alignment: .trailing)
            if model.isSystemApplication(app) {
                Text("System Protected").font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(width: 58)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).frame(width: 58)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(
            hoveredSoftwareID == app.id ? Color.accentColor.opacity(0.055) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onHover { hovering in hoveredSoftwareID = hovering ? app.id : nil }
        .onTapGesture { model.prepareUninstall(app) }
    }

    private func commandLineSection(manager: CommandLineToolManager, tools: [CommandLineTool]) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text("Command-line tools installed by package managers").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tools.count) · \(formatted(tools.reduce(0) { $0 + $1.bytes }))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(tools) { tool in
                HStack(spacing: 12) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.name).font(.system(size: 13, weight: .medium))
                        Text(tool.version.map { "Version \($0) · \(tool.installURL.path)" } ?? tool.installURL.path)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(formatted(tool.bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(
                    hoveredSoftwareID == tool.id ? Color.accentColor.opacity(0.055) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onHover { hovering in hoveredSoftwareID = hovering ? tool.id : nil }
                .onTapGesture { selectedCommandLineTool = tool }
                if tool.id != tools.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func applicationDetails(_ app: InstalledApplication) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.title3.weight(.semibold))
                    Text("App Details and Related Data").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    detailValue(title: "Version", value: app.version ?? L10n.string("Unknown"))
                    detailValue(title: "Bundle ID", value: app.bundleIdentifier ?? L10n.string("Unknown"))
                    detailValue(title: "Installed At", value: app.bundleURL.path)
                    detailValue(title: "App Size", value: formatted(app.bytes))
                    Divider().padding(.vertical, 5)
                    if model.uninstallResidues.isEmpty {
                        Text("No related leftover files found.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        Text("Related Files").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                        ForEach(model.uninstallResidues) { residue in
                            uninstallItem(title: residue.kind.rawValue, detail: residue.url.path, bytes: residue.bytes, selected: residueSelectionBinding(residue))
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Label("Recoverable from Trash", systemImage: "arrow.uturn.backward.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { model.uninstallCandidate = nil }
                if !model.isSystemApplication(app) {
                    Button("Uninstall App…", role: .destructive) { model.showAppRemovalConfirmation = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }

    private func detailValue(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.localized).font(.caption).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            Text(value).font(.system(size: 12)).textSelection(.enabled)
            Spacer()
        }
    }

    private func commandLineToolDetails(_ tool: CommandLineTool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill").font(.system(size: 28)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.name).font(.title3.weight(.semibold))
                    Text(tool.manager.rawValue.localized).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            detailValue(title: "Version", value: tool.version ?? L10n.string("Unrecognized"))
            detailValue(title: "Installed At", value: tool.installURL.path)
            detailValue(title: "Storage Used", value: formatted(tool.bytes))
            detailValue(title: "Uninstall Command", value: uninstallCommand(for: tool))
            Text("Command-line tools are managed by package managers. Sift shows suggested commands instead of deleting directories, which could break dependencies.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack { Spacer(); Button("Close") { selectedCommandLineTool = nil }.keyboardShortcut(.defaultAction) }
        }
        .padding(22).frame(width: 520, height: 310)
    }

    private func uninstallCommand(for tool: CommandLineTool) -> String {
        tool.manager.uninstallCommand(name: tool.name, version: tool.version)
            ?? L10n.string("Package ownership could not be verified; inspect it manually")
    }

    private func uninstallItem(title: String, detail: String, bytes: Int64, selected: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selected).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formatted(bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func residueSelectionBinding(_ residue: ApplicationResidue) -> Binding<Bool> {
        Binding(
            get: { model.selectedResidueIDs.contains(residue.id) },
            set: { selected in
                if selected { model.selectedResidueIDs.insert(residue.id) }
                else { model.selectedResidueIDs.remove(residue.id) }
            }
        )
    }

    private var loginItemsView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    refreshControl(for: .loginItems, action: model.scanLoginItems)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "person.badge.key",
                title: "Matches macOS Login Items",
                detail: "Apps that open automatically after logging in are displayed here; some new items can only be managed in system settings.",
                buttonTitle: "Open Login Item Settings"
            )

            inventorySearchField(placeholder: "Search login items or app paths")

            if model.isLoading(.loginItems) && model.loginApplications.isEmpty {
                inventoryLoadingView(title: "Reading login items…")
            } else if let error = model.loginApplicationsError, model.loginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: "Unable to Read Login Items",
                    detail: error,
                    icon: "exclamationmark.triangle"
                )
            } else if filteredLoginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: inventorySearch.isEmpty ? "No Login Items" : "No matching login items",
                    detail: inventorySearch.isEmpty ? "Apps that open when logging in can be added in system settings" : "Try another search term",
                    icon: "person.badge.key"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        inventorySectionHeader(
                            title: "Open at Login",
                            subtitle: "Open automatically after logging in to the current account",
                            count: filteredLoginApplications.count
                        )
                        Divider()
                        ForEach(filteredLoginApplications) { item in
                            loginApplicationRow(item)
                            if item.id != filteredLoginApplications.last?.id { Divider().padding(.leading, 66) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredLoginApplications: [LoginApplication] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.loginApplications }
        return model.loginApplications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func loginApplicationRow(_ item: LoginApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? L10n.string("Path Unavailable"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("File Not Found")
            }
            if item.isHidden {
                inventoryBadge("Hide After Launch", color: .secondary)
            }
            if let url = item.applicationURL {
                Button("Show") { reveal(url) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
            Button("Remove", role: .destructive) { model.requestLoginApplicationRemoval(item) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var backgroundActivityView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            model.showBackgroundDatabaseResetConfirmation = true
                        } label: {
                            Label("Rebuild Database", systemImage: "arrow.triangle.2.circlepath")
                        }
                        refreshControl(for: .backgroundActivity, action: model.scanBackgroundActivity)
                    }
                    .disabled(model.isScanning)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "waveform.path.ecg",
                title: "About Background Activity",
                detail: "\"Autostart\" means to start after the configuration is loaded; \"Restart after exit\" means that launchd will try to start again after the process exits.",
                buttonTitle: "Open Background Settings"
            )

            inventorySearchField(placeholder: "Search background items, labels, or paths")

            if model.isLoading(.backgroundActivity) && model.backgroundItems.isEmpty && model.registeredBackgroundTasks.isEmpty {
                inventoryLoadingView(title: "Reading background activity…")
            } else if filteredBackgroundItemGroups.isEmpty && filteredRegisteredBackgroundTasks.isEmpty {
                ContentUnavailableView(
                    inventorySearch.isEmpty ? "No Background Items" : "No matching background items",
                    systemImage: "waveform.path.ecg",
                    description: Text(model.backgroundTaskScanError ?? (inventorySearch.isEmpty ? "No background tasks or launchd configuration found" : "Try another search term"))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if let notice = model.backgroundDatabaseNotice {
                            HStack(spacing: 9) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(notice).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if let error = model.backgroundTaskScanError {
                            HStack(spacing: 9) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                Text(error).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if !filteredRegisteredBackgroundTasks.isEmpty {
                            registeredBackgroundTaskSection
                        }
                        ForEach(filteredBackgroundItemGroups) { group in
                            backgroundItemSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredRegisteredBackgroundTasks: [RegisteredBackgroundTask] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.registeredBackgroundTasks }
        return model.registeredBackgroundTasks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.teamIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var registeredBackgroundTaskSection: some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: "App Background Activity",
                subtitle: "App records in the macOS background task management database",
                count: filteredRegisteredBackgroundTasks.count
            )
            Divider()
            ForEach(filteredRegisteredBackgroundTasks) { item in
                registeredBackgroundTaskRow(item)
                if item.id != filteredRegisteredBackgroundTasks.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func registeredBackgroundTaskRow(_ item: RegisteredBackgroundTask) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? item.bundleIdentifier ?? L10n.string("System Record"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge(item.isRemovableTrashResidue(home: FileManager.default.homeDirectoryForCurrentUser)
                    ? "Trash Record"
                    : "App Not Found")
            }
            if let url = item.applicationURL {
                Button("Show") { reveal(url) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
            if item.isRemovableTrashResidue(home: FileManager.default.homeDirectoryForCurrentUser) {
                Button("Remove", role: .destructive) { model.requestRegisteredBackgroundTaskRemoval(item) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var filteredBackgroundItemGroups: [LoginItemGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.backgroundItems : model.backgroundItems.filter {
            $0.label.localizedCaseInsensitiveContains(query)
                || $0.configURL.path.localizedCaseInsensitiveContains(query)
                || ($0.executableURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \LoginItem.domain)
        return LoginItemDomain.allCases.compactMap { domain in
            guard let items = grouped[domain], !items.isEmpty else { return nil }
            return LoginItemGroup(domain: domain, items: items)
        }
    }

    private func backgroundItemSection(_ group: LoginItemGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.domain.rawValue,
                subtitle: group.domain.explanation,
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                backgroundItemRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func backgroundItemRow(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.executableURL?.path ?? item.configURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.executableURL?.path ?? item.configURL.path)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("File Not Found")
            }
            if item.runsAtLoad {
                inventoryBadge("Run at Load", color: .blue)
                    .help("Starts automatically when launchd loads the configuration. User agents usually load at login; daemons usually load at startup.")
            }
            if item.keepsAlive {
                inventoryBadge("Restart After Exit", color: .orange)
                    .help("After the process exits or crashes, launchd may try to start it again.")
            }
            Button("Show") { reveal(item.configURL) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            Button("Remove", role: .destructive) { model.requestBackgroundItemRemoval(item) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.configURL) }
    }

    private var extensionsView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    refreshControl(for: .extensions, action: model.scanExtensions)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "puzzlepiece.extension",
                title: "Extensions are installed with their respective apps",
                detail: "Please use system settings or the associated application to disable extensions to avoid damaging signatures and automatic updates.",
                buttonTitle: "Open Extension Settings"
            )

            inventorySearchField(placeholder: "Search extensions, owning apps, or bundle IDs")

            if model.isLoading(.extensions) && model.installedExtensions.isEmpty {
                inventoryLoadingView(title: "Inspecting installed apps…")
            } else if filteredExtensionGroups.isEmpty {
                ContentUnavailableView(
                    inventorySearch.isEmpty ? "No Extensions Found" : "No matching extensions",
                    systemImage: "puzzlepiece.extension",
                    description: Text(inventorySearch.isEmpty ? "No components found in installed apps or common extension folders" : "Try another search term")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredExtensionGroups) { group in
                            extensionSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredExtensionGroups: [ExtensionGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.installedExtensions : model.installedExtensions.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.ownerName?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \InstalledExtension.kind)
        return InstalledExtensionKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return ExtensionGroup(kind: kind, items: items)
        }
    }

    private func extensionSection(_ group: ExtensionGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.kind.rawValue,
                subtitle: extensionKindExplanation(group.kind),
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                extensionRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func extensionRow(_ item: InstalledExtension) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    if let owner = item.ownerName { Text(owner) }
                    if let version = item.version { Text("Version \(version)") }
                    if item.ownerName == nil && item.version == nil { Text(item.bundleURL.path) }
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("The application does not exist")
            }
            if let identifier = item.bundleIdentifier {
                Text(identifier).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            Button("Show") { reveal(item.bundleURL) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            if item.ownerApplicationURL == nil {
                Button("Remove", role: .destructive) { model.requestExtensionRemoval(item) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            } else {
                Button("Uninstall App") {
                    applicationSearch = item.ownerName ?? ""
                    model.changeMode(.uninstall)
                }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.bundleURL) }
    }

    private func inventoryManagementBanner(
        icon: String,
        title: String,
        detail: String,
        buttonTitle: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(detail.localized).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button(buttonTitle, action: openLoginItemsSettings).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(11)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private var systemInventoryTabs: some View {
        Picker("Item Type", selection: Binding(
            get: { model.mode },
            set: { newMode in
                inventorySearch = ""
                model.changeMode(newMode)
            }
        )) {
            Text("Login Items").tag(FeatureMode.loginItems)
            Text("Background Activity").tag(FeatureMode.backgroundActivity)
            Text("Extensions").tag(FeatureMode.extensions)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func inventorySearchField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $inventorySearch).textFieldStyle(.plain)
            if !inventorySearch.isEmpty {
                Button { inventorySearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .padding(16)
    }

    private func inventoryLoadingView(title: String) -> some View {
        VStack(spacing: 13) {
            ProgressView().controlSize(.large)
            Text(title.localized).font(.system(size: 13, weight: .medium))
            Text("Reads component information without changing system settings").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactInventoryEmptyState(title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized).font(.system(size: 13, weight: .semibold))
                    Text(detail.localized).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
    }

    private func inventorySectionHeader(title: String, subtitle: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(subtitle.localized).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func inventoryBadge(_ title: String, color: Color) -> some View {
        Text(title.localized)
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).frame(height: 21)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func missingBadge(_ title: String) -> some View {
        inventoryBadge(title, color: .red)
            .help("No matching file was found at the recorded path or among installed apps; this may be an uninstall leftover.")
    }

    private var loginApplicationRemovalMessage: String {
        guard let item = model.loginApplicationRemovalCandidate else {
            return L10n.string("This will be removed from macOS Login Items.")
        }
        let missing = item.assessment == .likelyResidue ? L10n.string("The corresponding file no longer exists.") : ""
        return L10n.format("%@ “%@” will be removed from Login Items. App files will not be deleted.", missing, item.name)
    }

    private var backgroundItemRemovalMessage: String {
        guard let item = model.backgroundItemRemovalCandidate else { return L10n.string("The launch configuration will be moved to Trash.") }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("The target program was not found; this may be an uninstall leftover.")
            : item.assessment.explanation.localized + L10n.string(".")
        return L10n.format("%@ “%@”'s launch configuration will be moved to Trash. Running processes will not be terminated.", assessment, item.label)
    }

    private var registeredBackgroundTaskRemovalMessage: String {
        guard let item = model.registeredBackgroundTaskRemovalCandidate else {
            return L10n.string("The app leftover in Trash will be permanently deleted.")
        }
        return L10n.format("“%@” is already in Trash. Continuing permanently deletes this app leftover and cannot be undone; the macOS background record may disappear after you sign in again.", item.name)
    }

    private var extensionRemovalMessage: String {
        guard let item = model.extensionRemovalCandidate else { return L10n.string("The extension will be moved to Trash.") }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("No matching owning app was found; this may be an uninstall leftover.")
            : item.assessment.explanation.localized + L10n.string(".")
        return L10n.format("%@ “%@” will be moved to Trash. Its features will no longer load after you sign in again.", assessment, item.name)
    }

    private func extensionKindExplanation(_ kind: InstalledExtensionKind) -> String {
        switch kind {
        case .system: "Use modern system extension technologies like DriverKit"
        case .network: "Participate in VPN, filtering or network connections"
        case .safari: "Powering Safari with web and browser functionality"
        case .finder: "Provide menu or sync status in Finder"
        case .quickLook: "Provides file previews and thumbnails"
        case .spotlight: "Help Spotlight read specific file formats"
        case .share: "Shown in system sharing menu"
        case .app: "Functional components provided by the owning application"
        }
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.LoginItems-Settings.extension"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private var portsView: some View {
        VStack(spacing: 0) {
            header(
                title: "Ports",
                subtitle: "Inspect TCP listeners, UDP bindings, and their processes",
                trailing: AnyView(autoUpdateIndicator(
                    active: true,
                    detail: model.lastUpdatedText(for: .ports)
                ))
            )
            .padding(18)

            if model.isLoading(.ports), model.listeningPorts.isEmpty {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("Reading ports and processes…")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Scans locally using macOS lsof")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                portListContent
            }
        }
    }

    private var portListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    portSummaryItem(
                        title: "Port",
                        value: "\(model.listeningPorts.count)",
                        icon: "network",
                        color: .blue
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "Process",
                        value: "\(Set(model.listeningPorts.map(\.processIdentifier)).count)",
                        icon: "terminal.fill",
                        color: .indigo
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "TCP",
                        value: "\(model.listeningPorts.filter { $0.transport == .tcp }.count)",
                        icon: "arrow.left.arrow.right",
                        color: .mint
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "Exposed",
                        value: "\(model.listeningPorts.filter { $0.exposure != .loopback }.count)",
                        icon: "exclamationmark.shield.fill",
                        color: .orange
                    )
                }
                .padding(.vertical, 11)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }

                if let error = model.portScanError {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search ports, processes, PIDs, paths, or commands", text: $portSearch)
                            .textFieldStyle(.plain)
                        if !portSearch.isEmpty {
                            Button { portSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 11).frame(height: 34)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                    Picker("Filter", selection: $portFilter) {
                        ForEach(PortFilter.allCases) { filter in
                            Text(filter.rawValue.localized).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 278)
                }

                if filteredPorts.isEmpty {
                    ContentUnavailableView(
                        portSearch.isEmpty ? "No Ports Found" : "No Results",
                        systemImage: "network.slash",
                        description: Text(portSearch.isEmpty ? "No TCP listeners or UDP bindings to display" : "Try another port, process name, or path")
                    )
                    .frame(minHeight: 260)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Port").frame(width: 104, alignment: .leading)
                            Text("Bind Address").frame(width: 142, alignment: .leading)
                            Text("Process").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Scope").frame(width: 80, alignment: .leading)
                            Color.clear.frame(width: 74)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 13).frame(height: 34)
                        Divider()
                        ForEach(Array(filteredPorts.enumerated()), id: \.element.id) { index, port in
                            portRow(port)
                            if index < filteredPorts.count - 1 { Divider().padding(.leading, 13) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }

                Label(
                    "Graceful quit sends SIGTERM so the process can clean up before exiting. Force quit may lose unsaved data; launchd, containers, or supervisors may restart the process.",
                    systemImage: "info.circle"
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var filteredPorts: [ListeningPort] {
        let query = portSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.listeningPorts.filter { port in
            let matchesFilter: Bool
            switch portFilter {
            case .all: matchesFilter = true
            case .tcp: matchesFilter = port.transport == .tcp
            case .udp: matchesFilter = port.transport == .udp
            case .exposed: matchesFilter = port.exposure != .loopback
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            let searchable = [
                String(port.port),
                String(port.processIdentifier),
                port.processName,
                port.processDescription.localized,
                port.localAddress,
                port.executableURL?.path ?? "",
                port.workingDirectoryURL?.path ?? "",
                port.commandLine ?? ""
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    private func portSummaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    private var portSummaryDivider: some View {
        Divider()
            .frame(height: 34)
    }

    private func portRow(_ port: ListeningPort) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(verbatim: String(port.port)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(port.transport.rawValue.localized)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(port.transport == .tcp ? Color.blue : Color.purple)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((port.transport == .tcp ? Color.blue : Color.purple).opacity(0.10), in: Capsule())
            }
            .frame(width: 104, alignment: .leading)

            Text(port.localAddress)
                .font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                .frame(width: 142, alignment: .leading)

            Button { selectedPort = port } label: {
                HStack(spacing: 9) {
                    processIcon(port)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(port.processName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(port.processDescription.localized)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("PID \(port.processIdentifier) · \(portProcessSubtitle(port))")
                            .font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(port.exposure.rawValue.localized)
                .font(.caption.weight(.medium)).foregroundStyle(portExposureColor(port.exposure))
                .frame(width: 80, alignment: .leading)

            Button("Quit") { model.requestPortTermination(port) }
                .buttonStyle(.borderless)
                .foregroundStyle(port.canTerminate ? Color.red : Color.secondary)
                .disabled(!port.canTerminate)
                .help((port.protectionReason ?? "Quit the process using this port").localized)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 68)
        .contextMenu {
            Button("View Process Details") { selectedPort = port }
            if let executableURL = port.executableURL {
                Button("Show Executable in Finder") { reveal(executableURL) }
            }
            if let workingDirectoryURL = port.workingDirectoryURL {
                Button("Open Working Directory") { NSWorkspace.shared.open(workingDirectoryURL) }
            }
            Divider()
            Button("Quit Process", role: .destructive) { model.requestPortTermination(port) }
                .disabled(!port.canTerminate)
        }
    }

    @ViewBuilder
    private func processIcon(_ port: ListeningPort) -> some View {
        if let executableURL = port.executableURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: executableURL.path))
                .resizable().frame(width: 28, height: 28)
        } else {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.secondary).frame(width: 28, height: 28)
        }
    }

    private func portProcessSubtitle(_ port: ListeningPort) -> String {
        if let workingDirectoryURL = port.workingDirectoryURL { return workingDirectoryURL.path }
        if let executableURL = port.executableURL { return executableURL.path }
        return port.commandLine ?? L10n.string("Process path unknown")
    }

    private func portExposureColor(_ exposure: PortExposure) -> Color {
        switch exposure {
        case .loopback: .green
        case .network: .blue
        case .allInterfaces: .orange
        }
    }

    private func portDetails(_ port: ListeningPort) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                processIcon(port)
                VStack(alignment: .leading, spacing: 3) {
                    Text(port.processName).font(.title3.weight(.semibold))
                    Text(port.processDescription.localized).font(.caption).foregroundStyle(.secondary)
                    Text("PID \(port.processIdentifier)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Text(verbatim: "\(port.transport.rawValue) \(port.localAddress):\(String(port.port))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }

            VStack(spacing: 0) {
                portDetailRow("Process Description", value: port.processDescription.localized)
                Divider().padding(.leading, 104)
                portDetailRow("Listening Scope", value: port.exposure.rawValue.localized)
                Divider().padding(.leading, 104)
                portDetailRow("Executable", value: port.executableURL?.path ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("Working Directory", value: port.workingDirectoryURL?.path ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("Launch Command", value: port.commandLine ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("User UID", value: String(port.ownerUserID))
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

            if let reason = port.protectionReason {
                Label(reason.localized, systemImage: "lock.shield.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Quitting terminates the entire process and releases every port it uses.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                if let executableURL = port.executableURL {
                    Button("Show Executable") { reveal(executableURL) }
                }
                if let workingDirectoryURL = port.workingDirectoryURL {
                    Button("Open Working Directory") { NSWorkspace.shared.open(workingDirectoryURL) }
                }
                Spacer()
                Button("Close", role: .cancel) { selectedPort = nil }
                Button("Quit Process", role: .destructive) {
                    selectedPort = nil
                    model.requestPortTermination(port)
                }
                .disabled(!port.canTerminate)
            }
        }
        .padding(20)
        .frame(width: 620)
    }

    private func portDetailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title.localized).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
    }

    private var portTerminationMessage: String {
        guard let port = model.portTerminationCandidate else { return "" }
        return L10n.format(
            "%@ (PID %d) is using %@ %@:%@. Graceful quit is safer; use force quit only if the process is unresponsive.",
            port.processName,
            port.processIdentifier,
            port.transport.rawValue,
            port.localAddress,
            String(port.port)
        )
    }

    private var performanceView: some View {
        VStack(spacing: 0) {
            header(
                title: "Performance",
                subtitle: "Monitor CPU, memory pressure, and top apps locally",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        autoUpdateIndicator(
                            active: model.isPerformanceMonitoring,
                            detail: model.isPerformanceMonitoring ? "every 2 seconds" : "Paused"
                        )
                        Button {
                            if model.isPerformanceMonitoring {
                                model.stopPerformanceMonitoring()
                            } else {
                                model.startPerformanceMonitoring()
                            }
                        } label: {
                            Label(model.isPerformanceMonitoring ? "Pause" : "Continue", systemImage: model.isPerformanceMonitoring ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                )
            )
            .padding(18)

            if let snapshot = model.performanceSnapshot {
                performanceContent(snapshot)
            } else {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("Collecting performance data…").font(.system(size: 14, weight: .semibold))
                    Text("The first CPU sample takes about 2 seconds").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func performanceContent(_ snapshot: PerformanceSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        cpuMetricCard(snapshot)
                        memoryMetricCard(snapshot)
                    }
                    VStack(spacing: 12) {
                        cpuMetricCard(snapshot)
                        memoryMetricCard(snapshot)
                    }
                }
                computeHardwareCard(snapshot.computeHardware)
                performanceTrendCard
                resourceApplicationList(snapshot)
                Text("Data updates locally every 2 seconds. Sampling stops when you leave this page or pause it. App rankings include identifiable graphical app processes only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func cpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("CPU", systemImage: "cpu.fill").font(.system(size: 14, weight: .semibold))
                Spacer()
                Circle().fill(model.isPerformanceMonitoring ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(model.isPerformanceMonitoring ? "Live" : "Paused")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.cpuPercent.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            }
            ProgressView(value: snapshot.cpuPercent, total: 100)
                .tint(snapshot.cpuPercent > 85 ? Color.orange : Color.accentColor)
            HStack {
                Text("Total System Usage")
                Spacer()
                Label(thermalStateText(snapshot.thermalState), systemImage: "thermometer.medium")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func memoryMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let color = memoryPressureColor(snapshot.memoryPressureLevel)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 6) {
                Label("Memory Usage", systemImage: "memorychip.fill").font(.system(size: 14, weight: .semibold))
                Button { showingMemoryHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Understand macOS memory management")
                .popover(isPresented: $showingMemoryHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("What Does Smart Release Do?", systemImage: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("macOS handles hidden apps that are marked for automatic termination and currently unused, while Sift returns reclaimable pages from its own heap.")
                            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Text("Regular foreground apps are not quit, processes are not force terminated, and administrator privileges are not required.")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 340, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(snapshot.memoryPressureLevel.rawValue.localized)
                    .font(.caption.weight(.semibold)).foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(formatted(snapshot.usedMemory))
                    .font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("/ \(formatted(snapshot.physicalMemory))")
                    .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: snapshot.memoryPressure, total: 1).tint(color)
            HStack(spacing: 9) {
                Text("Cached \(formatted(snapshot.cachedMemory))")
                Text("Swap \(formatted(snapshot.swapUsed))")
                Spacer(minLength: 4)
                Button(action: model.optimizeMemory) {
                    if model.isOptimizingMemory {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("Smart Release", systemImage: "wand.and.sparkles")
                    }
                }
                .frame(minWidth: 76)
                .fixedSize(horizontal: true, vertical: false)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isOptimizingMemory)
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func computeHardwareCard(_ hardware: ComputeHardwareInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compute Hardware")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 8)
            computeHardwareRow(
                icon: "display",
                title: "GPU",
                subtitle: hardware.recommendedGPUWorkingSet > 0
                    ? L10n.format("%@ · Recommended working set %@", hardware.gpuName, formatted(hardware.recommendedGPUWorkingSet))
                    : hardware.gpuName,
                status: hardware.hasUnifiedMemory ? "Unified Memory" : "Dedicated Memory",
                color: .blue
            )
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func computeHardwareRow(icon: String, title: String, subtitle: String, status: String, color: Color) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.12))
                Image(systemName: icon).foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(subtitle.localized).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(status.localized)
                .font(.caption.weight(.semibold)).foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 14).frame(minHeight: 55)
    }

    private var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 60 Seconds").font(.system(size: 14, weight: .semibold))
                Spacer()
                Label("CPU", systemImage: "circle.fill").foregroundStyle(Color.accentColor)
                Label("Memory Usage", systemImage: "circle.fill").foregroundStyle(Color.purple)
            }
            .font(.caption)
            Chart(model.performanceHistory) { point in
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("Memory Usage", point.memoryPressurePercent),
                    series: .value("Metric", "Memory Usage")
                )
                .foregroundStyle(Color.purple)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)%") } }
                }
            }
            .frame(height: 138)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resourceApplicationList(_ snapshot: PerformanceSnapshot) -> some View {
        let applications = snapshot.applications.sorted { lhs, rhs in
            performanceSort == .cpu ? lhs.cpuPercent > rhs.cpuPercent : lhs.memoryBytes > rhs.memoryBytes
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Resource-Using Apps").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Sort", selection: $performanceSort) {
                    ForEach(PerformanceSort.allCases) { sort in Text(sort.rawValue.localized).tag(sort) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Sort")
                .frame(width: 150)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Apps").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 70, alignment: .trailing)
                    Text("Memory").frame(width: 92, alignment: .trailing)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 13).frame(height: 32)
                Divider()
                ForEach(Array(applications.prefix(12).enumerated()), id: \.element.id) { index, application in
                    resourceApplicationRow(application)
                    if index < min(applications.count, 12) - 1 { Divider().padding(.leading, 48) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func resourceApplicationRow(_ application: ApplicationResourceUsage) -> some View {
        HStack(spacing: 10) {
            Group {
                if let url = application.bundleURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    Image(systemName: "app.fill").resizable().scaledToFit().padding(5).foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(application.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("PID \(application.processIdentifier)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(application.cpuPercent.formatted(.number.precision(.fractionLength(1))))%")
                .font(.system(size: 12)).monospacedDigit().frame(width: 70, alignment: .trailing)
            Text(formatted(application.memoryBytes))
                .font(.system(size: 12)).monospacedDigit().frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, 13).frame(minHeight: 48)
        .contextMenu {
            if let url = application.bundleURL { Button("Show in Finder") { reveal(url) } }
        }
    }

    private func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: .green
        case .elevated: .orange
        case .critical: .red
        }
    }

    private func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Thermal State Normal")
        case .fair: L10n.string("Thermal State Elevated")
        case .serious: L10n.string("Thermal State High")
        case .critical: L10n.string("Thermal State Critical")
        @unknown default: L10n.string("Thermal State Unknown")
        }
    }

    private var filesView: some View {
        VStack(spacing: 0) {
            header(
                title: "Storage",
                subtitle: "Inspect disk usage, common folders, and large files",
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button("Choose Folder", action: model.chooseFolder)
                        if model.isStorageAnalyzing {
                            Button("Cancel", role: .cancel, action: model.cancelScan)
                        } else if model.storageAnalysis != nil {
                            refreshControl(for: .files, action: model.scanStorageAnalysis)
                        }
                    }
                )
            )
                .padding(18)
            if let analysis = model.storageAnalysis {
                storageAnalysisContent(analysis)
            } else if model.isStorageAnalyzing {
                storageAnalysisLoading
            } else {
                storageAnalysisEmptyView
            }
        }
    }

    private var storageAnalysisEmptyView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.indigo.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 150, height: 150)
                Circle().stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                    .frame(width: 124, height: 124)
                Image(systemName: "chart.pie.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.20))
                    .font(.system(size: 52, weight: .light))
            }
            .padding(.bottom, 24)

            Text("Quick overview of your home folder")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Shows only top-level folders, explains their purpose, and calculates actual usage")
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 7)

            HStack(spacing: 18) {
                scanPromise(icon: "lock.shield", text: "Local Analysis")
                scanPromise(icon: "eye.slash", text: "Contents are not read")
                scanPromise(icon: "trash.slash", text: "Nothing is deleted automatically")
            }
            .padding(.vertical, 22)

            Button(action: model.scanStorageAnalysis) {
                HStack(spacing: 9) {
                    Image(systemName: "chart.pie").font(.system(size: 14, weight: .bold))
                    Text("Start Analysis").font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
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

    private var storageAnalysisLoading: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Calculating folders in \(model.currentScanCategory)")
                .font(.system(size: 15, weight: .semibold))
            Text("Quickly summarizes the macOS file system without building a deep index")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("Reads only paths and disk usage, not file contents")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func storageAnalysisContent(_ analysis: StorageAnalysis) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if model.isStorageAnalyzing {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Updating folder sizes in the background")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(11)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }

                storageVolumeCard(analysis)

                if !model.storagePath.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(model.storagePath.enumerated()), id: \.element.path) { index, url in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Button(index == 0 ? "Home Folder" : url.lastPathComponent) {
                                model.navigateStorage(to: url)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .disabled(index == model.storagePath.count - 1)
                        }
                        Spacer()
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Home Folder")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("Top Level · Sorted by Size")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(analysis.directories.enumerated()), id: \.element.id) { index, usage in
                        storageDirectoryRow(usage)
                        if index < analysis.directories.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                Text("Folder sizes summarize currently readable content. Protected items may not be fully counted; click any folder to view it in Finder.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func storageDirectoryRow(_ usage: StorageDirectoryUsage) -> some View {
        Button {
            if usage.url == analysisRootURL { reveal(usage.url) }
            else { model.openStorageDirectory(usage.url) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.11))
                    Image(systemName: storageDirectoryIcon(usage.url.lastPathComponent))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(usage.url == analysisRootURL ? "files in user directory" : usage.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(usage.explanation.localized)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(formatted(usage.bytes))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 13).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var analysisRootURL: URL? { model.storageAnalysis?.analyzedRoots.first }

    private func storageDirectoryIcon(_ name: String) -> String {
        switch name {
        case "Desktop": "desktopcomputer"
        case "Documents": "doc.fill"
        case "Downloads": "arrow.down.circle.fill"
        case "Library": "books.vertical.fill"
        case "Movies": "film.fill"
        case "Music": "music.note"
        case "Pictures": "photo.fill"
        case "Applications": "app.fill"
        case ".Trash": "trash.fill"
        default: "folder.fill"
        }
    }

    private func storageVolumeCard(_ analysis: StorageAnalysis) -> some View {
        let ratio = analysis.totalCapacity > 0
            ? min(1, Double(analysis.usedCapacity) / Double(analysis.totalCapacity))
            : 0
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("System Disk").font(.system(size: 14, weight: .semibold))
                    Text("\(formatted(analysis.usedCapacity)) used of \(formatted(analysis.totalCapacity))")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatted(analysis.availableCapacity)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    Text("Available Space").font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: ratio)
                .tint(ratio > 0.9 ? Color.orange : Color.accentColor)
            HStack {
                Label("\(formatted(analysis.scannedBytes)) categorized", systemImage: "square.grid.2x2")
                Spacer()
                Text("Last analyzed \(model.lastScanText)")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func storageCategoryRow(_ usage: StorageCategoryUsage, maximumBytes: Int64) -> some View {
        let fraction = maximumBytes > 0 ? Double(usage.bytes) / Double(maximumBytes) : 0
        let color = storageCategoryColor(usage.category)
        return HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.13))
                Image(systemName: storageCategoryIcon(usage.category)).foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(usage.category.rawValue.localized).font(.system(size: 12, weight: .medium))
                    Text("\(usage.fileCount) files").font(.caption2).foregroundStyle(.secondary)
                }
                GeometryReader { geometry in
                    Capsule().fill(Color.secondary.opacity(0.10))
                        .overlay(alignment: .leading) {
                            Capsule().fill(color).frame(width: max(3, geometry.size.width * fraction))
                        }
                }
                .frame(height: 5)
            }
            Spacer()
            Text(formatted(usage.bytes)).font(.system(size: 12, weight: .medium)).monospacedDigit()
        }
        .padding(.horizontal, 13).frame(minHeight: 55)
    }

    private func storageCategoryIcon(_ category: StorageCategoryKind) -> String {
        switch category {
        case .applications: "app.fill"
        case .documents: "doc.fill"
        case .downloads: "arrow.down.circle.fill"
        case .pictures: "photo.fill"
        case .music: "music.note"
        case .movies: "film.fill"
        case .developer: "hammer.fill"
        case .systemData: "gearshape.2.fill"
        case .other: "archivebox.fill"
        }
    }

    private func storageCategoryColor(_ category: StorageCategoryKind) -> Color {
        switch category {
        case .applications: .blue
        case .documents: .indigo
        case .downloads: .cyan
        case .pictures: .pink
        case .music: .purple
        case .movies: .orange
        case .developer: .mint
        case .systemData: .gray
        case .other: .brown
        }
    }

    private func header(title: String, subtitle: String, trailing: AnyView? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 18, weight: .semibold))
                Text(subtitle.localized).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(); trailing
        }
    }

    private func refreshControl(for mode: FeatureMode, action: @escaping () -> Void) -> some View {
        let isRefreshing = model.isLoading(mode)
        return HStack(spacing: 7) {
            Text(model.lastUpdatedText(for: mode))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            Button(action: action) {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .help("Update Now")
            .accessibilityLabel(isRefreshing ? "Updating" : "Update Now")
            .disabled(isRefreshing)
        }
    }

    private func autoUpdateIndicator(active: Bool, detail: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(active ? "Auto Updating" : "Automatic updates paused")
                .font(.caption.weight(.medium))
            Text("· \(detail)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var junkSummary: String {
        model.items.isEmpty
            ? L10n.string("Scan Caches and Logs")
            : L10n.format("%@ cleanable", formatted(model.selectedBytes))
    }

    private func scanHome() { model.mode = .home; model.selectHomeAndScan() }
    private func scanJunk() { model.mode = .junk; if model.root == nil { model.selectHomeAndScan() } else { model.scan() } }
    private func performQuickAction() {
        if model.items.isEmpty || model.selectedCount == 0 { scanHome() }
        else { model.requestClean() }
    }
    private func selectionBinding(_ item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { model.isItemSelected(item) },
            set: { model.setItem(item, selected: $0) }
        )
    }
    private func formatted(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
