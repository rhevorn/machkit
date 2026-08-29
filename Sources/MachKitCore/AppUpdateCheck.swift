import Foundation

/// Numeric marketing version used for GitHub release comparison.
public struct SemanticVersion: Comparable, Equatable, Sendable, Hashable {
    public let components: [Int]

    public init(components: [Int]) {
        self.components = components.isEmpty ? [0] : components
    }

    /// Parses `1.2.3`, `v1.2.3`, or values with a pre-release/build suffix (`1.2.3-beta`).
    public static func parse(_ raw: String) -> SemanticVersion? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.first == "v" || text.first == "V" {
            text = String(text.dropFirst())
        }
        let core = text.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? text
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var numbers: [Int] = []
        numbers.reserveCapacity(parts.count)
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            numbers.append(value)
        }
        return SemanticVersion(components: numbers)
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return false }
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        // Hash the normalized numeric identity so trailing zeros do not diverge.
        var end = components.count
        while end > 1, components[end - 1] == 0 {
            end -= 1
        }
        for index in 0..<end {
            hasher.combine(components[index])
        }
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

public struct GitHubLatestRelease: Equatable, Sendable {
    public let tagName: String
    public let version: SemanticVersion
    public let htmlURL: URL

    public init(tagName: String, version: SemanticVersion, htmlURL: URL) {
        self.tagName = tagName
        self.version = version
        self.htmlURL = htmlURL
    }
}

public enum AppUpdateStatus: Equatable, Sendable {
    case upToDate(current: String, latest: String)
    case updateAvailable(current: String, latest: String, releaseURL: URL)
}

public enum AppUpdateCheckError: Error, Equatable, Sendable {
    case invalidResponse
    case missingReleaseFields
    case unreadableLatestVersion(String)
    case httpStatus(Int)
}

public enum AppUpdateCheck {
    /// Public Atom feed — avoids `api.github.com`, which often returns 403 to unauthenticated clients.
    public static let releasesFeedURL = URL(string: "https://github.com/rhevorn/machkit/releases.atom")!
    public static let releasesPageURL = URL(string: "https://github.com/rhevorn/machkit/releases/latest")!

    /// Parses the newest entry from GitHub’s public releases Atom feed.
    public static func parseLatestRelease(fromAtom data: Data) throws -> GitHubLatestRelease {
        guard let text = String(data: data, encoding: .utf8) else {
            throw AppUpdateCheckError.invalidResponse
        }
        guard let entryStart = text.range(of: "<entry>"),
              let entryEnd = text.range(of: "</entry>", range: entryStart.upperBound..<text.endIndex) else {
            throw AppUpdateCheckError.missingReleaseFields
        }
        let entry = text[entryStart.lowerBound..<entryEnd.upperBound]
        guard let htmlURL = firstLinkHREF(in: entry) else {
            throw AppUpdateCheckError.missingReleaseFields
        }
        guard let tagName = tagName(fromReleaseURL: htmlURL) else {
            throw AppUpdateCheckError.unreadableLatestVersion(htmlURL.absoluteString)
        }
        guard let version = SemanticVersion.parse(tagName) else {
            throw AppUpdateCheckError.unreadableLatestVersion(tagName)
        }
        return GitHubLatestRelease(tagName: tagName, version: version, htmlURL: htmlURL)
    }

    public static func tagName(fromReleaseURL url: URL) -> String? {
        let parts = url.path.split(separator: "/")
        // /rhevorn/machkit/releases/tag/v2.2.5
        guard parts.count >= 2,
              parts[parts.count - 2] == "tag" else { return nil }
        let tag = String(parts[parts.count - 1])
        return tag.isEmpty ? nil : tag
    }

    public static func status(
        currentVersionRaw: String,
        latest: GitHubLatestRelease
    ) -> AppUpdateStatus {
        let currentDisplay = displayVersion(currentVersionRaw)
        let latestDisplay = displayVersion(latest.tagName)
        guard let current = SemanticVersion.parse(currentVersionRaw) else {
            // Development / non-semver builds still surface the latest published release.
            return .updateAvailable(
                current: currentDisplay,
                latest: latestDisplay,
                releaseURL: latest.htmlURL
            )
        }
        if current < latest.version {
            return .updateAvailable(
                current: currentDisplay,
                latest: latestDisplay,
                releaseURL: latest.htmlURL
            )
        }
        return .upToDate(current: currentDisplay, latest: latestDisplay)
    }

    public static func displayVersion(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" {
            text = String(text.dropFirst())
        }
        return text.isEmpty ? raw : text
    }

    private static func firstLinkHREF(in entry: Substring) -> URL? {
        // Prefer release tag links: <link ... href=".../releases/tag/vX.Y.Z"/>
        let text = String(entry)
        let pattern = #"href="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: nsRange) {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: text),
                  let url = URL(string: String(text[range])),
                  url.path.contains("/releases/tag/") else { continue }
            return url
        }
        return nil
    }
}
