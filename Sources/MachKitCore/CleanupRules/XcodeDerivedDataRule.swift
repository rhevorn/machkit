import Foundation

enum XcodeDerivedDataRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "xcode-derived-data",
        title: "Xcode Derived Data",
        relativePath: "Library/Developer/Xcode/DerivedData",
        minimumAgeDays: 14,
        risk: .review,
        explanation: "Xcode build products can be regenerated, but the next build will be slower."
    )
}
