import Foundation

enum YarnDownloadCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "yarn-cache",
        title: "Yarn Download Cache",
        relativePath: "Library/Caches/Yarn",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Global Yarn download cache; project node_modules and offline mirrors are not scanned."
    )
}
