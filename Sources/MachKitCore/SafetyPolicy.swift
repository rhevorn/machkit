import Foundation

public enum SafetyPolicy {
    private static let forbiddenComponents: Set<String> = [
        ".ssh", ".gnupg", "Keychains", "Mail", "Messages", "Photos Library.photoslibrary"
    ]

    public static func validate(rule: ScanRule, root: URL) throws -> URL {
        guard !rule.relativePath.hasPrefix("/"), !rule.relativePath.contains("..") else {
            throw SafetyError.unsafeRule(rule.relativePath)
        }

        let components = Set(rule.relativePath.split(separator: "/").map(String.init))
        guard forbiddenComponents.isDisjoint(with: components), rule.risk != .blocked else {
            throw SafetyError.forbiddenLocation(rule.relativePath)
        }

        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let target = canonicalRoot.appending(path: rule.relativePath).standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard target.path.hasPrefix(prefix) else { throw SafetyError.outsideSelectedRoot }
        return target
    }

    public static func validateForCleaning(item: ScanItem, selectedRoot: URL) throws {
        let canonicalRoot = selectedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalItem = item.url.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard canonicalItem.path.hasPrefix(prefix), canonicalItem != canonicalRoot else {
            throw SafetyError.outsideSelectedRoot
        }
        guard item.rule.risk != .blocked else { throw SafetyError.forbiddenLocation(item.url.path) }
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
