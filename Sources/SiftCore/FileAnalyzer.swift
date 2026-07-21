import Foundation

public actor FileAnalyzer {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func storageAnalysis(
        roots: [URL],
        volumeURL: URL? = nil,
        largeFileMinimumBytes: Int64 = 500 * 1_024 * 1_024,
        progress: (@Sendable (StorageAnalysisProgress) -> Void)? = nil
    ) -> StorageAnalysis {
        let roots = nonOverlappingExistingRoots(roots)
        let volumeURL = volumeURL ?? roots.first ?? URL(fileURLWithPath: "/", isDirectory: true)
        let capacity = volumeCapacity(at: volumeURL)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey
        ]
        let largeFileRule = ScanRule(
            id: "large-file",
            title: "大文件",
            relativePath: ".",
            minimumAgeDays: 0,
            risk: .review,
            explanation: "大文件不等于垃圾，仅用于了解空间占用。"
        )

        var categoryBytes = Dictionary(uniqueKeysWithValues: StorageCategoryKind.allCases.map { ($0, Int64(0)) })
        var categoryCounts = Dictionary(uniqueKeysWithValues: StorageCategoryKind.allCases.map { ($0, 0) })
        var largeFiles: [ScanItem] = []
        var inspectedFiles = 0
        var scannedBytes: Int64 = 0
        var inaccessibleItemCount = 0

        for root in roots {
            guard !Task.isCancelled else { break }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { _, _ in
                    inaccessibleItemCount += 1
                    return true
                }
            ) else {
                inaccessibleItemCount += 1
                continue
            }

            for case let url as URL in enumerator {
                if Task.isCancelled { break }
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else { continue }

                let logicalBytes = Int64(values.fileSize ?? 0)
                let allocatedBytes = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                let bytes = max(0, allocatedBytes)
                let category = storageCategory(for: url)
                categoryBytes[category, default: 0] += bytes
                categoryCounts[category, default: 0] += 1
                inspectedFiles += 1
                scannedBytes += bytes

                if logicalBytes >= largeFileMinimumBytes {
                    largeFiles.append(ScanItem(
                        url: url,
                        bytes: logicalBytes,
                        modifiedAt: values.contentModificationDate,
                        rule: largeFileRule
                    ))
                }

                if inspectedFiles.isMultiple(of: 1_000) {
                    progress?(StorageAnalysisProgress(
                        currentRoot: root,
                        inspectedFiles: inspectedFiles,
                        scannedBytes: scannedBytes
                    ))
                }
            }
        }

        let categories = StorageCategoryKind.allCases
            .map { StorageCategoryUsage(category: $0, bytes: categoryBytes[$0, default: 0], fileCount: categoryCounts[$0, default: 0]) }
            .filter { $0.fileCount > 0 }
            .sorted { lhs, rhs in
                if lhs.bytes == rhs.bytes { return lhs.category.rawValue < rhs.category.rawValue }
                return lhs.bytes > rhs.bytes
            }
        largeFiles.sort { $0.bytes > $1.bytes }

        return StorageAnalysis(
            totalCapacity: capacity.total,
            availableCapacity: capacity.available,
            scannedBytes: scannedBytes,
            scannedFileCount: inspectedFiles,
            inaccessibleItemCount: inaccessibleItemCount,
            categories: categories,
            largeFiles: Array(largeFiles.prefix(200)),
            analyzedRoots: roots
        )
    }

    public func largeFiles(in root: URL, minimumBytes: Int64 = 500 * 1_024 * 1_024) -> [ScanItem] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let rule = ScanRule(
            id: "large-file",
            title: "大文件",
            relativePath: ".",
            minimumAgeDays: 0,
            risk: .review,
            explanation: "大文件不等于垃圾，只用于帮助你发现占用空间的内容。"
        )
        var results: [ScanItem] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  Int64(values.fileSize ?? 0) >= minimumBytes else { continue }
            results.append(ScanItem(
                url: url,
                bytes: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate,
                rule: rule
            ))
        }
        return results.sorted { $0.bytes > $1.bytes }
    }

    private func nonOverlappingExistingRoots(_ roots: [URL]) -> [URL] {
        let sortedRoots = roots
            .map(\.standardizedFileURL)
            .filter { fileManager.fileExists(atPath: $0.path) }
            .sorted { $0.path.count < $1.path.count }
        var result: [URL] = []
        for root in sortedRoots {
            let path = root.path
            let isCovered = result.contains { existing in
                path == existing.path || path.hasPrefix(existing.path.hasSuffix("/") ? existing.path : existing.path + "/")
            }
            if !isCovered { result.append(root) }
        }
        return result
    }

    private func volumeCapacity(at url: URL) -> (total: Int64, available: Int64) {
        let attributes = try? fileManager.attributesOfFileSystem(forPath: url.path)
        let total = (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let available = (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return (max(0, total), max(0, available))
    }

    private func storageCategory(for url: URL) -> StorageCategoryKind {
        let path = url.standardizedFileURL.path
        let pathComponents = url.standardizedFileURL.pathComponents
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
        let relativeToHome = path.hasPrefix(home + "/") ? String(path.dropFirst(home.count + 1)) : nil
        let firstHomeComponent = relativeToHome?.split(separator: "/").first.map(String.init)

        if path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/") || firstHomeComponent == "Applications" {
            return .applications
        }
        if path.hasPrefix("/Library/Developer/") || relativeToHome?.hasPrefix("Library/Developer/") == true || firstHomeComponent == "Developer" {
            return .developer
        }
        if firstHomeComponent == "Downloads" || pathComponents.contains("Downloads") { return .downloads }
        if firstHomeComponent == "Documents" || firstHomeComponent == "Desktop" || pathComponents.contains("Documents") || pathComponents.contains("Desktop") { return .documents }
        if firstHomeComponent == "Pictures" || pathComponents.contains("Pictures") { return .pictures }
        if firstHomeComponent == "Music" || pathComponents.contains("Music") { return .music }
        if firstHomeComponent == "Movies" || pathComponents.contains("Movies") { return .movies }
        if path.hasPrefix("/Library/") || path.hasPrefix("/System/") || path.hasPrefix("/private/") || firstHomeComponent == "Library" {
            return .systemData
        }

        let fileExtension = url.pathExtension.lowercased()
        if Self.pictureExtensions.contains(fileExtension) { return .pictures }
        if Self.audioExtensions.contains(fileExtension) { return .music }
        if Self.videoExtensions.contains(fileExtension) { return .movies }
        if Self.documentExtensions.contains(fileExtension) { return .documents }
        return .other
    }

    private static let pictureExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp", "raw", "dng", "svg"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "flac", "alac", "ogg"]
    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "mkv", "avi", "webm", "mpeg", "mpg"]
    private static let documentExtensions: Set<String> = ["pdf", "txt", "rtf", "md", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "csv"]
}
