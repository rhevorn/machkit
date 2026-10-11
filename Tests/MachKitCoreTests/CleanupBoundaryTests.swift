@testable import MachKitCore
import Foundation
import Testing

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private struct RemovingTrashMover: TrashMoving {
    func trashItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

private struct FailingTrashMover: TrashMoving {
    struct Failure: Error {}

    func trashItem(at url: URL) throws {
        throw Failure()
    }
}

@Test func developerRulesDoNotTargetInstalledDependencies() {
    let paths = DefaultRules.conservative.flatMap(\.relativePaths)
    #expect(paths.allSatisfy { !$0.contains("node_modules") })
    #expect(paths.allSatisfy { !$0.contains("site-packages") })
    #expect(paths.allSatisfy { !$0.contains(".venv") })
    #expect(paths.allSatisfy { !$0.contains(".nvm") })
    #expect(paths.allSatisfy { !$0.contains("Cellar") })
}

@Test func cleanupRuleRegistryKeepsOneRulePerDefinitionFile() throws {
    let rulesDirectory = repositoryRoot.appending(path: "Sources/MachKitCore/Cleanup/Rules", directoryHint: .isDirectory)
    let definitionFiles = try FileManager.default.contentsOfDirectory(
        at: rulesDirectory,
        includingPropertiesForKeys: nil
    ).filter {
        $0.pathExtension == "swift" && $0.lastPathComponent != "CleanupRuleDefinition.swift"
    }
    let registeredRules = DefaultRules.conservative + [DefaultRules.uninstallLeftovers]

    #expect(definitionFiles.count == registeredRules.count)
    #expect(Set(registeredRules.map(\.id)).count == registeredRules.count)
}

@Test func scannerCombinesResultsFromIndependentRules() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-parallel-rules-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstFile = root.appending(path: "First/old.one")
    let secondFile = root.appending(path: "Second/old.two")
    try FileManager.default.createDirectory(at: firstFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("one".utf8).write(to: firstFile)
    try Data("two".utf8).write(to: secondFile)
    let oldDate = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: firstFile.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: secondFile.path)
    let rules = [
        ScanRule(id: "first", title: "First", relativePath: "First", minimumAgeDays: 1, risk: .safe, explanation: ""),
        ScanRule(id: "second", title: "Second", relativePath: "Second", minimumAgeDays: 1, risk: .safe, explanation: "")
    ]

    let items = await Scanner().scan(root: root, rules: rules)

    #expect(Set(items.map { $0.rule.id }) == ["first", "second"])
}

@Test func scannerListsTopLevelTrashEntriesWithoutDescending() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-trash-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let trash = root.appending(path: ".Trash", directoryHint: .isDirectory)
    let nested = trash.appending(path: "RemovedFolder/nested.bin")
    try FileManager.default.createDirectory(at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("nested".utf8).write(to: nested)
    try Data("loose".utf8).write(to: trash.appending(path: "note.txt"))

    let items = await Scanner().scan(root: root, rules: [TrashRule.rule])
    let names = Set(items.map(\.url.lastPathComponent))
    #expect(names == ["RemovedFolder", "note.txt"])
    #expect(items.allSatisfy { $0.rule.risk == .review })
}

@Test func cleanerPermanentlyDeletesItemsAlreadyInTrash() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-empty-trash-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let trashItem = root.appending(path: ".Trash/old.txt")
    let cacheItem = root.appending(path: "Library/Caches/temp.dat")
    try FileManager.default.createDirectory(at: trashItem.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: cacheItem.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("trash".utf8).write(to: trashItem)
    try Data("cache".utf8).write(to: cacheItem)

    let trashScan = ScanItem(url: trashItem, bytes: 5, modifiedAt: Date(), rule: TrashRule.rule)
    let cacheScan = ScanItem(url: cacheItem, bytes: 5, modifiedAt: Date(), rule: UserCachesRule.rule)
    let result = await Cleaner(trashMover: RemovingTrashMover())
        .moveToTrash(items: [trashScan, cacheScan], selectedRoot: root)

    #expect(result.permanentlyDeleted.map(\.path) == [trashItem.path])
    #expect(result.movedToTrash.map(\.path) == [cacheItem.path])
    #expect(!FileManager.default.fileExists(atPath: trashItem.path))
    #expect(!FileManager.default.fileExists(atPath: cacheItem.path))
}

@Test func failedApplicationRemovalPreservesItsResidues() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: "machkit-uninstall-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: home) }
    let residueURL = home.appending(path: "Library/Preferences/com.example.app.plist")
    try FileManager.default.createDirectory(
        at: residueURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("preferences".utf8).write(to: residueURL)

    let missingAppURL = URL(
        fileURLWithPath: "/Applications/MachKitMissing-\(UUID().uuidString).app",
        isDirectory: true
    )
    let app = InstalledApplication(
        name: "Missing App",
        bundleURL: missingAppURL,
        bundleIdentifier: "com.example.app",
        version: nil,
        bytes: 0
    )
    let residue = ApplicationResidue(
        url: residueURL,
        kind: .preferences,
        bytes: 11,
        risk: .review
    )

    let result = await ApplicationScanner(trashMover: FailingTrashMover())
        .moveToTrash(app: app, residues: [residue], home: home)

    #expect(result.movedToTrash.isEmpty)
    #expect(result.failures.map(\.url) == [missingAppURL])
    #expect(FileManager.default.fileExists(atPath: residueURL.path))
}

@Test func unavailableSimulatorEnumerationDoesNotMatchActiveDevicesWithoutSimctlSignal() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-sim-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let device = root.appending(
        path: "Library/Developer/CoreSimulator/Devices/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
    try Data("plist".utf8).write(to: device.appending(path: "device.plist"))

    let items = await Scanner().scan(root: root, rules: [UnavailableSimulatorDevicesRule.rule])
    #expect(items.isEmpty)
}


@Test func agedFileScanAggregatesToFirstLevelFolders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-aggregate-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    let homebrewA = root.appending(path: "Library/Caches/Homebrew/downloads/a.bin")
    let homebrewB = root.appending(path: "Library/Caches/Homebrew/downloads/b.bin")
    let npmA = root.appending(path: "Library/Caches/npm/_cacache/x")
    try FileManager.default.createDirectory(at: homebrewA.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: npmA.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 1, count: 40).write(to: homebrewA)
    try Data(repeating: 2, count: 60).write(to: homebrewB)
    try Data(repeating: 3, count: 20).write(to: npmA)
    let oldDate = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
    for path in [homebrewA.path, homebrewB.path, npmA.path] {
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: path)
    }

    let items = await Scanner().scan(
        root: root,
        rules: [
            ScanRule(
                id: "caches",
                title: "Caches",
                relativePath: "Library/Caches",
                minimumAgeDays: 30,
                risk: .safe,
                explanation: ""
            )
        ]
    )

    #expect(items.count == 2)
    #expect(Set(items.map(\.url.lastPathComponent)) == Set(["Homebrew", "npm"]))
    let homebrew = try #require(items.first { $0.url.lastPathComponent == "Homebrew" })
    #expect(homebrew.fileCount == 2)
    #expect(homebrew.bytes == 100)
}

@Test func agedFileScanNeverSelectsAFolderContainingRecentFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-mixed-age-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    let oldFile = root.appending(path: "Library/Caches/example/old.bin")
    let recentFile = root.appending(path: "Library/Caches/example/recent.bin")
    try FileManager.default.createDirectory(at: oldFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("old".utf8).write(to: oldFile)
    try Data("recent".utf8).write(to: recentFile)
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)],
        ofItemAtPath: oldFile.path
    )

    let items = await Scanner().scan(
        root: root,
        rules: [ScanRule(
            id: "mixed-cache",
            title: "Mixed Cache",
            relativePath: "Library/Caches",
            minimumAgeDays: 30,
            risk: .safe,
            explanation: ""
        )]
    )

    #expect(items.isEmpty)
}

@Test func extensionFilteredScanReturnsOnlyMatchingFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-filtered-files-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }

    let archive = root.appending(path: "Downloads/Project/old.zip")
    let source = root.appending(path: "Downloads/Project/source.swift")
    try FileManager.default.createDirectory(at: archive.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("archive".utf8).write(to: archive)
    try Data("source".utf8).write(to: source)
    let oldDate = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: archive.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: source.path)

    let items = await Scanner().scan(root: root, rules: [DownloadsArchivesRule.rule])

    #expect(items.map(\.url.standardizedFileURL) == [archive.standardizedFileURL])
}

@Test func cleanupScanEngineAdvancesCategoriesSerially() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-cleanup-engine-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appending(path: "Alpha/group/old.one")
    let firstSibling = root.appending(path: "Alpha/group/older.one")
    let second = root.appending(path: "Beta/old.two")
    try FileManager.default.createDirectory(at: first.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("one".utf8).write(to: first)
    try Data("one-more".utf8).write(to: firstSibling)
    try Data("two".utf8).write(to: second)
    let oldDate = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: first.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: firstSibling.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: second.path)

    let categories = [
        CleanupCategorySpec(
            id: "a",
            rules: [ScanRule(id: "first", title: "First", relativePath: "Alpha", minimumAgeDays: 1, risk: .safe, explanation: "")]
        ),
        CleanupCategorySpec(
            id: "b",
            rules: [ScanRule(id: "second", title: "Second", relativePath: "Beta", minimumAgeDays: 1, risk: .safe, explanation: "")]
        )
    ]

    let progress = LockedCleanupProgress()
    let items = await CleanupScanEngine().scan(
        root: root,
        home: root,
        categories: categories
    ) { event in
        progress.observe(event)
    }

    #expect(progress.categoryIDs == ["a", "b"])
    #expect(items.count == 2)
    #expect(progress.maxOverall >= 0.99)
    #expect(progress.inspectionCountIsMonotonic)
}

private final class LockedCleanupProgress: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var categoryIDs: [String] = []
    private(set) var maxOverall = 0.0
    private(set) var inspectionCountIsMonotonic = true
    private var lastInspectedFiles = 0

    func observe(_ event: CleanupScanProgressEvent) {
        lock.lock()
        defer { lock.unlock() }
        if categoryIDs.last != event.categoryID {
            categoryIDs.append(event.categoryID)
        }
        maxOverall = max(maxOverall, event.overallFraction)
        if event.inspectedFiles < lastInspectedFiles {
            inspectionCountIsMonotonic = false
        }
        lastInspectedFiles = event.inspectedFiles
    }
}


@Test func scannerCombinesMultipleRelativePathsForOneRule() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-multipath-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstFile = root.appending(path: "Alpha/old.one")
    let secondFile = root.appending(path: "Beta/old.two")
    try FileManager.default.createDirectory(at: firstFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("one".utf8).write(to: firstFile)
    try Data("two".utf8).write(to: secondFile)
    let oldDate = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: firstFile.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: secondFile.path)

    let rule = ScanRule(
        id: "multi",
        title: "Multi",
        relativePaths: ["Alpha", "Beta"],
        minimumAgeDays: 1,
        risk: .safe,
        explanation: ""
    )
    let items = await Scanner().scan(root: root, rules: [rule])

    #expect(items.count == 2)
    #expect(Set(items.map(\.rule.id)) == ["multi"])
}

@Test func scannerDoesNotDescendIntoExcludedCacheRoots() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-exclusions-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = root.appending(path: "Library/Caches", directoryHint: .isDirectory)
    let ordinary = cache.appending(path: "ordinary/old.data")
    let excluded = cache.appending(path: "Developer/old.data")
    try FileManager.default.createDirectory(at: ordinary.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: excluded.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("ordinary".utf8).write(to: ordinary)
    try Data("excluded".utf8).write(to: excluded)
    let oldDate = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: ordinary.path)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: excluded.path)

    let rule = ScanRule(
        id: "cache",
        title: "Cache",
        relativePath: "Library/Caches",
        minimumAgeDays: 1,
        excludedRelativePaths: ["Developer"],
        risk: .safe,
        explanation: ""
    )
    let items = await Scanner().scan(root: root, rules: [rule])

    #expect(
        items.map { $0.url.resolvingSymlinksInPath().path }
            == [ordinary.deletingLastPathComponent().resolvingSymlinksInPath().path]
    )
}

@Test func matchingDirectoryRulesSelectCachesButPreserveProfileData() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-app-support-cache-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let appRoot = root.appending(path: "Library/Application Support/Example", directoryHint: .isDirectory)
    let cache = appRoot.appending(path: "Default/Code Cache", directoryHint: .isDirectory)
    let cookies = appRoot.appending(path: "Default/Cookies", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: cookies, withIntermediateDirectories: true)
    try Data("cache".utf8).write(to: cache.appending(path: "entry.bin"))
    try Data("cookie".utf8).write(to: cookies.appending(path: "database"))
    let oldDate = Date(timeIntervalSinceNow: -10 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: cache.path)

    let rule = ScanRule(
        id: "support-cache",
        title: "Support Cache",
        relativePath: "Library/Application Support/Example",
        minimumAgeDays: 7,
        enumerationMode: .matchingDirectories,
        matchedDirectoryNames: ["Code Cache"],
        maximumDepth: 4,
        risk: .safe,
        explanation: ""
    )
    let items = await Scanner().scan(root: root, rules: [rule])

    #expect(items.map(\.url.standardizedFileURL.path) == [cache.standardizedFileURL.path])
    #expect(!items.contains { $0.url.standardizedFileURL.path == cookies.standardizedFileURL.path })
}

@Test func projectArtifactScanRequiresAProjectMarkerAndSkipsRecentOutput() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "machkit-project-artifacts-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appending(path: "Project", directoryHint: .isDirectory)
    let nodeModules = project.appending(path: "node_modules", directoryHint: .isDirectory)
    let recentDist = project.appending(path: "dist", directoryHint: .isDirectory)
    let unrelated = root.appending(path: "Archive/node_modules", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: recentDist, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: project.appending(path: "package.json"))
    try Data("dependency".utf8).write(to: nodeModules.appending(path: "module.js"))
    try Data("bundle".utf8).write(to: recentDist.appending(path: "app.js"))
    try Data("keep".utf8).write(to: unrelated.appending(path: "module.js"))
    let oldDate = Date(timeIntervalSinceNow: -10 * 24 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: nodeModules.path)

    let items = await Scanner().scan(root: root, rules: [ProjectBuildArtifactsRule.rule])

    #expect(items.map(\.url.standardizedFileURL.path) == [nodeModules.standardizedFileURL.path])
    #expect(items.allSatisfy { $0.rule.risk == .review })
}

