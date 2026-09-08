import Foundation

enum ApplicationSupportLogsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "application-support-logs",
        title: "Application Support Logs",
        relativePath: "Library/Application Support",
        minimumAgeDays: 14,
        enumerationMode: .matchingDirectories,
        matchedDirectoryNames: ["Log", "Logs"],
        maximumDepth: 3,
        risk: .review,
        explanation: "Old log directories embedded in Application Support. Review before cleaning because recent diagnostics may still be useful for troubleshooting."
    )
}
