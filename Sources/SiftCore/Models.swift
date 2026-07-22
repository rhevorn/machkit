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
    case loopback = "仅本机"
    case network = "局域网"
    case allInterfaces = "所有网络"
}

public struct ListeningPort: Identifiable, Sendable, Hashable {
    public let id: String
    public let processIdentifier: Int32
    public let processName: String
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

public struct LoginApplication: Identifiable, Sendable, Hashable {
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

public struct RegisteredBackgroundTask: Identifiable, Sendable, Hashable {
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
    case userAgent = "用户启动项"
    case sharedAgent = "所有用户启动项"
    case daemon = "后台服务"

    public var explanation: String {
        switch self {
        case .userAgent: "登录当前账户时由 launchd 读取"
        case .sharedAgent: "登录任意账户时由 launchd 读取"
        case .daemon: "由系统在后台启动，修改通常需要管理员权限"
        }
    }
}

public enum ComponentAssessment: String, CaseIterable, Codable, Sendable {
    case present = "关联应用存在"
    case likelyResidue = "可能是卸载残留"
    case unknown = "需确认"

    public var explanation: String {
        switch self {
        case .present: "目标程序或所属应用仍然存在"
        case .likelyResidue: "配置仍在，但没有找到它指向的程序或所属应用"
        case .unknown: "缺少足够信息，删除前需要人工确认"
        }
    }
}

public struct LoginItem: Identifiable, Sendable, Hashable {
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
    case system = "系统扩展"
    case network = "网络扩展"
    case safari = "Safari 扩展"
    case finder = "Finder 扩展"
    case quickLook = "快速查看扩展"
    case spotlight = "Spotlight 导入器"
    case share = "共享扩展"
    case app = "应用扩展"
}

public struct InstalledExtension: Identifiable, Sendable, Hashable {
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

public struct ScanRule: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let relativePath: String
    public let minimumAgeDays: Int
    public let allowedExtensions: Set<String>
    public let risk: RiskLevel
    public let explanation: String

    public init(
        id: String,
        title: String,
        relativePath: String,
        minimumAgeDays: Int,
        allowedExtensions: Set<String> = [],
        risk: RiskLevel,
        explanation: String
    ) {
        self.id = id
        self.title = title
        self.relativePath = relativePath
        self.minimumAgeDays = minimumAgeDays
        self.allowedExtensions = allowedExtensions
        self.risk = risk
        self.explanation = explanation
    }
}

public struct ScanItem: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let bytes: Int64
    public let modifiedAt: Date?
    public let rule: ScanRule

    public init(id: UUID = UUID(), url: URL, bytes: Int64, modifiedAt: Date?, rule: ScanRule) {
        self.id = id
        self.url = url
        self.bytes = bytes
        self.modifiedAt = modifiedAt
        self.rule = rule
    }
}

public enum StorageCategoryKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case applications = "应用程序"
    case documents = "文稿"
    case downloads = "下载"
    case pictures = "图片"
    case music = "音乐"
    case movies = "影片"
    case developer = "开发文件"
    case systemData = "系统与应用数据"
    case other = "其他"

    public var id: String { rawValue }
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

public struct StorageAnalysis: Sendable, Hashable {
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let scannedBytes: Int64
    public let scannedFileCount: Int
    public let inaccessibleItemCount: Int
    public let categories: [StorageCategoryUsage]
    public let largeFiles: [ScanItem]
    public let analyzedRoots: [URL]

    public var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }

    public init(
        totalCapacity: Int64,
        availableCapacity: Int64,
        scannedBytes: Int64,
        scannedFileCount: Int,
        inaccessibleItemCount: Int,
        categories: [StorageCategoryUsage],
        largeFiles: [ScanItem],
        analyzedRoots: [URL]
    ) {
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.scannedBytes = scannedBytes
        self.scannedFileCount = scannedFileCount
        self.inaccessibleItemCount = inaccessibleItemCount
        self.categories = categories
        self.largeFiles = largeFiles
        self.analyzedRoots = analyzedRoots
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
    public let failures: [CleanFailure]

    public init(movedToTrash: [URL], failures: [CleanFailure]) {
        self.movedToTrash = movedToTrash
        self.failures = failures
    }
}

public struct CleanFailure: Sendable {
    public let url: URL
    public let reason: String
}

public struct InstalledApplication: Identifiable, Sendable, Hashable {
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

public enum CommandLineToolManager: String, Sendable, CaseIterable {
    case homebrew = "Homebrew"
    case homebrewCask = "Homebrew Cask"
    case npm = "npm 全局包"
    case pnpm = "pnpm 全局包"
    case yarn = "Yarn 全局包"
    case bun = "Bun 全局包"
    case pip = "pip 用户包"
    case pipx = "pipx"
    case uv = "uv tools"
    case conda = "Conda 环境"
    case cargo = "Cargo"
    case go = "Go 工具"
    case rubyGems = "RubyGems"
    case macPorts = "MacPorts"
    case nix = "Nix"
    case sdkman = "SDKMAN"
    case manual = "其他 PATH 工具"

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

public struct CommandLineTool: Identifiable, Sendable, Hashable {
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
    case cache = "缓存"
    case preferences = "偏好设置"
    case support = "应用数据"
    case state = "窗口状态"
    case logs = "日志"
    case container = "沙盒容器"
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
