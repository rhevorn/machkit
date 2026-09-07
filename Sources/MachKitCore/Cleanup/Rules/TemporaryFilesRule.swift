import Foundation

enum TemporaryFilesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "temporary-files",
        title: "Temporary Files",
        relativePaths: [
            "Library/TemporaryItems",
            "tmp",
        ],
        minimumAgeDays: 1,
        risk: .review,
        explanation: "User-visible temporary files under the home folder. In-use temp files are skipped by age; confirm before removing."
    )
}
