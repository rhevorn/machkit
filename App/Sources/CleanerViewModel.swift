import AppKit
import Darwin
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

struct SystemStorageSnapshot: Sendable {
    let totalCapacity: Int64
    let availableCapacity: Int64

    static let empty = SystemStorageSnapshot(totalCapacity: 0, availableCapacity: 0)

    var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }
    var usedFraction: Double {
        guard totalCapacity > 0 else { return 0 }
        return min(1, max(0, Double(usedCapacity) / Double(totalCapacity)))
    }
}

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var mode: FeatureMode = .home
    @Published var root: URL?
    @Published var items: [ScanItem] = []
    @Published private(set) var storageAnalysis: StorageAnalysis?
    @Published private(set) var performanceSnapshot: PerformanceSnapshot?
    @Published private(set) var performanceHistory: [PerformanceHistoryPoint] = []
    @Published private(set) var systemStorage = SystemStorageSnapshot.empty
    @Published private(set) var cleanableBytes: Int64?
    @Published private(set) var hasLoadedPortSnapshot = false
    @Published private(set) var isPerformanceMonitoring = false
    @Published private(set) var isOptimizingMemory = false
    @Published private(set) var listeningPorts: [ListeningPort] = []
    @Published private(set) var portScanError: String?
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
    @Published var status = L10n.string("请选择你的用户目录或一个测试目录。")

    private let scanner = SiftCore.Scanner()
    private let cleaner = Cleaner()
    private let applicationScanner = ApplicationScanner()
    private let systemInventoryScanner = SystemInventoryScanner()
    private let fileAnalyzer = FileAnalyzer()
    private let performanceMonitor = PerformanceMonitor()
    private let portScanner = PortScanner()
    private var scanTask: Task<Void, Never>?
    private var inventoryTask: Task<Void, Never>?
    private var performanceTask: Task<Void, Never>?
    private var portMonitoringTask: Task<Void, Never>?
    private var homeMonitoringTask: Task<Void, Never>?
    private var hasScannedApplications = false
    private var hasAnalyzedStorage = false
    private var hasScannedLoginApplications = false
    private var hasScannedBackgroundItems = false
    private var hasScannedExtensions = false
    private var selectedCountByGroup: [String: Int] = [:]
    private var itemByID: [UUID: ScanItem] = [:]
    var selectedCount: Int { selectedIDs.count }
    var lastScanText: String {
        guard let lastScanAt else { return L10n.string("尚未扫描") }
        return lastScanAt.formatted(date: .omitted, time: .shortened)
    }

    init() {
        refreshSystemStorage()
        refreshPerformanceSnapshot()
        startHomeMonitoring()
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
        panel.prompt = L10n.string(mode == .uninstall ? "选择 Applications 目录" : "选择扫描目录")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        root = url
        if mode == .files {
            storageAnalysis = nil
            items = []
            status = L10n.format("已选择 %@，点击开始分析。", url.lastPathComponent)
            return
        }
        items = []
        selectedIDs = []
        rebuildJunkGroups()
        status = L10n.format("已选择 %@，尚未扫描。", url.path)
    }

    func scanInstalledApplications() {
        inventoryTask?.cancel()
        isScanning = true
        status = L10n.string("正在扫描已安装应用…")
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
            status = L10n.format("找到 %lld 个应用。", Int64(applications.count))
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
        currentScanCategory = L10n.string("准备扫描")
        inspectedFileCount = 0
        discoveredFileCount = 0
        discoveredBytes = 0
        status = L10n.string("正在扫描…")
        scanTask = Task {
            switch mode {
            case .home:
                let found = await scanJunk(root: root)
                guard !Task.isCancelled, mode == .home else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                cleanableBytes = selectedBytes
                status = L10n.format("扫描完成，发现 %lld 个候选文件。", Int64(found.count))
            case .junk:
                let found = await scanJunk(root: root)
                guard !Task.isCancelled, mode == .junk else { return }
                items = found
                selectedIDs = Set(found.filter { $0.rule.risk == .safe }.map(\.id))
                rebuildJunkGroups()
                cleanableBytes = selectedBytes
                status = L10n.format("找到 %lld 个候选文件。标记为“需确认”的项目不会默认选中。", Int64(found.count))
            case .uninstall:
                let found = await applicationScanner.applications(in: root)
                guard !Task.isCancelled, mode == .uninstall else { return }
                applications = found
                items = []
                selectedIDs = []
                rebuildJunkGroups()
                status = L10n.format("找到 %lld 个应用。当前版本仅盘点，不会直接卸载。", Int64(applications.count))
            case .files:
                break
            case .performance, .ports, .loginItems, .backgroundActivity, .extensions, .settings:
                break
            }
            lastScanAt = Date()
            currentScanCategory = L10n.string(Task.isCancelled ? "扫描已取消" : "扫描完成")
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
        currentScanCategory = selectedRoot == home ? L10n.string("用户目录与系统应用") : selectedRoot.lastPathComponent
        status = L10n.string("正在统计文件占用…")
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
            currentScanCategory = L10n.string("分析完成")
            status = L10n.format(
                "已分析 %lld 个文件，共归类 %@。",
                Int64(analysis.scannedFileCount),
                ByteCountFormatter.string(fromByteCount: analysis.scannedBytes, countStyle: .file)
            )
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentScanCategory = L10n.string("扫描已取消")
        status = L10n.string("扫描已取消。")
    }

    func startPerformanceMonitoring() {
        performanceTask?.cancel()
        isPerformanceMonitoring = true
        status = L10n.string("正在监控 CPU 与内存…")
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
                    "CPU %lld%% · 内存压力%@",
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
        status = L10n.string("性能监控已暂停。")
    }

    func optimizeMemory() {
        guard !isOptimizingMemory else { return }
        isOptimizingMemory = true
        status = L10n.string("正在让 macOS 释放闲置内存…")
        Task { [weak self] in
            guard let self else { return }
            NSRunningApplication.terminateAutomaticallyTerminableApplications()
            _ = await Task.detached(priority: .userInitiated) {
                malloc_zone_pressure_relief(nil, 0)
            }.value
            try? await Task.sleep(for: .milliseconds(800))
            refreshPerformanceSnapshot()
            isOptimizingMemory = false
            status = L10n.string("智能释放完成；已处理闲置后台 App，并归还 Sift 自身可回收内存。")
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

                    if refreshCount.isMultiple(of: 4), !self.isScanning {
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
        inventoryTask?.cancel()
        isScanning = true
        portScanError = nil
        status = L10n.string("正在读取监听端口与进程信息…")
        inventoryTask = Task {
            let result = await portScanner.scan()
            guard !Task.isCancelled, mode == .ports else { return }
            listeningPorts = result.ports
            hasLoadedPortSnapshot = true
            portScanError = result.errorMessage
            lastScanAt = Date()
            isScanning = false
            status = result.errorMessage ?? L10n.format("找到 %lld 个监听端口。", Int64(result.ports.count))
        }
    }

    private func startPortMonitoring() {
        portMonitoringTask?.cancel()
        scanPorts()
        portMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
                guard let self, self.mode == .ports else { return }
                if NSApp.isActive, !self.isScanning, !self.showPortTerminationConfirmation {
                    self.scanPorts()
                }
            }
        }
    }

    func requestPortTermination(_ port: ListeningPort) {
        guard port.canTerminate else {
            removalFailureMessage = port.protectionReason ?? L10n.string("这个进程不能在 Sift 中结束。")
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
            ? L10n.format("正在强制结束 %@…", port.processName)
            : L10n.format("正在请求 %@ 正常退出…", port.processName)
        Task {
            if let error = await portScanner.terminate(port, force: force) {
                removalFailureMessage = L10n.format("无法结束 %@：%@", port.processName, error)
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                listeningPorts.removeAll { $0.processIdentifier == port.processIdentifier }
                status = force
                    ? L10n.format("已强制结束 %@。", port.processName)
                    : L10n.format("已向 %@ 发送退出请求。", port.processName)
                try? await Task.sleep(for: .milliseconds(500))
                if mode == .ports { scanPorts() }
            }
        }
    }

    private func scanJunk(root: URL) async -> [ScanItem] {
        await scanner.scan(root: root, rules: DefaultRules.conservative) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scanProgress = progress.fractionCompleted
                self.currentScanCategory = progress.currentRuleTitle.localized
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
        portMonitoringTask?.cancel()
        portMonitoringTask = nil
        homeMonitoringTask?.cancel()
        homeMonitoringTask = nil
        isPerformanceMonitoring = false
        isScanning = false
        mode = newMode
        root = nil
        items = []
        selectedIDs = []
        rebuildJunkGroups()
        switch newMode {
        case .home:
            status = L10n.string("检查存储空间，快速进入常用工具。")
            startHomeMonitoring()
        case .junk: status = L10n.string("请选择你的用户目录，用于扫描缓存与日志。")
        case .uninstall:
            if hasScannedApplications {
                status = L10n.format("已缓存 %lld 个应用；点击刷新可重新扫描。", Int64(applications.count))
            } else {
                status = L10n.string("正在读取已安装应用…")
                scanInstalledApplications()
            }
        case .files:
            root = FileManager.default.homeDirectoryForCurrentUser
            if hasAnalyzedStorage, let storageAnalysis {
                status = L10n.format("已缓存 %lld 个文件的分析结果；点击刷新可重新分析。", Int64(storageAnalysis.scannedFileCount))
            } else {
                status = L10n.string("点击开始分析系统存储，或选择一个目录单独分析。")
            }
        case .performance:
            status = L10n.string("正在监控 CPU 与内存…")
            startPerformanceMonitoring()
        case .ports:
            startPortMonitoring()
        case .loginItems:
            if hasScannedLoginApplications {
                status = L10n.format("已缓存 %lld 个登录项；点击刷新可重新扫描。", Int64(loginApplications.count))
            } else {
                status = L10n.string("正在读取登录项…")
                scanLoginItems()
            }
        case .backgroundActivity:
            if hasScannedBackgroundItems {
                status = L10n.format(
                    "已缓存 %lld 个 App 后台记录和 %lld 个后台配置；点击刷新可重新扫描。",
                    Int64(registeredBackgroundTasks.count),
                    Int64(backgroundItems.count)
                )
            } else {
                status = L10n.string("正在读取后台活动…")
                scanBackgroundActivity()
            }
        case .extensions:
            if hasScannedExtensions {
                status = L10n.format("已缓存 %lld 个扩展；点击刷新可重新扫描。", Int64(installedExtensions.count))
            } else {
                status = L10n.string("正在读取应用扩展…")
                scanExtensions()
            }
        case .settings:
            status = L10n.string("管理语言、外观与其他偏好设置。")
        }
    }

    func refreshLocalizedStatus() {
        if isScanning {
            switch mode {
            case .home, .junk:
                status = L10n.string("正在扫描…")
            case .uninstall:
                status = L10n.string("正在扫描已安装应用…")
            case .files:
                status = L10n.string("正在统计文件占用…")
            case .performance:
                status = L10n.string("正在监控 CPU 与内存…")
            case .ports:
                status = L10n.string("正在读取监听端口与进程信息…")
            case .loginItems:
                status = L10n.string("正在读取登录项…")
            case .backgroundActivity:
                status = L10n.string("正在读取后台活动…")
            case .extensions:
                status = L10n.string("正在读取应用扩展…")
            case .settings:
                status = L10n.string("管理语言、外观与其他偏好设置。")
            }
            return
        }

        switch mode {
        case .home:
            status = items.isEmpty
                ? L10n.string("检查存储空间，快速进入常用工具。")
                : L10n.format("扫描完成，发现 %lld 个候选文件。", Int64(items.count))
        case .junk:
            status = items.isEmpty
                ? L10n.string("请选择你的用户目录，用于扫描缓存与日志。")
                : L10n.format("找到 %lld 个候选文件。标记为“需确认”的项目不会默认选中。", Int64(items.count))
        case .uninstall:
            status = hasScannedApplications
                ? L10n.format("已缓存 %lld 个应用；点击刷新可重新扫描。", Int64(applications.count))
                : L10n.string("正在读取已安装应用…")
        case .files:
            if hasAnalyzedStorage, let storageAnalysis {
                status = L10n.format(
                    "已缓存 %lld 个文件的分析结果；点击刷新可重新分析。",
                    Int64(storageAnalysis.scannedFileCount)
                )
            } else {
                status = L10n.string("点击开始分析系统存储，或选择一个目录单独分析。")
            }
        case .performance:
            status = isPerformanceMonitoring
                ? L10n.string("正在监控 CPU 与内存…")
                : L10n.string("性能监控已暂停。")
        case .ports:
            status = L10n.format("找到 %lld 个监听端口。", Int64(listeningPorts.count))
        case .loginItems:
            status = L10n.format("已缓存 %lld 个登录项；点击刷新可重新扫描。", Int64(loginApplications.count))
        case .backgroundActivity:
            status = L10n.format(
                "已缓存 %lld 个 App 后台记录和 %lld 个后台配置；点击刷新可重新扫描。",
                Int64(registeredBackgroundTasks.count),
                Int64(backgroundItems.count)
            )
        case .extensions:
            status = L10n.format("已缓存 %lld 个扩展；点击刷新可重新扫描。", Int64(installedExtensions.count))
        case .settings:
            status = L10n.string("管理语言、外观与其他偏好设置。")
        }
    }

    func scanLoginItems() {
        inventoryTask?.cancel()
        isScanning = true
        status = L10n.string("正在读取登录项…")
        inventoryTask = Task {
            let result = await systemInventoryScanner.loginApplications()
            guard !Task.isCancelled, mode == .loginItems else { return }
            loginApplications = result.items
            loginApplicationsError = result.errorMessage
            lastScanAt = Date()
            hasScannedLoginApplications = true
            isScanning = false
            status = result.errorMessage ?? L10n.format("找到 %lld 个登录项。", Int64(result.items.count))
        }
    }

    func scanBackgroundActivity() {
        inventoryTask?.cancel()
        isScanning = true
        backgroundDatabaseNotice = nil
        status = L10n.string("正在读取后台活动…")
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
                ?? L10n.format(
                    "找到 %lld 个 App 后台记录和 %lld 个后台配置。",
                    Int64(registered.items.count),
                    Int64(found.count)
                )
        }
    }

    func resetBackgroundTaskDatabaseConfirmed() {
        showBackgroundDatabaseResetConfirmation = false
        inventoryTask?.cancel()
        isScanning = true
        status = L10n.string("正在重建后台任务数据库…")
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
                backgroundDatabaseNotice = L10n.string("后台任务数据库已重建。请重启 Mac，让系统重新登记仍然有效的项目。")
                lastScanAt = Date()
                hasScannedBackgroundItems = false
                status = L10n.string("后台任务数据库已重建，请重启 Mac。")
            }
        }
    }

    func scanExtensions() {
        inventoryTask?.cancel()
        isScanning = true
        status = L10n.string("正在读取应用扩展…")
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
            status = L10n.format("找到 %lld 个扩展。", Int64(found.count))
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
        status = L10n.format("正在移除登录项 %@…", item.name)
        Task {
            if let error = await systemInventoryScanner.removeLoginApplication(item) {
                removalFailureMessage = error
                status = error
                showRemovalFailure = true
            } else {
                loginApplications.removeAll { $0.id == item.id }
                status = L10n.format("已从登录项中移除 %@。", item.name)
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
        status = L10n.format("正在移除 %@ 的废纸篓残留…", item.name)
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
                status = L10n.format("已永久删除 %@ 的废纸篓残留；macOS 后台记录可能在重新登录后消失。", item.name)
            }
        }
    }

    func removeBackgroundItemConfirmed() {
        guard let item = backgroundItemRemovalCandidate else { return }
        showBackgroundItemRemovalConfirmation = false
        backgroundItemRemovalCandidate = nil
        status = L10n.format("正在将 %@ 移入废纸篓…", item.label)
        Task {
            let result = await systemInventoryScanner.moveLoginItemToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            if result.movedToTrash.isEmpty {
                removalFailureMessage = L10n.format(
                    "无法移除 %@：%@",
                    item.label,
                    result.failures.first?.reason ?? L10n.string("未知错误")
                )
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                backgroundItems.removeAll { $0.id == item.id }
                status = L10n.format("已将 %@ 的启动配置移入废纸篓；当前进程可能会继续运行到退出或重启。", item.label)
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
        status = L10n.format("正在将 %@ 移入废纸篓…", item.name)
        Task {
            let result = await systemInventoryScanner.moveExtensionToTrash(
                item,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            if result.movedToTrash.isEmpty {
                removalFailureMessage = L10n.format(
                    "无法移除 %@：%@",
                    item.name,
                    result.failures.first?.reason ?? L10n.string("未知错误")
                )
                status = removalFailureMessage
                showRemovalFailure = true
            } else {
                installedExtensions.removeAll { $0.id == item.id }
                status = L10n.format("已将 %@ 移入废纸篓。重新登录后相关功能将不再加载。", item.name)
            }
        }
    }

    func prepareUninstall(_ app: InstalledApplication) {
        isPreparingUninstall = true
        status = L10n.format("正在查找 %@ 的关联文件…", app.name)
        Task {
            let found = await applicationScanner.residues(
                for: app,
                home: FileManager.default.homeDirectoryForCurrentUser
            )
            uninstallResidues = found
            selectedResidueIDs = Set(found.filter { $0.risk == .safe }.map(\.id))
            uninstallCandidate = app
            isPreparingUninstall = false
            status = L10n.string("请确认要移入废纸篓的内容。")
        }
    }

    func uninstallConfirmed() {
        guard let app = uninstallCandidate else { return }
        let selectedResidues = uninstallResidues.filter { selectedResidueIDs.contains($0.id) }
        uninstallCandidate = nil
        showAppRemovalConfirmation = false
        isScanning = true
        status = L10n.format("正在卸载 %@…", app.name)
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
                "已移入废纸篓 %lld 项；失败 %lld 项。",
                Int64(result.movedToTrash.count),
                Int64(result.failures.count)
            )
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
            cleanableBytes = selectedBytes
            status = L10n.format(
                "已移入废纸篓 %lld 项；失败 %lld 项。可从废纸篓恢复。",
                Int64(result.movedToTrash.count),
                Int64(result.failures.count)
            )
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
