import Foundation

enum NPMCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "npm-cache",
        title: "npm Download Cache",
        relativePath: ".npm/_cacache",
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "Redownloadable npm content-addressed cache; global packages and project node_modules are not deleted."
    )
}
