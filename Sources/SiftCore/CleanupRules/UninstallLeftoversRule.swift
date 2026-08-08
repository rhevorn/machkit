import Foundation

enum UninstallLeftoversRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "uninstall-leftovers",
        title: "Uninstall Leftovers",
        relativePath: "Library",
        minimumAgeDays: 0,
        risk: .review,
        explanation: "Files whose app is no longer installed; review them before moving them to Trash."
    )
}
