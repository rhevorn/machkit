import SiftCore
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
