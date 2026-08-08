import Foundation

enum NPMLogsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "npm-logs",
        title: "npm Debug Logs",
        relativePath: ".npm/_logs",
        minimumAgeDays: 7,
        allowedExtensions: ["log"],
        risk: .safe,
        explanation: "Old npm debug logs."
    )
}
