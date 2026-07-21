import Foundation

public actor FileAnalyzer {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
}
