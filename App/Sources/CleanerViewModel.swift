import AppKit
import Darwin
import SiftCore
import Foundation

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var mode: FeatureMode = .home
    @Published var root: URL?
    @Published var items: [ScanItem] = []
    @Published private(set) var storageAnalysis: StorageAnalysis?
    @Published private(set) var storagePath: [URL] = []
    @Published private(set) var performanceSnapshot: PerformanceSnapshot?
    @Published private(set) var performanceHistory: [PerformanceHistoryPoint] = []
    @Published private(set) var systemStorage = SystemStorageSnapshot.empty
    @Published private(set) var cleanableBytes: Int64?
    @Published private(set) var hasLoadedPortSnapshot = false
    @Published private(set) var isPerformanceMonitoring = false
    @Published private(set) var isOptimizingMemory = false
    @Published private(set) var listeningPorts: [ListeningPort] = []
    @Published private(set) var portScanError: String?
    @Published private(set) var networkSnapshot: NetworkSnapshot?
    @Published private(set) var routeLookup: NetworkRouteLookup?
    @Published private(set) var isLookingUpRoute = false
    @Published var portTerminationCandidate: ListeningPort?
    @Published var showPortTerminationConfirmation = false
    @Published var applications: [InstalledApplication] = []
    @Published var commandLineTools: [CommandLineTool] = []
    @Published var loginApplications: [LoginApplication] = []
    @Published var loginApplicationsError: String?
    @Published var backgroundItems: [LoginItem] = []
    @Published var registeredBackgroundTasks: [RegisteredBackgroundTask] = []
    @Published var backgroundTaskScanError: String?
    @Published var backgroundDatabaseNotice: String?
    @Published var installedExtensions: [InstalledExtension] = []
    @Published var loginApplicationRemovalCandidate: LoginApplication?
    @Published var registeredBackgroundTaskRemovalCandidate: RegisteredBackgroundTask?
    @Published var backgroundItemRemovalCandidate: LoginItem?
    @Published var extensionRemovalCandidate: InstalledExtension?
    @Published var showLoginApplicationRemovalConfirmation = false
    @Published var showRegisteredBackgroundTaskRemovalConfirmation = false
    @Published var showBackgroundDatabaseResetConfirmation = false
    @Published var showBackgroundItemRemovalConfirmation = false
    @Published var showExtensionRemovalConfirmation = false
    @Published var showRemovalFailure = false
    @Published var removalFailureMessage = ""
    @Published var operationReport: RemovalOperationReport?
    @Published private(set) var applicationGroups: [ApplicationGroup] = []
    @Published var uninstallCandidate: InstalledApplication?
    @Published var showAppRemovalConfirmation = false
    @Published private(set) var uninstallResidues: [ApplicationResidue] = []
    @Published var selectedResidueIDs: Set<String> = []
    @Published var isPreparingUninstall = false
    @Published private(set) var junkGroups: [JunkScanGroup] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var selectedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published var isScanning = false
    @Published private(set) var isCleanupScanning = false
    @Published private(set) var isStorageAnalyzing = false
    @Published private(set) var loadingModes: Set<FeatureMode> = []
    @Published var showCleanConfirmation = false
    @Published var lastScanAt: Date?
    @Published private(set) var lastUpdatedAt: [FeatureMode: Date] = [:]
    @Published var scanProgress = 0.0
    @Published var currentScanCategory = ""
    @Published private(set) var completedCleanupPhases: Set<String> = []
    @Published private(set) var activeCleanupPhaseID: String?
    @Published private(set) var showsLeftoverScanPhase = true
    @Published var inspectedFileCount = 0
    @Published var discoveredFileCount = 0
    @Published var discoveredBytes: Int64 = 0
    @Published var status = L10n.string("Choose your user folder or a test folder.")

    private let scanner = SiftCore.Scanner()
    private let cleaner = Cleaner()
    private let applicationScanner = ApplicationScanner()
    private let systemInventoryScanner = SystemInventoryScanner()
    private let fileAnalyzer = FileAnalyzer()
    private let performanceMonitor = PerformanceMonitor()
    private let portScanner = PortScanner()
    private let networkScanner = NetworkScanner()
    private var scanTask: Task<Void, Never>?
    private var storageAnalysisTask: Task<Void, Never>?
    private var featureTasks: [FeatureMode: Task<Void, Never>] = [:]
    private var performanceTask: Task<Void, Never>?
    private var networkMonitoringTask: Task<Void, Never>?
    private var routeLookupTask: Task<Void, Never>?
    private var homeMonitoringTask: Task<Void, Never>?
    private var hasScannedApplications = false
    private var hasAnalyzedStorage = false
    private var storageCache: [String: StorageAnalysis] = [:]
    private static let storageSnapshotKey = "storageOverviewSnapshot"
    private static let inventorySnapshotKey = "inventorySnapshot"
    private var hasScannedLoginApplications = false
    private var hasScannedBackgroundItems = false
    private var hasScannedExtensions = false
    private var selectedCountByGroup: [String: Int] = [:]
    private var itemByID: [UUID: ScanItem] = [:]
    private var cleanupRoot = FileManager.default.homeDirectoryForCurrentUser
    private var standardCleanupProgress = 0.0
    private var residueCleanupProgress = 0.0
    private var standardCleanupInspectedFiles = 0
    private var residueCleanupInspectedFiles = 0
    private var cleanupIncludesResidues = false
    var selectedCount: Int { selectedIDs.count }
    var lastScanText: String {
        guard let lastScanAt else { return L10n.string("Not scanned yet") }
        return lastScanAt.formatted(date: .omitted, time: .shortened)
    }

    func lastUpdatedText(for mode: FeatureMode) -> String {
        guard let date = lastUpdatedAt[mode] else { return L10n.string("Not updated yet") }
        return L10n.format("Updated on %@", date.formatted(date: .omitted, time: .shortened))
    }

    func isLoading(_ mode: FeatureMode) -> Bool {
        mode == .files ? isStorageAnalyzing : loadingModes.contains(mode)
    }

    init() {
        restoreStorageSnapshot()
        restoreInventorySnapshot()
        refreshSystemStorage()
        refreshPerformanceSnapshot()
        startHomeMonitoring()
    }

    func selectHomeAndScan() {
        cleanupRoot = FileManager.default.homeDirectoryForCurrentUser
        root = cleanupRoot
        scan()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.string(mode == .uninstall ? "Choose Applications Folder" : "Choose Scan Folder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url
        if mode == .files {
            storageAnalysis = nil
            status = L10n.format("%@ selected. Click Start Analysis.", url.lastPathComponent)
            return
        }
        cleanupRoot = url
        items = []
        selectedIDs = []
        rebuildJunkGroups()
        status = L10n.format("%@ selected; not scanned yet.", url.path)
    }

    func scanInstalledApplications() {
        featureTasks[.uninstall]?.cancel()
        isScanning = true
        loadingModes.insert(.uninstall)
        status = L10n.string("Scanning installed apps…")
        featureTasks[.uninstall] = Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let foundApplications = await applicationScanner.applications(in: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                home.appending(path: "Applications", directoryHint: .isDirectory)
            ])
            guard !Task.isCancelled else { return }
            applications = foundApplications
            rebuildApplicationGroups()
            if mode == .uninstall { status = L10n.string("Checking command-line tools…") }
            let foundTools = await applicationScanner.commandLineTools(home: home)
            guard !Task.isCancelled else { return }
            commandLineTools = foundTools
            items = []
            selectedIDs = []
            lastScanAt = Date()
            lastUpdatedAt[.uninstall] = lastScanAt
            hasScannedApplications = true
            persistInventorySnapshot()
            loadingModes.remove(.uninstall)
            featureTasks[.uninstall] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .uninstall {
                status = L10n.format("%lld apps found.", Int64(applications.count))
            }
        }
    }

    func scan() {
        if mode == .files {
            scanStorageAnalysis()
            return
        }
        guard mode == .home || mode == .junk else { return }
        let scanMode = mode
        let selectedRoot = cleanupRoot.standardizedFileURL
        root = selectedRoot
        scanTask?.cancel()
        isCleanupScanning = true
        scanProgress = 0
        standardCleanupProgress = 0
        residueCleanupProgress = 0
        standardCleanupInspectedFiles = 0
        residueCleanupInspectedFiles = 0
        cleanupIncludesResidues = selectedRoot.resolvingSymlinksInPath()
            == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        showsLeftoverScanPhase = cleanupIncludesResidues
        completedCleanupPhases = []
        activeCleanupPhaseID = nil
        rememberedCompletedRuleTitles = []
        currentScanCategory = L10n.string("Getting ready…")
        inspectedFileCount = 0
        discoveredFileCount = 0
        discoveredBytes = 0
        status = L10n.string("Scanning…")
        scanTask = Task {
            switch scanMode {
            case .home:
                let found = await scanJunk(root: selectedRoot)
                guard !Task.isCancelled else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                cleanableBytes = selectedBytes
                status = L10n.format("Scan complete. %lld candidate files found.", Int64(found.count))
            case .junk:
                let found = await scanJunk(root: selectedRoot)
                guard !Task.isCancelled else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                cleanableBytes = selectedBytes
                status = L10n.format("%lld candidate files found. Items marked ‘Review’ are not selected by default.", Int64(found.count))
            case .uninstall:
                break
            case .files:
                break
            case .performance, .network, .tools, .loginItems, .backgroundActivity, .extensions, .settings:
                break
            }
            lastScanAt = Date()
            lastUpdatedAt[scanMode] = lastScanAt
            currentScanCategory = L10n.string(Task.isCancelled ? "Scan canceled" : "Wrapping up…")
            if !Task.isCancelled { scanProgress = 1 }
            isCleanupScanning = false
            scanTask = nil
        }
    }

    func scanStorageAnalysis() {
        storageAnalysisTask?.cancel()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let selectedRoot = (root ?? home).standardizedFileURL
        root = selectedRoot
        isStorageAnalyzing = true
        scanProgress = 0
        inspectedFileCount = 0
        discoveredBytes = 0
        currentScanCategory = selectedRoot.lastPathComponent
        status = L10n.string("Reading directory occupancy...")
        storageAnalysisTask = Task {
            let analysis = await fileAnalyzer.directoryOverview(
                root: selectedRoot,
                volumeURL: URL(fileURLWithPath: "/", isDirectory: true)
            )
            guard !Task.isCancelled else { return }
            storageAnalysis = analysis
            storageCache[selectedRoot.path] = analysis
            if storagePath.isEmpty || storagePath.last != selectedRoot {
                storagePath = breadcrumbPath(to: selectedRoot)
            }
            items = []
            selectedIDs = []
            lastScanAt = Date()
            lastUpdatedAt[.files] = lastScanAt
            hasAnalyzedStorage = true
            persistStorageSnapshot(analysis)
            isStorageAnalyzing = false
            storageAnalysisTask = nil
            currentScanCategory = L10n.string("Analysis complete")
            if mode == .files {
                status = L10n.format(
                    "Read %lld items occupying %@.",
                    Int64(analysis.directories.count),
                    ByteCountFormatter.string(fromByteCount: analysis.scannedBytes, countStyle: .file)
                )
            }
        }
    }

    func openStorageDirectory(_ url: URL) {
        let url = url.standardizedFileURL
        root = url
        storagePath = breadcrumbPath(to: url)
        if let cached = storageCache[url.path] {
            storageAnalysis = cached
        }
        scanStorageAnalysis()
    }

    func navigateStorage(to url: URL) {
        openStorageDirectory(url)
    }

    private func breadcrumbPath(to url: URL) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let target = url.standardizedFileURL
        guard SafetyPolicy.contains(target, in: home, allowDirectoryItself: true) else { return [target] }
        if target == home { return [home] }
        var result = [home]
        var current = home
        let relative = target.path.dropFirst(home.path.count).split(separator: "/")
        for component in relative {
            current.append(path: String(component), directoryHint: .isDirectory)
            result.append(current)
        }
        return result
    }

    private struct StoredDirectory: Codable {
        let path: String
        let bytes: Int64
        let explanation: String
    }

    private struct StoredStorageSnapshot: Codable {
        let rootPath: String
        let totalCapacity: Int64
        let availableCapacity: Int64
        let scannedBytes: Int64
        let savedAt: Date
        let directories: [StoredDirectory]
    }

    private func persistStorageSnapshot(_ analysis: StorageAnalysis) {
        guard let root = analysis.analyzedRoots.first else { return }
        let snapshot = StoredStorageSnapshot(
            rootPath: root.path,
            totalCapacity: analysis.totalCapacity,
            availableCapacity: analysis.availableCapacity,
            scannedBytes: analysis.scannedBytes,
            savedAt: lastScanAt ?? Date(),
            directories: analysis.directories.map { StoredDirectory(path: $0.url.path, bytes: $0.bytes, explanation: $0.explanation) }
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storageSnapshotKey)
        }
    }

    private func restoreStorageSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageSnapshotKey),
              let snapshot = try? JSONDecoder().decode(StoredStorageSnapshot.self, from: data) else { return }
        let root = URL(fileURLWithPath: snapshot.rootPath, isDirectory: true)
        let analysis = StorageAnalysis(
            totalCapacity: snapshot.totalCapacity,
            availableCapacity: snapshot.availableCapacity,
            scannedBytes: snapshot.scannedBytes,
            scannedFileCount: snapshot.directories.count,
            inaccessibleItemCount: 0,
            categories: [],
            largeFiles: [],
            analyzedRoots: [root],
            directories: snapshot.directories.map {
                StorageDirectoryUsage(url: URL(fileURLWithPath: $0.path, isDirectory: true), bytes: $0.bytes, explanation: $0.explanation)
            }
        )
        storageAnalysis = analysis
        storageCache[root.path] = analysis
        storagePath = breadcrumbPath(to: root)
        lastUpdatedAt[.files] = snapshot.savedAt
        lastScanAt = snapshot.savedAt
        hasAnalyzedStorage = true
    }

    private struct StoredInventorySnapshot: Codable {
        let applications: [InstalledApplication]
        let commandLineTools: [CommandLineTool]
        let loginApplications: [LoginApplication]
        let backgroundItems: [LoginItem]
        let registeredBackgroundTasks: [RegisteredBackgroundTask]
        let installedExtensions: [InstalledExtension]
    }

    private func persistInventorySnapshot() {
        let snapshot = StoredInventorySnapshot(
            applications: applications,
            commandLineTools: commandLineTools,
            loginApplications: loginApplications,
            backgroundItems: backgroundItems,
            registeredBackgroundTasks: registeredBackgroundTasks,
            installedExtensions: installedExtensions
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.inventorySnapshotKey)
        }
    }

    private func restoreInventorySnapshot() {
        guard let data = UserDefaults.standard.data(forKey: Self.inventorySnapshotKey),
              let snapshot = try? JSONDecoder().decode(StoredInventorySnapshot.self, from: data) else { return }
        applications = snapshot.applications
        commandLineTools = snapshot.commandLineTools
        loginApplications = snapshot.loginApplications
        backgroundItems = snapshot.backgroundItems
        registeredBackgroundTasks = snapshot.registeredBackgroundTasks
        installedExtensions = snapshot.installedExtensions
        hasScannedApplications = !applications.isEmpty
        hasScannedLoginApplications = !loginApplications.isEmpty
        hasScannedBackgroundItems = !backgroundItems.isEmpty || !registeredBackgroundTasks.isEmpty
        hasScannedExtensions = !installedExtensions.isEmpty
        rebuildApplicationGroups()
    }

    func cancelScan() {
        if mode == .files, isStorageAnalyzing {
            storageAnalysisTask?.cancel()
            storageAnalysisTask = nil
            isStorageAnalyzing = false
            currentScanCategory = L10n.string("Analysis canceled")
            status = L10n.string("Analysis canceled.")
            return
        }
        scanTask?.cancel()
        scanTask = nil
        isCleanupScanning = false
        currentScanCategory = L10n.string("Scan canceled")
        status = L10n.string("Scan canceled.")
    }

    func startPerformanceMonitoring() {
        performanceTask?.cancel()
        isPerformanceMonitoring = true
        status = L10n.string("Monitoring CPU and memory…")
        performanceTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, mode == .performance {
                let snapshot = performanceMonitor.sample()
                performanceSnapshot = snapshot
                performanceHistory.append(PerformanceHistoryPoint(
                    sampledAt: snapshot.sampledAt,
                    cpuPercent: snapshot.cpuPercent,
                    memoryPressurePercent: snapshot.memoryPressure * 100
                ))
                if performanceHistory.count > 30 {
                    performanceHistory.removeFirst(performanceHistory.count - 30)
                }
                status = L10n.format(
                    "CPU %lld%% · Memory pressure: %@",
                    Int64(snapshot.cpuPercent.rounded()),
                    snapshot.memoryPressureLevel.rawValue.localized
                )
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPerformanceMonitoring() {
        performanceTask?.cancel()
        performanceTask = nil
        isPerformanceMonitoring = false
        status = L10n.string("Performance monitoring paused.")
    }

    func optimizeMemory() {
        guard !isOptimizingMemory else { return }
        isOptimizingMemory = true
        status = L10n.string("Asking macOS to release idle memory…")
        Task { [weak self] in
            guard let self else { return }
            NSRunningApplication.terminateAutomaticallyTerminableApplications()
            _ = await Task.detached(priority: .userInitiated) {
                malloc_zone_pressure_relief(nil, 0)
            }.value
            try? await Task.sleep(for: .milliseconds(800))
            refreshPerformanceSnapshot()
            isOptimizingMemory = false
            status = L10n.string("Smart release complete; idle background apps were handled and Sift returned its own reclaimable memory.")
        }
    }

    private func refreshPerformanceSnapshot() {
        let snapshot = performanceMonitor.sample()
        performanceSnapshot = snapshot
        performanceHistory.append(PerformanceHistoryPoint(
            sampledAt: snapshot.sampledAt,
            cpuPercent: snapshot.cpuPercent,
            memoryPressurePercent: snapshot.memoryPressure * 100
        ))
        if performanceHistory.count > 30 {
            performanceHistory.removeFirst(performanceHistory.count - 30)
        }
    }

    private func refreshSystemStorage() {
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        if let values = try? root.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) {
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
            if total > 0 {
                systemStorage = SystemStorageSnapshot(
                    totalCapacity: total,
                    availableCapacity: min(total, max(0, available))
                )
                return
            }
        }

        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: root.path)
        systemStorage = SystemStorageSnapshot(
            totalCapacity: (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0,
            availableCapacity: (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        )
    }

    private func startHomeMonitoring() {
        homeMonitoringTask?.cancel()
        refreshSystemStorage()
        homeMonitoringTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            var refreshCount = 0
            while !Task.isCancelled {
                guard let self, self.mode == .home else { return }
                if NSApp.isActive {
                    self.refreshSystemStorage()
                    self.refreshPerformanceSnapshot()

                    if refreshCount.isMultiple(of: 4), !self.isScanning, !self.isCleanupScanning {
                        let result = await self.portScanner.scan()
                        guard !Task.isCancelled, self.mode == .home else { return }
                        self.listeningPorts = result.ports
                        self.hasLoadedPortSnapshot = true
                    }
                    refreshCount += 1
                }

                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
            }
        }
    }

    func scanPorts() {
        featureTasks[.network]?.cancel()
        isScanning = true
        loadingModes.insert(.network)
        portScanError = nil
        status = L10n.string("Reading listening ports and process information…")
        featureTasks[.network] = Task {
            let result = await portScanner.scan()
            guard !Task.isCancelled else { return }
            listeningPorts = result.ports
            hasLoadedPortSnapshot = true
            let localizedError = result.errorMessage.map(L10n.diagnostic)
            portScanError = localizedError
            lastScanAt = Date()
            lastUpdatedAt[.network] = lastScanAt
            loadingModes.remove(.network)
            featureTasks[.network] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .network {
                status = localizedError ?? L10n.format("%lld listening ports found.", Int64(result.ports.count))
            }
        }
    }

    func scanNetwork() {
        featureTasks[.network]?.cancel()
        isScanning = true
        loadingModes.insert(.network)
        portScanError = nil
        status = L10n.string("Reading network activity, routes, and proxy settings…")
        featureTasks[.network] = Task {
            async let snapshotTask = networkScanner.scan()
            async let portsTask = portScanner.scan()
            let (snapshot, ports) = await (snapshotTask, portsTask)
            guard !Task.isCancelled else { return }
            networkSnapshot = snapshot
            listeningPorts = ports.ports
            hasLoadedPortSnapshot = true
            portScanError = ports.errorMessage.map(L10n.diagnostic)
            lastScanAt = snapshot.sampledAt
            lastUpdatedAt[.network] = snapshot.sampledAt
            loadingModes.remove(.network)
            featureTasks[.network] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .network {
                status = snapshot.errors.first.map(L10n.diagnostic)
                    ?? L10n.format("%lld active connections found.", Int64(snapshot.connections.filter { !$0.isListener }.count))
            }
        }
    }

    func lookupNetworkRoute(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        routeLookupTask?.cancel()
        isLookingUpRoute = true
        routeLookupTask = Task { [weak self] in
            guard let self else { return }
            let result = await networkScanner.route(to: query)
            guard !Task.isCancelled else { return }
            routeLookup = result
            isLookingUpRoute = false
            routeLookupTask = nil
        }
    }

    private func startNetworkMonitoring() {
        networkMonitoringTask?.cancel()
        scanNetwork()
        networkMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                guard let self, self.mode == .network else { return }
                if NSApp.isActive, !self.isLoading(.network), !self.showPortTerminationConfirmation {
                    self.scanNetwork()
                }
            }
        }
    }

    func requestPortTermination(_ port: ListeningPort) {
        guard port.canTerminate else {
            removalFailureMessage = port.protectionReason ?? L10n.string("This process cannot be quit from Sift.")
            showRemovalFailure = true
            return
        }
        portTerminationCandidate = port
        showPortTerminationConfirmation = true
    }

    func terminatePortProcess(force: Bool) {
        guard let port = portTerminationCandidate else { return }
        showPortTerminationConfirmation = false
        portTerminationCandidate = nil
        status = force
            ? L10n.format("Force quitting %@…", port.processName)
            : L10n.format("Asking %@ to quit gracefully…", port.processName)
        Task {
            if let error = await portScanner.terminate(port, force: force) {
                removalFailureMessage = L10n.format("Unable to quit %@: %@", port.processName, error)
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                listeningPorts.removeAll { $0.processIdentifier == port.processIdentifier }
                status = force
                    ? L10n.format("%@ was force quit.", port.processName)
                    : L10n.format("A quit request was sent to %@.", port.processName)
                try? await Task.sleep(for: .milliseconds(500))
                if mode == .network { scanNetwork() }
            }
        }
    }

    private func scanJunk(root: URL) async -> [ScanItem] {
        guard cleanupIncludesResidues else { return await scanRegularJunk(root: root) }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()

        let regularItems = await scanRegularJunk(root: root)
        guard !Task.isCancelled else { return [] }
        let residueGroups = await scanCleanupResidues(home: home)
        guard !Task.isCancelled else { return [] }

        let residueItems = residueGroups.flatMap(\.residues).map { residue in
            let modifiedAt = try? residue.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return ScanItem(
                url: residue.url,
                bytes: residue.bytes,
                modifiedAt: modifiedAt,
                rule: DefaultRules.uninstallLeftovers
            )
        }
        let residueRoots = residueItems.map { $0.url.standardizedFileURL.path }
        let deduplicatedRegularItems = regularItems.filter { item in
            let path = item.url.standardizedFileURL.path
            return !residueRoots.contains { root in
                path == root || path.hasPrefix(root + "/")
            }
        }
        let combined = deduplicatedRegularItems + residueItems
        scanProgress = 1
        discoveredFileCount = combined.count
        discoveredBytes = combined.reduce(0) { $0 + $1.bytes }
        return combined
    }

    private func scanRegularJunk(root: URL) async -> [ScanItem] {
        await scanner.scan(root: root, rules: DefaultRules.conservative) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.standardCleanupProgress = progress.fractionCompleted
                self.standardCleanupInspectedFiles = progress.inspectedFiles
                self.publishCleanupProgress()
                self.updateCleanupPhases(
                    completedRuleTitles: progress.completedRuleTitles,
                    currentRuleTitle: progress.currentRuleTitle
                )
                self.discoveredFileCount = progress.matchedFiles
                self.discoveredBytes = progress.matchedBytes
            }
        }
    }

    private func scanCleanupResidues(home: URL) async -> [ApplicationResidueGroup] {
        let installedIdentifiers = await applicationScanner.installedBundleIdentifiers(in: [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appending(path: "Applications", directoryHint: .isDirectory)
        ])
        guard !Task.isCancelled else { return [] }
        let residueGroups = await applicationScanner.orphanedResidues(
            installedBundleIdentifiers: installedIdentifiers,
            home: home
        ) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.residueCleanupProgress = progress.fractionCompleted
                self.residueCleanupInspectedFiles = progress.inspectedFiles
                self.publishCleanupProgress()
                self.updateCleanupPhases(
                    completedRuleTitles: [],
                    currentRuleTitle: DefaultRules.uninstallLeftovers.title
                )
            }
        }
        guard !Task.isCancelled else { return [] }
        residueCleanupProgress = 1
        publishCleanupProgress()
        updateCleanupPhases(
            completedRuleTitles: [DefaultRules.uninstallLeftovers.title],
            currentRuleTitle: nil
        )
        return residueGroups
    }

    private func publishCleanupProgress() {
        inspectedFileCount = standardCleanupInspectedFiles + residueCleanupInspectedFiles
        guard cleanupIncludesResidues else {
            scanProgress = standardCleanupProgress
            return
        }
        let totalRuleCount = Double(DefaultRules.conservative.count + 1)
        let standardWeight = Double(DefaultRules.conservative.count) / totalRuleCount
        scanProgress = standardCleanupProgress * standardWeight
            + residueCleanupProgress / totalRuleCount
    }

    private var rememberedCompletedRuleTitles = Set<String>()

    private func updateCleanupPhases(
        completedRuleTitles: [String],
        currentRuleTitle: String?
    ) {
        rememberedCompletedRuleTitles.formUnion(completedRuleTitles)
        if residueCleanupProgress >= 1 {
            rememberedCompletedRuleTitles.insert(DefaultRules.uninstallLeftovers.title)
        }

        let completedTitles = rememberedCompletedRuleTitles
        var done = Set<String>()
        for phase in Self.cleanupScanPhases where phase.ruleTitles.isSubset(of: completedTitles) {
            done.insert(phase.id)
        }
        completedCleanupPhases = done

        if cleanupIncludesResidues,
           residueCleanupProgress < 1,
           standardCleanupProgress >= 1 {
            activeCleanupPhaseID = "leftoverAppData"
            currentScanCategory = Self.friendlyCleanupPhase(for: DefaultRules.uninstallLeftovers.title)
            return
        }

        if let currentRuleTitle,
           let phaseID = Self.phaseID(forRuleTitle: currentRuleTitle),
           !done.contains(phaseID) {
            activeCleanupPhaseID = phaseID
            currentScanCategory = Self.friendlyCleanupPhase(for: currentRuleTitle)
        } else if let pending = Self.cleanupScanPhases.first(where: { !done.contains($0.id) && ($0.id != "leftoverAppData" || cleanupIncludesResidues) }) {
            activeCleanupPhaseID = pending.id
            currentScanCategory = Self.friendlyCleanupPhase(for: pending.ruleTitles.sorted().first ?? "")
        } else {
            activeCleanupPhaseID = nil
        }
    }

    private struct CleanupScanPhaseDefinition {
        let id: String
        let ruleTitles: Set<String>
    }

    private static let cleanupScanPhases: [CleanupScanPhaseDefinition] = [
        .init(id: "appCaches", ruleTitles: ["User Caches"]),
        .init(id: "developerLogs", ruleTitles: ["Old Logs", "npm Debug Logs"]),
        .init(
            id: "dependencyLibraries",
            ruleTitles: [
                "npm Download Cache",
                "Homebrew Download Cache",
                "CocoaPods Cache",
                "Swift Package Manager Cache",
                "Yarn Download Cache",
                "Python pip cache",
                "Python uv cache",
                "Cargo download cache",
                "Old installation packages and compressed packages"
            ]
        ),
        .init(
            id: "buildCaches",
            ruleTitles: [
                "Gradle Build Cache",
                "Android Tool Cache",
                "Xcode Derived Data",
                "Apple Simulator Cache"
            ]
        ),
        .init(id: "leftoverAppData", ruleTitles: ["Uninstall Leftovers"])
    ]

    private static func phaseID(forRuleTitle ruleTitle: String) -> String? {
        cleanupScanPhases.first { $0.ruleTitles.contains(ruleTitle) }?.id
    }

    /// Human-friendly scan phases — never expose rule numbers, paths, or technical titles.
    private static func friendlyCleanupPhase(for ruleTitle: String) -> String {
        switch ruleTitle {
        case "User Caches":
            return L10n.string("Checking app caches…")
        case "Old Logs", "npm Debug Logs":
            return L10n.string("Checking developer logs…")
        case "Old installation packages and compressed packages":
            return L10n.string("Checking old installers…")
        case "npm Download Cache",
             "Homebrew Download Cache",
             "CocoaPods Cache",
             "Swift Package Manager Cache",
             "Yarn Download Cache",
             "Python pip cache",
             "Python uv cache",
             "Cargo download cache":
            return L10n.string("Checking dependency libraries…")
        case "Gradle Build Cache",
             "Android Tool Cache",
             "Xcode Derived Data":
            return L10n.string("Checking build caches…")
        case "Apple Simulator Cache":
            return L10n.string("Checking simulator data…")
        case "Uninstall Leftovers":
            return L10n.string("Checking leftover app data…")
        default:
            return L10n.string("Looking around…")
        }
    }

    func changeMode(_ newMode: FeatureMode) {
        guard newMode != mode else { return }
        performanceTask?.cancel()
        performanceTask = nil
        networkMonitoringTask?.cancel()
        networkMonitoringTask = nil
        routeLookupTask?.cancel()
        routeLookupTask = nil
        isLookingUpRoute = false
        homeMonitoringTask?.cancel()
        homeMonitoringTask = nil
        isPerformanceMonitoring = false
        isScanning = !loadingModes.isEmpty
        mode = newMode
        switch newMode {
        case .home:
            status = L10n.string("Check storage and quickly access common tools.")
            startHomeMonitoring()
        case .junk:
            root = cleanupRoot
            status = isCleanupScanning
                ? L10n.string("Scanning…")
                : (items.isEmpty
                    ? L10n.string("Choose your user folder to scan caches and logs.")
                    : L10n.format("%lld candidate files found. Items marked ‘Review’ are not selected by default.", Int64(items.count)))
        case .uninstall:
            if hasScannedApplications {
                status = L10n.format("Updating in the background; currently showing the last %lld apps read.", Int64(applications.count))
                scanInstalledApplications()
            } else {
                status = L10n.string("Reading installed apps…")
                scanInstalledApplications()
            }
        case .files:
            root = storagePath.last ?? storageAnalysis?.analyzedRoots.first ?? FileManager.default.homeDirectoryForCurrentUser
            if hasAnalyzedStorage, let storageAnalysis {
                status = isStorageAnalyzing
                    ? L10n.string("Directory occupancy is being updated in the background; the last result is currently displayed.")
                    : L10n.format("Analysis results for %lld directories have been cached; click Refresh to reanalyze.", Int64(storageAnalysis.directories.count))
            } else if isStorageAnalyzing {
                status = L10n.string("Analyzing user directory in the background...")
            } else {
                status = L10n.string("Start a system storage analysis, or choose a folder to analyze separately.")
            }
        case .performance:
            status = L10n.string("Monitoring CPU and memory…")
            startPerformanceMonitoring()
        case .network:
            startNetworkMonitoring()
        case .tools:
            status = L10n.string("Manage developer tools and local environments.")
        case .loginItems:
            if hasScannedLoginApplications {
                status = L10n.format("Updating in the background; currently displaying the last %lld login items read.", Int64(loginApplications.count))
                scanLoginItems()
            } else {
                status = L10n.string("Reading login items…")
                scanLoginItems()
            }
        case .backgroundActivity:
            if hasScannedBackgroundItems {
                status = L10n.format(
                    "%lld app background records and %lld background configurations cached; refresh to scan again.",
                    Int64(registeredBackgroundTasks.count),
                    Int64(backgroundItems.count)
                )
                scanBackgroundActivity()
            } else {
                status = L10n.string("Reading background activity…")
                scanBackgroundActivity()
            }
        case .extensions:
            if hasScannedExtensions {
                status = L10n.format("Updating in the background; currently showing the last %lld extensions read.", Int64(installedExtensions.count))
                scanExtensions()
            } else {
                status = L10n.string("Reading app extensions…")
                scanExtensions()
            }
        case .settings:
            status = L10n.string("Manage language, appearance, and other preferences.")
        }
    }

    func refreshLocalizedStatus() {
        if isCleanupScanning, mode == .home || mode == .junk {
            status = L10n.string("Scanning…")
            return
        }
        if isScanning {
            switch mode {
            case .home, .junk:
                status = L10n.string("Scanning…")
            case .uninstall:
                status = L10n.string("Scanning installed apps…")
            case .files:
                status = L10n.string("Measuring file usage…")
            case .performance:
                status = L10n.string("Monitoring CPU and memory…")
            case .network:
                status = L10n.string("Reading network activity, routes, and proxy settings…")
            case .tools:
                status = L10n.string("Manage developer tools and local environments.")
            case .loginItems:
                status = L10n.string("Reading login items…")
            case .backgroundActivity:
                status = L10n.string("Reading background activity…")
            case .extensions:
                status = L10n.string("Reading app extensions…")
            case .settings:
                status = L10n.string("Manage language, appearance, and other preferences.")
            }
            return
        }

        switch mode {
        case .home:
            status = items.isEmpty
                ? L10n.string("Check storage and quickly access common tools.")
                : L10n.format("Scan complete. %lld candidate files found.", Int64(items.count))
        case .junk:
            status = items.isEmpty
                ? L10n.string("Choose your user folder to scan caches and logs.")
                : L10n.format("%lld candidate files found. Items marked ‘Review’ are not selected by default.", Int64(items.count))
        case .uninstall:
            status = hasScannedApplications
                ? L10n.format("%lld apps cached; refresh to scan again.", Int64(applications.count))
                : L10n.string("Reading installed apps…")
        case .files:
            if hasAnalyzedStorage, let storageAnalysis {
                status = L10n.format(
                    "Analysis of %lld files cached; refresh to analyze again.",
                    Int64(storageAnalysis.scannedFileCount)
                )
            } else {
                status = L10n.string("Start a system storage analysis, or choose a folder to analyze separately.")
            }
        case .performance:
            status = isPerformanceMonitoring
                ? L10n.string("Monitoring CPU and memory…")
                : L10n.string("Performance monitoring paused.")
        case .network:
            status = L10n.format("%lld connections cached; refresh to scan again.", Int64(networkSnapshot?.connections.count ?? 0))
        case .tools:
            status = L10n.string("Manage developer tools and local environments.")
        case .loginItems:
            status = L10n.format("%lld login items cached; refresh to scan again.", Int64(loginApplications.count))
        case .backgroundActivity:
            status = L10n.format(
                "%lld app background records and %lld background configurations cached; refresh to scan again.",
                Int64(registeredBackgroundTasks.count),
                Int64(backgroundItems.count)
            )
        case .extensions:
            status = L10n.format("%lld extensions cached; refresh to scan again.", Int64(installedExtensions.count))
        case .settings:
            status = L10n.string("Manage language, appearance, and other preferences.")
        }
    }

    func scanLoginItems() {
        featureTasks[.loginItems]?.cancel()
        isScanning = true
        loadingModes.insert(.loginItems)
        status = L10n.string("Reading login items…")
        featureTasks[.loginItems] = Task {
            let result = await systemInventoryScanner.loginApplications()
            guard !Task.isCancelled else { return }
            loginApplications = result.items
            let localizedError = result.errorMessage.map(L10n.diagnostic)
            loginApplicationsError = localizedError
            lastScanAt = Date()
            lastUpdatedAt[.loginItems] = lastScanAt
            hasScannedLoginApplications = true
            persistInventorySnapshot()
            loadingModes.remove(.loginItems)
            featureTasks[.loginItems] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .loginItems {
                status = localizedError ?? L10n.format("%lld login items found.", Int64(result.items.count))
            }
        }
    }

    func scanBackgroundActivity() {
        featureTasks[.backgroundActivity]?.cancel()
        isScanning = true
        loadingModes.insert(.backgroundActivity)
        backgroundDatabaseNotice = nil
        status = L10n.string("Reading background activity…")
        featureTasks[.backgroundActivity] = Task {
            let found = await systemInventoryScanner.loginItems(
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            guard !Task.isCancelled else { return }
            let registered = await systemInventoryScanner.registeredBackgroundTasks()
            guard !Task.isCancelled else { return }
            backgroundItems = found
            registeredBackgroundTasks = registered.items
            let localizedError = registered.errorMessage.map(L10n.diagnostic)
            backgroundTaskScanError = localizedError
            lastScanAt = Date()
            lastUpdatedAt[.backgroundActivity] = lastScanAt
            hasScannedBackgroundItems = true
            persistInventorySnapshot()
            loadingModes.remove(.backgroundActivity)
            featureTasks[.backgroundActivity] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .backgroundActivity {
                status = localizedError
                    ?? L10n.format(
                        "%lld app background records and %lld background configurations found.",
                        Int64(registered.items.count),
                        Int64(found.count)
                    )
            }
        }
    }

    func resetBackgroundTaskDatabaseConfirmed() {
        showBackgroundDatabaseResetConfirmation = false
        featureTasks[.backgroundActivity]?.cancel()
        isScanning = true
        loadingModes.insert(.backgroundActivity)
        status = L10n.string("Rebuilding background task database…")
        featureTasks[.backgroundActivity] = Task {
            let error = await systemInventoryScanner.resetBackgroundTaskDatabase()
            guard !Task.isCancelled else { return }
            loadingModes.remove(.backgroundActivity)
            featureTasks[.backgroundActivity] = nil
            isScanning = !loadingModes.isEmpty
            if let error {
                let localizedError = L10n.diagnostic(error)
                removalFailureMessage = localizedError
                if mode == .backgroundActivity { status = localizedError }
                showRemovalFailure = true
            } else {
                registeredBackgroundTasks = []
                backgroundTaskScanError = nil
                backgroundDatabaseNotice = L10n.string("The background task database was rebuilt. Restart your Mac so valid items can register again.")
                lastScanAt = Date()
                hasScannedBackgroundItems = false
                if mode == .backgroundActivity {
                    status = L10n.string("Background task database rebuilt. Restart your Mac.")
                }
            }
        }
    }

    func scanExtensions() {
        featureTasks[.extensions]?.cancel()
        isScanning = true
        loadingModes.insert(.extensions)
        status = L10n.string("Reading app extensions…")
        featureTasks[.extensions] = Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let apps = await applicationScanner.applications(in: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                home.appending(path: "Applications", directoryHint: .isDirectory)
            ])
            guard !Task.isCancelled else { return }
            let found = await systemInventoryScanner.extensions(in: apps, home: home)
            guard !Task.isCancelled else { return }
            installedExtensions = found
            lastScanAt = Date()
            lastUpdatedAt[.extensions] = lastScanAt
            hasScannedExtensions = true
            persistInventorySnapshot()
            loadingModes.remove(.extensions)
            featureTasks[.extensions] = nil
            isScanning = !loadingModes.isEmpty
            if mode == .extensions {
                status = L10n.format("%lld extensions found.", Int64(found.count))
            }
        }
    }

    func requestLoginApplicationRemoval(_ item: LoginApplication) {
        loginApplicationRemovalCandidate = item
        showLoginApplicationRemovalConfirmation = true
    }

    func removeLoginApplicationConfirmed() {
        guard let item = loginApplicationRemovalCandidate else { return }
        showLoginApplicationRemovalConfirmation = false
        loginApplicationRemovalCandidate = nil
        status = L10n.format("Removing login item %@…", item.name)
        Task {
            if let error = await systemInventoryScanner.removeLoginApplication(item) {
                let localizedError = L10n.diagnostic(error)
                removalFailureMessage = localizedError
                status = localizedError
                showRemovalFailure = true
            } else {
                loginApplications.removeAll { $0.id == item.id }
                status = L10n.format("%@ was removed from Login Items.", item.name)
            }
        }
    }

    func requestBackgroundItemRemoval(_ item: LoginItem) {
        backgroundItemRemovalCandidate = item
        showBackgroundItemRemovalConfirmation = true
    }

    func requestRegisteredBackgroundTaskRemoval(_ item: RegisteredBackgroundTask) {
        registeredBackgroundTaskRemovalCandidate = item
        showRegisteredBackgroundTaskRemovalConfirmation = true
    }

    func removeRegisteredBackgroundTaskConfirmed() {
        guard let item = registeredBackgroundTaskRemovalCandidate else { return }
        showRegisteredBackgroundTaskRemovalConfirmation = false
        registeredBackgroundTaskRemovalCandidate = nil
        status = L10n.format("Removing %@'s Trash leftover…", item.name)
        Task {
            if let error = await systemInventoryScanner.removeRegisteredBackgroundTaskResidue(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            ) {
                let localizedError = L10n.diagnostic(error)
                removalFailureMessage = localizedError
                status = localizedError
                showRemovalFailure = true
            } else {
                registeredBackgroundTasks.removeAll { $0.id == item.id }
                status = L10n.format("%@'s Trash leftover was permanently deleted. Its macOS background record may disappear after you sign in again.", item.name)
            }
        }
    }

    func removeBackgroundItemConfirmed() {
        guard let item = backgroundItemRemovalCandidate else { return }
        showBackgroundItemRemovalConfirmation = false
        backgroundItemRemovalCandidate = nil
        status = L10n.format("Moving %@ to Trash…", item.label)
        Task {
            let result = await systemInventoryScanner.moveLoginItemToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            publishOperationReport(title: L10n.format("%@ Remove results", item.label), result: result)
            if result.movedToTrash.isEmpty {
                removalFailureMessage = L10n.format(
                    "Unable to remove %@: %@",
                    item.label,
                    result.failures.first?.reason ?? L10n.string("Unknown error")
                )
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                backgroundItems.removeAll { $0.id == item.id }
                status = L10n.format("%@'s launch configuration was moved to Trash. Its current process may continue until it exits or the Mac restarts.", item.label)
            }
        }
    }

    func requestExtensionRemoval(_ item: InstalledExtension) {
        extensionRemovalCandidate = item
        showExtensionRemovalConfirmation = true
    }

    func removeExtensionConfirmed() {
        guard let item = extensionRemovalCandidate else { return }
        showExtensionRemovalConfirmation = false
        extensionRemovalCandidate = nil
        status = L10n.format("Moving %@ to Trash…", item.name)
        Task {
            let result = await systemInventoryScanner.moveExtensionToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            publishOperationReport(title: L10n.format("%@ Remove results", item.name), result: result)
            if result.movedToTrash.isEmpty {
                removalFailureMessage = L10n.format(
                    "Unable to remove %@: %@",
                    item.name,
                    result.failures.first?.reason ?? L10n.string("Unknown error")
                )
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                installedExtensions.removeAll { $0.id == item.id }
                status = L10n.format("%@ was moved to Trash. Its features will no longer load after you sign in again.", item.name)
            }
        }
    }

    func prepareUninstall(_ app: InstalledApplication) {
        isPreparingUninstall = true
        status = L10n.format("Finding files related to %@…", app.name)
        Task {
            let found = await applicationScanner.residues(
                for: app,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            uninstallResidues = found
            selectedResidueIDs = Set(found.filter { $0.risk == .safe }.map(\.id))
            uninstallCandidate = app
            isPreparingUninstall = false
            status = L10n.string("Review the items to move to Trash.")
        }
    }

    func uninstallConfirmed() {
        guard let app = uninstallCandidate else { return }
        let selectedResidues = uninstallResidues.filter { selectedResidueIDs.contains($0.id) }
        uninstallCandidate = nil
        showAppRemovalConfirmation = false
        isScanning = true
        status = L10n.format("Uninstalling %@…", app.name)
        Task {
            let result = await applicationScanner.moveToTrash(
                app: app,
                residues: selectedResidues,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            isScanning = false
            uninstallResidues = []
            selectedResidueIDs = []
            status = L10n.format(
                "%lld items moved to Trash; %lld failed. Items can be restored from Trash.",
                Int64(result.movedToTrash.count),
                Int64(result.failures.count)
            )
            operationReport = RemovalOperationReport(
                title: L10n.format("%@ Uninstall results", app.name),
                summary: L10n.format(
                    "%lld items moved to Trash; %lld failed. Items can be restored from Trash.",
                    Int64(result.movedToTrash.count),
                    Int64(result.failures.count)
                ),
                movedToTrash: result.movedToTrash,
                failures: result.failures
            )
            scanInstalledApplications()
        }
    }

    func isSystemApplication(_ app: InstalledApplication) -> Bool {
        app.bundleURL.path.hasPrefix("/System/")
    }

    private func publishOperationReport(title: String, result: CleanResult) {
        operationReport = RemovalOperationReport(
            title: title,
            summary: L10n.format(
                "%lld items moved to Trash; %lld failed.",
                Int64(result.movedToTrash.count),
                Int64(result.failures.count)
            ),
            movedToTrash: result.movedToTrash,
            failures: result.failures
        )
    }

    func requestClean() {
        guard !selectedIDs.isEmpty else { return }
        showCleanConfirmation = true
    }

    func cleanConfirmed() {
        let selected = items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        Task {
            let result = await cleaner.moveToTrash(items: selected, selectedRoot: cleanupRoot)
            let moved = Set(result.movedToTrash)
            items.removeAll { moved.contains($0.url) }
            selectedIDs.subtract(selected.map(\.id))
            rebuildJunkGroups()
            cleanableBytes = selectedBytes
            status = L10n.format(
                "%lld items moved to Trash; %lld failed.",
                Int64(result.movedToTrash.count),
                Int64(result.failures.count)
            )
            operationReport = RemovalOperationReport(
                title: L10n.string("Clean results"),
                summary: status,
                movedToTrash: result.movedToTrash,
                failures: result.failures
            )
        }
    }

    func isGroupSelected(_ group: JunkScanGroup) -> Bool {
        !group.items.isEmpty && selectedCountByGroup[group.id] == group.items.count
    }

    func selectAllJunkItems() {
        guard !items.isEmpty else { return }
        selectedIDs = Set(items.map(\.id))
        recalculateSelectionSummary()
    }

    func deselectAllJunkItems() {
        guard !selectedIDs.isEmpty else { return }
        selectedIDs = []
        recalculateSelectionSummary()
    }

    func setGroup(_ group: JunkScanGroup, selected: Bool) {
        let ids = group.items.map(\.id)
        if selected { selectedIDs.formUnion(ids) }
        else { selectedIDs.subtract(ids) }
        recalculateSelectionSummary()
    }

    func isItemSelected(_ item: ScanItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    func setItem(_ item: ScanItem, selected: Bool) {
        guard selectedIDs.contains(item.id) != selected else { return }
        if selected {
            selectedIDs.insert(item.id)
            selectedBytes += item.bytes
            selectedCountByGroup[item.rule.id, default: 0] += 1
        } else {
            selectedIDs.remove(item.id)
            selectedBytes -= item.bytes
            selectedCountByGroup[item.rule.id, default: 0] -= 1
        }
    }

    private func rebuildJunkGroups() {
        itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        totalBytes = items.reduce(0) { $0 + $1.bytes }
        var ruleOrder = Dictionary(uniqueKeysWithValues: DefaultRules.conservative.enumerated().map { ($0.element.id, $0.offset + 1) })
        ruleOrder[DefaultRules.uninstallLeftovers.id] = 0
        let grouped = Dictionary(grouping: items, by: { $0.rule.id })
        junkGroups = grouped.values.compactMap { groupItems in
            guard let first = groupItems.first else { return nil }
            let sorted = groupItems.sorted { $0.bytes > $1.bytes }
            return JunkScanGroup(
                id: first.rule.id,
                title: first.rule.title,
                explanation: first.rule.explanation,
                risk: first.rule.risk,
                items: sorted,
                bytes: sorted.reduce(0) { $0 + $1.bytes }
            )
        }.sorted {
            (ruleOrder[$0.id] ?? .max) < (ruleOrder[$1.id] ?? .max)
        }
        recalculateSelectionSummary()
    }

    private func rebuildApplicationGroups() {
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications", directoryHint: .isDirectory).path + "/"
        let grouped = Dictionary(grouping: applications) { app -> ApplicationCategory in
            if app.bundleURL.path.hasPrefix("/System/") { return .system }
            if app.bundleURL.path.hasPrefix(homeApplications) { return .user }
            if FileManager.default.fileExists(atPath: app.bundleURL.appending(path: "Contents/_MASReceipt/receipt").path) {
                return .appStore
            }
            return .thirdParty
        }
        applicationGroups = ApplicationCategory.allCases.compactMap { category in
            guard let apps = grouped[category], !apps.isEmpty else { return nil }
            return ApplicationGroup(category: category, applications: apps)
        }
    }

    private func recalculateSelectionSummary() {
        selectedBytes = selectedIDs.reduce(0) { $0 + (itemByID[$1]?.bytes ?? 0) }
        selectedCountByGroup = Dictionary(
            grouping: selectedIDs.compactMap { itemByID[$0]?.rule.id },
            by: { $0 }
        ).mapValues(\.count)
    }
}
