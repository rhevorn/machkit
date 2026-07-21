import Foundation

public actor SystemInventoryScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func loginItems(
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) -> [LoginItem] {
        let roots: [(URL, LoginItemDomain)] = [
            (home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory), .userAgent),
            (libraryRoot.appending(path: "LaunchAgents", directoryHint: .isDirectory), .sharedAgent),
            (libraryRoot.appending(path: "LaunchDaemons", directoryHint: .isDirectory), .daemon)
        ]

        return roots.flatMap { root, domain -> [LoginItem] in
            guard let files = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return files.compactMap { url in
                guard url.pathExtension.lowercased() == "plist",
                      let data = try? Data(contentsOf: url),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                      let values = plist as? [String: Any] else { return nil }

                let label = values["Label"] as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let program = values["Program"] as? String
                    ?? (values["ProgramArguments"] as? [String])?.first
                let executableURL = resolvedExecutableURL(program, home: home)
                let assessment: ComponentAssessment
                if let executableURL {
                    assessment = fileManager.fileExists(atPath: executableURL.path) ? .present : .likelyResidue
                } else {
                    assessment = .unknown
                }
                let keepAliveValue = values["KeepAlive"]
                let keepsAlive = (keepAliveValue as? Bool) == true
                    || (keepAliveValue as? [String: Any])?.isEmpty == false

                return LoginItem(
                    label: label,
                    configURL: url,
                    executableURL: executableURL,
                    domain: domain,
                    runsAtLoad: values["RunAtLoad"] as? Bool ?? false,
                    keepsAlive: keepsAlive,
                    assessment: assessment
                )
            }
        }
        .sorted {
            if $0.domain != $1.domain {
                return LoginItemDomain.allCases.firstIndex(of: $0.domain)! < LoginItemDomain.allCases.firstIndex(of: $1.domain)!
            }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    public func extensions(
        in applications: [InstalledApplication],
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) -> [InstalledExtension] {
        var result: [InstalledExtension] = []

        for app in applications {
            result += bundleExtensions(
                at: app.bundleURL.appending(path: "Contents/PlugIns", directoryHint: .isDirectory),
                ownerName: app.name,
                ownerApplicationURL: app.bundleURL
            )
            result += bundleExtensions(
                at: app.bundleURL.appending(path: "Contents/Library/SystemExtensions", directoryHint: .isDirectory),
                ownerName: app.name,
                ownerApplicationURL: app.bundleURL
            )
        }

        let standaloneRoots: [(URL, InstalledExtensionKind)] = [
            (home.appending(path: "Library/QuickLook", directoryHint: .isDirectory), .quickLook),
            (libraryRoot.appending(path: "QuickLook", directoryHint: .isDirectory), .quickLook),
            (home.appending(path: "Library/Spotlight", directoryHint: .isDirectory), .spotlight),
            (libraryRoot.appending(path: "Spotlight", directoryHint: .isDirectory), .spotlight)
        ]
        for (root, kind) in standaloneRoots {
            result += bundleExtensions(
                at: root,
                ownerName: nil,
                ownerApplicationURL: nil,
                forcedKind: kind,
                knownApplications: applications
            )
        }

        var seen = Set<String>()
        return result
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.kind != $1.kind {
                    return InstalledExtensionKind.allCases.firstIndex(of: $0.kind)! < InstalledExtensionKind.allCases.firstIndex(of: $1.kind)!
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func bundleExtensions(
        at root: URL,
        ownerName: String?,
        ownerApplicationURL: URL?,
        forcedKind: InstalledExtensionKind? = nil,
        knownApplications: [InstalledApplication] = []
    ) -> [InstalledExtension] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { url in
            let pathExtension = url.pathExtension.lowercased()
            guard ["appex", "systemextension", "qlgenerator", "mdimporter"].contains(pathExtension),
                  let bundle = Bundle(url: url) else { return nil }

            let extensionAttributes = bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]
            let pointIdentifier = extensionAttributes?["NSExtensionPointIdentifier"] as? String
            let kind = forcedKind ?? extensionKind(pathExtension: pathExtension, pointIdentifier: pointIdentifier)
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            let bundleIdentifier = bundle.bundleIdentifier
            let matchedApplication = matchingApplication(
                for: bundleIdentifier,
                applications: knownApplications
            )
            let resolvedOwnerName = ownerName ?? matchedApplication?.name
            let resolvedOwnerURL = ownerApplicationURL ?? matchedApplication?.bundleURL
            let assessment: ComponentAssessment
            if resolvedOwnerURL != nil {
                assessment = .present
            } else if forcedKind != nil, bundleIdentifier != nil {
                assessment = .likelyResidue
            } else {
                assessment = .unknown
            }
            return InstalledExtension(
                name: name,
                bundleURL: url,
                bundleIdentifier: bundleIdentifier,
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                kind: kind,
                ownerName: resolvedOwnerName,
                ownerApplicationURL: resolvedOwnerURL,
                assessment: assessment
            )
        }
    }

    public func moveLoginItemToTrash(
        _ item: LoginItem,
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) -> CleanResult {
        let allowedParents = Set([
            home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory).standardizedFileURL.path,
            libraryRoot.appending(path: "LaunchAgents", directoryHint: .isDirectory).standardizedFileURL.path,
            libraryRoot.appending(path: "LaunchDaemons", directoryHint: .isDirectory).standardizedFileURL.path
        ])
        guard item.configURL.pathExtension.lowercased() == "plist",
              allowedParents.contains(item.configURL.deletingLastPathComponent().standardizedFileURL.path) else {
            return rejectedRemoval(item.configURL, reason: "不在受支持的登录项目录中。")
        }
        return moveToTrash(item.configURL)
    }

    public func moveExtensionToTrash(
        _ item: InstalledExtension,
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) -> CleanResult {
        guard item.ownerApplicationURL == nil else {
            return rejectedRemoval(item.bundleURL, reason: "应用内置扩展必须随所属应用一起卸载。")
        }
        let allowedParents = Set([
            home.appending(path: "Library/QuickLook", directoryHint: .isDirectory).standardizedFileURL.path,
            libraryRoot.appending(path: "QuickLook", directoryHint: .isDirectory).standardizedFileURL.path,
            home.appending(path: "Library/Spotlight", directoryHint: .isDirectory).standardizedFileURL.path,
            libraryRoot.appending(path: "Spotlight", directoryHint: .isDirectory).standardizedFileURL.path
        ])
        let allowedExtensions = Set(["qlgenerator", "mdimporter"])
        guard allowedExtensions.contains(item.bundleURL.pathExtension.lowercased()),
              allowedParents.contains(item.bundleURL.deletingLastPathComponent().standardizedFileURL.path) else {
            return rejectedRemoval(item.bundleURL, reason: "该扩展不能安全地单独移除。")
        }
        return moveToTrash(item.bundleURL)
    }

    private func resolvedExecutableURL(_ program: String?, home: URL) -> URL? {
        guard let program, !program.isEmpty else { return nil }
        if program.hasPrefix("~/") {
            return home.appending(path: String(program.dropFirst(2)))
        }
        if program.hasPrefix("/") { return URL(fileURLWithPath: program) }
        return nil
    }

    private func matchingApplication(
        for extensionIdentifier: String?,
        applications: [InstalledApplication]
    ) -> InstalledApplication? {
        guard let extensionIdentifier else { return nil }
        return applications
            .filter { app in
                guard let identifier = app.bundleIdentifier else { return false }
                return extensionIdentifier == identifier || extensionIdentifier.hasPrefix(identifier + ".")
            }
            .max { ($0.bundleIdentifier?.count ?? 0) < ($1.bundleIdentifier?.count ?? 0) }
    }

    private func moveToTrash(_ url: URL) -> CleanResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return rejectedRemoval(url, reason: "项目已经不存在。")
        }
        do {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            return CleanResult(movedToTrash: [url], failures: [])
        } catch {
            return rejectedRemoval(url, reason: error.localizedDescription)
        }
    }

    private func rejectedRemoval(_ url: URL, reason: String) -> CleanResult {
        CleanResult(movedToTrash: [], failures: [CleanFailure(url: url, reason: reason)])
    }

    private func extensionKind(pathExtension: String, pointIdentifier: String?) -> InstalledExtensionKind {
        if pathExtension == "systemextension" { return .system }
        guard let identifier = pointIdentifier?.lowercased() else { return .app }
        if identifier.contains("networkextension") { return .network }
        if identifier.contains("safari") { return .safari }
        if identifier.contains("findersync") { return .finder }
        if identifier.contains("quicklook") { return .quickLook }
        if identifier.contains("share") { return .share }
        return .app
    }
}
