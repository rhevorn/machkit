import Foundation

private struct ResidueSizeWorkItem: Sendable {
    let identifier: String
    let url: URL
    let kind: ResidueKind
}

private actor ResidueProgressTracker {
    private let totalPaths: Int
    private let callback: (@Sendable (ApplicationResidueScanProgress) -> Void)?
    private var completedPaths = 0
    private var lastUpdate = Date.distantPast

    init(totalPaths: Int, callback: (@Sendable (ApplicationResidueScanProgress) -> Void)?) {
        self.totalPaths = totalPaths
        self.callback = callback
    }

    func started() {
        emit(force: true)
    }

    func completed() {
        completedPaths += 1
        emit(force: completedPaths >= totalPaths)
    }

    private func emit(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastUpdate) >= 0.2 else { return }
        lastUpdate = now
        callback?(ApplicationResidueScanProgress(
            completedPaths: completedPaths,
            totalPaths: max(totalPaths, 1),
            inspectedFiles: completedPaths,
            currentPathInspectedFiles: 0
        ))
    }
}

public actor ApplicationScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func applications(in root: URL) -> [InstalledApplication] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isApplicationKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return enumerator.compactMap { entry in
            guard let url = entry as? URL else { return nil }
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

    /// Reads app identifiers without calculating bundle sizes. Cleanup uses this
    /// lightweight inventory so large apps such as Xcode cannot stall the final rule.
    public func installedBundleIdentifiers(in roots: [URL]) async -> Set<String> {
        let roots = roots
        return await Task.detached(priority: .utility) {
            Self.collectInstalledBundleIdentifiers(in: roots)
        }.value
    }

    private nonisolated static func collectInstalledBundleIdentifiers(in roots: [URL]) -> Set<String> {
        var identifiers = Set<String>()
        let fileManager = FileManager.default
        for root in roots {
            collectAppIdentifiers(in: root, depth: 0, limit: 2, fileManager: fileManager, into: &identifiers)
        }
        return identifiers
    }

    /// Shallow walk only — never descend into `.app` packages or deep trees under Applications.
    private nonisolated static func collectAppIdentifiers(
        in root: URL,
        depth: Int,
        limit: Int,
        fileManager: FileManager,
        into identifiers: inout Set<String>
    ) {
        guard depth <= limit else { return }
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            if child.pathExtension.lowercased() == "app" {
                if let identifier = Bundle(url: child)?.bundleIdentifier {
                    identifiers.insert(identifier)
                }
                continue
            }
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                collectAppIdentifiers(
                    in: child,
                    depth: depth + 1,
                    limit: limit,
                    fileManager: fileManager,
                    into: &identifiers
                )
            }
        }
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

    /// Finds identifier-based data whose owning app is no longer installed.
    /// Results are review-only candidates: a missing app bundle is useful
    /// evidence, but helpers and command-line tools can own similar files.
    public func orphanedResidues(
        installedBundleIdentifiers: Set<String>,
        home: URL,
        onProgress: (@Sendable (ApplicationResidueScanProgress) -> Void)? = nil
    ) async -> [ApplicationResidueGroup] {
        let locations: [(String, ResidueKind, String?)] = [
            ("Library/Caches", .cache, nil),
            ("Library/Preferences", .preferences, ".plist"),
            ("Library/Application Support", .support, nil),
            ("Library/Saved Application State", .state, ".savedState"),
            ("Library/Logs", .logs, nil),
            ("Library/Containers", .container, nil),
            ("Library/Group Containers", .container, nil),
            ("Library/Application Scripts", .support, nil),
            ("Library/HTTPStorages", .cache, nil),
            ("Library/WebKit", .cache, nil),
            ("Library/Cookies", .cache, ".binarycookies")
        ]
        var candidates: [String: [(url: URL, kind: ResidueKind)]] = [:]

        for (relativeRoot, kind, suffix) in locations {
            let root = home.appending(path: relativeRoot, directoryHint: .isDirectory)
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                var identifier = child.lastPathComponent
                if let suffix {
                    guard identifier.hasSuffix(suffix) else { continue }
                    identifier.removeLast(suffix.count)
                }
                guard looksLikeThirdPartyBundleIdentifier(identifier),
                      !belongsToInstalledApplication(identifier, installed: installedBundleIdentifiers) else { continue }
                candidates[identifier, default: []].append((child, kind))
            }
        }

        let qualifiedCandidates = candidates.compactMap { identifier, evidence -> (String, [(url: URL, kind: ResidueKind)])? in
            var seenPaths = Set<String>()
            let unique = evidence.filter { seenPaths.insert($0.url.standardizedFileURL.path).inserted }
            let hasStrongEvidence = unique.contains {
                $0.kind == .container || $0.kind == .state || $0.kind == .preferences || $0.kind == .support
            }
            guard unique.count >= 2 || hasStrongEvidence else { return nil }
            return (identifier, unique)
        }
        // Discovery is shallow (top-level paths only). Never enumerate inside
        // candidate directories for sizing — Containers / Application Support can
        // have tens of thousands of children and `contentsOfDirectory` with
        // resource keys blocks the cooperative pool long enough to freeze the app.
        let workItems = qualifiedCandidates.flatMap { identifier, evidence in
            evidence.map { ResidueSizeWorkItem(identifier: identifier, url: $0.url, kind: $0.kind) }
        }.sorted { lhs, rhs in
            let leftPriority = lhs.kind == .container ? 1 : 0
            let rightPriority = rhs.kind == .container ? 1 : 0
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
        }
        let tracker = ResidueProgressTracker(totalPaths: workItems.count, callback: onProgress)
        if !workItems.isEmpty {
            await tracker.started()
        }

        var residuesByIdentifier: [String: [ApplicationResidue]] = [:]
        for work in workItems {
            guard !Task.isCancelled else { break }
            if let (identifier, residue) = await Self.measureResidue(work, tracker: tracker) {
                residuesByIdentifier[identifier, default: []].append(residue)
            }
            await Task.yield()
        }

        return residuesByIdentifier.map { identifier, residues in
            ApplicationResidueGroup(
                identifier: identifier,
                residues: residues.sorted { $0.bytes > $1.bytes }
            )
        }.sorted {
            if $0.bytes != $1.bytes { return $0.bytes > $1.bytes }
            return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        }
    }

    public func moveToTrash(
        app: InstalledApplication,
        residues: [ApplicationResidue],
        home: URL
    ) -> CleanResult {
        let systemRoot = URL(fileURLWithPath: "/System", isDirectory: true)
        let applicationRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appending(path: "Applications", directoryHint: .isDirectory)
        ]
        let mayRemoveApp = applicationRoots.contains { SafetyPolicy.isDirectChild(app.bundleURL, of: $0) }
        guard mayRemoveApp, !SafetyPolicy.contains(app.bundleURL, in: systemRoot) else {
            return CleanResult(movedToTrash: [], failures: [
                CleanFailure(url: app.bundleURL, reason: "System apps are protected and cannot be uninstalled.")
            ])
        }

        let libraryRoot = home.appending(path: "Library", directoryHint: .isDirectory)
        let allowedResidues = residues.filter {
            SafetyPolicy.contains($0.url, in: libraryRoot)
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

    private nonisolated static func measureResidue(
        _ work: ResidueSizeWorkItem,
        tracker: ResidueProgressTracker
    ) async -> (String, ApplicationResidue)? {
        guard !Task.isCancelled else { return nil }
        // Keep FileManager off the cooperative pool — sync I/O there stalls UI tasks.
        let bytes: Int64 = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.quickAllocatedBytes(at: work.url))
            }
        }
        guard !Task.isCancelled else { return nil }
        await tracker.completed()
        return (work.identifier, ApplicationResidue(
            url: work.url,
            kind: work.kind,
            bytes: bytes,
            risk: .review
        ))
    }

    /// Instant size probe for leftovers. Regular files get a single metadata read;
    /// directories always return 0 — never list children (Containers freeze otherwise).
    private nonisolated static func quickAllocatedBytes(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isRegularFile == true {
            return Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
        }
        return 0
    }

    private func looksLikeThirdPartyBundleIdentifier(_ value: String) -> Bool {
        let normalized = value
            .replacingOccurrences(of: "group.", with: "", options: [.anchored])
            .replacingOccurrences(of: "systemgroup.", with: "", options: [.anchored])
        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 3,
              !value.hasPrefix("com.apple."),
              !normalized.hasPrefix("com.apple.") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return components.allSatisfy { component in
            !component.isEmpty && component.unicodeScalars.allSatisfy(allowed.contains)
        }
    }

    private func belongsToInstalledApplication(_ identifier: String, installed: Set<String>) -> Bool {
        let identifier = identifier
            .replacingOccurrences(of: "group.", with: "", options: [.anchored])
            .replacingOccurrences(of: "systemgroup.", with: "", options: [.anchored])
        if installed.contains(identifier) { return true }

        var prefix = identifier
        while let dot = prefix.lastIndex(of: ".") {
            prefix = String(prefix[..<dot])
            if installed.contains(prefix) { return true }
        }

        return installed.contains { $0.hasPrefix(identifier + ".") }
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
