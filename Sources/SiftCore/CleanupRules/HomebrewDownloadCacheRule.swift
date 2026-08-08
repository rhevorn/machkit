import Foundation

enum HomebrewDownloadCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "homebrew-download-cache",
        title: "Homebrew Download Cache",
        relativePath: "Library/Caches/Homebrew/downloads",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Downloaded formula and cask archives; installed packages in Cellar and Caskroom are not touched."
    )
}
