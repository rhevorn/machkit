import Foundation

enum SwiftPackageManagerCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "swiftpm-cache",
        title: "Swift Package Manager Cache",
        relativePath: "Library/Caches/org.swift.swiftpm",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Swift package metadata and downloads can be resolved again; project checkouts and source packages are preserved."
    )
}
