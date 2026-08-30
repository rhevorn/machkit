import Foundation
import MachKitCore

private struct HostsWorkspace: Codable {
    var environments: [HostsEnvironment]
    var activeEnvironmentID: UUID?
    /// Draft shared (unmanaged) hosts text. Nil means “follow /etc/hosts”.
    var sharedContent: String?
}

private let defaultHostsEnvironments = [
    HostsEnvironment(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Development"),
    HostsEnvironment(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Testing"),
    HostsEnvironment(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Production")
]

@MainActor
final class HostsWebBridge {
    static let shared = HostsWebBridge()

    private let service = HostsSystemService()
    private let storageURL: URL
    private var workspace: HostsWorkspace
    private var revision = 0

    private init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        storageURL = base.appending(path: "MachKit/Hosts/environments.json")
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode(HostsWorkspace.self, from: data),
           !saved.environments.isEmpty {
            workspace = saved
        } else {
            workspace = HostsWorkspace(environments: defaultHostsEnvironments, activeEnvironmentID: nil)
            try? persist()
        }
    }

    func handle(_ payload: [String: Any]) async -> [String: Any] {
        let requestID = payload["requestID"] as? String ?? ""
        do {
            let result = try await perform(payload)
            return ["requestID": requestID, "ok": true, "result": result]
        } catch {
            return ["requestID": requestID, "ok": false, "error": error.localizedDescription]
        }
    }

    private func perform(_ payload: [String: Any]) async throws -> [String: Any] {
        switch payload["action"] as? String {
        case "load":
            if workspace.environments.isEmpty {
                workspace.environments = defaultHostsEnvironments
                workspace.activeEnvironmentID = nil
                try? persist()
            }
            return try await snapshot()
        case "save":
            try requireCurrentRevision(payload)
            let previousWorkspace = workspace
            let previousRevision = revision
            revision += 1
            do {
                // Drafts may contain incomplete lines while typing; syntax is checked on apply.
                try updateDrafts(from: payload, validateSyntax: false)
                try persist()
            } catch {
                workspace = previousWorkspace
                revision = previousRevision
                throw error
            }
            return try await snapshot()
        case "apply":
            try requireCurrentRevision(payload)
            let current = await service.currentContentsResult()
            if let errorMessage = current.errorMessage { throw BridgeError.operation(errorMessage) }
            let previousWorkspace = workspace
            let previousRevision = revision
            revision += 1
            do {
                try updateDrafts(from: payload, validateSyntax: true)
                let rawEnvironmentID = (payload["environmentID"] as? String)
                    ?? (payload["id"] as? String)
                if let rawEnvironmentID {
                    guard let id = UUID(uuidString: rawEnvironmentID),
                          workspace.environments.contains(where: { $0.id == id }) else {
                        throw BridgeError.invalidRequest
                    }
                    // Applying from an environment selection always switches the
                    // managed hosts section to that environment.
                    workspace.activeEnvironmentID = id
                }
                try await applySystem(previousContents: current.content)
                try persist()
            } catch {
                workspace = previousWorkspace
                revision = previousRevision
                if let rollbackError = await rollbackSystemIfNeeded(previousContents: current.content) {
                    throw BridgeError.rollback(original: error.localizedDescription, rollback: rollbackError.localizedDescription)
                }
                throw error
            }
            return try await snapshot()
        default:
            throw BridgeError.invalidRequest
        }
    }

    private func updateDrafts(from payload: [String: Any], validateSyntax: Bool) throws {
        if let rawEnvironments = payload["environments"] {
            guard let environments = decodeEnvironments(rawEnvironments) else {
                throw BridgeError.invalidRequest
            }
            let nextEnvironments = try environments.map {
                try decodeEnvironment($0, validateSyntax: validateSyntax)
            }
            guard !nextEnvironments.isEmpty else {
                throw BridgeError.invalidRequest
            }
            guard Set(nextEnvironments.map(\.id)).count == nextEnvironments.count else {
                throw BridgeError.invalidRequest
            }
            if let activeID = workspace.activeEnvironmentID,
               !nextEnvironments.contains(where: { $0.id == activeID }) {
                // Draft backups can omit a previously active environment; keep saving.
                workspace.activeEnvironmentID = nil
            }
            workspace.environments = nextEnvironments
        }
        if let shared = payload["sharedContent"] as? String {
            if validateSyntax {
                try HostsFileComposer.validate(shared)
            }
            workspace.sharedContent = shared
        }
    }

    private func decodeEnvironments(_ value: Any) -> [[String: Any]]? {
        if let environments = value as? [[String: Any]] {
            return environments
        }
        guard let items = value as? [Any] else { return nil }
        var environments: [[String: Any]] = []
        environments.reserveCapacity(items.count)
        for item in items {
            if let environment = item as? [String: Any] {
                environments.append(environment)
                continue
            }
            guard let environment = item as? NSDictionary else { return nil }
            var next: [String: Any] = [:]
            for (key, raw) in environment {
                guard let key = key as? String else { return nil }
                next[key] = raw
            }
            environments.append(next)
        }
        return environments
    }

    private func snapshot() async throws -> [String: Any] {
        let result = await service.currentContentsResult()
        if let errorMessage = result.errorMessage { throw BridgeError.operation(errorMessage) }
        let systemShared = try HostsFileComposer.removingManagedSection(from: result.content)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shared = (workspace.sharedContent ?? systemShared)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let needsApplyFlag: Bool
        do {
            needsApplyFlag = try needsApply(systemContent: result.content, sharedContent: shared)
        } catch {
            // Incomplete drafts should still load; treat them as needing apply.
            needsApplyFlag = true
        }
        return [
            "systemContent": result.content,
            "sharedContent": shared,
            "activeEnvironmentID": workspace.activeEnvironmentID?.uuidString ?? NSNull(),
            "revision": revision,
            "needsApply": needsApplyFlag,
            "environments": workspace.environments.map(encodeEnvironment)
        ]
    }

    private func needsApply(systemContent: String, sharedContent: String) throws -> Bool {
        let document = HostsDocument(
            unmanagedContent: sharedContent,
            environments: workspace.environments,
            activeEnvironmentID: workspace.activeEnvironmentID
        )
        let rendered = try HostsFileComposer.rendering(document)
        return normalizeHostsFile(rendered) != normalizeHostsFile(systemContent)
    }

    private func normalizeHostsFile(_ content: String) -> String {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySystem(previousContents: String) async throws {
        let systemShared = try HostsFileComposer.removingManagedSection(from: previousContents)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shared = (workspace.sharedContent ?? systemShared)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let document = HostsDocument(
            unmanagedContent: shared,
            environments: workspace.environments,
            activeEnvironmentID: workspace.activeEnvironmentID
        )
        if let error = await service.apply(document: document) { throw error }
        workspace.sharedContent = shared
    }

    private func rollbackSystemIfNeeded(previousContents: String) async -> HostsFileError? {
        let current = await service.currentContentsResult()
        if let errorMessage = current.errorMessage { return .writeFailed(errorMessage) }
        guard current.content != previousContents else { return nil }
        return await service.restore(contents: previousContents)
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(workspace).write(to: storageURL, options: .atomic)
    }

    private func requireCurrentRevision(_ payload: [String: Any]) throws {
        let requested: Int?
        if let number = payload["revision"] as? NSNumber {
            requested = number.intValue
        } else if let value = payload["revision"] as? Int {
            requested = value
        } else {
            requested = nil
        }
        guard let requested, requested == revision else {
            throw BridgeError.conflict
        }
    }

    private func decodeEnvironment(_ value: [String: Any], validateSyntax: Bool) throws -> HostsEnvironment {
        guard let rawID = value["id"] as? String,
              let id = UUID(uuidString: rawID),
              let name = value["name"] as? String,
              let content = value["content"] as? String else {
            throw BridgeError.invalidRequest
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Untitled" : trimmedName
        if validateSyntax {
            try HostsFileComposer.validate(content)
        }
        return HostsEnvironment(id: id, name: resolvedName, content: content)
    }

    private func encodeEnvironment(_ environment: HostsEnvironment) -> [String: Any] {
        ["id": environment.id.uuidString, "name": environment.name, "content": environment.content]
    }

    private enum BridgeError: LocalizedError {
        case invalidRequest
        case conflict
        case operation(String)
        case rollback(original: String, rollback: String)

        var errorDescription: String? {
            switch self {
            case .invalidRequest: "Invalid Hosts request."
            case .conflict: "Hosts configuration changed. Reload the tool and try again."
            case let .operation(message): message
            case let .rollback(original, rollback):
                "The Hosts operation failed (\(original)) and could not be rolled back (\(rollback))."
            }
        }
    }
}
