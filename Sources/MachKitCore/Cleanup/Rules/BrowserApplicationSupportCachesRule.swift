import Foundation

enum BrowserApplicationSupportCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "browser-application-support-caches",
        title: "Browser Support Caches",
        relativePaths: [
            "Library/Application Support/Google/Chrome",
            "Library/Application Support/Google/Chrome for Testing",
            "Library/Application Support/Chromium",
            "Library/Application Support/Microsoft Edge",
            "Library/Application Support/BraveSoftware/Brave-Browser",
            "Library/Application Support/Arc",
            "Library/Application Support/Vivaldi",
            "Library/Application Support/com.operasoftware.Opera",
        ],
        minimumAgeDays: 7,
        enumerationMode: .matchingDirectories,
        matchedDirectoryNames: [
            "Cache", "Code Cache", "GPUCache", "DawnCache", "GrShaderCache",
            "ShaderCache", "CacheStorage", "OptimizationHints",
        ],
        maximumDepth: 5,
        risk: .safe,
        explanation: "Regenerable Chromium-family caches stored inside Application Support. Profiles, cookies, passwords, history, extensions, and bookmarks are preserved."
    )
}
