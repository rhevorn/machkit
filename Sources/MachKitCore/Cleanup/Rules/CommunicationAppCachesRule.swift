import Foundation

enum CommunicationAppCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "communication-app-caches",
        title: "Communication App Caches",
        relativePaths: [
            "Library/Application Support/Slack",
            "Library/Application Support/discord",
            "Library/Application Support/Discord",
            "Library/Application Support/Microsoft/Teams",
            "Library/Application Support/Microsoft/TeamsMeetingAddin",
            "Library/Application Support/zoom.us",
            "Library/Application Support/Signal",
        ],
        minimumAgeDays: 7,
        enumerationMode: .matchingDirectories,
        matchedDirectoryNames: [
            "Cache", "Code Cache", "GPUCache", "DawnCache", "GrShaderCache",
            "ShaderCache", "CacheStorage",
        ],
        maximumDepth: 5,
        risk: .safe,
        explanation: "Regenerable desktop communication app caches. Accounts, messages, downloaded files, local databases, cookies, and sessions are preserved."
    )
}
