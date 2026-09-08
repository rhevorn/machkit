import Foundation

public enum SafetyPolicy {
    private static let forbiddenComponents: Set<String> = [
        ".ssh", ".gnupg", "keychains", "mail", "messages", "photos library.photoslibrary"
    ]

    public static func validateTargets(rule: ScanRule, root: URL) throws -> [URL] {
        try rule.relativePaths.map { try validate(relativePath: $0, risk: rule.risk, root: root) }
    }

    /// Validates the rule's primary path (first entry in `relativePaths`).
    public static func validate(rule: ScanRule, root: URL) throws -> URL {
        try validate(relativePath: rule.relativePath, risk: rule.risk, root: root)
    }

    public static func validate(relativePath: String, risk: RiskLevel, root: URL) throws -> URL {
        let pathComponents = relativePath.split(separator: "/").map(String.init)
        guard !relativePath.hasPrefix("/"), !pathComponents.contains("..") else {
            throw SafetyError.unsafeRule(relativePath)
        }

        guard !containsForbiddenComponent(pathComponents), risk != .blocked else {
            throw SafetyError.forbiddenLocation(relativePath)
        }

        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let target = canonicalRoot.appending(path: relativePath).standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard target.path.hasPrefix(prefix) else { throw SafetyError.outsideSelectedRoot }
        return target
    }

    public static func validateForCleaning(item: ScanItem, selectedRoot: URL) throws {
        switch item.rule.rootScope {
        case .selectedRoot:
            break
        case .systemVolume:
            let systemCaches = URL(fileURLWithPath: "/Library/Caches", isDirectory: true)
            guard item.rule.id == "system-caches",
                  item.rule.cleanupDisposition == .privilegedMoveToTrash,
                  isDirectChild(item.url, of: systemCaches) else {
                throw SafetyError.forbiddenLocation(item.url.path)
            }
            return
        case .mountedVolumes:
            let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
            guard item.rule.id == "incomplete-time-machine-backups",
                  item.rule.cleanupDisposition == .privilegedMoveToTrash,
                  isIncompleteTimeMachineBackup(item.url, under: volumes) else {
                throw SafetyError.forbiddenLocation(item.url.path)
            }
            return
        case .virtual:
            guard item.rule.id == "time-machine-local-snapshots",
                  item.rule.cleanupDisposition == .deleteTimeMachineSnapshot,
                  TimeMachineSnapshotParser.isValidDeletionIdentifier(item.url.lastPathComponent) else {
                throw SafetyError.forbiddenLocation(item.url.path)
            }
            return
        }

        let canonicalRoot = selectedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalItem = item.url.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard canonicalItem.path.hasPrefix(prefix), canonicalItem != canonicalRoot else {
            throw SafetyError.outsideSelectedRoot
        }
        let relativePath = String(canonicalItem.path.dropFirst(prefix.count))
        let relativeComponents = relativePath.split(separator: "/").map(String.init)
        guard item.rule.risk != .blocked,
              !containsForbiddenComponent(relativeComponents) else {
            throw SafetyError.forbiddenLocation(item.url.path)
        }
    }

    /// Checks containment using canonicalized path components rather than a lexical
    /// string prefix. Call this again immediately before every destructive action.
    public static func contains(_ candidate: URL, in directory: URL, allowDirectoryItself: Bool = false) -> Bool {
        let canonicalDirectory = canonicalized(directory)
        let canonicalCandidate = canonicalized(candidate)
        if canonicalCandidate == canonicalDirectory { return allowDirectoryItself }
        let prefix = canonicalDirectory.path.hasSuffix("/") ? canonicalDirectory.path : canonicalDirectory.path + "/"
        return canonicalCandidate.path.hasPrefix(prefix)
    }

    public static func isDirectChild(_ candidate: URL, of directory: URL) -> Bool {
        let canonicalDirectory = canonicalized(directory)
        let canonicalCandidate = canonicalized(candidate)
        return canonicalCandidate.deletingLastPathComponent() == canonicalDirectory
    }

    /// Accepts only `/Volumes/<volume>/Backups.backupdb/.../*.inProgress`.
    /// A nested lookalike directory elsewhere on a mounted volume is rejected.
    static func isIncompleteTimeMachineBackup(
        _ candidate: URL,
        under volumesRoot: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
    ) -> Bool {
        let canonicalVolumes = canonicalized(volumesRoot)
        let canonicalCandidate = canonicalized(candidate)
        let prefix = canonicalVolumes.path.hasSuffix("/")
            ? canonicalVolumes.path
            : canonicalVolumes.path + "/"
        guard canonicalCandidate.path.hasPrefix(prefix) else { return false }
        let relative = String(canonicalCandidate.path.dropFirst(prefix.count))
        let components = relative.split(separator: "/").map(String.init)
        return components.count >= 3
            && components[1] == "Backups.backupdb"
            && components.last?.hasSuffix(".inProgress") == true
    }

    /// `resolvingSymlinksInPath` stops at a missing leaf. Resolve the nearest
    /// existing ancestor first so containment checks remain correct for paths
    /// below a symlink even when the leaf disappeared after scanning.
    private static func canonicalized(_ url: URL) -> URL {
        var ancestor = url.standardizedFileURL
        var missingComponents: [String] = []
        while !FileManager.default.fileExists(atPath: ancestor.path), ancestor.path != "/" {
            missingComponents.append(ancestor.lastPathComponent)
            ancestor.deleteLastPathComponent()
        }
        var resolved = ancestor.resolvingSymlinksInPath()
        for component in missingComponents.reversed() {
            resolved.append(path: component)
        }
        return resolved.standardizedFileURL
    }

    private static func containsForbiddenComponent(_ components: [String]) -> Bool {
        components.contains { forbiddenComponents.contains($0.lowercased()) }
    }
}

public enum SafetyError: LocalizedError {
    case unsafeRule(String)
    case forbiddenLocation(String)
    case outsideSelectedRoot

    public var errorDescription: String? {
        switch self {
        case .unsafeRule(let path): "Unsafe scan rule: \(path)"
        case .forbiddenLocation(let path): "Scanning prohibited location: \(path)"
        case .outsideSelectedRoot: "Target exceeds directory selected by user"
        }
    }
}
