import Foundation
import Testing
@testable import MachKitCore

struct ConnectionTraceTests {
    @Test func parsesHTTPSURL() throws {
        let target = try ConnectionTrace.parseTarget("https://example.com/path", mode: .full)
        #expect(target.host == "example.com")
        #expect(target.port == 443)
        #expect(target.scheme == "https")
        #expect(target.url?.path == "/path")
    }

    @Test func parsesBareHostAsHTTPS() throws {
        let target = try ConnectionTrace.parseTarget("example.com", mode: .full)
        #expect(target.host == "example.com")
        #expect(target.port == 443)
        #expect(target.scheme == "https")
    }

    @Test func parsesHostPort() throws {
        let target = try ConnectionTrace.parseTarget("example.com:8443", mode: .full)
        #expect(target.host == "example.com")
        #expect(target.port == 8443)
    }

    @Test func rejectsEmpty() {
        #expect(throws: ConnectionTraceError.empty) {
            try ConnectionTrace.parseTarget("  ", mode: .dns)
        }
    }

    @Test func rejectsFTPForFullMode() {
        #expect(throws: ConnectionTraceError.unsupportedScheme("ftp")) {
            try ConnectionTrace.parseTarget("ftp://example.com", mode: .full)
        }
    }

    @Test func detectsIPLiteral() throws {
        let target = try ConnectionTrace.parseTarget("1.1.1.1", mode: .dns)
        #expect(target.isIPLiteral)
        #expect(target.host == "1.1.1.1")
    }
}
