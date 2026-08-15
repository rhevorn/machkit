import Foundation

enum BrowserCachesRule: CleanupRuleDefinition {
    /// Paths relative to `Library/Caches`, shared with User Caches exclusions.
    static let rootsRelativeToLibraryCaches: [String] = [
        "com.apple.Safari",
        "com.apple.Safari.SafeBrowsing",
        "Google/Chrome",
        "Google/Chrome for Testing",
        "Chromium",
        "Microsoft Edge",
        "com.microsoft.edgemac",
        "Firefox",
        "org.mozilla.firefox",
        "BraveSoftware",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
    ]

    static let rule = ScanRule(
        id: "browser-caches",
        title: "Browser Caches",
        relativePaths: rootsRelativeToLibraryCaches.map { "Library/Caches/\($0)" },
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "Regenerable website caches for Safari, Chrome, Edge, Firefox, and similar browsers. Cookies, passwords, and bookmarks are not included."
    )
}
