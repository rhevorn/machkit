import Foundation

public enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case safe
    case review
    case blocked
}

public enum NetworkTransport: String, CaseIterable, Codable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
}

public enum PortExposure: String, CaseIterable, Codable, Sendable {
    case loopback = "Local Only"
    case network = "Local Network"
    case allInterfaces = "All Interfaces"
}

public struct ListeningPort: Identifiable, Sendable, Hashable {
    public let id: String
    public let processIdentifier: Int32
    public let processName: String
    public let processDescription: String
    public let ownerUserID: UInt32
    public let transport: NetworkTransport
    public let localAddress: String
    public let port: UInt16
    public let exposure: PortExposure
    public let executableURL: URL?
    public let workingDirectoryURL: URL?
    public let commandLine: String?
    public let canTerminate: Bool
    public let protectionReason: String?

    public init(
        processIdentifier: Int32,
        processName: String,
        processDescription: String,
        ownerUserID: UInt32,
        transport: NetworkTransport,
        localAddress: String,
        port: UInt16,
        exposure: PortExposure,
        executableURL: URL?,
        workingDirectoryURL: URL?,
        commandLine: String?,
        canTerminate: Bool,
        protectionReason: String?
    ) {
        self.id = "\(processIdentifier)|\(transport.rawValue)|\(localAddress)|\(port)"
        self.processIdentifier = processIdentifier
        self.processName = processName
        self.processDescription = processDescription
        self.ownerUserID = ownerUserID
        self.transport = transport
        self.localAddress = localAddress
        self.port = port
        self.exposure = exposure
        self.executableURL = executableURL
        self.workingDirectoryURL = workingDirectoryURL
        self.commandLine = commandLine
        self.canTerminate = canTerminate
        self.protectionReason = protectionReason
    }
}

public struct PortScanResult: Sendable {
    public let ports: [ListeningPort]
    public let errorMessage: String?

    public init(ports: [ListeningPort], errorMessage: String? = nil) {
        self.ports = ports
        self.errorMessage = errorMessage
    }
}

public enum NetworkInterfaceKind: String, Codable, Sendable, CaseIterable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case tunnel = "VPN / TUN"
    case loopback = "Loopback"
    case bridge = "Bridge"
    case other = "Other"
}

public struct NetworkInterfaceUsage: Identifiable, Sendable, Hashable {
    public let name: String
    public let displayName: String
    public let kind: NetworkInterfaceKind
    public let isUp: Bool
    public let addresses: [String]
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public var id: String { name }

    public init(
        name: String,
        displayName: String,
        kind: NetworkInterfaceKind,
        isUp: Bool,
        addresses: [String],
        receivedBytes: UInt64,
        sentBytes: UInt64,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.name = name
        self.displayName = displayName
        self.kind = kind
        self.isUp = isUp
        self.addresses = addresses
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

public struct NetworkTransferRate: Sendable, Hashable {
    public let sampledAt: Date
    public let interfaceName: String?
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public init(
        sampledAt: Date,
        interfaceName: String?,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.sampledAt = sampledAt
        self.interfaceName = interfaceName
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

public struct NetworkProcessUsage: Identifiable, Sendable, Hashable {
    public let processIdentifier: Int32
    public let name: String
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    public let connectionCount: Int

    public var id: Int32 { processIdentifier }

    public init(
        processIdentifier: Int32,
        name: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double,
        connectionCount: Int
    ) {
        self.processIdentifier = processIdentifier
        self.name = name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.connectionCount = connectionCount
    }
}

public struct NetworkConnection: Identifiable, Sendable, Hashable {
    public let id: String
    public let processIdentifier: Int32
    public let processName: String
    public let transport: NetworkTransport
    public let localAddress: String
    public let localPort: UInt16?
    public let remoteAddress: String?
    public let remotePort: UInt16?
    public let state: String?
    public let interfaceName: String?
    public let isListener: Bool

    public init(
        processIdentifier: Int32,
        processName: String,
        transport: NetworkTransport,
        localAddress: String,
        localPort: UInt16?,
        remoteAddress: String?,
        remotePort: UInt16?,
        state: String?,
        interfaceName: String?,
        isListener: Bool
    ) {
        self.id = [
            String(processIdentifier), transport.rawValue, localAddress,
            localPort.map(String.init) ?? "", remoteAddress ?? "",
            remotePort.map(String.init) ?? "", state ?? ""
        ].joined(separator: "|")
        self.processIdentifier = processIdentifier
        self.processName = processName
        self.transport = transport
        self.localAddress = localAddress
        self.localPort = localPort
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.state = state
        self.interfaceName = interfaceName
        self.isListener = isListener
    }
}

public struct NetworkRoute: Identifiable, Sendable, Hashable {
    public let destination: String
    public let gateway: String
    public let flags: String
    public let interfaceName: String
    public let family: String

    public var id: String { "\(family)|\(destination)|\(gateway)|\(interfaceName)" }
    public var isDefault: Bool { destination == "default" }

    public init(destination: String, gateway: String, flags: String, interfaceName: String, family: String) {
        self.destination = destination
        self.gateway = gateway
        self.flags = flags
        self.interfaceName = interfaceName
        self.family = family
    }
}

public struct NetworkProxyConfiguration: Sendable, Hashable {
    public let services: [String]

    public var isEnabled: Bool { !services.isEmpty }
    public var summary: String { services.isEmpty ? "Direct Connection" : services.joined(separator: " · ") }

    public init(services: [String]) {
        self.services = services
    }
}

public struct NetworkRouteLookup: Sendable, Hashable {
    public let query: String
    public let destination: String
    public let gateway: String?
    public let interfaceName: String?
    public let errorMessage: String?

    public init(query: String, destination: String, gateway: String?, interfaceName: String?, errorMessage: String? = nil) {
        self.query = query
        self.destination = destination
        self.gateway = gateway
        self.interfaceName = interfaceName
        self.errorMessage = errorMessage
    }
}

public struct NetworkSnapshot: Sendable {
    public let sampledAt: Date
    public let interfaces: [NetworkInterfaceUsage]
    public let processes: [NetworkProcessUsage]
    public let connections: [NetworkConnection]
    public let routes: [NetworkRoute]
    public let defaultRoute: NetworkRouteLookup?
    public let proxy: NetworkProxyConfiguration
    public let errors: [String]

    public init(
        sampledAt: Date,
        interfaces: [NetworkInterfaceUsage],
        processes: [NetworkProcessUsage],
        connections: [NetworkConnection],
        routes: [NetworkRoute],
        defaultRoute: NetworkRouteLookup?,
        proxy: NetworkProxyConfiguration,
        errors: [String] = []
    ) {
        self.sampledAt = sampledAt
        self.interfaces = interfaces
        self.processes = processes
        self.connections = connections
        self.routes = routes
        self.defaultRoute = defaultRoute
        self.proxy = proxy
        self.errors = errors
    }
}

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

public enum ScanEnumerationMode: String, Codable, Sendable, Hashable {
    /// Recurse and match aged regular files (default).
    case agedFiles
    /// Immediate children of each scan root as removable units (files or directories).
    case topLevelEntries
    /// CoreSimulator device directories that `simctl` reports as unavailable.
    case unavailableSimulatorDevices
}

public struct ScanRule: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let relativePaths: [String]
    public let minimumAgeDays: Int
    public let allowedExtensions: Set<String>
    public let excludedRelativePaths: Set<String>
    public let enumerationMode: ScanEnumerationMode
    public let risk: RiskLevel
    public let explanation: String

    /// First scan root; kept for callers and tests that expect a single path.
    public var relativePath: String { relativePaths[0] }

    public init(
        id: String,
        title: String,
        relativePath: String,
        minimumAgeDays: Int,
        allowedExtensions: Set<String> = [],
        excludedRelativePaths: Set<String> = [],
        enumerationMode: ScanEnumerationMode = .agedFiles,
        risk: RiskLevel,
        explanation: String
    ) {
        self.init(
            id: id,
            title: title,
            relativePaths: [relativePath],
            minimumAgeDays: minimumAgeDays,
            allowedExtensions: allowedExtensions,
            excludedRelativePaths: excludedRelativePaths,
            enumerationMode: enumerationMode,
            risk: risk,
            explanation: explanation
        )
    }

    public init(
        id: String,
        title: String,
        relativePaths: [String],
        minimumAgeDays: Int,
        allowedExtensions: Set<String> = [],
        excludedRelativePaths: Set<String> = [],
        enumerationMode: ScanEnumerationMode = .agedFiles,
        risk: RiskLevel,
        explanation: String
    ) {
        precondition(!relativePaths.isEmpty, "ScanRule requires at least one relative path")
        self.id = id
        self.title = title
        self.relativePaths = relativePaths
        self.minimumAgeDays = minimumAgeDays
        self.allowedExtensions = allowedExtensions
        self.excludedRelativePaths = excludedRelativePaths
        self.enumerationMode = enumerationMode
        self.risk = risk
        self.explanation = explanation
    }
}

public struct ScanItem: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let bytes: Int64
    /// Matched files represented by this row (1 for a single file entry).
    public let fileCount: Int
    public let modifiedAt: Date?
    public let rule: ScanRule

    public init(
        id: UUID = UUID(),
        url: URL,
        bytes: Int64,
        fileCount: Int = 1,
        modifiedAt: Date?,
        rule: ScanRule
    ) {
        self.id = id
        self.url = url
        self.bytes = bytes
        self.fileCount = max(1, fileCount)
        self.modifiedAt = modifiedAt
        self.rule = rule
    }
}

public enum StorageCategoryKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case applications = "application"
    case documents = "Manuscript"
    case downloads = "Download"
    case pictures = "pictures"
    case music = "music"
    case movies = "Video"
    case developer = "development files"
    case systemData = "System and application data"
    case other = "Others"

    public var id: String { rawValue }

    /// Stable English title used as a localization key in the app.
    public var titleKey: String {
        switch self {
        case .applications: "Applications"
        case .documents: "Documents"
        case .downloads: "Downloads"
        case .pictures: "Pictures"
        case .music: "Music"
        case .movies: "Movies"
        case .developer: "Developer"
        case .systemData: "System Data"
        case .other: "Other"
        }
    }
}

public struct StorageCategoryUsage: Identifiable, Sendable, Hashable {
    public let category: StorageCategoryKind
    public let bytes: Int64
    public let fileCount: Int

    public var id: StorageCategoryKind { category }

    public init(category: StorageCategoryKind, bytes: Int64, fileCount: Int) {
        self.category = category
        self.bytes = bytes
        self.fileCount = fileCount
    }
}

public struct StorageDirectoryUsage: Identifiable, Sendable, Hashable, Codable {
    public let url: URL
    public let bytes: Int64
    public let explanation: String

    public var id: String { url.standardizedFileURL.path }

    public init(url: URL, bytes: Int64, explanation: String) {
        self.url = url
        self.bytes = bytes
        self.explanation = explanation
    }
}

public struct StorageAnalysis: Sendable, Hashable {
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let scannedBytes: Int64
    public let scannedFileCount: Int
    public let inaccessibleItemCount: Int
    public let categories: [StorageCategoryUsage]
    public let largeFiles: [ScanItem]
    public let analyzedRoots: [URL]
    public let directories: [StorageDirectoryUsage]

    public var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }

    public init(
        totalCapacity: Int64,
        availableCapacity: Int64,
        scannedBytes: Int64,
        scannedFileCount: Int,
        inaccessibleItemCount: Int,
        categories: [StorageCategoryUsage],
        largeFiles: [ScanItem],
        analyzedRoots: [URL],
        directories: [StorageDirectoryUsage] = []
    ) {
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.scannedBytes = scannedBytes
        self.scannedFileCount = scannedFileCount
        self.inaccessibleItemCount = inaccessibleItemCount
        self.categories = categories
        self.largeFiles = largeFiles
        self.analyzedRoots = analyzedRoots
        self.directories = directories
    }
}

public struct StorageAnalysisProgress: Sendable, Hashable {
    public let currentRoot: URL
    public let inspectedFiles: Int
    public let scannedBytes: Int64

    public init(currentRoot: URL, inspectedFiles: Int, scannedBytes: Int64) {
        self.currentRoot = currentRoot
        self.inspectedFiles = inspectedFiles
        self.scannedBytes = scannedBytes
    }
}

public struct CleanResult: Sendable {
    public let movedToTrash: [URL]
    public let permanentlyDeleted: [URL]
    public let failures: [CleanFailure]

    public init(movedToTrash: [URL], permanentlyDeleted: [URL] = [], failures: [CleanFailure]) {
        self.movedToTrash = movedToTrash
        self.permanentlyDeleted = permanentlyDeleted
        self.failures = failures
    }

    public var removedCount: Int { movedToTrash.count + permanentlyDeleted.count }
}

public struct CleanFailure: Sendable {
    public let url: URL
    public let reason: String
}

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

public enum CommandLineToolManager: String, Sendable, CaseIterable, Codable {
    case homebrew = "Homebrew"
    case homebrewCask = "Homebrew Cask"
    case npm = "npm global package"
    case pnpm = "pnpm global package"
    case yarn = "Yarn global package"
    case bun = "Bun global package"
    case pip = "pip user package"
    case pipx = "pipx"
    case uv = "uv tools"
    case conda = "Conda environment"
    case cargo = "Cargo"
    case go = "Go tools"
    case rubyGems = "RubyGems"
    case macPorts = "MacPorts"
    case nix = "Nix"
    case sdkman = "SDKMAN"
    case manual = "Other PATH tools"

    public func uninstallCommand(name: String, version: String?) -> String? {
        switch self {
        case .homebrew: "brew uninstall \(name)"
        case .homebrewCask: "brew uninstall --cask \(name)"
        case .npm: "npm uninstall -g \(name)"
        case .pnpm: "pnpm remove -g \(name)"
        case .yarn: "yarn global remove \(name)"
        case .bun: "bun remove -g \(name)"
        case .pip: "python3 -m pip uninstall \(name)"
        case .pipx: "pipx uninstall \(name)"
        case .uv: "uv tool uninstall \(name)"
        case .conda: "conda env remove -n \(name)"
        case .cargo: "cargo uninstall \(name)"
        case .go: nil
        case .rubyGems: "gem uninstall \(name)"
        case .macPorts: "sudo port uninstall \(name)"
        case .nix: "nix profile remove \(name)"
        case .sdkman:
            version.map { "sdk uninstall \(name) \($0)" }
        case .manual: nil
        }
    }
}

public struct CommandLineTool: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let version: String?
    public let installURL: URL
    public let manager: CommandLineToolManager
    public let bytes: Int64

    public init(name: String, version: String?, installURL: URL, manager: CommandLineToolManager, bytes: Int64) {
        self.id = installURL.path
        self.name = name
        self.version = version
        self.installURL = installURL
        self.manager = manager
        self.bytes = bytes
    }
}

public enum ResidueKind: String, Sendable {
    case cache = "cache"
    case preferences = "Preferences"
    case support = "application data"
    case state = "window status"
    case logs = "Log"
    case container = "sandbox container"
}

public struct ApplicationResidue: Identifiable, Sendable, Hashable {
    public let id: String
    public let url: URL
    public let kind: ResidueKind
    public let bytes: Int64
    public let risk: RiskLevel

    public init(url: URL, kind: ResidueKind, bytes: Int64, risk: RiskLevel) {
        self.id = url.path
        self.url = url
        self.kind = kind
        self.bytes = bytes
        self.risk = risk
    }
}

public struct ApplicationResidueGroup: Identifiable, Sendable, Hashable {
    public let identifier: String
    public let residues: [ApplicationResidue]

    public var id: String { identifier }
    public var bytes: Int64 { residues.reduce(0) { $0 + $1.bytes } }

    public init(identifier: String, residues: [ApplicationResidue]) {
        self.identifier = identifier
        self.residues = residues
    }
}

public struct ApplicationResidueScanProgress: Sendable {
    public let completedPaths: Int
    public let totalPaths: Int
    public let inspectedFiles: Int
    public let currentPathInspectedFiles: Int

    public var fractionCompleted: Double {
        guard totalPaths > 0 else { return 1 }
        let activity: Double
        if currentPathInspectedFiles > 0 {
            activity = min(0.9, 0.12 + log10(Double(currentPathInspectedFiles) + 1) * 0.13)
        } else {
            activity = 0
        }
        return min((Double(completedPaths) + activity) / Double(totalPaths), 1)
    }

    public init(completedPaths: Int, totalPaths: Int, inspectedFiles: Int, currentPathInspectedFiles: Int) {
        self.completedPaths = completedPaths
        self.totalPaths = totalPaths
        self.inspectedFiles = inspectedFiles
        self.currentPathInspectedFiles = currentPathInspectedFiles
    }
}
