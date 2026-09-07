import Foundation

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
