import Foundation

enum LanguageSupportCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "language-support-caches",
        title: "Language Support Caches",
        relativePath: "Library/LanguageModeling",
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "On-device language modeling caches. macOS regenerates them as you type and use dictation."
    )
}
