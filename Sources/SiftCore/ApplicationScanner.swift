import Foundation

public actor ApplicationScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func applications(in root: URL) -> [InstalledApplication] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isApplicationKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return children.compactMap { url in
            guard url.pathExtension.lowercased() == "app",
                  let bundle = Bundle(url: url) else { return nil }
            return InstalledApplication(
                name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent,
                bundleURL: url,
                bundleIdentifier: bundle.bundleIdentifier,
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                bytes: allocatedSize(at: url)
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func applications(in roots: [URL]) -> [InstalledApplication] {
        var seen = Set<String>()
        var result: [InstalledApplication] = []
        for root in roots {
            for app in applications(in: root) where seen.insert(app.bundleURL.standardizedFileURL.path).inserted {
                result.append(app)
            }
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func commandLineTools(home: URL) -> [CommandLineTool] {
        var tools: [CommandLineTool] = []
        tools += packageDirectories(
            roots: ["/opt/homebrew/Cellar", "/usr/local/Cellar"],
            manager: .homebrew,
            versionFromChild: true
        )
        tools += packageDirectories(
            roots: ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"],
            manager: .homebrewCask,
            versionFromChild: true
        )
        tools += nodePackages(
            roots: [
                home.appending(path: ".npm-global/lib/node_modules").path,
                "/opt/homebrew/lib/node_modules",
                "/usr/local/lib/node_modules"
            ],
            manager: .npm
        )
        tools += nodePackages(
            roots: nodeGlobalRoots(home: home, basePaths: [
                "Library/pnpm/global", ".local/share/pnpm/global"
            ]),
            manager: .pnpm
        )
        tools += nodePackages(
            roots: [home.appending(path: ".config/yarn/global/node_modules").path],
            manager: .yarn
        )
        tools += nodePackages(
            roots: [home.appending(path: ".bun/install/global/node_modules").path],
            manager: .bun
        )
        tools += packageDirectories(
            roots: [
                home.appending(path: ".local/pipx/venvs").path,
                home.appending(path: "Library/Application Support/pipx/venvs").path
            ],
            manager: .pipx,
            versionFromChild: false
        )
        tools += packageDirectories(
            roots: [home.appending(path: ".local/share/uv/tools").path],
            manager: .uv,
            versionFromChild: false
        )
        tools += pythonUserPackages(home: home)
        tools += packageDirectories(
            roots: [
                home.appending(path: "miniconda3/envs").path,
                home.appending(path: "anaconda3/envs").path,
                home.appending(path: ".conda/envs").path,
                "/opt/homebrew/Caskroom/miniconda/base/envs"
            ],
            manager: .conda,
            versionFromChild: false
        )
        tools += binaries(in: [home.appending(path: ".cargo/bin").path], manager: .cargo)
        tools += binaries(in: [home.appending(path: "go/bin").path], manager: .go)
        tools += rubyGems(home: home)
        tools += packageDirectories(
            roots: ["/opt/local/var/macports/software"],
            manager: .macPorts,
            versionFromChild: true
        )
        tools += binaries(in: [home.appending(path: ".nix-profile/bin").path], manager: .nix)
        tools += sdkmanCandidates(home: home)
        tools += binaries(
            in: [home.appending(path: ".local/bin").path, home.appending(path: "bin").path],
            manager: .manual
        )

        var seen = Set<String>()
        return tools
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.manager.rawValue != $1.manager.rawValue { return $0.manager.rawValue < $1.manager.rawValue }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    /// Produces candidates only. The caller must show every residue and require
    /// confirmation; name matches are review-risk because they can be ambiguous.
    public func residues(for app: InstalledApplication, home: URL) -> [ApplicationResidue] {
        guard let identifier = app.bundleIdentifier, !identifier.isEmpty else { return [] }
        let locations: [(String, ResidueKind, RiskLevel)] = [
            ("Library/Caches/\(identifier)", .cache, .safe),
            ("Library/Preferences/\(identifier).plist", .preferences, .review),
            ("Library/Application Support/\(identifier)", .support, .review),
            ("Library/Saved Application State/\(identifier).savedState", .state, .safe),
            ("Library/Logs/\(identifier)", .logs, .safe),
            ("Library/Containers/\(identifier)", .container, .review)
        ]

        return locations.compactMap { relative, kind, risk in
            let url = home.appending(path: relative)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return ApplicationResidue(url: url, kind: kind, bytes: allocatedSize(at: url), risk: risk)
        }
    }

    public func moveToTrash(
        app: InstalledApplication,
        residues: [ApplicationResidue],
        home: URL
    ) -> CleanResult {
        let appPath = app.bundleURL.standardizedFileURL.path
        let userApplications = home.appending(path: "Applications", directoryHint: .isDirectory).standardizedFileURL.path
        let mayRemoveApp = appPath.hasPrefix("/Applications/") || appPath.hasPrefix(userApplications + "/")
        guard mayRemoveApp, !appPath.hasPrefix("/System/") else {
            return CleanResult(movedToTrash: [], failures: [
                CleanFailure(url: app.bundleURL, reason: "系统应用受保护，不能卸载。")
            ])
        }

        let libraryRoot = home.appending(path: "Library", directoryHint: .isDirectory).standardizedFileURL.path + "/"
        let allowedResidues = residues.filter {
            $0.url.standardizedFileURL.path.hasPrefix(libraryRoot)
        }
        var moved: [URL] = []
        var failures: [CleanFailure] = []
        for url in [app.bundleURL] + allowedResidues.map(\.url) {
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                moved.append(url)
            } catch {
                failures.append(CleanFailure(url: url, reason: error.localizedDescription))
            }
        }
        return CleanResult(movedToTrash: moved, failures: failures)
    }

    private func allocatedSize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let values = try? child.resourceValues(forKeys: keys), values.isRegularFile == true {
                total += Int64(values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private func packageDirectories(
        roots: [String],
        manager: CommandLineToolManager,
        versionFromChild: Bool
    ) -> [CommandLineTool] {
        roots.flatMap { rootPath -> [CommandLineTool] in
            let root = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let packages = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return packages.compactMap { package in
                let isDirectory = (try? package.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                guard isDirectory, package.lastPathComponent != ".bin" else { return nil }
                var version: String?
                if versionFromChild,
                   let versions = try? fileManager.contentsOfDirectory(at: package, includingPropertiesForKeys: nil),
                   let newest = versions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first {
                    version = newest.lastPathComponent
                }
                return CommandLineTool(
                    name: package.lastPathComponent,
                    version: version,
                    installURL: package,
                    manager: manager,
                    bytes: allocatedSize(at: package)
                )
            }
        }
    }

    private func nodeGlobalRoots(home: URL, basePaths: [String]) -> [String] {
        basePaths.flatMap { relative -> [String] in
            let base = home.appending(path: relative, directoryHint: .isDirectory)
            guard let versions = try? fileManager.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey]) else {
                return []
            }
            return versions.map { $0.appending(path: "node_modules", directoryHint: .isDirectory).path }
        }
    }

    private func nodePackages(roots: [String], manager: CommandLineToolManager) -> [CommandLineTool] {
        roots.flatMap { rootPath -> [CommandLineTool] in
            let root = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                return []
            }
            let packages = entries.flatMap { entry -> [URL] in
                guard entry.lastPathComponent.hasPrefix("@") else { return [entry] }
                return (try? fileManager.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            }
            return packages.compactMap { package in
                guard package.lastPathComponent != ".bin" else { return nil }
                let manifest = package.appending(path: "package.json")
                var name = package.lastPathComponent
                var version: String?
                if let data = try? Data(contentsOf: manifest),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    name = json["name"] as? String ?? name
                    version = json["version"] as? String
                }
                return CommandLineTool(name: name, version: version, installURL: package, manager: manager, bytes: allocatedSize(at: package))
            }
        }
    }

    private func pythonUserPackages(home: URL) -> [CommandLineTool] {
        let pythonRoot = home.appending(path: "Library/Python", directoryHint: .isDirectory)
        guard let versions = try? fileManager.contentsOfDirectory(at: pythonRoot, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return versions.flatMap { versionRoot -> [CommandLineTool] in
            let sitePackages = versionRoot.appending(path: "lib/python/site-packages", directoryHint: .isDirectory)
            guard let entries = try? fileManager.contentsOfDirectory(at: sitePackages, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                return []
            }
            return entries.compactMap { metadata in
                let filename = metadata.lastPathComponent
                guard filename.hasSuffix(".dist-info") else { return nil }
                let stem = String(filename.dropLast(".dist-info".count))
                guard let split = stem.lastIndex(of: "-") else { return nil }
                let name = String(stem[..<split]).replacingOccurrences(of: "_", with: "-")
                let version = String(stem[stem.index(after: split)...])
                let module = sitePackages.appending(path: name.replacingOccurrences(of: "-", with: "_"), directoryHint: .isDirectory)
                let installURL = fileManager.fileExists(atPath: module.path) ? module : metadata
                return CommandLineTool(name: name, version: version, installURL: installURL, manager: .pip, bytes: allocatedSize(at: installURL) + allocatedSize(at: metadata))
            }
        }
    }

    private func rubyGems(home: URL) -> [CommandLineTool] {
        let rubyRoot = home.appending(path: ".gem/ruby", directoryHint: .isDirectory)
        guard let versions = try? fileManager.contentsOfDirectory(at: rubyRoot, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return versions.flatMap { rubyVersion -> [CommandLineTool] in
            let gems = rubyVersion.appending(path: "gems", directoryHint: .isDirectory)
            guard let entries = try? fileManager.contentsOfDirectory(at: gems, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
            return entries.map { gem in
                let stem = gem.lastPathComponent
                let split = stem.lastIndex(of: "-")
                let name = split.map { String(stem[..<$0]) } ?? stem
                let version = split.map { String(stem[stem.index(after: $0)...]) }
                return CommandLineTool(name: name, version: version, installURL: gem, manager: .rubyGems, bytes: allocatedSize(at: gem))
            }
        }
    }

    private func sdkmanCandidates(home: URL) -> [CommandLineTool] {
        let candidates = home.appending(path: ".sdkman/candidates", directoryHint: .isDirectory)
        guard let names = try? fileManager.contentsOfDirectory(at: candidates, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return names.flatMap { candidate -> [CommandLineTool] in
            guard let versions = try? fileManager.contentsOfDirectory(at: candidate, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
            return versions.filter { $0.lastPathComponent != "current" }.map { version in
                CommandLineTool(name: candidate.lastPathComponent, version: version.lastPathComponent, installURL: version, manager: .sdkman, bytes: allocatedSize(at: version))
            }
        }
    }

    private func binaries(in roots: [String], manager: CommandLineToolManager) -> [CommandLineTool] {
        roots.flatMap { rootPath -> [CommandLineTool] in
            let root = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return entries.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey])
                guard values?.isRegularFile == true || values?.isSymbolicLink == true else { return nil }
                let sizeURL = values?.isSymbolicLink == true ? url.resolvingSymlinksInPath() : url
                return CommandLineTool(name: url.lastPathComponent, version: nil, installURL: url, manager: manager, bytes: allocatedSize(at: sizeURL))
            }
        }
    }
}
