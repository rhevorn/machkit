import Foundation

public actor Cleaner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func moveToTrash(items: [ScanItem], selectedRoot: URL) -> CleanResult {
        let trashRoot = selectedRoot
            .appending(path: ".Trash", directoryHint: .isDirectory)
            .standardizedFileURL
        var moved: [URL] = []
        var permanentlyDeleted: [URL] = []
        var failures: [CleanFailure] = []

        for item in items {
            do {
                try SafetyPolicy.validateForCleaning(item: item, selectedRoot: selectedRoot)
                if SafetyPolicy.contains(item.url, in: trashRoot) {
                    try fileManager.removeItem(at: item.url)
                    permanentlyDeleted.append(item.url)
                } else {
                    var destination: NSURL?
                    try fileManager.trashItem(at: item.url, resultingItemURL: &destination)
                    moved.append(item.url)
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
