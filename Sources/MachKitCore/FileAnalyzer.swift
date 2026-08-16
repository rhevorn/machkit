import Foundation

public actor FileAnalyzer {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Produces a fast, first-level overview of a directory. `du` performs the
    /// size aggregation using the native filesystem walker, while the UI only
    /// presents the root's immediate children instead of indexing every file.
    public func directoryOverview(root: URL, volumeURL: URL? = nil) -> StorageAnalysis {
        let root = root.standardizedFileURL
        let capacity = volumeCapacity(at: volumeURL ?? root)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey]
        let children = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: []
        )) ?? []

        var directories: [URL] = []
        var rootFilesBytes: Int64 = 0
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys), values.isSymbolicLink != true else { continue }
            if values.isDirectory == true {
                directories.append(child)
            } else if values.isRegularFile == true {
                rootFilesBytes += Int64(values.fileAllocatedSize ?? 0)
            }
        }

        let measured = directorySizes(using: directories)
        var usages = directories.map { url in
            StorageDirectoryUsage(
                url: url,
                bytes: measured[url.standardizedFileURL.path, default: 0],
                explanation: Self.directoryExplanation(name: url.lastPathComponent)
            )
        }
        if rootFilesBytes > 0 {
            usages.append(StorageDirectoryUsage(
                url: root,
                bytes: rootFilesBytes,
                explanation: "Files stored directly in the user directory"
            ))
        }
        usages.sort { lhs, rhs in
            if lhs.bytes == rhs.bytes { return lhs.url.lastPathComponent.localizedStandardCompare(rhs.url.lastPathComponent) == .orderedAscending }
            return lhs.bytes > rhs.bytes
        }
        let scannedBytes = usages.reduce(0) { $0 + $1.bytes }
        return StorageAnalysis(
            totalCapacity: capacity.total,
            availableCapacity: capacity.available,
            scannedBytes: scannedBytes,
            scannedFileCount: children.count,
            inaccessibleItemCount: 0,
            categories: [],
            largeFiles: [],
            analyzedRoots: [root],
            directories: usages
        )
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
            title: "Large Files",
            relativePath: ".",
            minimumAgeDays: 0,
            risk: .review,
            explanation: "Large files do not mean garbage, they are only used to understand the space occupied."
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

    /// Fast folder overview first, then a deep categorize + large-file pass for the same root.
    public func fullStorageAnalysis(
        root: URL,
        volumeURL: URL? = nil,
        largeFileMinimumBytes: Int64 = 500 * 1_024 * 1_024,
        progress: (@Sendable (StorageAnalysisProgress) -> Void)? = nil
    ) -> StorageAnalysis {
        let root = root.standardizedFileURL
        let volume = volumeURL ?? URL(fileURLWithPath: "/", isDirectory: true)
        progress?(StorageAnalysisProgress(currentRoot: root, inspectedFiles: 0, scannedBytes: 0))
        let overview = directoryOverview(root: root, volumeURL: volume)
        guard !Task.isCancelled else { return overview }

        let deep = storageAnalysis(
            roots: [root],
            volumeURL: volume,
            largeFileMinimumBytes: largeFileMinimumBytes,
            progress: progress
        )
        guard !Task.isCancelled else {
            return StorageAnalysis(
                totalCapacity: overview.totalCapacity,
                availableCapacity: overview.availableCapacity,
                scannedBytes: overview.scannedBytes,
                scannedFileCount: overview.scannedFileCount,
                inaccessibleItemCount: overview.inaccessibleItemCount,
                categories: deep.categories,
                largeFiles: deep.largeFiles,
                analyzedRoots: overview.analyzedRoots,
                directories: overview.directories
            )
        }

        return StorageAnalysis(
            totalCapacity: max(overview.totalCapacity, deep.totalCapacity),
            availableCapacity: deep.availableCapacity > 0 ? deep.availableCapacity : overview.availableCapacity,
            scannedBytes: deep.scannedBytes,
            scannedFileCount: deep.scannedFileCount,
            inaccessibleItemCount: deep.inaccessibleItemCount,
            categories: deep.categories,
            largeFiles: deep.largeFiles,
            analyzedRoots: overview.analyzedRoots,
            directories: overview.directories
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
            title: "Large Files",
            relativePath: ".",
            minimumAgeDays: 0,
            risk: .review,
            explanation: "Large files do not equal garbage, they are only used to help you discover content taking up space."
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

    private func directorySizes(using urls: [URL]) -> [String: Int64] {
        guard !urls.isEmpty else { return [:] }
        do {
            let output = try SystemCommandRunner.run(
                executable: "/usr/bin/du",
                arguments: ["-sk", "-x", "--"] + urls.map(\.path),
                timeout: 60
            )
            return Self.parseDirectorySizes(output.text)
        } catch {
            return [:]
        }
    }

    static func parseDirectorySizes(_ text: String) -> [String: Int64] {
        var result: [String: Int64] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard fields.count == 2, let kibibytes = Int64(fields[0]) else { continue }
            result[URL(fileURLWithPath: fields[1]).standardizedFileURL.path] = kibibytes * 1_024
        }
        return result
    }

    public static func directoryExplanation(name: String) -> String {
        switch name {
        case "Applications": "Applications installed by the current user"
        case "Desktop": "Files and folders on the desktop"
        case "Documents": "Manuscripts and Profiles"
        case "Downloads": "Files downloaded by browsers and other apps"
        case "Library": "App data, cache, settings and development tools files"
        case "Movies": "Film and Video Projects"
        case "Music": "Music, audio and music libraries"
        case "Pictures": "Photos, graphics and image libraries"
        case "Public": "Content accessible to other users of the same Mac"
        case ".Trash": "Contents of the Trash"
        case ".cache": "Command line tools and development tools cache"
        case ".config": "Command line tools and development tool configuration"
        case ".local": "User-level command line tools and local data"
        case ".npm": "npm download cache, logs and configuration"
        case ".cargo": "Rust toolchain, source cache, and installed commands"
        case ".gradle": "Gradle download cache and build data"
        default: name.hasPrefix(".") ? "Hidden directories created by applications or command line tools" : "Folders in user directory"
        }
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
