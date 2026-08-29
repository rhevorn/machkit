import Foundation

/// Pure helpers for pinned developer-tool ordering.
///
/// Persistence stores raw tool IDs. Callers must pass the current registry IDs so
/// removed tools are silently dropped and never surface in the UI.
public enum ToolPinOrder {
    /// Keeps saved order, drops unknown IDs, and de-duplicates.
    public static func resolve(pinnedIDs: [String], availableIDs: Set<String>) -> [String] {
        var seen = Set<String>()
        var resolved: [String] = []
        resolved.reserveCapacity(pinnedIDs.count)
        for id in pinnedIDs {
            guard availableIDs.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            resolved.append(id)
        }
        return resolved
    }

    /// Registry-order IDs that are not currently pinned.
    public static func unpinnedIDs(registryOrder: [String], pinnedIDs: [String]) -> [String] {
        let pinned = Set(pinnedIDs)
        return registryOrder.filter { !pinned.contains($0) }
    }

    /// Pins `id` at the end when it exists in the registry and is not already pinned.
    public static func pin(
        _ id: String,
        in pinnedIDs: [String],
        availableIDs: Set<String>
    ) -> [String] {
        var resolved = resolve(pinnedIDs: pinnedIDs, availableIDs: availableIDs)
        guard availableIDs.contains(id), !resolved.contains(id) else { return resolved }
        resolved.append(id)
        return resolved
    }

    /// Removes `id` from the pinned list.
    public static func unpin(
        _ id: String,
        from pinnedIDs: [String],
        availableIDs: Set<String>
    ) -> [String] {
        resolve(pinnedIDs: pinnedIDs, availableIDs: availableIDs).filter { $0 != id }
    }

    /// Moves `movingID` to sit immediately before `targetID`.
    /// When `targetID` is nil or missing, appends to the end.
    public static func move(
        _ movingID: String,
        before targetID: String?,
        in pinnedIDs: [String],
        availableIDs: Set<String>
    ) -> [String] {
        var ids = resolve(pinnedIDs: pinnedIDs, availableIDs: availableIDs)
        guard availableIDs.contains(movingID),
              let fromIndex = ids.firstIndex(of: movingID)
        else { return ids }

        if let targetID, targetID == movingID {
            return ids
        }

        ids.remove(at: fromIndex)
        if let targetID, let toIndex = ids.firstIndex(of: targetID) {
            ids.insert(movingID, at: toIndex)
        } else {
            ids.append(movingID)
        }
        return ids
    }
}
