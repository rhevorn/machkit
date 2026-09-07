import Foundation

enum IncompleteTimeMachineBackupsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "incomplete-time-machine-backups",
        title: "Incomplete Time Machine Backups",
        relativePath: "Volumes",
        minimumAgeDays: 1,
        enumerationMode: .incompleteTimeMachineBackups,
        rootScope: .mountedVolumes,
        cleanupDisposition: .privilegedMoveToTrash,
        risk: .review,
        explanation: "Failed Time Machine backup directories ending in .inProgress on mounted backup volumes. Confirm the backup is not currently running before removal."
    )
}
