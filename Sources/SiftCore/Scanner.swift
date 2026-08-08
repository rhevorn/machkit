import Foundation

public struct ScanProgress: Sendable {
    public let completedRules: Int
    public let totalRules: Int
    public let currentRuleTitle: String
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
        completedRuleIDs.insert(rule.id)
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
            inspectedFiles: aggregate.inspectedFiles,
            currentRuleInspectedFiles: statsByRuleID[rule.id]?.inspectedFiles ?? 0,
            matchedFiles: aggregate.matchedFiles,
            matchedBytes: aggregate.matchedBytes
        ))
    }
}

public actor Scanner {
    private let fileManager: FileManager
    private let maximumConcurrentRules: Int

    public init(fileManager: FileManager = .default, maximumConcurrentRules: Int = 3) {
        self.fileManager = fileManager
        self.maximumConcurrentRules = max(1, maximumConcurrentRules)
    }

    public func scan(
        root: URL,
        rules: [ScanRule],
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [ScanItem] {
        let activeRules = rules.filter { $0.risk != .blocked }
        guard !activeRules.isEmpty else { return [] }

        let tracker = RuleProgressTracker(totalRules: activeRules.count, callback: onProgress)
        let concurrencyLimit = min(maximumConcurrentRules, activeRules.count)
        let fileManager = SendableFileManager(value: self.fileManager)
        var resultsByIndex: [Int: [ScanItem]] = [:]

        await withTaskGroup(of: RuleScanResult.self) { group in
            var nextIndex = 0
            for _ in 0..<concurrencyLimit {
                let index = nextIndex
                let rule = activeRules[index]
                nextIndex += 1
                group.addTask {
                    await Self.scanRule(
                        rule,
                        ruleIndex: index,
                        root: root,
                        fileManager: fileManager,
                        tracker: tracker
                    )
                }
            }

            while let result = await group.next() {
                resultsByIndex[result.ruleIndex] = result.items
                guard nextIndex < activeRules.count, !Task.isCancelled else { continue }
                let index = nextIndex
                let rule = activeRules[index]
                nextIndex += 1
                group.addTask {
                    await Self.scanRule(
                        rule,
                        ruleIndex: index,
                        root: root,
                        fileManager: fileManager,
                        tracker: tracker
                    )
                }
            }
        }

        return resultsByIndex.keys.sorted().flatMap { resultsByIndex[$0] ?? [] }
            .sorted { $0.bytes > $1.bytes }
    }

    private nonisolated static func scanRule(
        _ rule: ScanRule,
        ruleIndex: Int,
        root: URL,
        fileManager: SendableFileManager,
        tracker: RuleProgressTracker
    ) async -> RuleScanResult {
        await tracker.started(rule: rule)
        var stats = RuleScanStats()
        var results: [ScanItem] = []
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let target = try? SafetyPolicy.validate(rule: rule, root: root),
              let enumerator = fileManager.value.enumerator(
                at: target,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            await tracker.completed(rule: rule, stats: stats)
            return RuleScanResult(ruleIndex: ruleIndex, items: [])
        }

        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -rule.minimumAgeDays, to: Date()) ?? .distantPast
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

        await tracker.completed(rule: rule, stats: stats)
        return RuleScanResult(ruleIndex: ruleIndex, items: results)
    }
}
