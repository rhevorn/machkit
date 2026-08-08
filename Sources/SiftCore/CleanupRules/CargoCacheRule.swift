import Foundation

enum CargoCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "cargo-cache",
        title: "Cargo download cache",
        relativePath: ".cargo/registry/cache",
        minimumAgeDays: 30,
        risk: .safe,
        explanation: "Rust crate download cache; does not delete toolchains, source code, or installed commands."
    )
}
