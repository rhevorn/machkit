import SiftCore
import Foundation
import Testing

@Test func rejectsParentTraversal() {
    let rule = ScanRule(id: "bad", title: "bad", relativePath: "../Library", minimumAgeDays: 0, risk: .safe, explanation: "")
    #expect(throws: SafetyError.self) {
        try SafetyPolicy.validate(rule: rule, root: URL(fileURLWithPath: "/tmp/root"))
    }
}

@Test func rejectsSensitiveFolders() {
    let rule = ScanRule(id: "bad", title: "bad", relativePath: "Library/Keychains", minimumAgeDays: 0, risk: .safe, explanation: "")
    #expect(throws: SafetyError.self) {
        try SafetyPolicy.validate(rule: rule, root: URL(fileURLWithPath: "/tmp/root"))
    }
}

@Test func resolvesSafeRuleInsideRoot() throws {
    let rule = ScanRule(id: "ok", title: "ok", relativePath: "Library/Caches", minimumAgeDays: 0, risk: .safe, explanation: "")
    let result = try SafetyPolicy.validate(rule: rule, root: URL(fileURLWithPath: "/tmp/root"))
    #expect(result.path.hasSuffix("/tmp/root/Library/Caches"))
}

@Test func canonicalContainmentRejectsSiblingWithSharedPrefix() {
    let root = URL(fileURLWithPath: "/tmp/SiftHome")
    let sibling = URL(fileURLWithPath: "/tmp/SiftHome-Other/file.log")
    #expect(!SafetyPolicy.contains(sibling, in: root))
}

@Test func directChildRejectsNestedItems() {
    let root = URL(fileURLWithPath: "/Applications", isDirectory: true)
    #expect(SafetyPolicy.isDirectChild(URL(fileURLWithPath: "/Applications/Example.app"), of: root))
    #expect(!SafetyPolicy.isDirectChild(URL(fileURLWithPath: "/Applications/Folder/Example.app"), of: root))
}

@Test func canonicalContainmentRejectsSymlinkEscape() throws {
    let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let root = temporary.appending(path: "Root", directoryHint: .isDirectory)
    let outside = temporary.appending(path: "Outside", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }

    let link = root.appending(path: "Escape")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    #expect(!SafetyPolicy.contains(link.appending(path: "file.log"), in: root))
}
