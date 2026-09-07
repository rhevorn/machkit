import Foundation

enum HomebrewCleanupRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "homebrew-cleanup",
        title: "Homebrew Caches & Logs",
        relativePaths: [
            "Library/Caches/Homebrew",
            "Library/Logs/Homebrew",
        ],
        minimumAgeDays: 14,
        enumerationMode: .topLevelEntries,
        risk: .safe,
        explanation: "Downloaded bottles, source archives, and old Homebrew logs. Installed formulae, casks, taps, and configuration are preserved."
    )
}
