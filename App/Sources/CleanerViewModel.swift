import AppKit
import Darwin
import MachKitCore
import Foundation

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var mode: FeatureMode = .home
    @Published var root: URL?
    @Published var items: [ScanItem] = []
    @Published private(set) var storageAnalysis: StorageAnalysis?
    @Published private(set) var storagePath: [URL] = []
    @Published private(set) var performanceSnapshot: PerformanceSnapshot?
    @Published private(set) var dashboardMetrics: DashboardMetricsSnapshot?
    @Published private(set) var performanceHistory: [PerformanceHistoryPoint] = []
    @Published private(set) var systemStorage = SystemStorageSnapshot.empty
    @Published private(set) var cleanableBytes: Int64?
    @Published private(set) var networkTransferRate: NetworkTransferRate?
    @Published private(set) var hasLoadedPortSnapshot = false
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
    @Published private(set) var safeCleanableBytes: Int64 = 0
    @Published private(set) var reviewCleanableBytes: Int64 = 0
    @Published private(set) var safeItemCount = 0
    @Published private(set) var reviewItemCount = 0
    @Published var isScanning = false
    @Published private(set) var isCleanupScanning = false
    @Published private(set) var isPreparingCleanupResults = false
    @Published private(set) var isCleaning = false
    @Published private(set) var cleaningProcessedCount = 0
    @Published private(set) var cleaningTotalCount = 0
    @Published private(set) var lastCleanupFreedBytes: Int64?
    @Published private(set) var isStorageAnalyzing = false
    @Published private(set) var storageInspectedFiles = 0
    @Published private(set) var storageScannedBytes: Int64 = 0
    @Published private(set) var storageDeepRoot: URL?
    @Published private(set) var loadingModes: Set<FeatureMode> = []
    @Published var showCleanConfirmation = false
    @Published var lastScanAt: Date?
    @Published private(set) var lastUpdatedAt: [FeatureMode: Date] = [:]
    @Published var scanProgress = 0.0
    @Published var currentScanCategory = ""
    @Published private(set) var completedCleanupPhases: Set<String> = []
    @Published private(set) var activeCleanupPhaseID: String?
    @Published private(set) var activeCleanupPhaseProgress = 0.0
    @Published private(set) var showsLeftoverScanPhase = true

    struct CleanupScanPhase: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let icon: String
        let summary: String
        let ruleIDs: [String]
        let scansLeftovers: Bool

        init(
            id: String,
            title: String,
            icon: String,
            summary: String,
            ruleIDs: [String] = [],
            scansLeftovers: Bool = false
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.summary = summary
            self.ruleIDs = ruleIDs
            self.scansLeftovers = scansLeftovers
        }
    }

    var visibleCleanupScanPhases: [CleanupScanPhase] {
        Self.cleanupScanPhases.filter { phase in
            phase.id != "leftovers" || showsLeftoverScanPhase
        }
    }
    @Published var inspectedFileCount = 0
    @Published var discoveredFileCount = 0
    @Published var discoveredBytes: Int64 = 0
    @Published var status = L10n.string("Choose your user folder or a test folder.")

    private let cleaner: any CleaningService
    private let snapshotStore: any AppSnapshotStoring
    private let applicationScanner = ApplicationScanner()
    private let systemInventoryScanner = SystemInventoryScanner()
    private let fileAnalyzer: any StorageAnalysisService
    private let systemMonitor: SystemMonitorService
    private let portScanner = PortScanner()
    private var scanTask: Task<Void, Never>?
    private var storageAnalysisTask: Task<Void, Never>?
    private var storageAnalysisGeneration = UUID()
    private var cleanupScanGeneration = UUID()
    private var lastCleanupProgressUIUpdate = Date.distantPast
    private static let cleanupProgressUIMinInterval: TimeInterval = 1.0 / 12.0
    private var featureTasks: [FeatureMode: Task<Void, Never>] = [:]
    private var performanceTask: Task<Void, Never>?
    private var networkMonitoringTask: Task<Void, Never>?
    private var routeLookupTask: Task<Void, Never>?
    private var homeMonitoringTask: Task<Void, Never>?
    private var isMainWindowVisible = false
    private var hasScannedApplications = false
    private var hasAnalyzedStorage = false
    private var storageCache: [String: StorageAnalysis] = [:]
    private var storageCacheOrder: [String] = []
    private static let storageCacheLimit = 12
    private var hasScannedLoginApplications = false
    private var hasScannedBackgroundItems = false
    private var hasScannedExtensions = false
    private var selectedCountByGroup: [String: Int] = [:]
    private var itemByID: [UUID: ScanItem] = [:]
    private var itemIDsByRuleID: [String: [UUID]] = [:]
    private var cleanupRoot = FileManager.default.homeDirectoryForCurrentUser
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

    var lastJunkScanText: String? {
        guard let date = lastUpdatedAt[.junk] else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func isLoading(_ mode: FeatureMode) -> Bool {
        mode == .files ? isStorageAnalyzing : loadingModes.contains(mode)
    }

    init(
        cleaner: any CleaningService = LiveCleaningService(),
        fileAnalyzer: any StorageAnalysisService = LiveStorageAnalysisService(),
        snapshotStore: any AppSnapshotStoring = UserDefaultsAppSnapshotStore(),
        systemMonitor: SystemMonitorService = .shared
    ) {
        self.cleaner = cleaner
        self.fileAnalyzer = fileAnalyzer
        self.snapshotStore = snapshotStore
        self.systemMonitor = systemMonitor
        restoreStorageSnapshot()
        restoreInventorySnapshot()
        refreshSystemStorage()
    }

    // MARK: - Root selection

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

    // MARK: - Application inventory

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

    // MARK: - Cleanup scanning

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
        let generation = UUID()
        cleanupScanGeneration = generation
        isCleanupScanning = true
        isPreparingCleanupResults = false
        // Drop previous results immediately so a re-scan never flashes old groups
        // under the scanning chrome.
        items = []
        selectedIDs = []
        junkGroups = []
        itemByID = [:]
        itemIDsByRuleID = [:]
        totalBytes = 0
        selectedBytes = 0
        selectedCountByGroup = [:]
        safeCleanableBytes = 0
        reviewCleanableBytes = 0
        safeItemCount = 0
        reviewItemCount = 0
        cleanableBytes = 0
        scanProgress = 0
        cleanupIncludesResidues = selectedRoot.resolvingSymlinksInPath()
            == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        showsLeftoverScanPhase = cleanupIncludesResidues
        completedCleanupPhases = []
        activeCleanupPhaseID = nil
        activeCleanupPhaseProgress = 0
        lastCleanupProgressUIUpdate = .distantPast
        currentScanCategory = L10n.string("Getting ready…")
        inspectedFileCount = 0
        discoveredFileCount = 0
        discoveredBytes = 0
        status = L10n.string("Scanning…")
        let includeResidues = cleanupIncludesResidues
        let phases = Self.cleanupScanPhases.filter { $0.id != "leftovers" || includeResidues }
        scanTask = Task { [scanMode, generation] in
            let (stream, continuation) = AsyncStream.makeStream(of: CleanupScanProgressEvent.self)
            let worker = Task.detached(priority: .userInitiated) {
                let items = await CleanerViewModel.runCleanupScan(
                    root: selectedRoot,
                    includeResidues: includeResidues,
                    phases: phases
                ) { event in
                    continuation.yield(event)
                }
                continuation.finish()
                return items
            }
            defer {
                worker.cancel()
                continuation.finish()
            }

            for await event in stream {
                guard cleanupScanGeneration == generation else { return }
                guard !Task.isCancelled else { return }
                applyCleanupProgress(event, generation: generation)
            }

            guard cleanupScanGeneration == generation else { return }
            guard !Task.isCancelled else { return }

            let found = await worker.value
            guard cleanupScanGeneration == generation, !Task.isCancelled else { return }

            currentScanCategory = L10n.string("Preparing results…")
            isPreparingCleanupResults = true
            let prepared = await Task.detached(priority: .userInitiated) {
                CleanerViewModel.prepareCleanupResults(from: found)
            }.value
            guard cleanupScanGeneration == generation, !Task.isCancelled else { return }

            applyPreparedCleanupResults(prepared)
            lastScanAt = Date()
            lastUpdatedAt[scanMode] = lastScanAt
            scanProgress = 1
            activeCleanupPhaseProgress = 1
            completedCleanupPhases = Set(phases.map(\.id))
            activeCleanupPhaseID = nil
            currentScanCategory = L10n.string("Wrapping up…")
            isPreparingCleanupResults = false
            isCleanupScanning = false
            scanTask = nil
            switch scanMode {
            case .home:
                status = L10n.format("Scan complete. %lld candidate files found.", Int64(found.count))
            case .junk:
                status = L10n.format(
                    "%lld candidate files found. Items marked ‘Review’ are not selected by default.",
                    Int64(found.count)
                )
            default:
                break
            }
        }
    }

    /// Background cleanup orchestration — never touches UI state directly.
    private nonisolated static func runCleanupScan(
        root: URL,
        includeResidues: Bool,
        phases: [CleanupScanPhase],
        onProgress: @escaping @Sendable (CleanupScanProgressEvent) -> Void
    ) async -> [ScanItem] {
        let rulesByID = Dictionary(uniqueKeysWithValues: DefaultRules.conservative.map { ($0.id, $0) })
        let categories: [CleanupCategorySpec] = phases.map { phase in
            if phase.scansLeftovers {
                return CleanupCategorySpec(id: phase.id, scansLeftovers: true)
            }
            let rules = phase.ruleIDs.compactMap { rulesByID[$0] }
            return CleanupCategorySpec(id: phase.id, rules: rules)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let engine = CleanupScanEngine()
        let found = await engine.scan(
            root: root,
            home: home,
            categories: categories,
            onProgress: onProgress
        )
        guard includeResidues else { return found }

        let leftoverRootSet = Set(
            found
                .filter { $0.rule.id == DefaultRules.uninstallLeftovers.id }
                .map { $0.url.standardizedFileURL.path }
        )
        guard !leftoverRootSet.isEmpty else { return found }

        return found.filter { item in
            if item.rule.id == DefaultRules.uninstallLeftovers.id { return true }
            return !Self.path(item.url.standardizedFileURL.path, isCoveredBy: leftoverRootSet)
        }
    }

    /// True when `path` equals a leftover root or sits under one (ancestor walk, O(depth)).
    private nonisolated static func path(_ path: String, isCoveredBy roots: Set<String>) -> Bool {
        if roots.contains(path) { return true }
        var prefix = path
        while let slash = prefix.lastIndex(of: "/") {
            prefix = String(prefix[..<slash])
            if prefix.isEmpty { break }
            if roots.contains(prefix) { return true }
        }
        return false
    }

    private struct PreparedCleanupResults: Sendable {
        let items: [ScanItem]
        let selectedIDs: Set<UUID>
        let junkGroups: [JunkScanGroup]
        let itemByID: [UUID: ScanItem]
        let itemIDsByRuleID: [String: [UUID]]
        let totalBytes: Int64
        let selectedBytes: Int64
        let selectedCountByGroup: [String: Int]
        let safeCleanableBytes: Int64
        let reviewCleanableBytes: Int64
        let safeItemCount: Int
        let reviewItemCount: Int
    }

    private nonisolated static let maxJunkItemsPerGroup = 50

    private nonisolated static func prepareCleanupResults(from found: [ScanItem]) -> PreparedCleanupResults {
        let itemByID = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
        let totalBytes = found.reduce(into: Int64(0)) { $0 += $1.bytes }
        var safeBytes: Int64 = 0
        var reviewBytes: Int64 = 0
        var safeCount = 0
        var reviewCount = 0
        var selectedIDs = Set<UUID>()
        var itemIDsByRuleID: [String: [UUID]] = [:]

        for item in found {
            itemIDsByRuleID[item.rule.id, default: []].append(item.id)
            switch item.rule.risk {
            case .safe:
                safeBytes += item.bytes
                safeCount += 1
                selectedIDs.insert(item.id)
            case .review:
                reviewBytes += item.bytes
                reviewCount += 1
            case .blocked:
                break
            }
        }

        var ruleOrder = Dictionary(uniqueKeysWithValues: DefaultRules.conservative.enumerated().map { ($0.element.id, $0.offset + 1) })
        ruleOrder[DefaultRules.uninstallLeftovers.id] = 0
        let grouped = Dictionary(grouping: found, by: \.rule.id)
        let junkGroups: [JunkScanGroup] = grouped.values.compactMap { groupItems in
            guard let first = groupItems.first else { return nil }
            let sorted = groupItems.sorted { $0.bytes > $1.bytes }
            return JunkScanGroup(
                id: first.rule.id,
                title: first.rule.title,
                explanation: first.rule.explanation,
                risk: first.rule.risk,
                items: Array(sorted.prefix(maxJunkItemsPerGroup)),
                totalCount: sorted.count,
                bytes: sorted.reduce(into: Int64(0)) { $0 += $1.bytes }
            )
        }.sorted {
            (ruleOrder[$0.id] ?? .max) < (ruleOrder[$1.id] ?? .max)
        }

        let selectedCountByGroup = Dictionary(
            grouping: selectedIDs.compactMap { itemByID[$0]?.rule.id },
            by: { $0 }
        ).mapValues(\.count)
        let selectedBytes = selectedIDs.reduce(into: Int64(0)) { partial, id in
            partial += itemByID[id]?.bytes ?? 0
        }

        return PreparedCleanupResults(
            items: found,
            selectedIDs: selectedIDs,
            junkGroups: junkGroups,
            itemByID: itemByID,
            itemIDsByRuleID: itemIDsByRuleID,
            totalBytes: totalBytes,
            selectedBytes: selectedBytes,
            selectedCountByGroup: selectedCountByGroup,
            safeCleanableBytes: safeBytes,
            reviewCleanableBytes: reviewBytes,
            safeItemCount: safeCount,
            reviewItemCount: reviewCount
        )
    }

    private func applyPreparedCleanupResults(_ prepared: PreparedCleanupResults) {
        items = prepared.items
        selectedIDs = prepared.selectedIDs
        junkGroups = prepared.junkGroups
        itemByID = prepared.itemByID
        itemIDsByRuleID = prepared.itemIDsByRuleID
        totalBytes = prepared.totalBytes
        selectedBytes = prepared.selectedBytes
        selectedCountByGroup = prepared.selectedCountByGroup
        safeCleanableBytes = prepared.safeCleanableBytes
        reviewCleanableBytes = prepared.reviewCleanableBytes
        safeItemCount = prepared.safeItemCount
        reviewItemCount = prepared.reviewItemCount
        cleanableBytes = prepared.selectedBytes
    }

    private func applyCleanupProgress(_ event: CleanupScanProgressEvent, generation: UUID) {
        guard cleanupScanGeneration == generation else { return }
        let phaseChanged = activeCleanupPhaseID != event.categoryID
        let categoryFinished = event.categoryFraction >= 0.999
        let now = Date()
        let intervalElapsed = now.timeIntervalSince(lastCleanupProgressUIUpdate)
            >= Self.cleanupProgressUIMinInterval
        // Always publish phase boundaries; throttle in-phase ticks so a warm
        // re-scan does not rebuild the scanning UI dozens of times per second.
        guard phaseChanged || categoryFinished || intervalElapsed else { return }
        lastCleanupProgressUIUpdate = now

        activeCleanupPhaseID = event.categoryID
        activeCleanupPhaseProgress = event.categoryFraction
        completedCleanupPhases = Set(event.completedCategoryIDs)
        scanProgress = event.overallFraction
        inspectedFileCount = event.inspectedFiles
        discoveredFileCount = event.matchedFiles
        discoveredBytes = event.matchedBytes
        currentScanCategory = Self.friendlyCleanupPhase(forPhaseID: event.categoryID)
    }

    // MARK: - Storage analysis

    func scanStorageAnalysis() {
        storageAnalysisTask?.cancel()
        let generation = UUID()
        storageAnalysisGeneration = generation
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let selectedRoot = (root ?? home).standardizedFileURL
        root = selectedRoot
        storageDeepRoot = selectedRoot
        isStorageAnalyzing = true
        scanProgress = 0
        storageInspectedFiles = 0
        storageScannedBytes = 0
        inspectedFileCount = 0
        discoveredBytes = 0
        currentScanCategory = L10n.string("Folder overview")
        status = L10n.string("Analyzing storage…")
        storageAnalysisTask = Task {
            let analysis = await fileAnalyzer.fullStorageAnalysis(
                root: selectedRoot,
                volumeURL: URL(fileURLWithPath: "/", isDirectory: true)
            ) { [weak self] progress in
                Task { @MainActor in
                    guard let self,
                          self.storageAnalysisGeneration == generation else { return }
                    self.storageInspectedFiles = progress.inspectedFiles
                    self.storageScannedBytes = progress.scannedBytes
                    self.inspectedFileCount = progress.inspectedFiles
                    self.discoveredBytes = progress.scannedBytes
                    self.currentScanCategory = progress.inspectedFiles == 0
                        ? L10n.string("Folder overview")
                        : L10n.string("Categorizing files")
                    // Indeterminate-ish progress: grow slowly with inspected files.
                    self.scanProgress = min(0.95, 0.08 + Double(progress.inspectedFiles) / 80_000)
                }
            }
            guard !Task.isCancelled,
                  storageAnalysisGeneration == generation else { return }
            storageAnalysis = analysis
            cacheStorageAnalysis(analysis, for: selectedRoot.path)
            storagePath = breadcrumbPath(to: selectedRoot)
            items = []
            selectedIDs = []
            lastScanAt = Date()
            lastUpdatedAt[.files] = lastScanAt
            hasAnalyzedStorage = true
            persistStorageSnapshot(analysis)
            isStorageAnalyzing = false
            storageAnalysisTask = nil
            scanProgress = 1
            currentScanCategory = L10n.string("Analysis complete")
            if mode == .files {
                status = L10n.format(
                    "Found %lld files · %@ scanned · %lld large files.",
                    Int64(analysis.scannedFileCount),
                    ByteCountFormatter.string(fromByteCount: analysis.scannedBytes, countStyle: .file),
                    Int64(analysis.largeFiles.count)
                )
            }
        }
    }

    func openStorageDirectory(_ url: URL) {
        let url = url.standardizedFileURL
        root = url
        storagePath = breadcrumbPath(to: url)
        if let cached = cachedStorageAnalysis(for: url.path) {
            storageAnalysis = mergeFolderListing(cached, into: storageAnalysis)
            return
        }
        storageAnalysisTask?.cancel()
        let generation = UUID()
        storageAnalysisGeneration = generation
        isStorageAnalyzing = true
        currentScanCategory = url.lastPathComponent
        status = L10n.string("Reading directory occupancy...")
        storageAnalysisTask = Task {
            let overview = await fileAnalyzer.directoryOverview(
                root: url,
                volumeURL: URL(fileURLWithPath: "/", isDirectory: true)
            )
            guard !Task.isCancelled,
                  storageAnalysisGeneration == generation else { return }
            cacheStorageAnalysis(overview, for: url.path)
            storageAnalysis = mergeFolderListing(overview, into: storageAnalysis)
            isStorageAnalyzing = false
            storageAnalysisTask = nil
            if mode == .files {
                status = L10n.format(
                    "Read %lld items occupying %@.",
                    Int64(overview.directories.count),
                    ByteCountFormatter.string(fromByteCount: overview.scannedBytes, countStyle: .file)
                )
            }
        }
    }

    func navigateStorage(to url: URL) {
        openStorageDirectory(url)
    }

    private func mergeFolderListing(_ overview: StorageAnalysis, into existing: StorageAnalysis?) -> StorageAnalysis {
        guard let existing, !existing.categories.isEmpty || !existing.largeFiles.isEmpty else {
            return overview
        }
        return StorageAnalysis(
            totalCapacity: existing.totalCapacity > 0 ? existing.totalCapacity : overview.totalCapacity,
            availableCapacity: existing.availableCapacity > 0 ? existing.availableCapacity : overview.availableCapacity,
            scannedBytes: existing.scannedBytes,
            scannedFileCount: existing.scannedFileCount,
            inaccessibleItemCount: existing.inaccessibleItemCount,
            categories: existing.categories,
            largeFiles: existing.largeFiles,
            analyzedRoots: existing.analyzedRoots,
            directories: overview.directories
        )
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

    private func persistStorageSnapshot(_ analysis: StorageAnalysis) {
        snapshotStore.saveStorage(analysis, savedAt: lastScanAt ?? Date())
    }

    private func cachedStorageAnalysis(for path: String) -> StorageAnalysis? {
        guard let analysis = storageCache[path] else { return nil }
        storageCacheOrder.removeAll { $0 == path }
        storageCacheOrder.append(path)
        return analysis
    }

    private func cacheStorageAnalysis(_ analysis: StorageAnalysis, for path: String) {
        storageCache[path] = analysis
        storageCacheOrder.removeAll { $0 == path }
        storageCacheOrder.append(path)
        while storageCacheOrder.count > Self.storageCacheLimit {
            let evictedPath = storageCacheOrder.removeFirst()
            storageCache.removeValue(forKey: evictedPath)
        }
    }

    private func restoreStorageSnapshot() {
        guard let snapshot = snapshotStore.loadStorage(),
              let root = snapshot.analysis.analyzedRoots.first else { return }
        let analysis = snapshot.analysis
        storageAnalysis = analysis
        cacheStorageAnalysis(analysis, for: root.path)
        storageDeepRoot = root
        storagePath = breadcrumbPath(to: root)
        lastUpdatedAt[.files] = snapshot.savedAt
        lastScanAt = snapshot.savedAt
        hasAnalyzedStorage = true
    }

    private func persistInventorySnapshot() {
        snapshotStore.saveInventory(InventorySnapshotState(
            applications: applications,
            commandLineTools: commandLineTools,
            loginApplications: loginApplications,
            backgroundItems: backgroundItems,
            registeredBackgroundTasks: registeredBackgroundTasks,
            installedExtensions: installedExtensions
        ))
    }

    private func restoreInventorySnapshot() {
        guard let snapshot = snapshotStore.loadInventory() else { return }
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
            storageAnalysisGeneration = UUID()
            storageAnalysisTask = nil
            isStorageAnalyzing = false
            currentScanCategory = L10n.string("Analysis canceled")
            status = L10n.string("Analysis canceled.")
            return
        }
        cleanupScanGeneration = UUID()
        scanTask?.cancel()
        scanTask = nil
        isCleanupScanning = false
        isPreparingCleanupResults = false
        currentScanCategory = L10n.string("Scan canceled")
        status = L10n.string("Scan canceled.")
    }

    // MARK: - Performance monitoring

    func startPerformanceMonitoring() {
        guard isMainWindowVisible, mode == .performance else { return }
        performanceTask?.cancel()
        status = L10n.string("Monitoring system performance…")
        performanceTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, mode == .performance, isMainWindowVisible {
                if !NSApp.isActive {
                    do {
                        try await Task.sleep(for: .seconds(30))
                    } catch {
                        return
                    }
                    continue
                }
                let snapshot = await self.systemMonitor.samplePerformanceSnapshot()
                guard !Task.isCancelled, mode == .performance, isMainWindowVisible else {
                    return
                }
                performanceSnapshot = snapshot
                performanceHistory.append(PerformanceHistoryPoint(
                    sampledAt: snapshot.sampledAt,
                    cpuPercent: snapshot.cpuPercent,
                    gpuPercent: snapshot.gpuPercent,
                    memoryPressurePercent: snapshot.memoryPressure * 100
                ))
                if performanceHistory.count > 30 {
                    performanceHistory.removeFirst(performanceHistory.count - 30)
                }
                status = L10n.format(
                    "CPU %lld%% · GPU %@ · Memory pressure: %@",
                    Int64(snapshot.cpuPercent.rounded()),
                    snapshot.gpuPercent.map { "\(Int($0.rounded()))%" } ?? "—",
                    snapshot.memoryPressureLevel.rawValue.localized
                )
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPerformanceMonitoring() {
        performanceTask?.cancel()
        performanceTask = nil
        status = L10n.string("Performance monitoring stopped.")
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
            await refreshPerformanceSnapshot()
            isOptimizingMemory = false
            status = L10n.string("Smart release complete; idle background apps were handled and MachKit returned its own reclaimable memory.")
        }
    }

    private func refreshPerformanceSnapshot() async {
        let snapshot = await systemMonitor.samplePerformanceSnapshot()
        guard !Task.isCancelled else { return }
        performanceSnapshot = snapshot
        performanceHistory.append(PerformanceHistoryPoint(
            sampledAt: snapshot.sampledAt,
            cpuPercent: snapshot.cpuPercent,
            gpuPercent: snapshot.gpuPercent,
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
        guard isMainWindowVisible, mode == .home else { return }
        homeMonitoringTask?.cancel()
        refreshSystemStorage()
        homeMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.mode == .home, self.isMainWindowVisible else { return }
                if NSApp.isActive {
                    self.refreshSystemStorage()
                    let metrics = await self.systemMonitor.sampleDashboardMetrics()
                    let transferRate = await self.systemMonitor.sampleTransferRate()
                    guard !Task.isCancelled,
                          self.mode == .home,
                          self.isMainWindowVisible
                    else { return }
                    self.dashboardMetrics = metrics
                    self.networkTransferRate = transferRate
                }

                do {
                    try await Task.sleep(
                        for: NSApp.isActive ? .seconds(3) : .seconds(30)
                    )
                } catch {
                    return
                }
            }
        }
    }

    // MARK: - Network monitoring

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
            async let snapshotTask = systemMonitor.scanNetwork()
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
            let result = await systemMonitor.route(to: query)
            guard !Task.isCancelled else { return }
            routeLookup = result
            isLookingUpRoute = false
            routeLookupTask = nil
        }
    }

    private func startNetworkMonitoring() {
        guard isMainWindowVisible, mode == .network else { return }
        networkMonitoringTask?.cancel()
        scanNetwork()
        networkMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        for: NSApp.isActive ? .seconds(5) : .seconds(30)
                    )
                } catch {
                    return
                }
                guard let self,
                      self.mode == .network,
                      self.isMainWindowVisible
                else { return }
                if NSApp.isActive, !self.isLoading(.network), !self.showPortTerminationConfirmation {
                    self.scanNetwork()
                }
            }
        }
    }

    func requestPortTermination(_ port: ListeningPort) {
        guard port.canTerminate else {
            removalFailureMessage = port.protectionReason ?? L10n.string("This process cannot be quit from MachKit.")
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

    private static let cleanupScanPhases: [CleanupScanPhase] = [
        .init(
            id: "trash",
            title: "Trash",
            icon: "trash",
            summary: "Items already in Trash that can be emptied permanently.",
            ruleIDs: ["trash"]
        ),
        .init(
            id: "caches",
            title: "Caches",
            icon: "internaldrive",
            summary: "App caches, browser website caches, shared tool caches, temporary files, and language modeling caches.",
            ruleIDs: [
                "user-caches",
                "browser-caches",
                "xdg-caches",
                "temporary-files",
                "language-support-caches",
            ]
        ),
        .init(
            id: "downloads",
            title: "Downloads & mail",
            icon: "tray.and.arrow.down",
            summary: "Old installers and archives in Downloads, plus Mail attachment downloads.",
            ruleIDs: [
                "downloads-archives",
                "mail-downloads",
            ]
        ),
        .init(
            id: "backups",
            title: "Device backups",
            icon: "iphone",
            summary: "Local iPhone and iPad backups stored on this Mac.",
            ruleIDs: ["device-backups"]
        ),
        .init(
            id: "developer",
            title: "Developer files",
            icon: "hammer",
            summary: "Developer logs, package-manager caches, Xcode build artifacts, and unavailable simulator devices.",
            ruleIDs: [
                "user-logs",
                "developer-home-caches",
                "xcode-artifacts",
                "simulator-cache",
                "unavailable-simulator-devices",
            ]
        ),
        .init(
            id: "leftovers",
            title: "Leftover apps",
            icon: "app.badge",
            summary: "Preferences, containers, and support files left behind after apps were uninstalled.",
            scansLeftovers: true
        ),
    ]

    /// Human-friendly scan phases — never expose rule numbers, paths, or technical titles.
    private static func friendlyCleanupPhase(forPhaseID phaseID: String) -> String {
        switch phaseID {
        case "trash":
            return L10n.string("Checking Trash…")
        case "caches":
            return L10n.string("Scanning caches…")
        case "downloads":
            return L10n.string("Checking downloads and mail…")
        case "backups":
            return L10n.string("Checking device backups…")
        case "developer":
            return L10n.string("Scanning developer files…")
        case "leftovers":
            return L10n.string("Looking for leftover app data…")
        default:
            return L10n.string("Looking around…")
        }
    }

    // MARK: - Feature lifecycle

    func setMainWindowVisible(_ visible: Bool) {
        guard isMainWindowVisible != visible else { return }
        isMainWindowVisible = visible
        if visible {
            resumeMonitoringForCurrentMode()
        } else {
            suspendDashboardMonitoring()
        }
    }

    func applicationDidBecomeActive() {
        guard isMainWindowVisible else { return }
        resumeMonitoringForCurrentMode()
    }

    private func resumeMonitoringForCurrentMode() {
        switch mode {
        case .home:
            startHomeMonitoring()
        case .performance:
            startPerformanceMonitoring()
        case .network:
            startNetworkMonitoring()
        default:
            break
        }
    }

    private func suspendDashboardMonitoring() {
        performanceTask?.cancel()
        performanceTask = nil
        networkMonitoringTask?.cancel()
        networkMonitoringTask = nil
        homeMonitoringTask?.cancel()
        homeMonitoringTask = nil
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
        isScanning = !loadingModes.isEmpty
        mode = newMode
        switch newMode {
        case .home:
            status = L10n.string("Check storage and quickly access common tools.")
            if isMainWindowVisible { startHomeMonitoring() }
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
            status = L10n.string("Monitoring system performance…")
            if isMainWindowVisible { startPerformanceMonitoring() }
        case .network:
            if isMainWindowVisible { startNetworkMonitoring() }
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
                status = L10n.string("Monitoring system performance…")
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
            status = L10n.string("Monitoring system performance…")
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

    // MARK: - System inventory

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

    // MARK: - Application removal

    func prepareUninstall(_ app: InstalledApplication) {
        isPreparingUninstall = true
        showAppRemovalConfirmation = false
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
            summary: Self.cleanupResultSummary(result),
            movedToTrash: result.movedToTrash,
            permanentlyDeleted: result.permanentlyDeleted,
            failures: result.failures
        )
    }

    // MARK: - Cleanup actions and selection

    func requestClean() {
        guard !selectedIDs.isEmpty, !isCleaning else { return }
        showCleanConfirmation = true
    }

    func clearJunkResults() {
        if totalBytes > 0 {
            cleanableBytes = totalBytes
        }
        items = []
        selectedIDs = []
        applyPreparedCleanupResults(Self.prepareCleanupResults(from: []))
    }

    var selectedIncludesTrashContents: Bool {
        let trashRoot = cleanupRoot.appending(path: ".Trash", directoryHint: .isDirectory)
        return items.contains { item in
            selectedIDs.contains(item.id) && SafetyPolicy.contains(item.url, in: trashRoot)
        }
    }

    var selectedIncludesNonTrashContents: Bool {
        let trashRoot = cleanupRoot.appending(path: ".Trash", directoryHint: .isDirectory)
        return items.contains { item in
            selectedIDs.contains(item.id) && !SafetyPolicy.contains(item.url, in: trashRoot)
        }
    }

    func cleanConfirmed() {
        let selected = items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty, !isCleaning else { return }
        let freedBytes = selected.reduce(into: Int64(0)) { $0 += $1.bytes }
        isCleaning = true
        cleaningProcessedCount = 0
        cleaningTotalCount = selected.count
        Task {
            var moved: [URL] = []
            var permanentlyDeleted: [URL] = []
            var failures: [CleanFailure] = []
            let batchSize = 25
            var start = selected.startIndex
            while start < selected.endIndex {
                let end = selected.index(start, offsetBy: batchSize, limitedBy: selected.endIndex) ?? selected.endIndex
                let batch = Array(selected[start..<end])
                let result = await cleaner.moveToTrash(items: batch, selectedRoot: cleanupRoot)
                moved.append(contentsOf: result.movedToTrash)
                permanentlyDeleted.append(contentsOf: result.permanentlyDeleted)
                failures.append(contentsOf: result.failures)
                cleaningProcessedCount += batch.count
                start = end
            }

            let removed = Set(moved + permanentlyDeleted)
            items.removeAll { removed.contains($0.url) }
            selectedIDs.subtract(selected.map(\.id))
            rebuildJunkGroups()
            cleanableBytes = items.isEmpty ? 0 : selectedBytes
            status = Self.cleanupResultSummary(
                CleanResult(
                    movedToTrash: moved,
                    permanentlyDeleted: permanentlyDeleted,
                    failures: failures
                )
            )
            isCleaning = false
            cleaningProcessedCount = 0
            cleaningTotalCount = 0
            operationReport = RemovalOperationReport(
                title: L10n.string("Clean results"),
                summary: status,
                movedToTrash: moved,
                permanentlyDeleted: permanentlyDeleted,
                failures: failures
            )
            if items.isEmpty {
                lastCleanupFreedBytes = freedBytes
            }
        }
    }

    private static func cleanupResultSummary(_ result: CleanResult) -> String {
        if !result.permanentlyDeleted.isEmpty && result.movedToTrash.isEmpty {
            return L10n.format(
                "%lld items permanently deleted; %lld failed.",
                Int64(result.permanentlyDeleted.count),
                Int64(result.failures.count)
            )
        }
        if !result.permanentlyDeleted.isEmpty {
            return L10n.format(
                "%lld items moved to Trash, %lld permanently deleted; %lld failed.",
                Int64(result.movedToTrash.count),
                Int64(result.permanentlyDeleted.count),
                Int64(result.failures.count)
            )
        }
        return L10n.format(
            "%lld items moved to Trash; %lld failed.",
            Int64(result.movedToTrash.count),
            Int64(result.failures.count)
        )
    }

    func isGroupSelected(_ group: JunkScanGroup) -> Bool {
        group.totalCount > 0 && selectedCountByGroup[group.id] == group.totalCount
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
        let ids = itemIDsByRuleID[group.id] ?? items.lazy.filter { $0.rule.id == group.id }.map(\.id)
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
        let prepared = Self.prepareCleanupResults(from: items)
        // Preserve current selection when rebuilding after a clean.
        let preservedSelection = selectedIDs
        applyPreparedCleanupResults(prepared)
        selectedIDs = preservedSelection.intersection(Set(prepared.items.map(\.id)))
        recalculateSelectionSummary()
        cleanableBytes = selectedBytes
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
