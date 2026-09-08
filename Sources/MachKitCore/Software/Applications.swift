import Foundation

public struct InstalledApplication: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let bytes: Int64

    public init(name: String, bundleURL: URL, bundleIdentifier: String?, version: String?, bytes: Int64) {
        self.id = bundleURL.path
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.bytes = bytes
    }
}
