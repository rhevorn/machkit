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
