import Foundation

public actor Cleaner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func moveToTrash(items: [ScanItem], selectedRoot: URL) -> CleanResult {
        var moved: [URL] = []
        var failures: [CleanFailure] = []

        for item in items {
            do {
                try SafetyPolicy.validateForCleaning(item: item, selectedRoot: selectedRoot)
                var destination: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &destination)
                moved.append(item.url)
            } catch {
                failures.append(CleanFailure(url: item.url, reason: error.localizedDescription))
            }
        }
        return CleanResult(movedToTrash: moved, failures: failures)
    }
}
