import Foundation

enum AndroidToolCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "android-cache",
        title: "Android Tool Cache",
        relativePath: ".android/cache",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Regenerable Android tool downloads and metadata; SDK platforms, emulators, and projects are not scanned."
    )
}
