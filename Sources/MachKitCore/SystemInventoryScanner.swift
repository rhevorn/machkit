import Foundation
import Security
import MachKitPrivilegedShim

private final class PrivilegedAuthorizationSession: @unchecked Sendable {
    var reference: AuthorizationRef?

    deinit {
        if let reference {
            AuthorizationFree(reference, [])
        }
    }
}

public actor SystemInventoryScanner {
    private let fileManager: FileManager
    private let privilegedAuthorizationSession = PrivilegedAuthorizationSession()

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func loginApplications() -> LoginApplicationScanResult {
        let script = """
        tell application "System Events"
            set outputText to ""
            repeat with currentItem in every login item
                set itemName to name of currentItem as text
                set itemPath to ""
                try
                    set itemPath to path of currentItem as text
                end try
                set itemHidden to hidden of currentItem as text
                set outputText to outputText & itemName & (ASCII character 9) & itemPath & (ASCII character 9) & itemHidden & (ASCII character 10)
            end repeat
            return outputText
        end tell
        """

        let result = runAppleScript(script)
        guard result.status == 0 else {
            return LoginApplicationScanResult(
                items: [],
                errorMessage: "Unable to read macOS login items. Please allow MachKit to control System Events in system settings, or manage it directly in system settings."
            )
        }
        return LoginApplicationScanResult(items: Self.parseLoginApplications(result.output, fileManager: fileManager))
    }

    public func removeLoginApplication(_ item: LoginApplication) -> String? {
        let script = """
        on run argv
            set requestedName to item 1 of argv
        tell application "System Events"
                delete (first login item whose name is requestedName)
        end tell
        end run
        """
        let result = runAppleScript(script, arguments: [item.name])
        return result.status == 0 ? nil : "Cannot remove login item. Please check automation permissions, or go to system settings to remove manually."
    }

    public func registeredBackgroundTasks() -> BackgroundTaskScanResult {
        let result = runPrivilegedSFLTool(action: "dumpbtm")
        guard result.status == 0 else {
            return BackgroundTaskScanResult(
                items: [],
                errorMessage: result.message ?? "Unable to read macOS background task database. You can refresh and authorize it again, or view it directly in the system settings."
            )
        }
        return BackgroundTaskScanResult(
            items: Self.parseRegisteredBackgroundTasks(result.output, fileManager: fileManager)
        )
    }

    public func resetBackgroundTaskDatabase() -> String? {
        let result = runPrivilegedSFLTool(action: "resetbtm")
        return result.status == 0
            ? nil
            : result.message ?? "Unable to rebuild macOS background task database."
    }

    public func removeRegisteredBackgroundTaskResidue(
        _ item: RegisteredBackgroundTask,
        home: URL
    ) -> String? {
        guard item.isRemovableTrashResidue(home: home), let applicationURL = item.applicationURL else {
            return "Only confirmed app remnants in the current user's Trash can be removed."
        }
        do {
            try fileManager.removeItem(at: applicationURL)
            return nil
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return "The macOS background database still retains this old path, but the disk file no longer exists; the system does not provide an interface for removing a single database record."
        } catch let error as CocoaError where error.code == .fileReadNoPermission || error.code == .fileWriteNoPermission {
            return "MachKit does not have permission to access the Trash. Please turn on \"Full Disk Access\" on the home page, restart MachKit and try again."
        } catch {
            return "Unable to delete residue from Trash: \(error.localizedDescription)"
        }
    }

    static func parseLoginApplications(_ output: String, fileManager: FileManager) -> [LoginApplication] {
        output.split(whereSeparator: { $0.isNewline }).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let name = fields.first, !name.isEmpty else { return nil }
            let path = fields.count > 1 ? fields[1] : ""
            let applicationURL = path.isEmpty ? nil : URL(fileURLWithPath: path)
            let assessment: ComponentAssessment
            if let applicationURL {
                assessment = fileManager.fileExists(atPath: applicationURL.path) ? .present : .likelyResidue
            } else {
                assessment = .unknown
            }
            return LoginApplication(
                name: name,
                applicationURL: applicationURL,
                isHidden: fields.count > 2 && fields[2].lowercased() == "true",
                assessment: assessment
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func parseRegisteredBackgroundTasks(
        _ output: String,
        fileManager: FileManager
    ) -> [RegisteredBackgroundTask] {
        var parsed: [RegisteredBackgroundTask] = []
        var fields: [String: String] = [:]

        func appendCurrentRecord() {
            guard fields["Type"]?.hasPrefix("app ") == true,
                  let identifier = fields["Identifier"],
                  let name = fields["Name"], !name.isEmpty else {
                fields = [:]
                return
            }
            let url: URL?
            if let value = fields["URL"], value.hasPrefix("file:") {
                url = URL(string: value)
            } else {
                url = nil
            }
            let assessment: ComponentAssessment
            if let url {
                let isInTrash = url.standardizedFileURL.path.contains("/.Trash/")
                assessment = !isInTrash && fileManager.fileExists(atPath: url.path) ? .present : .likelyResidue
            } else {
                assessment = .unknown
            }
            parsed.append(RegisteredBackgroundTask(
                id: fields["Bundle Identifier"] ?? identifier,
                name: name,
                bundleIdentifier: fields["Bundle Identifier"],
                teamIdentifier: fields["Team Identifier"],
                applicationURL: url,
                isEnabled: fields["Disposition"]?.contains("[enabled") == true,
                assessment: assessment
            ))
            fields = [:]
        }

        let supportedKeys = Set([
            "Name", "Team Identifier", "Type", "Disposition",
            "Identifier", "URL", "Bundle Identifier"
        ])
        for rawLine in output.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let recordNumber = trimmed.hasPrefix("#") && trimmed.hasSuffix(":")
                ? trimmed.dropFirst().dropLast()
                : ""
            if leadingSpaces <= 1, !recordNumber.isEmpty, recordNumber.allSatisfy({ $0.isNumber }) {
                appendCurrentRecord()
                continue
            }
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separator])
            guard supportedKeys.contains(key) else { continue }
            fields[key] = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
        }
        appendCurrentRecord()

        var seen = Set<String>()
        return parsed
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
        let allowedParents = [
            home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory),
            libraryRoot.appending(path: "LaunchAgents", directoryHint: .isDirectory),
            libraryRoot.appending(path: "LaunchDaemons", directoryHint: .isDirectory)
        ]
        guard item.configURL.pathExtension.lowercased() == "plist",
              allowedParents.contains(where: { SafetyPolicy.isDirectChild(item.configURL, of: $0) }) else {
            return rejectedRemoval(item.configURL, reason: "Not in the supported login items directory.")
        }
        return moveToTrash(item.configURL)
    }

    public func moveExtensionToTrash(
        _ item: InstalledExtension,
        home: URL,
        libraryRoot: URL = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) -> CleanResult {
        guard item.ownerApplicationURL == nil else {
            return rejectedRemoval(item.bundleURL, reason: "In-app extensions must be uninstalled together with the app they belong to.")
        }
        let allowedParents = [
            home.appending(path: "Library/QuickLook", directoryHint: .isDirectory),
            libraryRoot.appending(path: "QuickLook", directoryHint: .isDirectory),
            home.appending(path: "Library/Spotlight", directoryHint: .isDirectory),
            libraryRoot.appending(path: "Spotlight", directoryHint: .isDirectory)
        ]
        let allowedExtensions = Set(["qlgenerator", "mdimporter"])
        guard allowedExtensions.contains(item.bundleURL.pathExtension.lowercased()),
              allowedParents.contains(where: { SafetyPolicy.isDirectChild(item.bundleURL, of: $0) }) else {
            return rejectedRemoval(item.bundleURL, reason: "This extension cannot be safely removed alone.")
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
            return rejectedRemoval(url, reason: "The project no longer exists.")
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

    private func runAppleScript(_ script: String, arguments: [String] = []) -> (status: Int32, output: String) {
        do {
            let result = try SystemCommandRunner.run(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script, "--"] + arguments,
                timeout: 120
            )
            return (result.status, result.text)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func runPrivilegedSFLTool(action: String) -> (status: Int32, output: String, message: String?) {
        guard action == "dumpbtm" || action == "resetbtm" else {
            return (-1, "", "Unsupported background database operation.")
        }

        let authorization: AuthorizationRef
        if let existingAuthorization = privilegedAuthorizationSession.reference {
            authorization = existingAuthorization
        } else {
            var createdAuthorization: AuthorizationRef?
            let createStatus = AuthorizationCreate(nil, nil, [], &createdAuthorization)
            guard createStatus == errAuthorizationSuccess, let createdAuthorization else {
                return (createStatus, "", authorizationFailureMessage(createStatus))
            }
            privilegedAuthorizationSession.reference = createdAuthorization
            authorization = createdAuthorization
        }

        let rightStatus = kAuthorizationRightExecute.withCString { rightName in
            var authorizationItem = AuthorizationItem(
                name: rightName,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &authorizationItem) { itemPointer in
                var rights = AuthorizationRights(count: 1, items: itemPointer)
                return AuthorizationCopyRights(
                    authorization,
                    &rights,
                    nil,
                    [.interactionAllowed, .extendRights, .preAuthorize],
                    nil
                )
            }
        }
        guard rightStatus == errAuthorizationSuccess else {
            return (rightStatus, "", authorizationFailureMessage(rightStatus))
        }

        var communicationsPipe: UnsafeMutablePointer<FILE>?
        let executeStatus = action.withCString { actionPointer in
            MachKitExecuteSFLTool(authorization, actionPointer, &communicationsPipe)
        }
        guard executeStatus == errAuthorizationSuccess else {
            return (executeStatus, "", authorizationFailureMessage(executeStatus))
        }
        guard let communicationsPipe else { return (0, "", nil) }
        let output = FileHandle(fileDescriptor: fileno(communicationsPipe), closeOnDealloc: true)
            .readDataToEndOfFile()
        return (0, String(decoding: output, as: UTF8.self), nil)
    }

    private func authorizationFailureMessage(_ status: OSStatus) -> String {
        if status == errAuthorizationCanceled {
            return "Administrator authorization has been canceled."
        }
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "Error code \(status)"
        return "Administrator authorization failed: \(detail)"
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
