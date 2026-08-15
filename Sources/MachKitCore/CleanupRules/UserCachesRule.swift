import Foundation

enum UserCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "user-caches",
        title: "User Caches",
        relativePath: "Library/Caches",
        minimumAgeDays: 30,
        excludedRelativePaths: ["Homebrew", "CocoaPods", "org.swift.swiftpm", "Yarn", "pip"],
        risk: .safe,
        explanation: "Regular caches unchanged for 30 days; apps may recreate them at next launch."
    )
}
