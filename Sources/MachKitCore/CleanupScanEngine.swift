import Foundation

/// One serial cleanup category (UI phase). Rules run left-to-right inside the category.
public struct CleanupCategorySpec: Sendable, Identifiable {
    public let id: String
    public let rules: [ScanRule]
    public let scansLeftovers: Bool

    public init(id: String, rules: [ScanRule] = [], scansLeftovers: Bool = false) {
        self.id = id
        self.rules = rules
        self.scansLeftovers = scansLeftovers
    }
}

/// Stable progress for the cleanup axis: overall advances only as categories finish left→right.
public struct CleanupScanProgressEvent: Sendable {
    public let categoryID: String
    public let categoryIndex: Int
    public let categoryCount: Int
    /// 0...1 progress inside the active category.
    public let categoryFraction: Double
    /// 0...1 overall = (completedCategories + categoryFraction) / categoryCount.
    public let overallFraction: Double
    public let inspectedFiles: Int
    public let matchedFiles: Int
    public let matchedBytes: Int64
    public let completedCategoryIDs: [String]

    public init(
        categoryID: String,
        categoryIndex: Int,
        categoryCount: Int,
        categoryFraction: Double,
        overallFraction: Double,
        inspectedFiles: Int,
        matchedFiles: Int,
        matchedBytes: Int64,
        completedCategoryIDs: [String]
    ) {
        self.categoryID = categoryID
        self.categoryIndex = categoryIndex
        self.categoryCount = categoryCount
        self.categoryFraction = categoryFraction
        self.overallFraction = overallFraction
        self.inspectedFiles = inspectedFiles
        self.matchedFiles = matchedFiles
        self.matchedBytes = matchedBytes
        self.completedCategoryIDs = completedCategoryIDs
    }
}

/// Runs cleanup categories strictly one after another on a background actor.
public actor CleanupScanEngine {
    private let scanner: Scanner
    private let applicationScanner: ApplicationScanner

    public init(
        scanner: Scanner = Scanner(),
        applicationScanner: ApplicationScanner = ApplicationScanner()
    ) {
        self.scanner = scanner
        self.applicationScanner = applicationScanner
    }

    public func scan(
        root: URL,
        home: URL,
        categories: [CleanupCategorySpec],
        onProgress: (@Sendable (CleanupScanProgressEvent) -> Void)? = nil
    ) async -> [ScanItem] {
        let active = categories.filter { !$0.rules.isEmpty || $0.scansLeftovers }
        guard !active.isEmpty else { return [] }

        var items: [ScanItem] = []
        var matchedFiles = 0
        var matchedBytes: Int64 = 0
        var inspectedFiles = 0
        var completedCategoryIDs: [String] = []
        let categoryCount = active.count

        for (categoryIndex, category) in active.enumerated() {
            guard !Task.isCancelled else { break }

            emit(
                onProgress,
                CleanupScanProgressEvent(
                    categoryID: category.id,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    categoryFraction: 0,
                    overallFraction: Double(categoryIndex) / Double(categoryCount),
                    inspectedFiles: inspectedFiles,
                    matchedFiles: matchedFiles,
                    matchedBytes: matchedBytes,
                    completedCategoryIDs: completedCategoryIDs
                )
            )

            if category.scansLeftovers {
                let leftoverItems = await scanLeftovers(
                    home: home,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    categoryID: category.id,
                    completedCategoryIDs: completedCategoryIDs,
                    matchedFiles: &matchedFiles,
                    matchedBytes: &matchedBytes,
                    inspectedFiles: &inspectedFiles,
                    onProgress: onProgress
                )
                items.append(contentsOf: leftoverItems)
            } else {
                let ruleItems = await scanRules(
                    category.rules,
                    root: root,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    categoryID: category.id,
                    completedCategoryIDs: completedCategoryIDs,
                    matchedFiles: &matchedFiles,
                    matchedBytes: &matchedBytes,
                    inspectedFiles: &inspectedFiles,
                    onProgress: onProgress
                )
                items.append(contentsOf: ruleItems)
            }

            guard !Task.isCancelled else { break }
            completedCategoryIDs.append(category.id)
            emit(
                onProgress,
                CleanupScanProgressEvent(
                    categoryID: category.id,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    categoryFraction: 1,
                    overallFraction: Double(categoryIndex + 1) / Double(categoryCount),
                    inspectedFiles: inspectedFiles,
                    matchedFiles: matchedFiles,
                    matchedBytes: matchedBytes,
                    completedCategoryIDs: completedCategoryIDs
                )
            )
        }

        return items.sorted { $0.bytes > $1.bytes }
    }

    private func scanRules(
        _ rules: [ScanRule],
        root: URL,
        categoryIndex: Int,
        categoryCount: Int,
        categoryID: String,
        completedCategoryIDs: [String],
        matchedFiles: inout Int,
        matchedBytes: inout Int64,
        inspectedFiles: inout Int,
        onProgress: (@Sendable (CleanupScanProgressEvent) -> Void)?
    ) async -> [ScanItem] {
        let activeRules = rules.filter { $0.risk != .blocked }
        guard !activeRules.isEmpty else { return [] }

        var collected: [ScanItem] = []
        let ruleCount = Double(activeRules.count)

        for (ruleIndex, rule) in activeRules.enumerated() {
            guard !Task.isCancelled else { break }
            let baselineMatchedFiles = matchedFiles
            let baselineMatchedBytes = matchedBytes
            let baselineInspected = inspectedFiles

            let scanned = await scanner.scan(root: root, rules: [rule]) { progress in
                let withinRule = Self.activityFraction(inspected: progress.currentRuleInspectedFiles)
                let categoryFraction = min(0.999, (Double(ruleIndex) + withinRule) / ruleCount)
                let overall = (Double(categoryIndex) + categoryFraction) / Double(categoryCount)
                onProgress?(CleanupScanProgressEvent(
                    categoryID: categoryID,
                    categoryIndex: categoryIndex,
                    categoryCount: categoryCount,
                    categoryFraction: categoryFraction,
                    overallFraction: overall,
                    inspectedFiles: baselineInspected + progress.inspectedFiles,
                    matchedFiles: baselineMatchedFiles + progress.matchedFiles,
                    matchedBytes: baselineMatchedBytes + progress.matchedBytes,
                    completedCategoryIDs: completedCategoryIDs
                ))
            }

            collected.append(contentsOf: scanned)
            matchedFiles = baselineMatchedFiles + scanned.count
            matchedBytes = baselineMatchedBytes + scanned.reduce(0) { $0 + $1.bytes }
            // Prefer last progress inspected count when available.
            inspectedFiles = baselineInspected + max(scanned.count, 1)
            await Task.yield()
        }

        return collected
    }

    private func scanLeftovers(
        home: URL,
        categoryIndex: Int,
        categoryCount: Int,
        categoryID: String,
        completedCategoryIDs: [String],
        matchedFiles: inout Int,
        matchedBytes: inout Int64,
        inspectedFiles: inout Int,
        onProgress: (@Sendable (CleanupScanProgressEvent) -> Void)?
    ) async -> [ScanItem] {
        let baselineMatchedFiles = matchedFiles
        let baselineMatchedBytes = matchedBytes
        let baselineInspected = inspectedFiles

        func publish(_ categoryFraction: Double, inspected: Int = baselineInspected) {
            let fraction = min(0.999, max(0, categoryFraction))
            let overall = (Double(categoryIndex) + fraction) / Double(categoryCount)
            onProgress?(CleanupScanProgressEvent(
                categoryID: categoryID,
                categoryIndex: categoryIndex,
                categoryCount: categoryCount,
                categoryFraction: fraction,
                overallFraction: overall,
                inspectedFiles: inspected,
                matchedFiles: baselineMatchedFiles,
                matchedBytes: baselineMatchedBytes,
                completedCategoryIDs: completedCategoryIDs
            ))
        }

        publish(0.02)
        let installed = await applicationScanner.installedBundleIdentifiers(in: [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appending(path: "Applications", directoryHint: .isDirectory)
        ])
        guard !Task.isCancelled else { return [] }
        publish(0.08)

        let groups = await applicationScanner.orphanedResidues(
            installedBundleIdentifiers: installed,
            home: home
        ) { progress in
            // Reserve 8% for inventory; remainder tracks residue path work.
            let categoryFraction = 0.08 + min(0.919, progress.fractionCompleted * 0.919)
            let overall = (Double(categoryIndex) + categoryFraction) / Double(categoryCount)
            onProgress?(CleanupScanProgressEvent(
                categoryID: categoryID,
                categoryIndex: categoryIndex,
                categoryCount: categoryCount,
                categoryFraction: categoryFraction,
                overallFraction: overall,
                inspectedFiles: baselineInspected + progress.inspectedFiles,
                matchedFiles: baselineMatchedFiles,
                matchedBytes: baselineMatchedBytes,
                completedCategoryIDs: completedCategoryIDs
            ))
        }

        let items = groups.flatMap(\.residues).map { residue in
            ScanItem(
                url: residue.url,
                bytes: residue.bytes,
                modifiedAt: nil,
                rule: DefaultRules.uninstallLeftovers
            )
        }

        matchedFiles = baselineMatchedFiles + items.count
        matchedBytes = baselineMatchedBytes + items.reduce(0) { $0 + $1.bytes }
        inspectedFiles = baselineInspected + items.count
        return items
    }

    private func emit(
        _ onProgress: (@Sendable (CleanupScanProgressEvent) -> Void)?,
        _ event: CleanupScanProgressEvent
    ) {
        onProgress?(event)
    }

    private static func activityFraction(inspected: Int) -> Double {
        guard inspected > 0 else { return 0.02 }
        return min(0.92, 0.08 + log10(Double(inspected) + 1) * 0.14)
    }
}
