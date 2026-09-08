import Foundation

public enum StorageCategoryKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case applications = "application"
    case documents = "Manuscript"
    case downloads = "Download"
    case pictures = "pictures"
    case music = "music"
    case movies = "Video"
    case developer = "development files"
    case systemData = "System and application data"
    case other = "Others"

    public var id: String { rawValue }

    /// Stable English title used as a localization key in the app.
    public var titleKey: String {
        switch self {
        case .applications: "Applications"
        case .documents: "Documents"
        case .downloads: "Downloads"
        case .pictures: "Pictures"
        case .music: "Music"
        case .movies: "Movies"
        case .developer: "Developer"
        case .systemData: "System Data"
        case .other: "Other"
        }
    }
}

public struct StorageCategoryUsage: Identifiable, Sendable, Hashable {
    public let category: StorageCategoryKind
    public let bytes: Int64
    public let fileCount: Int

    public var id: StorageCategoryKind { category }

    public init(category: StorageCategoryKind, bytes: Int64, fileCount: Int) {
        self.category = category
        self.bytes = bytes
        self.fileCount = fileCount
    }
}

public struct StorageDirectoryUsage: Identifiable, Sendable, Hashable, Codable {
    public let url: URL
    public let bytes: Int64
    public let explanation: String

    public var id: String { url.standardizedFileURL.path }

    public init(url: URL, bytes: Int64, explanation: String) {
        self.url = url
        self.bytes = bytes
        self.explanation = explanation
    }
}

public struct StorageAnalysis: Sendable, Hashable {
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let scannedBytes: Int64
    public let scannedFileCount: Int
    public let inaccessibleItemCount: Int
    public let categories: [StorageCategoryUsage]
    public let largeFiles: [ScanItem]
    public let analyzedRoots: [URL]
    public let directories: [StorageDirectoryUsage]

    public var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }

    public init(
        totalCapacity: Int64,
        availableCapacity: Int64,
        scannedBytes: Int64,
        scannedFileCount: Int,
        inaccessibleItemCount: Int,
        categories: [StorageCategoryUsage],
        largeFiles: [ScanItem],
        analyzedRoots: [URL],
        directories: [StorageDirectoryUsage] = []
    ) {
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.scannedBytes = scannedBytes
        self.scannedFileCount = scannedFileCount
        self.inaccessibleItemCount = inaccessibleItemCount
        self.categories = categories
        self.largeFiles = largeFiles
        self.analyzedRoots = analyzedRoots
        self.directories = directories
    }
}

public struct StorageAnalysisProgress: Sendable, Hashable {
    public let currentRoot: URL
    public let inspectedFiles: Int
    public let scannedBytes: Int64

    public init(currentRoot: URL, inspectedFiles: Int, scannedBytes: Int64) {
        self.currentRoot = currentRoot
        self.inspectedFiles = inspectedFiles
        self.scannedBytes = scannedBytes
    }
}
