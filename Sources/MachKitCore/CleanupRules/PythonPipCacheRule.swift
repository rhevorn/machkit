import Foundation

enum PythonPipCacheRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "python-pip-cache",
        title: "Python pip cache",
        relativePath: "Library/Caches/pip",
        minimumAgeDays: 14,
        risk: .safe,
        explanation: "pip download and build cache; Python, site-packages, or virtual environments will not be deleted."
    )
}
