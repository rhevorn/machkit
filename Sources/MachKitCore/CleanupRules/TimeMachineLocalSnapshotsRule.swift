import Foundation

enum TimeMachineLocalSnapshotsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "time-machine-local-snapshots",
        title: "Time Machine Local Snapshots",
        relativePath: "Time Machine",
        minimumAgeDays: 1,
        enumerationMode: .timeMachineLocalSnapshots,
        rootScope: .virtual,
        cleanupDisposition: .deleteTimeMachineSnapshot,
        risk: .review,
        explanation: "Local APFS snapshots reported by Time Machine. Deletion is permanent, requires administrator approval, and macOS may create new snapshots later."
    )
}
