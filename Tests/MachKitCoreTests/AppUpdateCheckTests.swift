import Foundation
import Testing
@testable import MachKitCore

@Test func semanticVersionParsesTagsAndCompares() {
    #expect(SemanticVersion.parse("v2.2.5") == SemanticVersion(components: [2, 2, 5]))
    #expect(SemanticVersion.parse("1.0") == SemanticVersion(components: [1, 0]))
    #expect(SemanticVersion.parse("1.2.3-beta") == SemanticVersion(components: [1, 2, 3]))
    #expect(SemanticVersion.parse("dev") == nil)
    #expect(SemanticVersion.parse("") == nil)
    #expect(SemanticVersion.parse("v1.2.3")! < SemanticVersion.parse("v1.2.4")!)
    #expect(SemanticVersion.parse("1.2")! < SemanticVersion.parse("1.2.1")!)
    #expect(SemanticVersion.parse("2.0.0")! > SemanticVersion.parse("1.9.9")!)
    #expect(SemanticVersion.parse("1.2.0")! == SemanticVersion.parse("1.2")!)
}

@Test func appUpdateCheckParsesGitHubReleasesAtomFeed() throws {
    let atom = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Release notes from machkit</title>
      <entry>
        <id>tag:github.com,2008:Repository/1/v2.2.5</id>
        <link rel="alternate" type="text/html" href="https://github.com/rhevorn/machkit/releases/tag/v2.2.5"/>
        <title>MachKit v2.2.5</title>
      </entry>
      <entry>
        <link rel="alternate" type="text/html" href="https://github.com/rhevorn/machkit/releases/tag/v2.2.4"/>
        <title>MachKit v2.2.4</title>
      </entry>
    </feed>
    """.data(using: .utf8)!
    let release = try AppUpdateCheck.parseLatestRelease(fromAtom: atom)
    #expect(release.tagName == "v2.2.5")
    #expect(release.version == SemanticVersion(components: [2, 2, 5]))
    #expect(release.htmlURL.absoluteString == "https://github.com/rhevorn/machkit/releases/tag/v2.2.5")
}

@Test func appUpdateCheckRejectsMalformedAtomFeed() {
    #expect(throws: AppUpdateCheckError.invalidResponse) {
        // Non-UTF8 payload
        try AppUpdateCheck.parseLatestRelease(fromAtom: Data([0xFF, 0xFE, 0xFD]))
    }
    #expect(throws: AppUpdateCheckError.missingReleaseFields) {
        try AppUpdateCheck.parseLatestRelease(fromAtom: Data("<feed></feed>".utf8))
    }
    let badLink = Data("""
    <feed><entry><link href="https://example.com/not-a-release"/></entry></feed>
    """.utf8)
    #expect(throws: AppUpdateCheckError.missingReleaseFields) {
        try AppUpdateCheck.parseLatestRelease(fromAtom: badLink)
    }
}

@Test func appUpdateStatusComparesCurrentAgainstLatest() throws {
    let latest = try AppUpdateCheck.parseLatestRelease(fromAtom: Data("""
    <feed><entry>
      <link href="https://github.com/rhevorn/machkit/releases/tag/v2.2.5"/>
    </entry></feed>
    """.utf8))

    #expect(AppUpdateCheck.status(currentVersionRaw: "2.2.5", latest: latest) == .upToDate(current: "2.2.5", latest: "2.2.5"))
    #expect(AppUpdateCheck.status(currentVersionRaw: "2.2.6", latest: latest) == .upToDate(current: "2.2.6", latest: "2.2.5"))
    #expect(
        AppUpdateCheck.status(currentVersionRaw: "2.1.0", latest: latest)
            == .updateAvailable(
                current: "2.1.0",
                latest: "2.2.5",
                releaseURL: latest.htmlURL
            )
    )
    #expect(
        AppUpdateCheck.status(currentVersionRaw: "dev", latest: latest)
            == .updateAvailable(
                current: "dev",
                latest: "2.2.5",
                releaseURL: latest.htmlURL
            )
    )
}

@Test func appUpdateCheckExtractsTagFromReleaseURL() {
    let url = URL(string: "https://github.com/rhevorn/machkit/releases/tag/v2.2.5")!
    #expect(AppUpdateCheck.tagName(fromReleaseURL: url) == "v2.2.5")
    #expect(AppUpdateCheck.tagName(fromReleaseURL: URL(string: "https://github.com/rhevorn/machkit/releases")!) == nil)
}
