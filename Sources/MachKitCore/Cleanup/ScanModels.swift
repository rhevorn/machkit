import Foundation

public enum ScanEnumerationMode: String, Codable, Sendable, Hashable {
    /// Recurse and match aged regular files (default).
    case agedFiles
    /// Immediate children of each scan root as removable units (files or directories).
    case topLevelEntries
    /// CoreSimulator device directories that `simctl` reports as unavailable.
    case unavailableSimulatorDevices
    /// Named cache or log directories below a bounded set of known app roots.
    case matchingDirectories
    /// Rebuildable dependency and build directories inside recognized projects.
    case projectBuildArtifacts
    /// Incomplete Time Machine backup directories on mounted backup volumes.
    case incompleteTimeMachineBackups
    /// Local APFS Time Machine snapshots reported by `tmutil`.
    case timeMachineLocalSnapshots
}

public enum ScanRootScope: String, Codable, Sendable, Hashable {
    /// Paths are relative to the folder explicitly selected by the user.
    case selectedRoot
    /// Paths are relative to the system data volume. Only fixed allowlisted roots are valid.
    case systemVolume
    /// Discovery is restricted to mounted volumes and validated by its specialized scanner.
    case mountedVolumes
    /// The item represents a system-maintained object rather than a filesystem path.
    case virtual
}

public enum CleanupDisposition: String, Codable, Sendable, Hashable {
    case moveToTrash
    case permanentlyDelete
    case privilegedMoveToTrash
    case deleteTimeMachineSnapshot
}

public struct ScanRule: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let relativePaths: [String]
    public let minimumAgeDays: Int
    public let allowedExtensions: Set<String>
    public let excludedRelativePaths: Set<String>
    public let enumerationMode: ScanEnumerationMode
    public let matchedDirectoryNames: Set<String>
    public let maximumDepth: Int
    public let rootScope: ScanRootScope
    public let cleanupDisposition: CleanupDisposition
    public let risk: RiskLevel
    public let explanation: String

    /// First scan root; kept for callers and tests that expect a single path.
    public var relativePath: String { relativePaths[0] }

    public init(
        id: String,
        title: String,
        relativePath: String,
        minimumAgeDays: Int,
        allowedExtensions: Set<String> = [],
        excludedRelativePaths: Set<String> = [],
        enumerationMode: ScanEnumerationMode = .agedFiles,
        matchedDirectoryNames: Set<String> = [],
        maximumDepth: Int = 4,
        rootScope: ScanRootScope = .selectedRoot,
        cleanupDisposition: CleanupDisposition = .moveToTrash,
        risk: RiskLevel,
        explanation: String
    ) {
        self.init(
            id: id,
            title: title,
            relativePaths: [relativePath],
            minimumAgeDays: minimumAgeDays,
            allowedExtensions: allowedExtensions,
            excludedRelativePaths: excludedRelativePaths,
            enumerationMode: enumerationMode,
            matchedDirectoryNames: matchedDirectoryNames,
            maximumDepth: maximumDepth,
            rootScope: rootScope,
            cleanupDisposition: cleanupDisposition,
            risk: risk,
            explanation: explanation
        )
    }

    public init(
        id: String,
        title: String,
        relativePaths: [String],
        minimumAgeDays: Int,
        allowedExtensions: Set<String> = [],
        excludedRelativePaths: Set<String> = [],
        enumerationMode: ScanEnumerationMode = .agedFiles,
        matchedDirectoryNames: Set<String> = [],
        maximumDepth: Int = 4,
        rootScope: ScanRootScope = .selectedRoot,
        cleanupDisposition: CleanupDisposition = .moveToTrash,
        risk: RiskLevel,
        explanation: String
    ) {
        precondition(!relativePaths.isEmpty, "ScanRule requires at least one relative path")
        self.id = id
        self.title = title
        self.relativePaths = relativePaths
        self.minimumAgeDays = minimumAgeDays
        self.allowedExtensions = allowedExtensions
        self.excludedRelativePaths = excludedRelativePaths
        self.enumerationMode = enumerationMode
        self.matchedDirectoryNames = matchedDirectoryNames
        self.maximumDepth = max(1, maximumDepth)
        self.rootScope = rootScope
        self.cleanupDisposition = cleanupDisposition
        self.risk = risk
        self.explanation = explanation
    }
}

public struct ScanItem: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let bytes: Int64
    /// Matched files represented by this row (1 for a single file entry).
    public let fileCount: Int
    public let modifiedAt: Date?
    public let rule: ScanRule

    public init(
        id: UUID = UUID(),
        url: URL,
        bytes: Int64,
        fileCount: Int = 1,
        modifiedAt: Date?,
        rule: ScanRule
    ) {
        self.id = id
        self.url = url
        self.bytes = bytes
        self.fileCount = max(1, fileCount)
        self.modifiedAt = modifiedAt
        self.rule = rule
    }
}
