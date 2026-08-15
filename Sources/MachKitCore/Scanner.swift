import Foundation

public struct ScanProgress: Sendable {
    public let completedRules: Int
    public let totalRules: Int
    public let currentRuleTitle: String
    public let completedRuleTitles: [String]
    public let inspectedFiles: Int
    public let currentRuleInspectedFiles: Int
    public let matchedFiles: Int
    public let matchedBytes: Int64

    public var fractionCompleted: Double {
        guard totalRules > 0 else { return 0 }
        let activity: Double
        if currentRuleInspectedFiles > 0 {
            activity = min(0.9, 0.12 + log10(Double(currentRuleInspectedFiles) + 1) * 0.13)
        } else {
            activity = 0
        }
        return min((Double(completedRules) + activity) / Double(totalRules), 1)
    }
}

private struct RuleScanStats: Sendable {
    var inspectedFiles = 0
    var matchedFiles = 0
    var matchedBytes: Int64 = 0
}

private struct RuleScanResult: Sendable {
    let ruleIndex: Int
    let items: [ScanItem]
}

private struct SendableFileManager: @unchecked Sendable {
    let value: FileManager
}

private actor RuleProgressTracker {
    private let totalRules: Int
    private let callback: (@Sendable (ScanProgress) -> Void)?
    private var statsByRuleID: [String: RuleScanStats] = [:]
    private var completedRuleIDs = Set<String>()
    private var completedRuleTitles: [String] = []
    private var lastUpdate = Date.distantPast

    init(totalRules: Int, callback: (@Sendable (ScanProgress) -> Void)?) {
        self.totalRules = totalRules
        self.callback = callback
    }

    func started(rule: ScanRule) {
        statsByRuleID[rule.id] = RuleScanStats()
        emit(rule: rule, force: completedRuleIDs.isEmpty && statsByRuleID.count == 1)
    }

    func updated(rule: ScanRule, stats: RuleScanStats) {
        statsByRuleID[rule.id] = stats
        emit(rule: rule, force: false)
    }

    func completed(rule: ScanRule, stats: RuleScanStats) {
        statsByRuleID[rule.id] = stats
        if completedRuleIDs.insert(rule.id).inserted {
            completedRuleTitles.append(rule.title)
        }
        emit(rule: rule, force: true)
    }

    private func emit(rule: ScanRule, force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastUpdate) >= 0.15 else { return }
        lastUpdate = now
        let aggregate = statsByRuleID.values.reduce(into: RuleScanStats()) { total, ruleStats in
            total.inspectedFiles += ruleStats.inspectedFiles
            total.matchedFiles += ruleStats.matchedFiles
            total.matchedBytes += ruleStats.matchedBytes
        }
        callback?(ScanProgress(
            completedRules: completedRuleIDs.count,
            totalRules: totalRules,
            currentRuleTitle: rule.title,
            completedRuleTitles: completedRuleTitles,
            inspectedFiles: aggregate.inspectedFiles,
            currentRuleInspectedFiles: statsByRuleID[rule.id]?.inspectedFiles ?? 0,
            matchedFiles: aggregate.matchedFiles,
            matchedBytes: aggregate.matchedBytes
        ))
    }
}

public actor Scanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(
        root: URL,
        rules: [ScanRule],
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [ScanItem] {
        let activeRules = rules.filter { $0.risk != .blocked }
        guard !activeRules.isEmpty else { return [] }

        let tracker = RuleProgressTracker(totalRules: activeRules.count, callback: onProgress)
        let fileManager = SendableFileManager(value: self.fileManager)
        var results: [ScanItem] = []

        for (index, rule) in activeRules.enumerated() {
            guard !Task.isCancelled else { break }
            let scanned = await Self.scanRule(
                rule,
                ruleIndex: index,
                root: root,
                fileManager: fileManager,
                tracker: tracker
            )
            results.append(contentsOf: scanned.items)
        }

        return results.sorted { $0.bytes > $1.bytes }
    }

    private nonisolated static func scanRule(
        _ rule: ScanRule,
        ruleIndex: Int,
        root: URL,
        fileManager: SendableFileManager,
        tracker: RuleProgressTracker
    ) async -> RuleScanResult {
        await tracker.started(rule: rule)
        let result: RuleScanResult
        switch rule.enumerationMode {
        case .agedFiles:
            result = await scanAgedFiles(
                rule,
                ruleIndex: ruleIndex,
                root: root,
                fileManager: fileManager,
                tracker: tracker
            )
        case .topLevelEntries:
            result = await scanTopLevelEntries(
                rule,
                ruleIndex: ruleIndex,
                root: root,
                fileManager: fileManager,
                tracker: tracker
            )
        case .unavailableSimulatorDevices:
            result = await scanUnavailableSimulatorDevices(
                rule,
                ruleIndex: ruleIndex,
                root: root,
                fileManager: fileManager,
                tracker: tracker
            )
        }
        return result
    }

    private nonisolated static func scanAgedFiles(
        _ rule: ScanRule,
        ruleIndex: Int,
        root: URL,
        fileManager: SendableFileManager,
        tracker: RuleProgressTracker
    ) async -> RuleScanResult {
        var stats = RuleScanStats()
        var results: [ScanItem] = []
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        let targets = (try? SafetyPolicy.validateTargets(rule: rule, root: root)) ?? []
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -rule.minimumAgeDays, to: Date()) ?? .distantPast

        for target in targets {
            guard !Task.isCancelled else { break }
            guard let enumerator = fileManager.value.enumerator(
                at: target,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            let excludedPaths = rule.excludedRelativePaths.map {
                target.appending(path: $0, directoryHint: .isDirectory).standardizedFileURL.path
            }

            while let fileURL = enumerator.nextObject() as? URL {
                guard !Task.isCancelled else { break }
                let standardizedPath = fileURL.standardizedFileURL.path
                if let excludedRoot = excludedPaths.first(where: {
                    standardizedPath == $0 || standardizedPath.hasPrefix($0 + "/")
                }) {
                    if standardizedPath == excludedRoot { enumerator.skipDescendants() }
                    continue
                }

                stats.inspectedFiles += 1
                if stats.inspectedFiles.isMultiple(of: 512) {
                    await tracker.updated(rule: rule, stats: stats)
                    await Task.yield()
                }
                guard let values = try? fileURL.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      let modified = values.contentModificationDate,
                      modified < cutoff else { continue }

                let ext = fileURL.pathExtension.lowercased()
                guard rule.allowedExtensions.isEmpty || rule.allowedExtensions.contains(ext) else { continue }
                let item = ScanItem(
                    url: fileURL,
                    bytes: Int64(values.fileSize ?? 0),
                    modifiedAt: modified,
                    rule: rule
                )
                results.append(item)
                stats.matchedFiles += 1
                stats.matchedBytes += item.bytes
            }
        }

        await tracker.completed(rule: rule, stats: stats)
        return RuleScanResult(ruleIndex: ruleIndex, items: results)
    }

    private nonisolated static func scanTopLevelEntries(
        _ rule: ScanRule,
        ruleIndex: Int,
        root: URL,
        fileManager: SendableFileManager,
        tracker: RuleProgressTracker
    ) async -> RuleScanResult {
        var stats = RuleScanStats()
        var results: [ScanItem] = []
        let targets = (try? SafetyPolicy.validateTargets(rule: rule, root: root)) ?? []
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -rule.minimumAgeDays, to: Date()) ?? .distantPast
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        for target in targets {
            guard !Task.isCancelled else { break }
            guard fileManager.value.fileExists(atPath: target.path) else { continue }
            guard let children = try? fileManager.value.contentsOfDirectory(
                at: target,
                includingPropertiesForKeys: Array(keys),
                options: []
            ) else { continue }

            for child in children.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                guard !Task.isCancelled else { break }
                if child.lastPathComponent == ".DS_Store" { continue }
                stats.inspectedFiles += 1
                await tracker.updated(rule: rule, stats: stats)

                guard let values = try? child.resourceValues(forKeys: keys),
                      values.isSymbolicLink != true else { continue }
                if rule.minimumAgeDays > 0 {
                    let modified = values.contentModificationDate ?? .distantPast
                    guard modified < cutoff else { continue }
                }

                let bytes = await allocatedBytes(at: child)
                guard bytes > 0 || values.isDirectory == true || values.isRegularFile == true else { continue }
                let item = ScanItem(url: child, bytes: bytes, modifiedAt: values.contentModificationDate, rule: rule)
                results.append(item)
                stats.matchedFiles += 1
                stats.matchedBytes += item.bytes
            }
        }

        await tracker.completed(rule: rule, stats: stats)
        return RuleScanResult(ruleIndex: ruleIndex, items: results)
    }

    private nonisolated static func scanUnavailableSimulatorDevices(
        _ rule: ScanRule,
        ruleIndex: Int,
        root: URL,
        fileManager: SendableFileManager,
        tracker: RuleProgressTracker
    ) async -> RuleScanResult {
        var stats = RuleScanStats()
        var results: [ScanItem] = []
        let targets = (try? SafetyPolicy.validateTargets(rule: rule, root: root)) ?? []
        guard let devicesRoot = targets.first else {
            await tracker.completed(rule: rule, stats: stats)
            return RuleScanResult(ruleIndex: ruleIndex, items: [])
        }

        let unavailableIDs = unavailableSimulatorDeviceIDs()
        guard !unavailableIDs.isEmpty else {
            await tracker.completed(rule: rule, stats: stats)
            return RuleScanResult(ruleIndex: ruleIndex, items: [])
        }

        for deviceID in unavailableIDs.sorted() {
            guard !Task.isCancelled else { break }
            let deviceURL = devicesRoot.appending(path: deviceID, directoryHint: .isDirectory)
            stats.inspectedFiles += 1
            await tracker.updated(rule: rule, stats: stats)
            var isDirectory: ObjCBool = false
            guard fileManager.value.fileExists(atPath: deviceURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let modified = try? deviceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let bytes = await allocatedBytes(at: deviceURL)
            let item = ScanItem(url: deviceURL, bytes: bytes, modifiedAt: modified, rule: rule)
            results.append(item)
            stats.matchedFiles += 1
            stats.matchedBytes += item.bytes
        }

        await tracker.completed(rule: rule, stats: stats)
        return RuleScanResult(ruleIndex: ruleIndex, items: results)
    }

    private nonisolated static func unavailableSimulatorDeviceIDs() -> Set<String> {
        let output: SystemCommandOutput
        do {
            output = try SystemCommandRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "list", "devices", "-j"],
                timeout: 20
            )
        } catch {
            return []
        }
        guard output.status == 0,
              let data = output.text.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = payload["devices"] as? [String: Any] else {
            return []
        }

        var ids = Set<String>()
        for (_, value) in devicesByRuntime {
            guard let devices = value as? [[String: Any]] else { continue }
            for device in devices {
                let available = device["isAvailable"] as? Bool ?? true
                guard !available,
                      let udid = device["udid"] as? String,
                      !udid.isEmpty else { continue }
                ids.insert(udid)
            }
        }
        return ids
    }

    private nonisolated static func allocatedBytes(at url: URL) async -> Int64 {
        await Task.detached(priority: .utility) {
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .fileAllocatedSizeKey]
            if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
                return Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
            }
            do {
                let output = try SystemCommandRunner.run(
                    executable: "/usr/bin/du",
                    arguments: ["-sk", url.path],
                    timeout: 30
                )
                guard output.status == 0,
                      let token = output.text.split(whereSeparator: \.isWhitespace).first,
                      let kilobytes = Int64(token) else {
                    return 0
                }
                return kilobytes * 1_024
            } catch {
                return 0
            }
        }.value
    }
}
