import Foundation

enum DeveloperHomeCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "developer-home-caches",
        title: "Developer Home Caches",
        relativePaths: [
            ".npm",
            ".bun/install/cache",
            ".m2/repository",
            "go/pkg/mod",
            ".cargo",
            ".gradle/caches",
            ".android/cache",
            "Library/pnpm",
            ".local/share/pnpm",
            ".docker/buildx",
        ],
        minimumAgeDays: 14,
        risk: .review,
        explanation: "Package-manager and build caches in the home folder. Next installs or builds may redownload dependencies."
    )
}
