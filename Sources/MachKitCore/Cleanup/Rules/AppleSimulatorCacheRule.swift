import Foundation

enum AppleSimulatorCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "simulator-cache",
        title: "Apple Simulator Cache",
        relativePath: "Library/Developer/CoreSimulator/Caches",
        minimumAgeDays: 30,
        risk: .review,
        explanation: "Regenerable simulator caches only; simulator devices, installed runtimes, and app data are preserved."
    )
}
