import Darwin
import Foundation
import Security
import MachKitPrivilegedShim

public struct HostsEnvironment: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var content: String

    public init(id: UUID = UUID(), name: String, content: String = "") {
        self.id = id
        self.name = name
        self.content = content
    }
}

public struct HostsContentsResult: Sendable {
    public let content: String
    public let errorMessage: String?

    public init(content: String, errorMessage: String? = nil) {
        self.content = content
        self.errorMessage = errorMessage
    }
}

public struct HostsDocument: Equatable, Sendable {
    public var unmanagedContent: String
    public var environments: [HostsEnvironment]
    public var activeEnvironmentID: UUID?

    public init(
        unmanagedContent: String,
        environments: [HostsEnvironment] = [],
        activeEnvironmentID: UUID? = nil
    ) {
        self.unmanagedContent = unmanagedContent
        self.environments = environments
        self.activeEnvironmentID = activeEnvironmentID
    }
}

public enum HostsFileError: LocalizedError, Equatable, Sendable {
    case incompleteManagedSection
    case reservedMarker
    case invalidEntry(line: Int)
    case authorizationCancelled
    case authorizationFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .incompleteManagedSection:
            "The MachKit section in /etc/hosts is incomplete. Remove the broken markers manually and try again."
        case .reservedMarker:
            "Host entries cannot contain MachKit's reserved section markers."
        case let .invalidEntry(line):
            "Line \(line) is not a valid hosts entry. Use an IP address followed by one or more host names."
        case .authorizationCancelled:
            "Administrator authorization was cancelled."
        case let .authorizationFailed(detail):
            "Administrator authorization failed: \(detail)"
        case let .writeFailed(detail):
            "Unable to update /etc/hosts: \(detail)"
        }
    }
}

public enum HostsFileComposer {
    public static let startMarker = "# >>> MachKit managed hosts"
    public static let endMarker = "# <<< MachKit managed hosts"
    private static let environmentPrefix = "# Environment: "

    public static func validate(_ content: String) throws {
        guard !content.contains(startMarker), !content.contains(endMarker) else {
            throw HostsFileError.reservedMarker
        }

        for (index, rawLine) in content.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 2, isIPAddress(String(fields[0])) else {
                throw HostsFileError.invalidEntry(line: index + 1)
            }
        }
    }

    public static func parse(_ content: String) throws -> HostsDocument {
        let lines = content.components(separatedBy: .newlines)
        guard let managedRange = try managedRange(in: lines) else {
            return HostsDocument(unmanagedContent: content)
        }
        let start = managedRange.lowerBound
        let end = managedRange.upperBound

        let unmanaged = Array(lines[..<start]) + Array(lines[(end + 1)...])
        let section = Array(lines[(start + 1)..<end])
        guard let environmentHeader = section.first,
              environmentHeader.hasPrefix(environmentPrefix) else {
            throw HostsFileError.incompleteManagedSection
        }
        let name = String(environmentHeader.dropFirst(environmentPrefix.count))
        guard !name.isEmpty else { throw HostsFileError.incompleteManagedSection }
        let environment = HostsEnvironment(
            name: name,
            content: section.dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return HostsDocument(
            unmanagedContent: unmanaged.joined(separator: "\n"),
            environments: [environment],
            activeEnvironmentID: environment.id
        )
    }

    public static func rendering(_ document: HostsDocument) throws -> String {
        try validate(document.unmanagedContent)
        for environment in document.environments { try validate(environment.content) }
        if let activeID = document.activeEnvironmentID,
           !document.environments.contains(where: { $0.id == activeID }) {
            throw HostsFileError.writeFailed("The active environment no longer exists.")
        }

        let base = normalized(try removingManagedSection(from: document.unmanagedContent))
        let active = document.activeEnvironmentID.flatMap { activeID in
            document.environments.first(where: { $0.id == activeID })
        }
        let section = active.flatMap { environment in
            normalized(environment.content).isEmpty ? nil : managedSection(environment)
        }
        return [base, section].compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n") + "\n"
    }

    public static func removingManagedSection(from content: String) throws -> String {
        let lines = content.components(separatedBy: .newlines)
        guard let managedRange = try managedRange(in: lines) else { return content }

        var result = lines
        result.removeSubrange(managedRange)
        return result.joined(separator: "\n")
    }

    private static func managedRange(in lines: [String]) throws -> ClosedRange<Int>? {
        let start = lines.firstIndex(of: startMarker)
        let end = lines.firstIndex(of: endMarker)
        guard start != nil || end != nil else { return nil }
        guard let start, let end, start <= end else {
            throw HostsFileError.incompleteManagedSection
        }
        return start...end
    }

    private static func managedSection(_ environment: HostsEnvironment) -> String {
        var lines = [startMarker, "# Environment: \(environment.name)"]
        let content = normalized(environment.content)
        if !content.isEmpty { lines.append(content) }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    private static func normalized(_ content: String) -> String {
        content.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isIPAddress(_ value: String) -> Bool {
        var ipv4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 { return true }
        var ipv6 = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &ipv6) } == 1
    }
}

private final class HostsAuthorizationSession: @unchecked Sendable {
    var reference: AuthorizationRef?

    deinit {
        if let reference { AuthorizationFree(reference, []) }
    }
}

public actor HostsSystemService {
    private let fileManager: FileManager
    private let hostsURL: URL
    private let authorizationSession = HostsAuthorizationSession()

    public init(
        fileManager: FileManager = .default,
        hostsURL: URL = URL(fileURLWithPath: "/etc/hosts")
    ) {
        self.fileManager = fileManager
        self.hostsURL = hostsURL
    }

    public func currentContents() throws -> String {
        try String(contentsOf: hostsURL, encoding: .utf8)
    }

    public func currentContentsResult() -> HostsContentsResult {
        do {
            return HostsContentsResult(content: try currentContents())
        } catch {
            return HostsContentsResult(content: "", errorMessage: error.localizedDescription)
        }
    }

    public func apply(document: HostsDocument) -> HostsFileError? {
        do {
            try performReplacement(HostsFileComposer.rendering(document))
            return nil
        } catch let error as HostsFileError {
            return error
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    public func restore(contents: String) -> HostsFileError? {
        do {
            try performReplacement(contents)
            return nil
        } catch let error as HostsFileError {
            return error
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    private func performReplacement(_ replacement: String) throws {
        let temporaryURL = fileManager.temporaryDirectory
            .appending(path: "machkit-hosts-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        do {
            try replacement.write(to: temporaryURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: temporaryURL.path)
        } catch {
            throw HostsFileError.writeFailed(error.localizedDescription)
        }

        let authorization = try authorizationReference()
        var communicationsPipe: UnsafeMutablePointer<FILE>?
        let executeStatus = temporaryURL.path.withCString { sourcePath in
            MachKitReplaceHostsFile(authorization, sourcePath, &communicationsPipe)
        }
        guard executeStatus == errAuthorizationSuccess else {
            if executeStatus == errAuthorizationCanceled { throw HostsFileError.authorizationCancelled }
            throw HostsFileError.authorizationFailed(securityMessage(executeStatus))
        }

        if let communicationsPipe {
            _ = FileHandle(fileDescriptor: fileno(communicationsPipe), closeOnDealloc: true)
                .readDataToEndOfFile()
        }

        do {
            guard try currentContents() == replacement else {
                throw HostsFileError.writeFailed("The file did not match the requested configuration after writing.")
            }
        } catch let error as HostsFileError {
            throw error
        } catch {
            throw HostsFileError.writeFailed(error.localizedDescription)
        }
    }

    private func authorizationReference() throws -> AuthorizationRef {
        if let existing = authorizationSession.reference { return existing }

        var created: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &created)
        guard createStatus == errAuthorizationSuccess, let created else {
            throw HostsFileError.authorizationFailed(securityMessage(createStatus))
        }

        let rightStatus = kAuthorizationRightExecute.withCString { rightName in
            var item = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { itemPointer in
                var rights = AuthorizationRights(count: 1, items: itemPointer)
                return AuthorizationCopyRights(
                    created,
                    &rights,
                    nil,
                    [.interactionAllowed, .extendRights, .preAuthorize],
                    nil
                )
            }
        }
        guard rightStatus == errAuthorizationSuccess else {
            AuthorizationFree(created, [])
            if rightStatus == errAuthorizationCanceled { throw HostsFileError.authorizationCancelled }
            throw HostsFileError.authorizationFailed(securityMessage(rightStatus))
        }
        authorizationSession.reference = created
        return created
    }

    private func securityMessage(_ status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "Error code \(status)"
    }
}
