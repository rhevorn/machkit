import Foundation

public protocol CleaningService: Sendable {
    func moveToTrash(items: [ScanItem], selectedRoot: URL) async -> CleanResult
}

public struct LiveCleaningService: CleaningService {
    private let cleaner: Cleaner

    public init() {
        cleaner = Cleaner()
    }

    public func moveToTrash(items: [ScanItem], selectedRoot: URL) async -> CleanResult {
        await cleaner.moveToTrash(items: items, selectedRoot: selectedRoot)
    }
}

public protocol StorageAnalysisService: Sendable {
    func directoryOverview(root: URL, volumeURL: URL?) async -> StorageAnalysis
    func fullStorageAnalysis(
        root: URL,
        volumeURL: URL?,
        progress: (@Sendable (StorageAnalysisProgress) -> Void)?
    ) async -> StorageAnalysis
}

public struct LiveStorageAnalysisService: StorageAnalysisService {
    private let analyzer: FileAnalyzer

    public init() {
        analyzer = FileAnalyzer()
    }

    public func directoryOverview(root: URL, volumeURL: URL?) async -> StorageAnalysis {
        await analyzer.directoryOverview(root: root, volumeURL: volumeURL)
    }

    public func fullStorageAnalysis(
        root: URL,
        volumeURL: URL?,
        progress: (@Sendable (StorageAnalysisProgress) -> Void)?
    ) async -> StorageAnalysis {
        await analyzer.fullStorageAnalysis(
            root: root,
            volumeURL: volumeURL,
            progress: progress
        )
    }
}
