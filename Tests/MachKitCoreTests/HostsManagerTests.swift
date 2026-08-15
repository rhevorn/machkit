import Foundation
import Testing
@testable import MachKitCore

struct HostsManagerTests {
    @Test func replacesOnlyMachKitManagedSection() throws {
        let current = """
        127.0.0.1 localhost

        # >>> MachKit managed hosts
        # old
        10.0.0.1 old.local
        # <<< MachKit managed hosts
        """
        let environment = HostsEnvironment(name: "Development", content: "10.0.0.2 api.local")
        let base = try HostsFileComposer.removingManagedSection(from: current)
            + "\n127.0.0.1 shared.local"
        let result = try HostsFileComposer.rendering(
            HostsDocument(
                unmanagedContent: base,
                environments: [environment],
                activeEnvironmentID: environment.id
            )
        )

        #expect(result.contains("127.0.0.1 localhost"))
        #expect(result.contains("127.0.0.1 shared.local"))
        #expect(result.contains("10.0.0.2 api.local"))
        #expect(!result.contains("old.local"))
        #expect(result.components(separatedBy: HostsFileComposer.startMarker).count == 2)
    }

    @Test func rejectsMalformedEntry() {
        #expect(throws: HostsFileError.invalidEntry(line: 2)) {
            try HostsFileComposer.validate("# comment\napi.local 10.0.0.1")
        }
    }

    @Test func acceptsIPv4AndIPv6Entries() throws {
        try HostsFileComposer.validate("127.0.0.1 api.local alias.local\n::1 ipv6.local")
    }

    @Test func refusesIncompleteManagedSection() {
        #expect(throws: HostsFileError.incompleteManagedSection) {
            try HostsFileComposer.removingManagedSection(
                from: "127.0.0.1 localhost\n\(HostsFileComposer.startMarker)\n"
            )
        }
    }

    @Test func rejectsUnknownManagedSectionFormat() {
        #expect(throws: HostsFileError.incompleteManagedSection) {
            try HostsFileComposer.parse(
                "\(HostsFileComposer.startMarker)\n# MachKit shared: obsolete\n\(HostsFileComposer.endMarker)"
            )
        }
    }

    @Test func writesOnlyTheActiveEnvironmentToHosts() throws {
        let development = HostsEnvironment(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Development",
            content: "10.0.0.1 api.dev.local"
        )
        let production = HostsEnvironment(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Production",
            content: "10.0.0.2 api.prod.local"
        )
        let document = HostsDocument(
            unmanagedContent: "127.0.0.1 localhost\n127.0.0.1 shared.local",
            environments: [development, production],
            activeEnvironmentID: development.id
        )

        let rendered = try HostsFileComposer.rendering(document)
        let parsed = try HostsFileComposer.parse(rendered)

        #expect(parsed.unmanagedContent.contains("127.0.0.1 shared.local"))
        #expect(parsed.environments.count == 1)
        #expect(parsed.environments[0].name == development.name)
        #expect(parsed.environments[0].content == development.content)
        #expect(rendered.contains("10.0.0.1 api.dev.local"))
        #expect(!rendered.contains("10.0.0.2 api.prod.local"))
        #expect(!rendered.contains(development.id.uuidString.uppercased()))
        #expect(!rendered.contains(production.id.uuidString.uppercased()))
    }

    @Test func hostsSectionStoresTheNameButNotTheApplicationIdentifier() throws {
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let document = HostsDocument(
            unmanagedContent: "127.0.0.1 localhost",
            environments: [HostsEnvironment(id: id, name: "Staging", content: "10.0.0.3 api.local")],
            activeEnvironmentID: id
        )
        let rendered = try HostsFileComposer.rendering(document)
        #expect(rendered.contains("# Environment: Staging"))
        #expect(!rendered.contains(id.uuidString))
    }

    @Test func emptyEnvironmentsAreNotWrittenToHosts() throws {
        let empty = HostsEnvironment(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Testing"
        )
        let document = HostsDocument(
            unmanagedContent: "127.0.0.1 localhost",
            environments: [empty],
            activeEnvironmentID: empty.id
        )

        let rendered = try HostsFileComposer.rendering(document)

        #expect(rendered == "127.0.0.1 localhost\n")
        #expect(!rendered.contains(HostsFileComposer.startMarker))
        #expect(!rendered.contains(empty.id.uuidString))
    }

    @Test func emptyEnvironmentIsOmittedBesideConfiguredEnvironments() throws {
        let configured = HostsEnvironment(name: "Development", content: "10.0.0.1 api.local")
        let empty = HostsEnvironment(name: "Testing")
        let document = HostsDocument(
            unmanagedContent: "127.0.0.1 localhost",
            environments: [configured, empty],
            activeEnvironmentID: configured.id
        )

        let parsed = try HostsFileComposer.parse(HostsFileComposer.rendering(document))

        #expect(parsed.environments.count == 1)
        #expect(parsed.environments[0].name == configured.name)
        #expect(parsed.environments[0].content == configured.content)
        #expect(!(try HostsFileComposer.rendering(document)).contains(empty.id.uuidString))
    }
}
