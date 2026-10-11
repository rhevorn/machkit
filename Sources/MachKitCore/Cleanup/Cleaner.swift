import Foundation

public actor Cleaner {
    private let fileManager: FileManager
    private let trashMover: any TrashMoving

    public init(
        fileManager: FileManager = .default,
        trashMover: any TrashMoving = SystemTrashMover()
    ) {
        self.fileManager = fileManager
        self.trashMover = trashMover
    }

    public func moveToTrash(items: [ScanItem], selectedRoot: URL) -> CleanResult {
        var moved: [URL] = []
        var permanentlyDeleted: [URL] = []
        var failures: [CleanFailure] = []

        for item in items {
            do {
                try SafetyPolicy.validateForCleaning(item: item, selectedRoot: selectedRoot)
                switch item.rule.cleanupDisposition {
                case .permanentlyDelete:
                    try fileManager.removeItem(at: item.url)
                    permanentlyDeleted.append(item.url)
                case .moveToTrash:
                    try trashMover.trashItem(at: item.url)
                    moved.append(item.url)
                case .privilegedMoveToTrash:
                    let domain: PrivilegedCommandRunner.ProtectedCleanupDomain
                    switch item.rule.id {
                    case "system-caches":
                        domain = .systemCache
                    case "incomplete-time-machine-backups":
                        domain = .incompleteTimeMachineBackup
                    default:
                        throw PrivilegedCommandError.invalidRequest
                    }
                    _ = try PrivilegedCommandRunner.moveProtectedCleanupItemToTrash(
                        item.url,
                        domain: domain,
                        home: fileManager.homeDirectoryForCurrentUser,
                        fileManager: fileManager
                    )
                    moved.append(item.url)
                case .deleteTimeMachineSnapshot:
                    try PrivilegedCommandRunner.deleteTimeMachineLocalSnapshot(
                        identifier: item.url.lastPathComponent
                    )
                    permanentlyDeleted.append(item.url)
                }
            } catch {
                failures.append(CleanFailure(url: item.url, reason: error.localizedDescription))
            }
        }
        return CleanResult(
            movedToTrash: moved,
            permanentlyDeleted: permanentlyDeleted,
            failures: failures
        )
    }
}
