import AppKit
import SiftCore
import Foundation

struct JunkScanGroup: Identifiable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let risk: RiskLevel
    let items: [ScanItem]
    let bytes: Int64
}

enum ApplicationCategory: String, CaseIterable, Sendable {
    case user = "用户应用"
    case appStore = "App Store"
    case thirdParty = "第三方应用"
    case system = "Apple 系统应用"

    var subtitle: String {
        switch self {
        case .user: "安装在当前用户目录"
        case .appStore: "通过 Mac App Store 安装"
        case .thirdParty: "从开发者或其他渠道安装"
        case .system: "macOS 自带，受系统保护"
        }
    }
}

struct ApplicationGroup: Identifiable, Sendable {
    let category: ApplicationCategory
    let applications: [InstalledApplication]
    var id: String { category.rawValue }
    var bytes: Int64 { applications.reduce(0) { $0 + $1.bytes } }
}

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var mode: FeatureMode = .home
    @Published var root: URL?
    @Published var items: [ScanItem] = []
    @Published private(set) var storageAnalysis: StorageAnalysis?
    @Published private(set) var performanceSnapshot: PerformanceSnapshot?
    @Published private(set) var performanceHistory: [PerformanceHistoryPoint] = []
    @Published private(set) var isPerformanceMonitoring = false
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
    @Published var showCleanConfirmation = false
    @Published var lastScanAt: Date?
    @Published var scanProgress = 0.0
    @Published var currentScanCategory = ""
    @Published var inspectedFileCount = 0
    @Published var discoveredFileCount = 0
    @Published var discoveredBytes: Int64 = 0
    @Published var status = "请选择你的用户目录或一个测试目录。"

    private let scanner = SiftCore.Scanner()
    private let cleaner = Cleaner()
    private let applicationScanner = ApplicationScanner()
    private let systemInventoryScanner = SystemInventoryScanner()
    private let fileAnalyzer = FileAnalyzer()
    private let performanceMonitor = PerformanceMonitor()
    private var scanTask: Task<Void, Never>?
    private var inventoryTask: Task<Void, Never>?
    private var performanceTask: Task<Void, Never>?
    private var hasScannedApplications = false
    private var hasAnalyzedStorage = false
    private var hasScannedLoginApplications = false
    private var hasScannedBackgroundItems = false
    private var hasScannedExtensions = false
    private var selectedCountByGroup: [String: Int] = [:]
    private var itemByID: [UUID: ScanItem] = [:]
    var selectedCount: Int { selectedIDs.count }
    var lastScanText: String {
        guard let lastScanAt else { return "尚未扫描" }
        return lastScanAt.formatted(date: .omitted, time: .shortened)
    }

    func selectHomeAndScan() {
        root = FileManager.default.homeDirectoryForCurrentUser
        scan()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = mode == .uninstall ? "选择 Applications 目录" : "选择扫描目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url
        if mode == .files {
            storageAnalysis = nil
            items = []
            status = "已选择 \(url.lastPathComponent)，点击开始分析。"
            return
        }
        items = []
        selectedIDs = []
        rebuildJunkGroups()
        status = "已选择 \(url.path)，尚未扫描。"
    }

    func scanInstalledApplications() {
        inventoryTask?.cancel()
        isScanning = true
        status = "正在扫描已安装应用…"
        inventoryTask = Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let foundApplications = await applicationScanner.applications(in: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                home.appending(path: "Applications", directoryHint: .isDirectory)
            ])
            guard !Task.isCancelled else { return }
            let foundTools = await applicationScanner.commandLineTools(home: home)
            guard !Task.isCancelled, mode == .uninstall else { return }
            applications = foundApplications
            commandLineTools = foundTools
            rebuildApplicationGroups()
            items = []
            selectedIDs = []
            lastScanAt = Date()
            hasScannedApplications = true
            isScanning = false
            status = "找到 \(applications.count) 个应用。"
        }
    }

    func scan() {
        guard let root else { return }
        if mode == .files {
            scanStorageAnalysis()
            return
        }
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        currentScanCategory = "准备扫描"
        inspectedFileCount = 0
        discoveredFileCount = 0
        discoveredBytes = 0
        status = "正在扫描…"
        scanTask = Task {
            switch mode {
            case .home:
                let found = await scanJunk(root: root)
                guard !Task.isCancelled, mode == .home else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                status = "扫描完成，发现 \(found.count) 个候选文件。"
            case .junk:
                let found = await scanJunk(root: root)
                guard !Task.isCancelled, mode == .junk else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                status = "找到 \(found.count) 个候选文件。标记为“需确认”的项目不会默认选中。"
            case .uninstall:
                let found = await applicationScanner.applications(in: root)
                guard !Task.isCancelled, mode == .uninstall else { return }
                applications = found
                items = []
                selectedIDs = []
                rebuildJunkGroups()
                status = "找到 \(applications.count) 个应用。当前版本仅盘点，不会直接卸载。"
            case .files:
                break
            case .performance, .loginItems, .backgroundActivity, .extensions:
                break
            }
            lastScanAt = Date()
            currentScanCategory = Task.isCancelled ? "扫描已取消" : "扫描完成"
            if !Task.isCancelled { scanProgress = 1 }
            isScanning = false
        }
    }

    func scanStorageAnalysis() {
        scanTask?.cancel()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let selectedRoot = (root ?? home).standardizedFileURL
        root = selectedRoot
        let roots: [URL]
        if selectedRoot == home {
            roots = [
                home,
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                URL(fileURLWithPath: "/Library", isDirectory: true)
            ]
        } else {
            roots = [selectedRoot]
        }

        isScanning = true
        scanProgress = 0
        inspectedFileCount = 0
        discoveredBytes = 0
        currentScanCategory = selectedRoot == home ? "用户目录与系统应用" : selectedRoot.lastPathComponent
        status = "正在统计文件占用…"
        scanTask = Task {
            let analysis = await fileAnalyzer.storageAnalysis(
                roots: roots,
                volumeURL: URL(fileURLWithPath: "/", isDirectory: true)
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.mode == .files, self.isScanning else { return }
                    self.currentScanCategory = progress.currentRoot.lastPathComponent.isEmpty
                        ? progress.currentRoot.path
                        : progress.currentRoot.lastPathComponent
                    self.inspectedFileCount = progress.inspectedFiles
                    self.discoveredBytes = progress.scannedBytes
                }
            }
            guard !Task.isCancelled, mode == .files else { return }
            storageAnalysis = analysis
            items = analysis.largeFiles
            selectedIDs = []
            lastScanAt = Date()
            hasAnalyzedStorage = true
            isScanning = false
            currentScanCategory = "分析完成"
            status = "已分析 \(analysis.scannedFileCount) 个文件，共归类 \(ByteCountFormatter.string(fromByteCount: analysis.scannedBytes, countStyle: .file))。"
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentScanCategory = "扫描已取消"
        status = "扫描已取消。"
    }

    func startPerformanceMonitoring() {
        performanceTask?.cancel()
        isPerformanceMonitoring = true
        status = "正在监控 CPU 与内存…"
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
                status = "CPU \(Int(snapshot.cpuPercent.rounded()))% · 内存压力\(snapshot.memoryPressureLevel.rawValue)"
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPerformanceMonitoring() {
        performanceTask?.cancel()
        performanceTask = nil
        isPerformanceMonitoring = false
        status = "性能监控已暂停。"
    }

    private func scanJunk(root: URL) async -> [ScanItem] {
        await scanner.scan(root: root, rules: DefaultRules.conservative) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scanProgress = progress.fractionCompleted
                self.currentScanCategory = progress.currentRuleTitle
                self.inspectedFileCount = progress.inspectedFiles
                self.discoveredFileCount = progress.matchedFiles
                self.discoveredBytes = progress.matchedBytes
            }
        }
    }

    func changeMode(_ newMode: FeatureMode) {
        scanTask?.cancel()
        scanTask = nil
        inventoryTask?.cancel()
        performanceTask?.cancel()
        performanceTask = nil
        isPerformanceMonitoring = false
        isScanning = false
        mode = newMode
        root = nil
        items = []
        selectedIDs = []
        rebuildJunkGroups()
        switch newMode {
        case .home: status = "检查存储空间，快速进入常用工具。"
        case .junk: status = "请选择你的用户目录，用于扫描缓存与日志。"
        case .uninstall:
            if hasScannedApplications {
                status = "已缓存 \(applications.count) 个应用；点击刷新可重新扫描。"
            } else {
                status = "正在读取已安装应用…"
                scanInstalledApplications()
            }
        case .files:
            root = FileManager.default.homeDirectoryForCurrentUser
            if hasAnalyzedStorage, let storageAnalysis {
                status = "已缓存 \(storageAnalysis.scannedFileCount) 个文件的分析结果；点击刷新可重新分析。"
            } else {
                status = "点击开始分析系统存储，或选择一个目录单独分析。"
            }
        case .performance:
            status = "正在监控 CPU 与内存…"
            startPerformanceMonitoring()
        case .loginItems:
            if hasScannedLoginApplications {
                status = "已缓存 \(loginApplications.count) 个登录项；点击刷新可重新扫描。"
            } else {
                status = "正在读取登录项…"
                scanLoginItems()
            }
        case .backgroundActivity:
            if hasScannedBackgroundItems {
                status = "已缓存 \(registeredBackgroundTasks.count) 个 App 后台记录和 \(backgroundItems.count) 个后台配置；点击刷新可重新扫描。"
            } else {
                status = "正在读取后台活动…"
                scanBackgroundActivity()
            }
        case .extensions:
            if hasScannedExtensions {
                status = "已缓存 \(installedExtensions.count) 个扩展；点击刷新可重新扫描。"
            } else {
                status = "正在读取应用扩展…"
                scanExtensions()
            }
        }
    }

    func scanLoginItems() {
        inventoryTask?.cancel()
        isScanning = true
        status = "正在读取登录项…"
        inventoryTask = Task {
            let result = await systemInventoryScanner.loginApplications()
            guard !Task.isCancelled, mode == .loginItems else { return }
            loginApplications = result.items
            loginApplicationsError = result.errorMessage
            lastScanAt = Date()
            hasScannedLoginApplications = true
            isScanning = false
            status = result.errorMessage ?? "找到 \(result.items.count) 个登录项。"
        }
    }

    func scanBackgroundActivity() {
        inventoryTask?.cancel()
        isScanning = true
        backgroundDatabaseNotice = nil
        status = "正在读取后台活动…"
        inventoryTask = Task {
            let found = await systemInventoryScanner.loginItems(
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            guard !Task.isCancelled else { return }
            let registered = await systemInventoryScanner.registeredBackgroundTasks()
            guard !Task.isCancelled, mode == .backgroundActivity else { return }
            backgroundItems = found
            registeredBackgroundTasks = registered.items
            backgroundTaskScanError = registered.errorMessage
            lastScanAt = Date()
            hasScannedBackgroundItems = true
            isScanning = false
            status = registered.errorMessage
                ?? "找到 \(registered.items.count) 个 App 后台记录和 \(found.count) 个后台配置。"
        }
    }

    func resetBackgroundTaskDatabaseConfirmed() {
        showBackgroundDatabaseResetConfirmation = false
        inventoryTask?.cancel()
        isScanning = true
        status = "正在重建后台任务数据库…"
        inventoryTask = Task {
            let error = await systemInventoryScanner.resetBackgroundTaskDatabase()
            guard !Task.isCancelled, mode == .backgroundActivity else { return }
            isScanning = false
            if let error {
                removalFailureMessage = error
                status = error
                showRemovalFailure = true
            } else {
                registeredBackgroundTasks = []
                backgroundTaskScanError = nil
                backgroundDatabaseNotice = "后台任务数据库已重建。请重启 Mac，让系统重新登记仍然有效的项目。"
                lastScanAt = Date()
                hasScannedBackgroundItems = false
                status = "后台任务数据库已重建，请重启 Mac。"
            }
        }
    }

    func scanExtensions() {
        inventoryTask?.cancel()
        isScanning = true
        status = "正在读取应用扩展…"
        inventoryTask = Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let apps = await applicationScanner.applications(in: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                home.appending(path: "Applications", directoryHint: .isDirectory)
            ])
            guard !Task.isCancelled else { return }
            let found = await systemInventoryScanner.extensions(in: apps, home: home)
            guard !Task.isCancelled, mode == .extensions else { return }
            installedExtensions = found
            lastScanAt = Date()
            hasScannedExtensions = true
            isScanning = false
            status = "找到 \(found.count) 个扩展。"
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
        status = "正在移除登录项 \(item.name)…"
        Task {
            if let error = await systemInventoryScanner.removeLoginApplication(item) {
                removalFailureMessage = error
                status = error
                showRemovalFailure = true
            } else {
                loginApplications.removeAll { $0.id == item.id }
                status = "已从登录项中移除 \(item.name)。"
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
        status = "正在移除 \(item.name) 的废纸篓残留…"
        Task {
            if let error = await systemInventoryScanner.removeRegisteredBackgroundTaskResidue(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            ) {
                removalFailureMessage = error
                status = error
                showRemovalFailure = true
            } else {
                registeredBackgroundTasks.removeAll { $0.id == item.id }
                status = "已永久删除 \(item.name) 的废纸篓残留；macOS 后台记录可能在重新登录后消失。"
            }
        }
    }

    func removeBackgroundItemConfirmed() {
        guard let item = backgroundItemRemovalCandidate else { return }
        showBackgroundItemRemovalConfirmation = false
        backgroundItemRemovalCandidate = nil
        status = "正在将 \(item.label) 移入废纸篓…"
        Task {
            let result = await systemInventoryScanner.moveLoginItemToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            if result.movedToTrash.isEmpty {
                removalFailureMessage = "无法移除 \(item.label)：\(result.failures.first?.reason ?? "未知错误")"
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                backgroundItems.removeAll { $0.id == item.id }
                status = "已将 \(item.label) 的启动配置移入废纸篓；当前进程可能会继续运行到退出或重启。"
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
        status = "正在将 \(item.name) 移入废纸篓…"
        Task {
            let result = await systemInventoryScanner.moveExtensionToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            if result.movedToTrash.isEmpty {
                removalFailureMessage = "无法移除 \(item.name)：\(result.failures.first?.reason ?? "未知错误")"
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                installedExtensions.removeAll { $0.id == item.id }
                status = "已将 \(item.name) 移入废纸篓。重新登录后相关功能将不再加载。"
            }
        }
    }

    func prepareUninstall(_ app: InstalledApplication) {
        isPreparingUninstall = true
        status = "正在查找 \(app.name) 的关联文件…"
        Task {
            let found = await applicationScanner.residues(
                for: app,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            uninstallResidues = found
            selectedResidueIDs = Set(found.filter { $0.risk == .safe }.map(\.id))
            uninstallCandidate = app
            isPreparingUninstall = false
            status = "请确认要移入废纸篓的内容。"
        }
    }

    func uninstallConfirmed() {
        guard let app = uninstallCandidate else { return }
        let selectedResidues = uninstallResidues.filter { selectedResidueIDs.contains($0.id) }
        uninstallCandidate = nil
        showAppRemovalConfirmation = false
        isScanning = true
        status = "正在卸载 \(app.name)…"
        Task {
            let result = await applicationScanner.moveToTrash(
                app: app,
                residues: selectedResidues,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            isScanning = false
            uninstallResidues = []
            selectedResidueIDs = []
            status = "已移入废纸篓 \(result.movedToTrash.count) 项；失败 \(result.failures.count) 项。"
            scanInstalledApplications()
        }
    }

    func isSystemApplication(_ app: InstalledApplication) -> Bool {
        app.bundleURL.path.hasPrefix("/System/")
    }

    func requestClean() {
        guard !selectedIDs.isEmpty else { return }
        showCleanConfirmation = true
    }

    func cleanConfirmed() {
        guard let root else { return }
        let selected = items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        Task {
            let result = await cleaner.moveToTrash(items: selected, selectedRoot: root)
            let moved = Set(result.movedToTrash)
            items.removeAll { moved.contains($0.url) }
            selectedIDs.subtract(selected.map(\.id))
            rebuildJunkGroups()
            status = "已移入废纸篓 \(result.movedToTrash.count) 项；失败 \(result.failures.count) 项。可从废纸篓恢复。"
        }
    }

    func isGroupSelected(_ group: JunkScanGroup) -> Bool {
        !group.items.isEmpty && selectedCountByGroup[group.id] == group.items.count
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
        let ruleOrder = Dictionary(uniqueKeysWithValues: DefaultRules.conservative.enumerated().map { ($0.element.id, $0.offset) })
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
