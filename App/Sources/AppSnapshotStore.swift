import Foundation
import MachKitCore

struct StorageSnapshotState {
    let analysis: StorageAnalysis
    let savedAt: Date
}

struct InventorySnapshotState {
    let applications: [InstalledApplication]
    let commandLineTools: [CommandLineTool]
    let loginApplications: [LoginApplication]
    let backgroundItems: [LoginItem]
    let registeredBackgroundTasks: [RegisteredBackgroundTask]
    let installedExtensions: [InstalledExtension]
}

@MainActor
protocol AppSnapshotStoring {
    func loadStorage() -> StorageSnapshotState?
    func saveStorage(_ analysis: StorageAnalysis, savedAt: Date)
    func loadInventory() -> InventorySnapshotState?
    func saveInventory(_ snapshot: InventorySnapshotState)
}

@MainActor
final class UserDefaultsAppSnapshotStore: AppSnapshotStoring {
    private enum Key {
        static let storage = "storageOverviewSnapshot"
        static let inventory = "inventorySnapshot"
    }

    private struct StoredDirectory: Codable {
        let path: String
        let bytes: Int64
        let explanation: String
    }

    private struct StoredCategory: Codable {
        let category: String
        let bytes: Int64
        let fileCount: Int
    }

    private struct StoredLargeFile: Codable {
        let path: String
        let bytes: Int64
        let modifiedAt: Date?
    }

    private struct StoredStorageSnapshot: Codable {
        let rootPath: String
        let totalCapacity: Int64
        let availableCapacity: Int64
        let scannedBytes: Int64
        let scannedFileCount: Int?
        let inaccessibleItemCount: Int?
        let savedAt: Date
        let directories: [StoredDirectory]
        let categories: [StoredCategory]?
        let largeFiles: [StoredLargeFile]?
    }

    private struct StoredInventorySnapshot: Codable {
        let applications: [InstalledApplication]
        let commandLineTools: [CommandLineTool]
        let loginApplications: [LoginApplication]
        let backgroundItems: [LoginItem]
        let registeredBackgroundTasks: [RegisteredBackgroundTask]
        let installedExtensions: [InstalledExtension]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveStorage(_ analysis: StorageAnalysis, savedAt: Date) {
        guard let root = analysis.analyzedRoots.first else { return }
        let snapshot = StoredStorageSnapshot(
            rootPath: root.path,
            totalCapacity: analysis.totalCapacity,
            availableCapacity: analysis.availableCapacity,
            scannedBytes: analysis.scannedBytes,
            scannedFileCount: analysis.scannedFileCount,
            inaccessibleItemCount: analysis.inaccessibleItemCount,
            savedAt: savedAt,
            directories: analysis.directories.map {
                StoredDirectory(path: $0.url.path, bytes: $0.bytes, explanation: $0.explanation)
            },
            categories: analysis.categories.map {
                StoredCategory(category: $0.category.rawValue, bytes: $0.bytes, fileCount: $0.fileCount)
            },
            largeFiles: Array(analysis.largeFiles.prefix(80)).map {
                StoredLargeFile(path: $0.url.path, bytes: $0.bytes, modifiedAt: $0.modifiedAt)
            }
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.storage)
    }

    func loadStorage() -> StorageSnapshotState? {
        guard let data = defaults.data(forKey: Key.storage),
              let snapshot = try? JSONDecoder().decode(StoredStorageSnapshot.self, from: data) else {
            return nil
        }

        let root = URL(fileURLWithPath: snapshot.rootPath, isDirectory: true)
        let largeFileRule = ScanRule(
            id: "large-file",
            title: "Large Files",
            relativePath: ".",
            minimumAgeDays: 0,
            risk: .review,
            explanation: "Large files do not mean garbage, they are only used to understand the space occupied."
        )
        let categories = (snapshot.categories ?? []).compactMap { stored -> StorageCategoryUsage? in
            guard let kind = StorageCategoryKind(rawValue: stored.category) else { return nil }
            return StorageCategoryUsage(category: kind, bytes: stored.bytes, fileCount: stored.fileCount)
        }
        let largeFiles = (snapshot.largeFiles ?? []).map {
            ScanItem(
                url: URL(fileURLWithPath: $0.path),
                bytes: $0.bytes,
                modifiedAt: $0.modifiedAt,
                rule: largeFileRule
            )
        }
        let analysis = StorageAnalysis(
            totalCapacity: snapshot.totalCapacity,
            availableCapacity: snapshot.availableCapacity,
            scannedBytes: snapshot.scannedBytes,
            scannedFileCount: snapshot.scannedFileCount ?? snapshot.directories.count,
            inaccessibleItemCount: snapshot.inaccessibleItemCount ?? 0,
            categories: categories,
            largeFiles: largeFiles,
            analyzedRoots: [root],
            directories: snapshot.directories.map {
                StorageDirectoryUsage(
                    url: URL(fileURLWithPath: $0.path, isDirectory: true),
                    bytes: $0.bytes,
                    explanation: $0.explanation
                )
            }
        )
        return StorageSnapshotState(analysis: analysis, savedAt: snapshot.savedAt)
    }

    func saveInventory(_ snapshot: InventorySnapshotState) {
        let stored = StoredInventorySnapshot(
            applications: snapshot.applications,
            commandLineTools: snapshot.commandLineTools,
            loginApplications: snapshot.loginApplications,
            backgroundItems: snapshot.backgroundItems,
            registeredBackgroundTasks: snapshot.registeredBackgroundTasks,
            installedExtensions: snapshot.installedExtensions
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Key.inventory)
    }

    func loadInventory() -> InventorySnapshotState? {
        guard let data = defaults.data(forKey: Key.inventory),
              let snapshot = try? JSONDecoder().decode(StoredInventorySnapshot.self, from: data) else {
            return nil
        }
        return InventorySnapshotState(
            applications: snapshot.applications,
            commandLineTools: snapshot.commandLineTools,
            loginApplications: snapshot.loginApplications,
            backgroundItems: snapshot.backgroundItems,
            registeredBackgroundTasks: snapshot.registeredBackgroundTasks,
            installedExtensions: snapshot.installedExtensions
        )
    }
}
