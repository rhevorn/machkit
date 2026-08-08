import Foundation

enum OldLogsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "user-logs",
        title: "Old Logs",
        relativePath: "Library/Logs",
        minimumAgeDays: 14,
        allowedExtensions: ["log", "txt", "old"],
        risk: .safe,
        explanation: "Log files older than 14 days, excluding files currently being written."
    )
}
