@testable import SiftCore
import Foundation
import Testing

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func formatPlaceholders(in value: String) -> [String] {
    let expression = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(?:lld|llu|ld|lu|zd|zu|d|u|f|g|s|c|@)"#)
    let range = NSRange(value.startIndex..., in: value)
    return expression.matches(in: value, range: range).compactMap { match in
        guard let range = Range(match.range, in: value) else { return nil }
        return String(value[range]).replacingOccurrences(
            of: #"%\d+\$"#,
            with: "%",
            options: .regularExpression
        )
    }.sorted()
}

@Test func developerRulesDoNotTargetInstalledDependencies() {
    let paths = DefaultRules.conservative.map(\.relativePath)
    #expect(paths.allSatisfy { !$0.contains("node_modules") })
    #expect(paths.allSatisfy { !$0.contains("site-packages") })
    #expect(paths.allSatisfy { !$0.contains(".venv") })
    #expect(paths.allSatisfy { !$0.contains(".nvm") })
    #expect(paths.allSatisfy { !$0.contains("Cellar") })
}

@Test func fileAnalysisNeverDefaultsToSafeDeletion() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "large.bin")
    try Data(repeating: 0, count: 1_024).write(to: file)

    let results = await FileAnalyzer().largeFiles(in: root, minimumBytes: 1)
    #expect(results.count == 1)
    #expect(results.first?.rule.risk == .review)
}

@Test func storageAnalysisClassifiesCommonFoldersWithoutMarkingFilesForDeletion() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let downloads = root.appending(path: "Downloads", directoryHint: .isDirectory)
    let pictures = root.appending(path: "Pictures", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data(repeating: 1, count: 2_048).write(to: downloads.appending(path: "archive.zip"))
    try Data(repeating: 2, count: 1_024).write(to: pictures.appending(path: "photo.jpg"))

    let analysis = await FileAnalyzer().storageAnalysis(
        roots: [root],
        volumeURL: root,
        largeFileMinimumBytes: 1
    )

    #expect(analysis.scannedFileCount == 2)
    #expect(analysis.categories.first(where: { $0.category == .downloads })?.fileCount == 1)
    #expect(analysis.categories.first(where: { $0.category == .pictures })?.fileCount == 1)
    #expect(analysis.largeFiles.count == 2)
    #expect(analysis.largeFiles.allSatisfy { $0.rule.risk == .review })
}

@Test func directoryOverviewOnlyReturnsImmediateChildrenWithExplanations() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let downloads = root.appending(path: "Downloads", directoryHint: .isDirectory)
    let nested = downloads.appending(path: "Nested", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 4_096).write(to: nested.appending(path: "archive.bin"))
    defer { try? FileManager.default.removeItem(at: root) }

    let overview = await FileAnalyzer().directoryOverview(root: root, volumeURL: root)
    #expect(overview.analyzedRoots == [root.standardizedFileURL])
    #expect(overview.directories.count == 1)
    #expect(overview.directories.first?.url.lastPathComponent == "Downloads")
    #expect(overview.directories.first?.explanation.contains("downloaded") == true)
    #expect(!overview.directories.contains { $0.url.lastPathComponent == "Nested" })
    #expect(overview.largeFiles.isEmpty)
}

@Test func portScannerKeepsListenersAndBoundUDPPortsOnly() {
    let output = """
    p4100
    cnode
    u501
    f12
    PTCP
    n127.0.0.1:5173
    TST=LISTEN
    f13
    PTCP
    n127.0.0.1:5173
    TST=LISTEN
    f15
    PUDP
    n*:5353
    p4200
    cgo-api
    u501
    f8
    PUDP
    n0.0.0.0:9000
    f9
    PUDP
    n192.168.1.20:62000->8.8.8.8:53
    """

    let records = PortScanner.parseLSOFOutput(output)
    let hasNodeTCP = records.contains { record in
        record.processIdentifier == 4100 && record.transport == .tcp && record.port == 5173
    }
    let hasNodeUDP = records.contains { record in
        record.processIdentifier == 4100 && record.transport == .udp && record.port == 5353
    }
    let hasGoUDP = records.contains { record in
        record.processIdentifier == 4200 && record.transport == .udp && record.port == 9000
    }
    let hasConnectedUDP = records.contains { $0.port == 62000 }

    #expect(records.count == 3)
    #expect(hasNodeTCP)
    #expect(hasNodeUDP)
    #expect(hasGoUDP)
    #expect(!hasConnectedUDP)
}

@Test func portScannerDecodesEscapedUTF8Paths() {
    let escaped = "/Users/test/\\xe4\\xb8\\xad\\xe6\\x96\\x87\\xe9\\xa1\\xb9\\xe7\\x9b\\xae"
    #expect(PortScanner.decodeEscapedUTF8(escaped) == "/Users/test/中文项目")
    #expect(PortScanner.decodeEscapedUTF8("/tmp/folder\\x20name") == "/tmp/folder\\x20name")
}

@Test func portScannerDescribesCommonDeveloperServices() {
    #expect(PortScanner.processDescription(
        processName: "node",
        executablePath: "/opt/homebrew/bin/node",
        commandLine: "node /workspace/node_modules/.bin/vite --host",
        port: 5173
    ) == "Vite Development Server")
    #expect(PortScanner.processDescription(
        processName: "api",
        executablePath: "/private/var/folders/example/go-build/api",
        commandLine: "/private/var/folders/example/go-build/api",
        port: 8080
    ) == "Go Development Service")
    #expect(PortScanner.processDescription(
        processName: "python3",
        executablePath: "/opt/homebrew/bin/python3",
        commandLine: "python3 -m uvicorn app:main",
        port: 8000
    ) == "Uvicorn / FastAPI Service")
    #expect(PortScanner.processDescription(
        processName: "postgres",
        executablePath: "/opt/homebrew/bin/postgres",
        commandLine: nil,
        port: 5432
    ) == "PostgreSQL Database")
}

@Test func portTerminationProtectsSystemAndUnverifiedProcesses() {
    let developerProcess = PortScanner.protectionReason(
        processIdentifier: 4100,
        ownerUserID: 501,
        executablePath: "/opt/homebrew/bin/node",
        currentUserID: 501,
        currentProcessID: 9999
    )
    let systemProcess = PortScanner.protectionReason(
        processIdentifier: 4200,
        ownerUserID: 501,
        executablePath: "/usr/libexec/rapportd",
        currentUserID: 501,
        currentProcessID: 9999
    )
    let otherUserProcess = PortScanner.protectionReason(
        processIdentifier: 4300,
        ownerUserID: 0,
        executablePath: "/opt/homebrew/bin/node",
        currentUserID: 501,
        currentProcessID: 9999
    )
    let unknownProcess = PortScanner.protectionReason(
        processIdentifier: 4400,
        ownerUserID: 501,
        executablePath: nil,
        currentUserID: 501,
        currentProcessID: 9999
    )

    #expect(developerProcess == nil)
    #expect(systemProcess != nil)
    #expect(otherUserProcess != nil)
    #expect(unknownProcess != nil)
}

@Test func packageManagersExposeSafeUninstallGuidance() {
    #expect(CommandLineToolManager.homebrew.uninstallCommand(name: "ripgrep", version: nil) == "brew uninstall ripgrep")
    #expect(CommandLineToolManager.homebrewCask.uninstallCommand(name: "firefox", version: nil) == "brew uninstall --cask firefox")
    #expect(CommandLineToolManager.npm.uninstallCommand(name: "typescript", version: nil) == "npm uninstall -g typescript")
    #expect(CommandLineToolManager.uv.uninstallCommand(name: "ruff", version: nil) == "uv tool uninstall ruff")
    #expect(CommandLineToolManager.sdkman.uninstallCommand(name: "java", version: "21-tem") == "sdk uninstall java 21-tem")
}

@Test func ambiguousBinariesNeverInventRemovalCommands() {
    #expect(CommandLineToolManager.go.uninstallCommand(name: "tool", version: nil) == nil)
    #expect(CommandLineToolManager.manual.uninstallCommand(name: "tool", version: nil) == nil)
}

@Test func loginItemInventoryReadsKnownLaunchdDomainsWithoutChangingThem() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let home = root.appending(path: "Home", directoryHint: .isDirectory)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let userAgents = home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
    let daemons = library.appending(path: "LaunchDaemons", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: userAgents, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: daemons, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let userPlist: [String: Any] = [
        "Label": "com.example.menu-helper",
        "ProgramArguments": ["/Applications/Example.app/Contents/MacOS/helper"],
        "RunAtLoad": true
    ]
    let daemonPlist: [String: Any] = [
        "Label": "com.example.daemon",
        "Program": "/Library/PrivilegedHelperTools/com.example.daemon",
        "KeepAlive": true
    ]
    try PropertyListSerialization.data(fromPropertyList: userPlist, format: .xml, options: 0)
        .write(to: userAgents.appending(path: "com.example.menu-helper.plist"))
    try PropertyListSerialization.data(fromPropertyList: daemonPlist, format: .xml, options: 0)
        .write(to: daemons.appending(path: "com.example.daemon.plist"))

    let items = await SystemInventoryScanner().loginItems(home: home, libraryRoot: library)
    #expect(items.count == 2)
    #expect(items.first(where: { $0.label == "com.example.menu-helper" })?.domain == .userAgent)
    #expect(items.first(where: { $0.label == "com.example.menu-helper" })?.runsAtLoad == true)
    #expect(items.first(where: { $0.label == "com.example.menu-helper" })?.assessment == .likelyResidue)
    #expect(items.first(where: { $0.label == "com.example.daemon" })?.domain == .daemon)
    #expect(items.first(where: { $0.label == "com.example.daemon" })?.keepsAlive == true)
}

@Test func loginItemRemovalRejectsNestedAndLookalikeDirectories() async {
    let home = URL(fileURLWithPath: "/tmp/SiftHome", isDirectory: true)
    let library = URL(fileURLWithPath: "/tmp/SiftLibrary", isDirectory: true)
    let nested = home.appending(path: "Library/LaunchAgents/Nested/item.plist")
    let lookalike = home.appending(path: "Library/LaunchAgents-Old/item.plist")
    let scanner = SystemInventoryScanner()

    for url in [nested, lookalike] {
        let item = LoginItem(
            label: "test",
            configURL: url,
            executableURL: nil,
            domain: .userAgent,
            runsAtLoad: true,
            keepsAlive: false
        )
        let result = await scanner.moveLoginItemToTrash(item, home: home, libraryRoot: library)
        #expect(result.movedToTrash.isEmpty)
        #expect(result.failures.count == 1)
    }
}

@Test func extensionInventoryClassifiesEmbeddedSafariExtensions() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let appURL = root.appending(path: "Example.app", directoryHint: .isDirectory)
    let extensionURL = appURL.appending(path: "Contents/PlugIns/WebExtension.appex", directoryHint: .isDirectory)
    let contents = extensionURL.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let info: [String: Any] = [
        "CFBundleIdentifier": "com.example.app.web-extension",
        "CFBundleName": "Example Web Extension",
        "CFBundlePackageType": "XPC!",
        "CFBundleShortVersionString": "1.2",
        "NSExtension": ["NSExtensionPointIdentifier": "com.apple.Safari.web-extension"]
    ]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: contents.appending(path: "Info.plist"))

    let app = InstalledApplication(
        name: "Example",
        bundleURL: appURL,
        bundleIdentifier: "com.example.app",
        version: "1.0",
        bytes: 0
    )
    let extensions = await SystemInventoryScanner().extensions(
        in: [app],
        home: root.appending(path: "Home"),
        libraryRoot: root.appending(path: "Library")
    )
    #expect(extensions.count == 1)
    #expect(extensions.first?.kind == .safari)
    #expect(extensions.first?.ownerName == "Example")
    #expect(extensions.first?.bundleIdentifier == "com.example.app.web-extension")
    #expect(extensions.first?.assessment == .present)

    let removal = await SystemInventoryScanner().moveExtensionToTrash(
        extensions[0],
        home: root.appending(path: "Home"),
        libraryRoot: root.appending(path: "Library")
    )
    #expect(removal.movedToTrash.isEmpty)
    #expect(removal.failures.count == 1)
}

@Test func standaloneExtensionWithoutMatchingApplicationIsMarkedAsPossibleResidue() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let library = root.appending(path: "Library", directoryHint: .isDirectory)
    let extensionURL = library.appending(path: "QuickLook/OldPreview.qlgenerator", directoryHint: .isDirectory)
    let contents = extensionURL.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let info: [String: Any] = [
        "CFBundleIdentifier": "com.removed.vendor.preview",
        "CFBundleName": "Old Preview",
        "CFBundlePackageType": "BNDL"
    ]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: contents.appending(path: "Info.plist"))

    let extensions = await SystemInventoryScanner().extensions(
        in: [],
        home: root.appending(path: "Home"),
        libraryRoot: library
    )
    #expect(extensions.count == 1)
    #expect(extensions.first?.kind == .quickLook)
    #expect(extensions.first?.assessment == .likelyResidue)
    #expect(extensions.first?.ownerApplicationURL == nil)
}

@Test func loginApplicationParsingOnlyFlagsMissingFiles() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let existing = root.appending(path: "Existing.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let output = """
    Existing\t\(existing.path)\tfalse
    Removed\t\(root.appending(path: "Removed.app").path)\ttrue
    Unknown\t\tfalse

    """
    let items = SystemInventoryScanner.parseLoginApplications(output, fileManager: .default)
    #expect(items.first(where: { $0.name == "Existing" })?.assessment == .present)
    #expect(items.first(where: { $0.name == "Removed" })?.assessment == .likelyResidue)
    #expect(items.first(where: { $0.name == "Unknown" })?.assessment == .unknown)
    #expect(items.first(where: { $0.name == "Removed" })?.isHidden == true)
}

@Test func backgroundTaskDatabaseFindsUninstalledAppsAndDeduplicatesRecords() {
    let output = """
    ========================
     Records for UID -2 : FFFFEEEE-DDDD-CCCC-BBBB-AAAAFFFFFFFE
    ========================

     #1:
                     Name: Pearcleaner
          Team Identifier: BK8443AXLU
                     Type: app (0x2)
              Disposition: [disabled, allowed, not notified] (0x2)
               Identifier: 2.com.alienator88.Pearcleaner
                      URL: file:///Users/test/.Trash/Pearcleaner.app/
        Bundle Identifier: com.alienator88.Pearcleaner

     #2:
                     Name: PearcleanerHelper
                     Type: daemon (0x10)
               Identifier: 16.com.alienator88.Pearcleaner.PearcleanerHelper

    ========================
     Records for UID 501 : EXAMPLE
    ========================

     #1:
                     Name: Pearcleaner
          Team Identifier: BK8443AXLU
                     Type: app (0x2)
              Disposition: [disabled, allowed, notified] (0xa)
               Identifier: 2.com.alienator88.Pearcleaner
                      URL: file:///Users/test/.Trash/Pearcleaner.app/
        Bundle Identifier: com.alienator88.Pearcleaner

    """
    let items = SystemInventoryScanner.parseRegisteredBackgroundTasks(output, fileManager: .default)
    #expect(items.count == 1)
    #expect(items.first?.name == "Pearcleaner")
    #expect(items.first?.bundleIdentifier == "com.alienator88.Pearcleaner")
    #expect(items.first?.assessment == .likelyResidue)
}

@Test func backgroundTaskRemovalOnlyDeletesResiduesInsideCurrentUsersTrash() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let home = root.appending(path: "Home", directoryHint: .isDirectory)
    let trashedApp = home.appending(path: ".Trash/Removed.app", directoryHint: .isDirectory)
    let outsideApp = root.appending(path: "Removed.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: trashedApp, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outsideApp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let trashedItem = RegisteredBackgroundTask(
        id: "com.example.removed",
        name: "Removed",
        bundleIdentifier: "com.example.removed",
        teamIdentifier: nil,
        applicationURL: trashedApp,
        isEnabled: false,
        assessment: .likelyResidue
    )
    let outsideItem = RegisteredBackgroundTask(
        id: "com.example.outside",
        name: "Outside",
        bundleIdentifier: "com.example.outside",
        teamIdentifier: nil,
        applicationURL: outsideApp,
        isEnabled: false,
        assessment: .likelyResidue
    )
    let scanner = SystemInventoryScanner()

    #expect(await scanner.removeRegisteredBackgroundTaskResidue(outsideItem, home: home) != nil)
    #expect(FileManager.default.fileExists(atPath: outsideApp.path))
    #expect(await scanner.removeRegisteredBackgroundTaskResidue(trashedItem, home: home) == nil)
    #expect(!FileManager.default.fileExists(atPath: trashedApp.path))
    let missingResult = await scanner.removeRegisteredBackgroundTaskResidue(trashedItem, home: home)
    #expect(missingResult?.contains("database still retains this old path") == true)
}

@Test func aiEndpointsRequireEncryptedTransportExceptForLoopbackDevelopment() {
    #expect(AIEndpointBuilder.chatCompletionsURL(baseURL: "https://api.openai.com/v1")?.absoluteString ==
        "https://api.openai.com/v1/chat/completions")
    #expect(AIEndpointBuilder.chatCompletionsURL(baseURL: "https://example.com/v1/chat/completions")?.absoluteString ==
        "https://example.com/v1/chat/completions")
    #expect(AIEndpointBuilder.chatCompletionsURL(baseURL: "http://example.com/v1") == nil)
    #expect(AIEndpointBuilder.chatCompletionsURL(baseURL: "http://localhost:11434/v1")?.absoluteString ==
        "http://localhost:11434/v1/chat/completions")
    #expect(AIEndpointBuilder.chatCompletionsURL(baseURL: "http://127.0.0.1:1234")?.absoluteString ==
        "http://127.0.0.1:1234/chat/completions")
}

@Test func localizationCatalogHasNoEmptyKeysAndKeepsFormatArgumentsCompatible() throws {
    let catalogURL = repositoryRoot.appending(path: "Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(object["strings"] as? [String: Any])

    #expect(strings[""] == nil)
    for (key, rawEntry) in strings {
        guard let entry = rawEntry as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else { continue }
        let expected = formatPlaceholders(in: key)
        for (locale, rawLocalization) in localizations {
            guard let localization = rawLocalization as? [String: Any],
                  let unit = localization["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else { continue }
            #expect(
                formatPlaceholders(in: value) == expected,
                "Placeholder mismatch for \(locale) translation of \(key)"
            )
        }
    }
}

@Test func appSourcesNeverUseAnEmptyLocalizationFormatKey() throws {
    let sources = repositoryRoot.appending(path: "App/Sources")
    let files = try FileManager.default.contentsOfDirectory(
        at: sources,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }
    let expression = try NSRegularExpression(pattern: #"L10n\s*\.\s*format\s*\(\s*\"\""#)

    for file in files {
        let source = try String(contentsOf: file, encoding: .utf8)
        let range = NSRange(source.startIndex..., in: source)
        #expect(
            expression.firstMatch(in: source, range: range) == nil,
            "Empty localization format key in \(file.lastPathComponent)"
        )
    }
}

@Test func changingPagesDoesNotCancelOrClearAnActiveCleanupScan() throws {
    let sourceURL = repositoryRoot.appending(path: "App/Sources/CleanerViewModel.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let start = try #require(source.range(of: "func changeMode(_ newMode: FeatureMode)"))
    let tail = source[start.lowerBound...]
    let end = try #require(tail.range(of: "\n    func ", range: start.upperBound..<tail.endIndex))
    let implementation = String(tail[..<end.lowerBound])

    #expect(!implementation.contains("scanTask?.cancel()"))
    #expect(!implementation.contains("items = []"))
    #expect(!implementation.contains("selectedIDs = []"))
}
