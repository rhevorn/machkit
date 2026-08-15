import Foundation

enum PythonUVCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "python-uv-cache",
        title: "Python uv cache",
        relativePath: ".cache/uv",
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "uv Regenerable cache; project virtual environment will not be deleted."
    )
}
