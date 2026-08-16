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
