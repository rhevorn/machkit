import Foundation

enum CocoaPodsCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "cocoapods-cache",
        title: "CocoaPods Cache",
        relativePath: "Library/Caches/CocoaPods",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Downloaded pod archives and specs can be fetched again; project Pods directories are not scanned."
    )
}
