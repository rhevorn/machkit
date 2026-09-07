import Foundation

enum EditorCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "editor-caches",
        title: "Editor Caches",
        relativePaths: [
            "Library/Application Support/Code",
            "Library/Application Support/Code - Insiders",
            "Library/Application Support/Cursor",
            "Library/Application Support/Windsurf",
            "Library/Application Support/VSCodium",
            "Library/Application Support/Sublime Text",
            "Library/Application Support/Zed",
        ],
        minimumAgeDays: 7,
        enumerationMode: .matchingDirectories,
        matchedDirectoryNames: [
            "Cache", "CachedData", "CachedExtensions", "CachedExtensionVSIXs",
            "Code Cache", "GPUCache", "DawnCache", "GrShaderCache",
            "ShaderCache", "CacheStorage",
        ],
        maximumDepth: 5,
        risk: .safe,
        explanation: "Regenerable editor UI, extension download, shader, and webview caches. Settings, projects, extensions, and workspace state are preserved."
    )
}
