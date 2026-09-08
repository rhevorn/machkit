import Foundation

enum SystemCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "system-caches",
        title: "System-level Caches",
        relativePath: "Library/Caches",
        minimumAgeDays: 30,
        enumerationMode: .topLevelEntries,
        rootScope: .systemVolume,
        cleanupDisposition: .privilegedMoveToTrash,
        risk: .review,
        explanation: "Optional caches under /Library/Caches. Cleaning requires administrator approval and may make apps or services rebuild data on next use."
    )
}
