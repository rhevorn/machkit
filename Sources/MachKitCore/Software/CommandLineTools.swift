import Foundation

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
