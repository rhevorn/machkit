import Foundation

public struct ScanProgress: Sendable {
    public let completedRules: Int
    public let totalRules: Int
    public let currentRuleTitle: String
    public let inspectedFiles: Int
    public let matchedFiles: Int
    public let matchedBytes: Int64

    public var fractionCompleted: Double {
        guard totalRules > 0 else { return 0 }
        return min(Double(completedRules) / Double(totalRules), 1)
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
    ) -> [ScanItem] {
        var results: [ScanItem] = []
        var inspectedFiles = 0
        var matchedBytes: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        let cutoffCalendar = Calendar(identifier: .gregorian)
        let activeRules = rules.filter { $0.risk != .blocked }

        for (ruleIndex, rule) in activeRules.enumerated() {
            guard !Task.isCancelled else { break }
            emitProgress(
                completedRules: ruleIndex,
                totalRules: activeRules.count,
                currentRule: rule.title,
                inspected: inspectedFiles,
                results: results,
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
            for case let fileURL as URL in enumerator {
                guard !Task.isCancelled else { break }
                inspectedFiles += 1
                if inspectedFiles.isMultiple(of: 128) {
                    emitProgress(
                        completedRules: ruleIndex,
                        totalRules: activeRules.count,
                        currentRule: rule.title,
                        inspected: inspectedFiles,
                        results: results,
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
                results: results,
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
        results: [ScanItem],
        bytes: Int64,
        callback: (@Sendable (ScanProgress) -> Void)?
    ) {
        callback?(ScanProgress(
            completedRules: completedRules,
            totalRules: totalRules,
            currentRuleTitle: currentRule,
            inspectedFiles: inspected,
            matchedFiles: results.count,
            matchedBytes: bytes
        ))
    }
}
