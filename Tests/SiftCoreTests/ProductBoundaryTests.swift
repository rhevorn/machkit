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

@Test func systemCommandsHaveADeadlineInsteadOfHangingForever() throws {
    let startedAt = Date()
    do {
        _ = try SystemCommandRunner.run(
            executable: "/bin/sleep",
            arguments: ["5"],
            timeout: 0.1
        )
        Issue.record("The command should have timed out")
    } catch let error as SystemCommandRunnerError {
        guard case .timedOut = error else {
            Issue.record("Expected a timeout, received \(error)")
            return
        }
    }
    #expect(Date().timeIntervalSince(startedAt) < 2)
}

@Test func releaseWorkflowTestsAndBuildsBothMacArchitectures() throws {
    let workflow = try String(
        contentsOf: repositoryRoot.appending(path: ".github/workflows/release.yml"),
        encoding: .utf8
    )
    #expect(workflow.contains("swift test -c release"))
    #expect(workflow.contains("generic/platform=macOS"))
    #expect(workflow.contains("ARCHS=\"arm64 x86_64\""))
    #expect(workflow.contains("lipo -archs"))
}

@Test func closingTheLastWindowOnlyKeepsAnEnabledMenuBarAppAlive() throws {
    let source = try String(
        contentsOf: repositoryRoot.appending(path: "App/Sources/SiftApp.swift"),
        encoding: .utf8
    )
    #expect(source.contains("applicationShouldTerminateAfterLastWindowClosed"))
    #expect(source.contains("!UserDefaults.standard.bool(forKey: AppPreferenceKey.showMenuBar)"))
    #expect(source.contains("isInserted: $showMenuBar"))
    #expect(!source.contains("menuBarInserted"))
    #expect(source.contains("AppPreferenceKey.menuBarCloseBehaviorRepair"))
    #expect(source.contains("defaults.set(true, forKey: AppPreferenceKey.showMenuBar)"))
}

@Test func privacyPromptUsesEnglishFallbackAndAllSupportedTranslations() throws {
    let plistData = try Data(contentsOf: repositoryRoot.appending(path: "App/Info.plist"))
    let plist = try #require(
        PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
    )
    let fallback = try #require(plist["NSAppleEventsUsageDescription"] as? String)
    #expect(fallback == "Sift needs access to System Events to read and remove login items configured in macOS.")

    let catalogData = try Data(contentsOf: repositoryRoot.appending(path: "Resources/InfoPlist.xcstrings"))
    let catalog = try #require(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
    let strings = try #require(catalog["strings"] as? [String: Any])
    let entry = try #require(strings["NSAppleEventsUsageDescription"] as? [String: Any])
    let localizations = try #require(entry["localizations"] as? [String: Any])
    let expectedLocales: Set<String> = [
        "de", "en", "es", "fr", "ja", "ko", "pt-BR", "ru", "zh-Hans", "zh-Hant"
    ]
    #expect(expectedLocales.isSubset(of: Set(localizations.keys)))
}

@Test func developerRulesDoNotTargetInstalledDependencies() {
    let paths = DefaultRules.conservative.map(\.relativePath)
    #expect(paths.allSatisfy { !$0.contains("node_modules") })
    #expect(paths.allSatisfy { !$0.contains("site-packages") })
    #expect(paths.allSatisfy { !$0.contains(".venv") })
    #expect(paths.allSatisfy { !$0.contains(".nvm") })
    #expect(paths.allSatisfy { !$0.contains("Cellar") })
}

@Test func cleanupRuleRegistryKeepsOneRulePerDefinitionFile() throws {
    let rulesDirectory = repositoryRoot.appending(path: "Sources/SiftCore/CleanupRules", directoryHint: .isDirectory)
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
        .appending(path: "sift-parallel-rules-\(UUID().uuidString)", directoryHint: .isDirectory)
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

@Test func broadCacheRuleExcludesDedicatedDeveloperCacheRoots() throws {
    let broadRule = try #require(DefaultRules.conservative.first { $0.id == "user-caches" })
    let nestedRules = DefaultRules.conservative.filter {
        $0.id != broadRule.id && $0.relativePath.hasPrefix("Library/Caches/")
    }

    for rule in nestedRules {
        let relative = String(rule.relativePath.dropFirst("Library/Caches/".count))
        #expect(broadRule.excludedRelativePaths.contains { excluded in
            relative == excluded || relative.hasPrefix(excluded + "/")
        }, "Dedicated cache rule overlaps the broad user cache rule: \(rule.id)")
    }
}

@Test func scannerDoesNotDescendIntoExcludedCacheRoots() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "sift-exclusions-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    #expect(items.map { $0.url.resolvingSymlinksInPath().path } == [ordinary.resolvingSymlinksInPath().path])
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

@Test func networkScannerParsesProcessTrafficAndDottedNames() throws {
    let output = """
    ,bytes_in,bytes_out,
    Code Helper.32739,18946,8727,
    com.apple.WebKi.8447,5610,3122,
    """

    let records = NetworkScanner.parseProcessTrafficOutput(output)
    #expect(records.count == 2)
    #expect(records[0].processIdentifier == 32739)
    #expect(records[0].name == "Code Helper")
    #expect(records[0].received == 18_946)
    #expect(records[1].processIdentifier == 8447)
    #expect(records[1].name == "com.apple.WebKi")
}

@Test func networkScannerSeparatesActiveConnectionsFromListeners() {
    let output = """
    p4100
    cnode
    f12
    PTCP
    n127.0.0.1:5173
    TST=LISTEN
    f13
    PTCP
    n192.168.1.20:62000->1.1.1.1:443
    TST=ESTABLISHED
    p4200
    cdns-client
    f8
    PUDP
    n[fe80::1]:5353->[2606:4700:4700::1111]:53
    """

    let records = NetworkScanner.parseConnections(
        output,
        addressToInterface: ["192.168.1.20": "en0", "fe80::1": "en0"]
    )
    #expect(records.count == 3)
    #expect(records.contains { $0.localPort == 5173 && $0.isListener })
    #expect(records.contains {
        $0.remoteAddress == "1.1.1.1" && $0.remotePort == 443 && $0.interfaceName == "en0" && !$0.isListener
    })
    #expect(records.contains {
        $0.remoteAddress == "2606:4700:4700::1111" && $0.remotePort == 53 && $0.interfaceName == "en0"
    })
}

@Test func networkScannerParsesRoutesProxyAndRouteLookup() {
    let routeTable = """
    Routing tables

    Internet:
    Destination        Gateway            Flags               Netif Expire
    default            192.168.1.1        UGScg                 en0
    10/8               10.0.0.1           UGSc                 utun4
    """
    let routes = NetworkScanner.parseRoutes(routeTable, family: "IPv4")
    #expect(routes.count == 2)
    #expect(routes[0].isDefault)
    #expect(routes[1].interfaceName == "utun4")

    let proxy = NetworkScanner.parseProxyConfiguration("""
    <dictionary> {
      HTTPEnable : 1
      HTTPProxy : 127.0.0.1
      HTTPPort : 7890
      SOCKSEnable : 0
      ProxyAutoConfigEnable : 1
      ProxyAutoConfigURLString : http://127.0.0.1/proxy.pac
    }
    """)
    #expect(proxy.isEnabled)
    #expect(proxy.services == ["HTTP 127.0.0.1:7890", "PAC http://127.0.0.1/proxy.pac"])

    let detectedProxy = NetworkScanner.augmentProxyConfiguration(
        NetworkProxyConfiguration(services: []),
        connections: [NetworkConnection(
            processIdentifier: 4331,
            processName: "verge-mihomo",
            transport: .tcp,
            localAddress: "192.168.1.20",
            localPort: 62000,
            remoteAddress: "1.1.1.1",
            remotePort: 443,
            state: "ESTABLISHED",
            interfaceName: "en0",
            isListener: false
        )],
        interfaces: [NetworkInterfaceUsage(
            name: "utun4",
            displayName: "VPN / TUN",
            kind: .tunnel,
            isUp: true,
            addresses: ["10.0.0.2"],
            receivedBytes: 0,
            sentBytes: 0,
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0
        )]
    )
    #expect(detectedProxy.services == ["Detected verge-mihomo", "TUN utun4"])

    let lookup = NetworkScanner.parseRouteLookup("""
       route to: 1.1.1.1
    destination: default
           mask: default
        gateway: 192.168.1.1
      interface: en0
    """, query: "1.1.1.1", status: 0)
    #expect(lookup.destination == "1.1.1.1")
    #expect(lookup.gateway == "192.168.1.1")
    #expect(lookup.interfaceName == "en0")
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

@Test func localizationCatalogHasNoEmptyKeysAndKeepsFormatArgumentsCompatible() throws {
    let catalogURL = repositoryRoot.appending(path: "Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(object["strings"] as? [String: Any])
    let supportedLocales: Set<String> = [
        "de", "es", "fr", "ja", "ko", "pt-BR", "ru", "zh-Hans", "zh-Hant"
    ]

    #expect(strings[""] == nil)
    for (key, rawEntry) in strings {
        guard let entry = rawEntry as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else {
            Issue.record("Missing localizations for \(key)")
            continue
        }
        #expect(
            supportedLocales.isSubset(of: Set(localizations.keys)),
            "Incomplete locale coverage for \(key)"
        )
        let expected = formatPlaceholders(in: key)
        for locale in supportedLocales {
            guard let localization = localizations[locale] as? [String: Any],
                  let unit = localization["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else {
                Issue.record("Missing \(locale) string unit for \(key)")
                continue
            }
            #expect(!value.isEmpty, "Empty \(locale) translation for \(key)")
            #expect(
                formatPlaceholders(in: value) == expected,
                "Placeholder mismatch for \(locale) translation of \(key)"
            )
        }
    }
}

@Test func explicitRuntimeLocalizationKeysExistInCatalog() throws {
    let catalogURL = repositoryRoot.appending(path: "Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(object["strings"] as? [String: Any])
    let catalogKeys = Set(strings.keys)
    let sources = repositoryRoot.appending(path: "App/Sources")
    let files = try FileManager.default.contentsOfDirectory(
        at: sources,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }
    let expression = try NSRegularExpression(
        pattern: #"L10n\s*\.\s*(?:format|string)\s*\(\s*\"((?:\\.|[^\"\\])*)\""#
    )

    for file in files where file.lastPathComponent != "Localization.swift" {
        let source = try String(contentsOf: file, encoding: .utf8)
        let range = NSRange(source.startIndex..., in: source)
        for match in expression.matches(in: source, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
            let key = String(source[keyRange])
            #expect(catalogKeys.contains(key), "Missing localization key \(key) used by \(file.lastPathComponent)")
        }
    }
}

@Test func appSourcesNeverCreateEmptyLocalizationKeys() throws {
    let sources = repositoryRoot.appending(path: "App/Sources")
    let files = try FileManager.default.contentsOfDirectory(
        at: sources,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }
    let expressions = try [
        #"L10n\s*\.\s*(?:format|string)\s*\(\s*\"\""#,
        #"Toggle\s*\(\s*\"\""#
    ].map { try NSRegularExpression(pattern: $0) }

    for file in files {
        let source = try String(contentsOf: file, encoding: .utf8)
        let range = NSRange(source.startIndex..., in: source)
        for expression in expressions {
            #expect(
                expression.firstMatch(in: source, range: range) == nil,
                "Empty localization key in \(file.lastPathComponent)"
            )
        }
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

@Test func orphanedApplicationResiduesRequireConservativeEvidence() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: "sift-residue-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: home) }

    func makeDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: home.appending(path: relativePath, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    try makeDirectory("Library/Caches/com.example.removed")
    try makeDirectory("Library/Preferences")
    try Data("settings".utf8).write(to: home.appending(path: "Library/Preferences/com.example.removed.plist"))
    try makeDirectory("Library/Caches/com.example.present")
    try Data("settings".utf8).write(to: home.appending(path: "Library/Preferences/com.example.present.plist"))
    try makeDirectory("Library/Caches/com.example.lonely")
    try makeDirectory("Library/Containers/com.example.container")
    try makeDirectory("Library/Containers/com.apple.system-helper")

    let groups = await ApplicationScanner().orphanedResidues(
        installedBundleIdentifiers: ["com.example.present"],
        home: home
    )

    #expect(groups.contains { $0.identifier == "com.example.removed" && $0.residues.count == 2 })
    #expect(groups.contains { $0.identifier == "com.example.container" && $0.residues.count == 1 })
    #expect(!groups.contains { $0.identifier == "com.example.present" })
    #expect(!groups.contains { $0.identifier == "com.example.lonely" })
    #expect(!groups.contains { $0.identifier.hasPrefix("com.apple.") })
    #expect(groups.flatMap(\.residues).allSatisfy { $0.risk == .review })
}
