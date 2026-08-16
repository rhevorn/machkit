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

/// Narrow administrator boundary used by the two system features that require
/// root access. The AppleScript is constant, validates its executable again,
/// and quotes every argument before asking macOS to authorize the operation.
enum PrivilegedCommandRunner {
    private static let administratorScript = """
    on run argv
        if (count of argv) < 1 then error "Missing executable"
        set executablePath to item 1 of argv
        if executablePath is not "/bin/cp" and executablePath is not "/usr/bin/sfltool" then
            error "Executable is not allowed"
        end if
        set commandText to quoted form of executablePath
        if (count of argv) > 1 then
            repeat with argumentIndex from 2 to count of argv
                set commandText to commandText & space & quoted form of (item argumentIndex of argv)
            end repeat
        end if
        return do shell script commandText with administrator privileges
    end run
    """

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

    private static func run(executable: String, arguments: [String]) throws -> String {
        let output = try SystemCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", administratorScript, "--", executable] + arguments,
            timeout: 120
        )
        guard output.status == 0 else {
            let detail = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = detail.lowercased()
            if normalized.contains("user canceled")
                || normalized.contains("user cancelled")
                || normalized.contains("(-128)") {
                throw PrivilegedCommandError.authorizationCancelled
            }
            throw PrivilegedCommandError.commandFailed(
                detail.isEmpty ? "osascript exited with status \(output.status)." : detail
            )
        }
        return output.text.trimmingCharacters(in: .newlines)
    }
}
