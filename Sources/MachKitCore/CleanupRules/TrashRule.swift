import Foundation

enum TrashRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "trash",
        title: "Trash",
        relativePath: ".Trash",
        minimumAgeDays: 0,
        enumerationMode: .topLevelEntries,
        risk: .review,
        explanation: "Items already in Trash. Emptying them permanently deletes files and cannot be undone."
    )
}
