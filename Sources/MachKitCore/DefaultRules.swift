import Foundation

public enum DefaultRules {
    public static let uninstallLeftovers = UninstallLeftoversRule.rule

    /// Category-based registry. Order matches cleanup scan phases in the UI.
    public static let conservative: [ScanRule] = [
        // Trash
        TrashRule.rule,
        // Caches
        UserCachesRule.rule,
        BrowserCachesRule.rule,
        XDGCachesRule.rule,
        TemporaryFilesRule.rule,
        LanguageSupportCachesRule.rule,
        // Downloads & mail
        DownloadsArchivesRule.rule,
        MailDownloadsRule.rule,
        // Device backups
        DeviceBackupsRule.rule,
        // Developer files
        OldLogsRule.rule,
        DeveloperHomeCachesRule.rule,
        XcodeArtifactsRule.rule,
        AppleSimulatorCacheRule.rule,
        UnavailableSimulatorDevicesRule.rule,
    ]
}
