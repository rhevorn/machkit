import Foundation

enum GradleBuildCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "gradle-cache",
        title: "Gradle Build Cache",
        relativePath: ".gradle/caches",
        minimumAgeDays: 30,
        risk: .review,
        explanation: "Gradle can rebuild or redownload these files, but the next Android or JVM build may be much slower."
    )
}
