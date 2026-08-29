import Foundation
import MachKitCore

@MainActor
final class ToolPinStore: ObservableObject {
    static let shared = ToolPinStore()

    @Published private(set) var pinnedIDs: [String]
    private let defaults: UserDefaults
    private let storageKey = "developerToolPinnedIDsV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.array(forKey: storageKey) as? [String] {
            pinnedIDs = saved
        } else {
            pinnedIDs = []
        }
    }

    func isPinned(_ toolID: String) -> Bool {
        pinnedIDs.contains(toolID)
    }

    /// Drops IDs that no longer exist in the registry and persists when needed.
    func prune(availableIDs: Set<String>) {
        let resolved = ToolPinOrder.resolve(pinnedIDs: pinnedIDs, availableIDs: availableIDs)
        guard resolved != pinnedIDs else { return }
        pinnedIDs = resolved
        persist()
    }

    func resolvedPinnedIDs(availableIDs: Set<String>) -> [String] {
        ToolPinOrder.resolve(pinnedIDs: pinnedIDs, availableIDs: availableIDs)
    }

    func pin(_ toolID: String, availableIDs: Set<String>) {
        let next = ToolPinOrder.pin(toolID, in: pinnedIDs, availableIDs: availableIDs)
        guard next != pinnedIDs else { return }
        pinnedIDs = next
        persist()
    }

    func unpin(_ toolID: String, availableIDs: Set<String>) {
        let next = ToolPinOrder.unpin(toolID, from: pinnedIDs, availableIDs: availableIDs)
        guard next != pinnedIDs else { return }
        pinnedIDs = next
        persist()
    }

    func move(_ toolID: String, before targetID: String?, availableIDs: Set<String>) {
        let next = ToolPinOrder.move(
            toolID,
            before: targetID,
            in: pinnedIDs,
            availableIDs: availableIDs
        )
        guard next != pinnedIDs else { return }
        pinnedIDs = next
        persist()
    }

    private func persist() {
        defaults.set(pinnedIDs, forKey: storageKey)
    }
}
