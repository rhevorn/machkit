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
        BrowserApplicationSupportCachesRule.rule,
        EditorCachesRule.rule,
        CommunicationAppCachesRule.rule,
        XDGCachesRule.rule,
        TemporaryFilesRule.rule,
        LanguageSupportCachesRule.rule,
        HomebrewCleanupRule.rule,
        // Downloads & mail
        DownloadsArchivesRule.rule,
        MailDownloadsRule.rule,
        // Device backups
        DeviceBackupsRule.rule,
        DeviceFirmwareCachesRule.rule,
        IncompleteTimeMachineBackupsRule.rule,
        TimeMachineLocalSnapshotsRule.rule,
        // Developer files
        OldLogsRule.rule,
        ApplicationSupportLogsRule.rule,
        DeveloperHomeCachesRule.rule,
        XcodeArtifactsRule.rule,
        AppleSimulatorCacheRule.rule,
        UnavailableSimulatorDevicesRule.rule,
        ProjectBuildArtifactsRule.rule,
        // Optional administrator-reviewed cleanup
        SystemCachesRule.rule,
    ]
}
