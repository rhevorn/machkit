import Foundation

public protocol TrashMoving: Sendable {
    func trashItem(at url: URL) throws
}

public struct SystemTrashMover: TrashMoving {
    public init() {}

    public func trashItem(at url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}
