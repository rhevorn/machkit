import Foundation

public enum SafetyPolicy {
    private static let forbiddenComponents: Set<String> = [
        ".ssh", ".gnupg", "Keychains", "Mail", "Messages", "Photos Library.photoslibrary"
    ]

    public static func validate(rule: ScanRule, root: URL) throws -> URL {
        guard !rule.relativePath.hasPrefix("/"), !rule.relativePath.contains("..") else {
            throw SafetyError.unsafeRule(rule.relativePath)
        }

        let components = Set(rule.relativePath.split(separator: "/").map(String.init))
        guard forbiddenComponents.isDisjoint(with: components), rule.risk != .blocked else {
            throw SafetyError.forbiddenLocation(rule.relativePath)
        }

        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let target = canonicalRoot.appending(path: rule.relativePath).standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard target.path.hasPrefix(prefix) else { throw SafetyError.outsideSelectedRoot }
        return target
    }

    public static func validateForCleaning(item: ScanItem, selectedRoot: URL) throws {
        let canonicalRoot = selectedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalItem = item.url.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
        guard canonicalItem.path.hasPrefix(prefix), canonicalItem != canonicalRoot else {
            throw SafetyError.outsideSelectedRoot
        }
        guard item.rule.risk != .blocked else { throw SafetyError.forbiddenLocation(item.url.path) }
    }
}

public enum SafetyError: LocalizedError {
    case unsafeRule(String)
    case forbiddenLocation(String)
    case outsideSelectedRoot

    public var errorDescription: String? {
        switch self {
        case .unsafeRule(let path): "不安全的扫描规则：\(path)"
        case .forbiddenLocation(let path): "禁止扫描的位置：\(path)"
        case .outsideSelectedRoot: "目标超出用户选择的目录"
        }
    }
}
