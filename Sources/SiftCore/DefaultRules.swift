import Foundation

public enum DefaultRules {
    public static let uninstallLeftovers = UninstallLeftoversRule.rule

    /// The registry defines display order only. Every rule owns its definition
    /// in a separate file so it can be changed, tested, or reverted independently.
    public static let conservative: [ScanRule] = [
        UserCachesRule.rule,
        OldLogsRule.rule,
        DownloadsArchivesRule.rule,
        NPMCacheRule.rule,
        NPMLogsRule.rule,
        HomebrewDownloadCacheRule.rule,
        CocoaPodsCacheRule.rule,
        SwiftPackageManagerCacheRule.rule,
        YarnDownloadCacheRule.rule,
        GradleBuildCacheRule.rule,
        AndroidToolCacheRule.rule,
        AppleSimulatorCacheRule.rule,
        PythonPipCacheRule.rule,
        PythonUVCacheRule.rule,
        CargoCacheRule.rule,
        XcodeDerivedDataRule.rule
    ]
}
