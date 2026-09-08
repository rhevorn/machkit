import Foundation

public struct LoginApplication: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let applicationURL: URL?
    public let isHidden: Bool
    public let assessment: ComponentAssessment

    public init(name: String, applicationURL: URL?, isHidden: Bool, assessment: ComponentAssessment) {
        self.id = applicationURL?.standardizedFileURL.path ?? name
        self.name = name
        self.applicationURL = applicationURL
        self.isHidden = isHidden
        self.assessment = assessment
    }
}

public struct LoginApplicationScanResult: Sendable {
    public let items: [LoginApplication]
    public let errorMessage: String?

    public init(items: [LoginApplication], errorMessage: String? = nil) {
        self.items = items
        self.errorMessage = errorMessage
    }
}

public struct RegisteredBackgroundTask: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let teamIdentifier: String?
    public let applicationURL: URL?
    public let isEnabled: Bool
    public let assessment: ComponentAssessment

    public init(
        id: String,
        name: String,
        bundleIdentifier: String?,
        teamIdentifier: String?,
        applicationURL: URL?,
        isEnabled: Bool,
        assessment: ComponentAssessment
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.applicationURL = applicationURL
        self.isEnabled = isEnabled
        self.assessment = assessment
    }

    public func isRemovableTrashResidue(home: URL) -> Bool {
        guard assessment == .likelyResidue, let applicationURL else { return false }
        let trashPath = home
            .appending(path: ".Trash", directoryHint: .isDirectory)
            .standardizedFileURL.path + "/"
        return applicationURL.standardizedFileURL.path.hasPrefix(trashPath)
    }
}

public struct BackgroundTaskScanResult: Sendable {
    public let items: [RegisteredBackgroundTask]
    public let errorMessage: String?

    public init(items: [RegisteredBackgroundTask], errorMessage: String? = nil) {
        self.items = items
        self.errorMessage = errorMessage
    }
}

public enum LoginItemDomain: String, CaseIterable, Codable, Sendable {
    case userAgent = "user-initiated items"
    case sharedAgent = "All user startup items"
    case daemon = "Background service"

    public var explanation: String {
        switch self {
        case .userAgent: "Read by launchd when logging into the current account"
        case .sharedAgent: "Read by launchd when logging in to any account"
        case .daemon: "Started by the system in the background, modification usually requires administrator rights"
        }
    }
}

public enum ComponentAssessment: String, CaseIterable, Codable, Sendable {
    case present = "Related App Present"
    case likelyResidue = "Possible Uninstall Leftover"
    case unknown = "Review"

    public var explanation: String {
        switch self {
        case .present: "The target program or owning app is still present"
        case .likelyResidue: "The configuration remains, but its target program or owning app was not found"
        case .unknown: "Not enough information; review before deleting"
        }
    }
}

public struct LoginItem: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let label: String
    public let configURL: URL
    public let executableURL: URL?
    public let domain: LoginItemDomain
    public let runsAtLoad: Bool
    public let keepsAlive: Bool
    public let assessment: ComponentAssessment

    public init(
        label: String,
        configURL: URL,
        executableURL: URL?,
        domain: LoginItemDomain,
        runsAtLoad: Bool,
        keepsAlive: Bool,
        assessment: ComponentAssessment = .unknown
    ) {
        self.id = configURL.standardizedFileURL.path
        self.label = label
        self.configURL = configURL
        self.executableURL = executableURL
        self.domain = domain
        self.runsAtLoad = runsAtLoad
        self.keepsAlive = keepsAlive
        self.assessment = assessment
    }
}
