import Foundation
import MachKitCore

private struct HostsWorkspace: Codable {
    var environments: [HostsEnvironment]
    var activeEnvironmentID: UUID?
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
           let saved = try? JSONDecoder().decode(HostsWorkspace.self, from: data) {
            workspace = saved
        } else {
            workspace = HostsWorkspace(environments: defaultHostsEnvironments, activeEnvironmentID: nil)
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
            return try await snapshot()
        case "save":
            guard let environments = payload["environments"] as? [[String: Any]] else {
                throw BridgeError.invalidRequest
            }
            let current = await service.currentContentsResult()
            if let errorMessage = current.errorMessage { throw BridgeError.operation(errorMessage) }
            try requireCurrentRevision(payload)
            let previousShared = try HostsFileComposer.removingManagedSection(from: current.content)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let shared = payload["sharedContent"] as? String ?? previousShared
            try HostsFileComposer.validate(shared)
            let previousEnvironments = workspace.environments
            let previousWorkspace = workspace
            let nextEnvironments = try environments.map(decodeEnvironment)
            guard Set(nextEnvironments.map(\.id)).count == nextEnvironments.count else {
                throw BridgeError.invalidRequest
            }
            if let activeID = workspace.activeEnvironmentID,
               !nextEnvironments.contains(where: { $0.id == activeID }) {
                throw BridgeError.invalidRequest
            }
            let activeChanged = workspace.activeEnvironmentID.flatMap { activeID in
                previousEnvironments.first { $0.id == activeID }?.content
                    != nextEnvironments.first { $0.id == activeID }?.content
            } ?? false
            let previousRevision = revision
            revision += 1
            workspace.environments = nextEnvironments
            var attemptedSystemApply = false
            do {
                if shared != previousShared || activeChanged {
                    attemptedSystemApply = true
                    try await apply(sharedContent: shared)
                }
                try persist()
            } catch {
                workspace = previousWorkspace
                revision = previousRevision
                if attemptedSystemApply, let rollbackError = await rollbackSystemIfNeeded(previousContents: current.content) {
                    throw BridgeError.rollback(original: error.localizedDescription, rollback: rollbackError.localizedDescription)
                }
                throw error
            }
            return try await snapshot()
        case "activate":
            guard let rawID = payload["id"] as? String, let id = UUID(uuidString: rawID),
                  workspace.environments.contains(where: { $0.id == id }) else {
                throw BridgeError.invalidRequest
            }
            let current = await service.currentContentsResult()
            if let errorMessage = current.errorMessage { throw BridgeError.operation(errorMessage) }
            try requireCurrentRevision(payload)
            let previousWorkspace = workspace
            let previousRevision = revision
            revision += 1
            workspace.activeEnvironmentID = id
            var attemptedSystemApply = false
            do {
                attemptedSystemApply = true
                try await apply()
                try persist()
            } catch {
                workspace = previousWorkspace
                revision = previousRevision
                if attemptedSystemApply, let rollbackError = await rollbackSystemIfNeeded(previousContents: current.content) {
                    throw BridgeError.rollback(original: error.localizedDescription, rollback: rollbackError.localizedDescription)
                }
                throw error
            }
            return try await snapshot()
        default:
            throw BridgeError.invalidRequest
        }
    }

    private func snapshot() async throws -> [String: Any] {
        let result = await service.currentContentsResult()
        if let errorMessage = result.errorMessage { throw BridgeError.operation(errorMessage) }
        let shared = try HostsFileComposer.removingManagedSection(from: result.content)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "systemContent": result.content,
            "sharedContent": shared,
            "activeEnvironmentID": workspace.activeEnvironmentID?.uuidString ?? NSNull(),
            "revision": revision,
            "environments": workspace.environments.map(encodeEnvironment)
        ]
    }

    private func apply(sharedContent: String? = nil) async throws {
        let current = await service.currentContentsResult()
        if let errorMessage = current.errorMessage { throw BridgeError.operation(errorMessage) }
        let shared = try sharedContent ?? HostsFileComposer.removingManagedSection(from: current.content)
        let document = HostsDocument(
            unmanagedContent: shared,
            environments: workspace.environments,
            activeEnvironmentID: workspace.activeEnvironmentID
        )
        if let error = await service.apply(document: document) { throw error }
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
        guard let requestedRevision = payload["revision"] as? NSNumber,
              requestedRevision.intValue == revision else {
            throw BridgeError.conflict
        }
    }

    private func decodeEnvironment(_ value: [String: Any]) throws -> HostsEnvironment {
        guard let rawID = value["id"] as? String,
              let id = UUID(uuidString: rawID),
              let name = value["name"] as? String,
              let content = value["content"] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.invalidRequest
        }
        try HostsFileComposer.validate(content)
        return HostsEnvironment(id: id, name: name, content: content)
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
