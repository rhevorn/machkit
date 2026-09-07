import Foundation

public enum InstalledExtensionKind: String, CaseIterable, Codable, Sendable {
    case system = "System expansion"
    case network = "network extension"
    case safari = "Safari extension"
    case finder = "Finder extension"
    case quickLook = "Quick view extension"
    case spotlight = "Spotlight Importer"
    case share = "Shared extension"
    case app = "Application extension"
}

public struct InstalledExtension: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let kind: InstalledExtensionKind
    public let ownerName: String?
    public let ownerApplicationURL: URL?
    public let assessment: ComponentAssessment

    public init(
        name: String,
        bundleURL: URL,
        bundleIdentifier: String?,
        version: String?,
        kind: InstalledExtensionKind,
        ownerName: String?,
        ownerApplicationURL: URL? = nil,
        assessment: ComponentAssessment = .unknown
    ) {
        self.id = bundleURL.standardizedFileURL.path
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.kind = kind
        self.ownerName = ownerName
        self.ownerApplicationURL = ownerApplicationURL
        self.assessment = assessment
    }
}
