import Foundation

enum XcodeArtifactsRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "xcode-artifacts",
        title: "Xcode Artifacts",
        relativePaths: [
            "Library/Developer/Xcode/DerivedData",
            "Library/Developer/Xcode/iOS DeviceSupport",
            "Library/Developer/Xcode/watchOS DeviceSupport",
            "Library/Developer/Xcode/tvOS DeviceSupport",
            "Library/Developer/Xcode/Archives",
        ],
        minimumAgeDays: 14,
        risk: .review,
        explanation: "Xcode DerivedData, DeviceSupport, and Archives. Builds and device debugging may be slower until data is regenerated; keep recent release archives you still need."
    )
}
