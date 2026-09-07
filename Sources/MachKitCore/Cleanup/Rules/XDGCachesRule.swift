import Foundation

enum XDGCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "xdg-caches",
        title: "Shared Tool Caches",
        relativePath: ".cache",
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "Shared CLI and tool caches under ~/.cache (XDG). Regenerable downloads for many developer tools."
    )
}
