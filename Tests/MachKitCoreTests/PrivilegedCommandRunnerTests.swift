@testable import MachKitCore
import Foundation
import Testing

@Test func privilegedRunnerRejectsUnapprovedSFLToolActions() {
    #expect(throws: PrivilegedCommandError.self) {
        _ = try PrivilegedCommandRunner.runSFLTool(action: "delete-everything")
    }
}

@Test func privilegedRunnerRejectsHostsFilesOutsideItsTemporaryBoundary() {
    let source = URL(fileURLWithPath: "/etc/hosts")
    #expect(throws: PrivilegedCommandError.self) {
        try PrivilegedCommandRunner.replaceHostsFile(with: source)
    }
}

@Test func privilegedLaunchdTrashMoveRejectsUserAgentsAndUnsafePaths() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let home = root.appending(path: "Home", directoryHint: .isDirectory)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let userAgent = home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
    let sharedAgent = library.appending(path: "LaunchAgents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: userAgent, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sharedAgent, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let userPlist = userAgent.appending(path: "com.example.user.plist")
    try Data().write(to: userPlist)
    #expect(throws: PrivilegedCommandError.invalidRequest) {
        _ = try PrivilegedCommandRunner.validatedProtectedLaunchdTrashMove(
            source: userPlist,
            home: home,
            libraryRoot: library
        )
    }

    let nested = sharedAgent.appending(path: "Nested", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let nestedPlist = nested.appending(path: "com.example.nested.plist")
    try Data().write(to: nestedPlist)
    #expect(throws: PrivilegedCommandError.invalidRequest) {
        _ = try PrivilegedCommandRunner.validatedProtectedLaunchdTrashMove(
            source: nestedPlist,
            home: home,
            libraryRoot: library
        )
    }

    let lookalike = library.appending(path: "LaunchAgents-Old/com.example.plist")
    try FileManager.default.createDirectory(
        at: lookalike.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data().write(to: lookalike)
    #expect(throws: PrivilegedCommandError.invalidRequest) {
        _ = try PrivilegedCommandRunner.validatedProtectedLaunchdTrashMove(
            source: lookalike,
            home: home,
            libraryRoot: library
        )
    }
}

@Test func privilegedLaunchdTrashMoveAcceptsDirectLibraryPlists() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let home = root.appending(path: "Home", directoryHint: .isDirectory)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let daemons = library.appending(path: "LaunchDaemons", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: daemons, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let plist = daemons.appending(path: "com.example.daemon.plist")
    try Data("test".utf8).write(to: plist)

    let destination = try PrivilegedCommandRunner.validatedProtectedLaunchdTrashMove(
        source: plist,
        home: home,
        libraryRoot: library
    )
    #expect(destination.lastPathComponent == "com.example.daemon.plist")
    #expect(SafetyPolicy.isDirectChild(destination, of: home.appending(path: ".Trash", directoryHint: .isDirectory)))
    #expect(FileManager.default.fileExists(atPath: home.appending(path: ".Trash", directoryHint: .isDirectory).path))
}
