import Foundation

enum PrivilegedCommandError: LocalizedError, Equatable {
    case authorizationCancelled
    case commandFailed(String)
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .authorizationCancelled:
            "Administrator authorization has been canceled."
        case let .commandFailed(detail):
            "Administrator command failed: \(detail)"
        case .invalidRequest:
            "The administrator command was rejected by MachKit."
        }
    }
}

/// Narrow administrator boundary used by the system features that require root
/// access. Commands run in-process via `NSAppleScript` so the macOS password
/// sheet attributes to MachKit instead of the `osascript` helper process.
enum PrivilegedCommandRunner {
    private static let allowedExecutables: Set<String> = [
        "/bin/cp",
        "/bin/mv",
        "/usr/bin/tmutil",
        "/usr/bin/sfltool"
    ]

    enum ProtectedCleanupDomain: Sendable {
        case systemCache
        case incompleteTimeMachineBackup
    }

    static func replaceHostsFile(with source: URL) throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
        let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard SafetyPolicy.contains(source, in: temporaryRoot),
              source.lastPathComponent.hasPrefix("machkit-hosts-"),
              values?.isRegularFile == true,
              values?.isSymbolicLink != true else {
            throw PrivilegedCommandError.invalidRequest
        }
        _ = try run(executable: "/bin/cp", arguments: [source.path, "/etc/hosts"])
    }

    static func runSFLTool(action: String) throws -> String {
        guard action == "dumpbtm" || action == "resetbtm" else {
            throw PrivilegedCommandError.invalidRequest
        }
        return try run(executable: "/usr/bin/sfltool", arguments: [action])
    }

    static func deleteTimeMachineLocalSnapshot(identifier: String) throws {
        guard TimeMachineSnapshotParser.isValidDeletionIdentifier(identifier) else {
            throw PrivilegedCommandError.invalidRequest
        }
        _ = try run(
            executable: "/usr/bin/tmutil",
            arguments: ["deletelocalsnapshots", identifier]
        )
    }

    static func moveProtectedCleanupItemToTrash(
        _ source: URL,
        domain: ProtectedCleanupDomain,
        home: URL,
        systemCacheRoot: URL = URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
        volumesRoot: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true),
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination = try validatedProtectedCleanupTrashMove(
            source: source,
            domain: domain,
            home: home,
            systemCacheRoot: systemCacheRoot,
            volumesRoot: volumesRoot,
            fileManager: fileManager
        )
        _ = try run(executable: "/bin/mv", arguments: [source.path, destination.path])
        return destination
    }

    static func validatedProtectedCleanupTrashMove(
        source: URL,
        domain: ProtectedCleanupDomain,
        home: URL,
        systemCacheRoot: URL = URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
        volumesRoot: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true),
        fileManager: FileManager = .default
    ) throws -> URL {
        let standardized = source.standardizedFileURL
        switch domain {
        case .systemCache:
            guard SafetyPolicy.isDirectChild(standardized, of: systemCacheRoot) else {
                throw PrivilegedCommandError.invalidRequest
            }
        case .incompleteTimeMachineBackup:
            guard SafetyPolicy.isIncompleteTimeMachineBackup(
                standardized,
                under: volumesRoot
            ) else {
                throw PrivilegedCommandError.invalidRequest
            }
        }

        let values = try? standardized.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        ])
        guard fileManager.fileExists(atPath: standardized.path),
              values?.isSymbolicLink != true,
              values?.isDirectory == true || values?.isRegularFile == true else {
            throw PrivilegedCommandError.invalidRequest
        }

        let trash = home.appending(path: ".Trash", directoryHint: .isDirectory).standardizedFileURL
        try fileManager.createDirectory(at: trash, withIntermediateDirectories: true)
        var destination = trash.appending(path: standardized.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            let suffix = String(UUID().uuidString.prefix(8))
            destination = trash.appending(path: "\(standardized.lastPathComponent).\(suffix)")
        }
        guard SafetyPolicy.isDirectChild(destination, of: trash),
              !fileManager.fileExists(atPath: destination.path) else {
            throw PrivilegedCommandError.invalidRequest
        }
        return destination
    }

    /// Moves a validated `/Library/LaunchAgents|LaunchDaemons/*.plist` into the
    /// current user's Trash. Destination uniqueness is enforced before asking
    /// for administrator privileges.
    static func moveProtectedLaunchdPlistToTrash(
        _ source: URL,
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true),
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination = try validatedProtectedLaunchdTrashMove(
            source: source,
            home: home,
            libraryRoot: libraryRoot,
            fileManager: fileManager
        )
        _ = try run(executable: "/bin/mv", arguments: [source.path, destination.path])
        return destination
    }

    /// Pure validation used by tests and by the privileged mover.
    static func validatedProtectedLaunchdTrashMove(
        source: URL,
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true),
        fileManager: FileManager = .default
    ) throws -> URL {
        let allowedParents = [
            libraryRoot.appending(path: "LaunchAgents", directoryHint: .isDirectory),
            libraryRoot.appending(path: "LaunchDaemons", directoryHint: .isDirectory)
        ]
        let standardized = source.standardizedFileURL
        guard standardized.pathExtension.lowercased() == "plist",
              allowedParents.contains(where: { SafetyPolicy.isDirectChild(standardized, of: $0) }) else {
            throw PrivilegedCommandError.invalidRequest
        }

        let values = try? standardized.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey])
        guard fileManager.fileExists(atPath: standardized.path),
              values?.isSymbolicLink != true,
              values?.isDirectory != true,
              values?.isRegularFile == true else {
            throw PrivilegedCommandError.invalidRequest
        }

        let trash = home.appending(path: ".Trash", directoryHint: .isDirectory).standardizedFileURL
        try fileManager.createDirectory(at: trash, withIntermediateDirectories: true)

        var destinationName = standardized.lastPathComponent
        var destination = trash.appending(path: destinationName)
        if fileManager.fileExists(atPath: destination.path) {
            let stem = standardized.deletingPathExtension().lastPathComponent
            destinationName = "\(stem).\(UUID().uuidString.prefix(8)).plist"
            destination = trash.appending(path: destinationName)
        }
        guard SafetyPolicy.isDirectChild(destination, of: trash),
              !fileManager.fileExists(atPath: destination.path) else {
            throw PrivilegedCommandError.invalidRequest
        }
        return destination
    }

    private static func run(executable: String, arguments: [String]) throws -> String {
        guard allowedExecutables.contains(executable) else {
            throw PrivilegedCommandError.invalidRequest
        }

        // Build `quoted form of "…"` tokens in AppleScript so paths with spaces
        // stay literal arguments and never pass through a shell interpreter.
        let tokens = [executable] + arguments
        let quotedForms = tokens.map { token in
            "quoted form of \"\(escapeForAppleScriptString(token))\""
        }
        let source = """
        do shell script (\(quotedForms.joined(separator: " & space & "))) with administrator privileges
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw PrivilegedCommandError.invalidRequest
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let detail = (errorInfo[NSAppleScript.errorMessage] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let normalized = detail.lowercased()
            if number == -128
                || normalized.contains("user canceled")
                || normalized.contains("user cancelled") {
                throw PrivilegedCommandError.authorizationCancelled
            }
            throw PrivilegedCommandError.commandFailed(
                detail.isEmpty ? "Administrator command failed with status \(number)." : detail
            )
        }
        return (result.stringValue ?? "").trimmingCharacters(in: .newlines)
    }

    private static func escapeForAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
