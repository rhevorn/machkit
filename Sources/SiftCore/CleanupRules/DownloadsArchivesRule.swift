import Foundation

enum DownloadsArchivesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "downloads-archives",
        title: "Old installation packages and compressed packages",
        relativePath: "Downloads",
        minimumAgeDays: 30,
        allowedExtensions: ["dmg", "pkg", "zip"],
        risk: .review,
        explanation: "Old downloads may still have value and must be confirmed individually by the user."
    )
}
