import Testing
@testable import MachKitCore

struct TCPPortScanTests {
    @Test func parsesIndividualPortsAndRanges() throws {
        let ports = try TCPPortScan.parsePorts("22, 80, 443, 8000-8002")
        #expect(ports == [22, 80, 443, 8000, 8001, 8002])
    }

    @Test func supportsTheCompleteTCPPortRange() throws {
        let ports = try TCPPortScan.parsePorts("1-65535")
        #expect(ports.count == 65_535)
        #expect(ports.first == 1)
        #expect(ports.last == 65_535)
    }

    @Test func deduplicatesAndSortsPorts() throws {
        let ports = try TCPPortScan.parsePorts("443,80,80,79-81")
        #expect(ports == [79, 80, 81, 443])
    }

    @Test func rejectsInvalidPortsAndRanges() {
        #expect(throws: TCPPortScanError.invalidPort("0")) {
            try TCPPortScan.parsePorts("0")
        }
        #expect(throws: TCPPortScanError.invalidRange("100-10")) {
            try TCPPortScan.parsePorts("100-10")
        }
        #expect(throws: TCPPortScanError.invalidPort("65536")) {
            try TCPPortScan.parsePorts("65536")
        }
    }

    @Test func normalizesHostsAndURLs() throws {
        #expect(try TCPPortScan.normalizeHost("localhost") == "localhost")
        #expect(try TCPPortScan.normalizeHost("https://example.com/path") == "example.com")
        #expect(try TCPPortScan.normalizeHost("[::1]") == "::1")
    }

    @Test func identifiesCommonServices() {
        #expect(TCPPortScan.serviceName(for: 22) == "ssh")
        #expect(TCPPortScan.serviceName(for: 443) == "https")
        #expect(TCPPortScan.serviceName(for: 65_535) == nil)
    }
}
