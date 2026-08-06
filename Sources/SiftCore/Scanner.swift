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
        var results: [ScanItem] = []
        var inspectedFiles = 0
        var matchedBytes: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        let cutoffCalendar = Calendar(identifier: .gregorian)
        let activeRules = rules.filter { $0.risk != .blocked }

        for (ruleIndex, rule) in activeRules.enumerated() {
            guard !Task.isCancelled else { break }
            var inspectedInCurrentRule = 0
            var lastProgressUpdate = Date.distantPast
            emitProgress(
                completedRules: ruleIndex,
                totalRules: activeRules.count,
                currentRule: rule.title,
                inspected: inspectedFiles,
                currentRuleInspected: 0,
                resultCount: results.count,
                bytes: matchedBytes,
                callback: onProgress
            )
            guard let target = try? SafetyPolicy.validate(rule: rule, root: root),
                  let enumerator = fileManager.enumerator(
                    at: target,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }

            let cutoff = cutoffCalendar.date(byAdding: .day, value: -rule.minimumAgeDays, to: Date()) ?? .distantPast
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
                inspectedFiles += 1
                inspectedInCurrentRule += 1
                if inspectedInCurrentRule.isMultiple(of: 512) {
                    await Task.yield()
                }
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) >= 0.15 {
                    lastProgressUpdate = now
                    emitProgress(
                        completedRules: ruleIndex,
                        totalRules: activeRules.count,
                        currentRule: rule.title,
                        inspected: inspectedFiles,
                        currentRuleInspected: inspectedInCurrentRule,
                        resultCount: results.count,
                        bytes: matchedBytes,
                        callback: onProgress
                    )
                }
                guard let values = try? fileURL.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      let modified = values.contentModificationDate,
                      modified < cutoff else { continue }

                let ext = fileURL.pathExtension.lowercased()
                guard rule.allowedExtensions.isEmpty || rule.allowedExtensions.contains(ext) else { continue }
                let item = ScanItem(url: fileURL, bytes: Int64(values.fileSize ?? 0), modifiedAt: modified, rule: rule)
                results.append(item)
                matchedBytes += item.bytes
            }
            emitProgress(
                completedRules: ruleIndex + 1,
                totalRules: activeRules.count,
                currentRule: rule.title,
                inspected: inspectedFiles,
                currentRuleInspected: 0,
                resultCount: results.count,
                bytes: matchedBytes,
                callback: onProgress
            )
        }
        return results.sorted { $0.bytes > $1.bytes }
    }

    private func emitProgress(
        completedRules: Int,
        totalRules: Int,
        currentRule: String,
        inspected: Int,
        currentRuleInspected: Int,
        resultCount: Int,
        bytes: Int64,
        callback: (@Sendable (ScanProgress) -> Void)?
    ) {
        callback?(ScanProgress(
            completedRules: completedRules,
            totalRules: totalRules,
            currentRuleTitle: currentRule,
            inspectedFiles: inspected,
            currentRuleInspectedFiles: currentRuleInspected,
            matchedFiles: resultCount,
            matchedBytes: bytes
        ))
    }
}
