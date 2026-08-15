import Foundation

enum DeviceBackupsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "device-backups",
        title: "Device Backups",
        relativePath: "Library/Application Support/MobileSync/Backup",
        minimumAgeDays: 0,
        enumerationMode: .topLevelEntries,
        risk: .review,
        explanation: "Local iPhone and iPad backups. Removing a backup cannot be undone unless you have another copy."
    )
}
