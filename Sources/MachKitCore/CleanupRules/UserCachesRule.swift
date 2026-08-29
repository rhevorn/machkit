import Foundation

enum UserCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "user-caches",
        title: "User Caches",
        relativePath: "Library/Caches",
        minimumAgeDays: 30,
        excludedRelativePaths: Set(BrowserCachesRule.rootsRelativeToLibraryCaches).union(["Homebrew"]),
        risk: .safe,
        explanation: "Application caches under Library/Caches. Browser website caches are listed separately; apps can recreate the rest at next launch."
    )
}
