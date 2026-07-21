@testable import SiftCore
import Foundation
import Testing

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
    #expect(missingResult?.contains("数据库仍保留这个旧路径") == true)
}
