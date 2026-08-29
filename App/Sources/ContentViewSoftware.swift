import AppKit
import Charts
import MachKitCore
import SwiftUI

extension ContentView {
    var uninstallView: some View {
        VStack(spacing: 0) {
            header(
                title: "Apps",
                subtitle: "Apps on this Mac were detected automatically",
                trailing: AnyView(
                    HStack(spacing: 12) {
                        Text(L10n.format("%lld apps", Int64(model.applications.count)))
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        refreshControl(for: .uninstall, action: model.scanInstalledApplications)
                    }
                )
            )
                .padding(18)
            if model.applications.isEmpty && model.isLoading(.uninstall) {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("Reading installed apps…").font(.system(size: 13, weight: .medium))
                    Text("Usually takes only a few seconds").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search apps", text: $applicationSearch).textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 9)

                    softwareCategoryTabs

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                Color.clear
                                    .frame(height: 0)
                                    .id("softwareListTop")
                                if softwareTab != .commandLine {
                                    ForEach(filteredApplicationGroups) { group in applicationSection(group) }
                                }
                                if softwareTab == .all || softwareTab == .commandLine {
                                    ForEach(filteredCommandLineGroups, id: \.manager) { group in
                                        commandLineSection(manager: group.manager, tools: group.tools)
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 16)
                        }
                        .onChange(of: softwareTab) { _, _ in
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo("softwareListTop", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    var softwareCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(SoftwareTab.allCases) { tab in
                    Button {
                        guard softwareTab != tab else { return }
                        withAnimation(.easeOut(duration: 0.16)) { softwareTab = tab }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: softwareTabIcon(tab))
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue.localized).font(.system(size: 11, weight: .semibold))
                            Text("\(softwareTabCount(tab))")
                                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                                .padding(.horizontal, 5).frame(height: 17)
                                .background(
                                    softwareTab == tab ? Color.white.opacity(0.18) : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .foregroundStyle(softwareTab == tab ? Color.white : Color.primary.opacity(0.72))
                        .padding(.horizontal, 10).frame(height: 32)
                        .background {
                            Capsule(style: .continuous)
                                .fill(softwareTab == tab ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        }
                        .overlay {
                            if softwareTab != tab {
                                Capsule().stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    func softwareTabIcon(_ tab: SoftwareTab) -> String {
        switch tab {
        case .all: "square.grid.2x2"
        case .appStore: "bag"
        case .thirdParty: "shippingbox"
        case .user: "person.crop.circle"
        case .system: "apple.logo"
        case .commandLine: "terminal"
        }
    }

    func softwareTabCount(_ tab: SoftwareTab) -> Int {
        switch tab {
        case .all: model.applications.count + model.commandLineTools.count
        case .appStore: model.applicationGroups.first(where: { $0.category == .appStore })?.applications.count ?? 0
        case .thirdParty: model.applicationGroups.first(where: { $0.category == .thirdParty })?.applications.count ?? 0
        case .user: model.applicationGroups.first(where: { $0.category == .user })?.applications.count ?? 0
        case .system: model.applicationGroups.first(where: { $0.category == .system })?.applications.count ?? 0
        case .commandLine: model.commandLineTools.count
        }
    }

    var filteredApplicationGroups: [ApplicationGroup] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = model.applicationGroups.filter { group in
            switch softwareTab {
            case .all: true
            case .appStore: group.category == .appStore
            case .thirdParty: group.category == .thirdParty
            case .user: group.category == .user
            case .system: group.category == .system
            case .commandLine: false
            }
        }
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let matches = group.applications.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return matches.isEmpty ? nil : ApplicationGroup(category: group.category, applications: matches)
        }
    }

    var filteredCommandLineGroups: [(manager: CommandLineToolManager, tools: [CommandLineTool])] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let tools = query.isEmpty ? model.commandLineTools : model.commandLineTools.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.manager.rawValue.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: tools, by: \.manager)
        return CommandLineToolManager.allCases.compactMap { manager in
            guard let matches = grouped[manager], !matches.isEmpty else { return nil }
            return (manager, matches)
        }
    }

    func applicationSection(_ group: ApplicationGroup) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.category.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text(group.category.subtitle.localized).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(group.applications.count) · \(formatted(group.bytes))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(group.applications) { app in
                applicationRow(app)
                if app.id != group.applications.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    func applicationRow(_ app: InstalledApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if let version = app.version { Text("Version \(version)") }
                    Text(app.bundleURL.deletingLastPathComponent().path)
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(app.bytes > 0 ? formatted(app.bytes) : "—")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 62, alignment: .trailing)
            if model.isSystemApplication(app) {
                Text("System Protected").font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(width: 58)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).frame(width: 58)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(
            hoveredSoftwareID == app.id ? Color.accentColor.opacity(0.055) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onHover { hovering in hoveredSoftwareID = hovering ? app.id : nil }
        .onTapGesture { model.prepareUninstall(app) }
    }

    func commandLineSection(manager: CommandLineToolManager, tools: [CommandLineTool]) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text("Command-line tools installed by package managers").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tools.count) · \(formatted(tools.reduce(0) { $0 + $1.bytes }))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(tools) { tool in
                HStack(spacing: 12) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.name).font(.system(size: 13, weight: .medium))
                        Text(tool.version.map { "Version \($0) · \(tool.installURL.path)" } ?? tool.installURL.path)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(formatted(tool.bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(
                    hoveredSoftwareID == tool.id ? Color.accentColor.opacity(0.055) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onHover { hovering in hoveredSoftwareID = hovering ? tool.id : nil }
                .onTapGesture { selectedCommandLineTool = tool }
                if tool.id != tools.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    func applicationDetails(_ app: InstalledApplication) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.title3.weight(.semibold))
                    Text("App Details and Related Data").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    detailValue(title: "Version", value: app.version ?? L10n.string("Unknown"))
                    detailValue(title: "Bundle ID", value: app.bundleIdentifier ?? L10n.string("Unknown"))
                    detailValue(title: "Installed At", value: app.bundleURL.path)
                    detailValue(title: "App Size", value: formatted(app.bytes))
                    Divider().padding(.vertical, 5)
                    if model.uninstallResidues.isEmpty {
                        Text("No related leftover files found.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        Text("Related Files").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                        ForEach(model.uninstallResidues) { residue in
                            uninstallItem(title: residue.kind.rawValue, detail: residue.url.path, bytes: residue.bytes, selected: residueSelectionBinding(residue))
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Label("Recoverable from Trash", systemImage: "arrow.uturn.backward.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") {
                    model.showAppRemovalConfirmation = false
                    model.uninstallCandidate = nil
                }
                if !model.isSystemApplication(app) {
                    Button("Uninstall App…", role: .destructive) { model.showAppRemovalConfirmation = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }

    func detailValue(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.localized).font(.caption).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            Text(value).font(.system(size: 12)).textSelection(.enabled)
            Spacer()
        }
    }

    func commandLineToolDetails(_ tool: CommandLineTool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill").font(.system(size: 28)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.name).font(.title3.weight(.semibold))
                    Text(tool.manager.rawValue.localized).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            detailValue(title: "Version", value: tool.version ?? L10n.string("Unrecognized"))
            detailValue(title: "Installed At", value: tool.installURL.path)
            detailValue(title: "Storage Used", value: formatted(tool.bytes))
            detailValue(title: "Uninstall Command", value: uninstallCommand(for: tool))
            Text("Command-line tools are managed by package managers. MachKit shows suggested commands instead of deleting directories, which could break dependencies.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack { Spacer(); Button("Close") { selectedCommandLineTool = nil }.keyboardShortcut(.defaultAction) }
        }
        .padding(22).frame(width: 520, height: 310)
    }

    func uninstallCommand(for tool: CommandLineTool) -> String {
        tool.manager.uninstallCommand(name: tool.name, version: tool.version)
            ?? L10n.string("Package ownership could not be verified; inspect it manually")
    }

    func uninstallItem(title: String, detail: String, bytes: Int64, selected: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: selected) { EmptyView() }.labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formatted(bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    func residueSelectionBinding(_ residue: ApplicationResidue) -> Binding<Bool> {
        Binding(
            get: { model.selectedResidueIDs.contains(residue.id) },
            set: { selected in
                if selected { model.selectedResidueIDs.insert(residue.id) }
                else { model.selectedResidueIDs.remove(residue.id) }
            }
        )
    }

    var loginItemsView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    refreshControl(for: .loginItems, action: model.scanLoginItems)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "person.badge.key",
                title: "Matches macOS Login Items",
                detail: "Apps that open automatically after logging in are displayed here; some new items can only be managed in system settings.",
                buttonTitle: "Open Login Item Settings"
            )

            inventorySearchField(placeholder: "Search login items or app paths")

            if model.isLoading(.loginItems) && model.loginApplications.isEmpty {
                inventoryLoadingView(title: "Reading login items…")
            } else if let error = model.loginApplicationsError, model.loginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: "Unable to Read Login Items",
                    detail: error,
                    icon: "exclamationmark.triangle"
                )
            } else if filteredLoginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: inventorySearch.isEmpty ? "No Login Items" : "No matching login items",
                    detail: inventorySearch.isEmpty ? "Apps that open when logging in can be added in system settings" : "Try another search term",
                    icon: "person.badge.key"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        inventorySectionHeader(
                            title: "Open at Login",
                            subtitle: "Open automatically after logging in to the current account",
                            count: filteredLoginApplications.count
                        )
                        Divider()
                        ForEach(filteredLoginApplications) { item in
                            loginApplicationRow(item)
                            if item.id != filteredLoginApplications.last?.id { Divider().padding(.leading, 66) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    var filteredLoginApplications: [LoginApplication] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.loginApplications }
        return model.loginApplications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func loginApplicationRow(_ item: LoginApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? L10n.string("Path Unavailable"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("File Not Found")
            }
            if item.isHidden {
                inventoryBadge("Hide After Launch", color: .secondary)
            }
            if let url = item.applicationURL {
                inventoryTextAction("Show") { reveal(url) }
            }
            inventoryTextAction("Remove", isDestructive: true) {
                model.requestLoginApplicationRemoval(item)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    var backgroundActivityView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        Button {
                            model.showBackgroundDatabaseResetConfirmation = true
                        } label: {
                            Label("Rebuild Database", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                        .help("Use when an uninstalled app still shows under Background Activity or Login Items.")
                        refreshControl(for: .backgroundActivity, action: model.scanBackgroundActivity)
                    }
                    .disabled(model.isScanning)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "waveform.path.ecg",
                title: "About Background Activity",
                detail: "\"Autostart\" means to start after the configuration is loaded; \"Restart after exit\" means that launchd will try to start again after the process exits.",
                buttonTitle: "Open Background Settings"
            )

            rebuildDatabaseTipBanner

            inventorySearchField(placeholder: "Search background items, labels, or paths")

            if model.isLoading(.backgroundActivity) && model.backgroundItems.isEmpty && model.registeredBackgroundTasks.isEmpty {
                inventoryLoadingView(title: "Reading background activity…")
            } else if filteredBackgroundItemGroups.isEmpty && filteredRegisteredBackgroundTasks.isEmpty {
                ContentUnavailableView(
                    (inventorySearch.isEmpty ? "No Background Items" : "No matching background items").localized,
                    systemImage: "waveform.path.ecg",
                    description: Text(
                        model.backgroundTaskScanError
                            ?? (inventorySearch.isEmpty
                                ? "No background tasks or launchd configuration found".localized
                                : "Try another search term".localized)
                    )
                )
            } else {
                ScrollView {
                    // Prefer VStack over LazyVStack: borderless/plain buttons inside
                    // LazyVStack+ForEach have crashed SwiftUI layout on recent macOS.
                    VStack(spacing: 14) {
                        if let notice = model.backgroundDatabaseNotice {
                            HStack(spacing: 9) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(notice).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if let error = model.backgroundTaskScanError {
                            HStack(spacing: 9) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                Text(error).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if !filteredRegisteredBackgroundTasks.isEmpty {
                            registeredBackgroundTaskSection
                        }
                        ForEach(filteredBackgroundItemGroups) { group in
                            backgroundItemSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    var filteredRegisteredBackgroundTasks: [RegisteredBackgroundTask] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.registeredBackgroundTasks }
        return model.registeredBackgroundTasks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.teamIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var registeredBackgroundTaskSection: some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: "App Background Activity",
                subtitle: "System database records. macOS has no API to delete one entry; use Rebuild Database for leftovers. Removable launchd plists are listed in the sections below.",
                count: filteredRegisteredBackgroundTasks.count
            )
            Divider()
            ForEach(filteredRegisteredBackgroundTasks) { item in
                registeredBackgroundTaskRow(item)
                if item.id != filteredRegisteredBackgroundTasks.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    func registeredBackgroundTaskRow(_ item: RegisteredBackgroundTask) -> some View {
        let canRemoveTrashResidue = item.isRemovableTrashResidue(
            home: FileManager.default.homeDirectoryForCurrentUser
        )
        return HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? item.bundleIdentifier ?? L10n.string("System Record"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if item.assessment == .likelyResidue {
                missingBadge(canRemoveTrashResidue ? "Trash Record" : "App Not Found")
            }
            if let url = item.applicationURL {
                inventoryTextAction("Show") { reveal(url) }
            }
            if canRemoveTrashResidue {
                inventoryTextAction("Remove", isDestructive: true) {
                    model.requestRegisteredBackgroundTaskRemoval(item)
                }
            } else {
                Text("No single-item remove".localized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("macOS does not allow MachKit to delete one background database record. Use Rebuild Database above for leftovers, or remove a launchd configuration from the sections below if one exists.")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    var filteredBackgroundItemGroups: [LoginItemGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.backgroundItems : model.backgroundItems.filter {
            $0.label.localizedCaseInsensitiveContains(query)
                || $0.configURL.path.localizedCaseInsensitiveContains(query)
                || ($0.executableURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \LoginItem.domain)
        return LoginItemDomain.allCases.compactMap { domain in
            guard let items = grouped[domain], !items.isEmpty else { return nil }
            return LoginItemGroup(domain: domain, items: items)
        }
    }

    func backgroundItemSection(_ group: LoginItemGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.domain.rawValue,
                subtitle: group.domain.explanation,
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                backgroundItemRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    func backgroundItemRow(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.executableURL?.path ?? item.configURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.executableURL?.path ?? item.configURL.path)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("File Not Found")
            }
            if item.runsAtLoad {
                inventoryBadge("Run at Load", color: .blue)
                    .help("Starts automatically when launchd loads the configuration. User agents usually load at login; daemons usually load at startup.")
            }
            if item.keepsAlive {
                inventoryBadge("Restart After Exit", color: .orange)
                    .help("After the process exits or crashes, launchd may try to start it again.")
            }
            inventoryTextAction("Show") { reveal(item.configURL) }
            inventoryTextAction("Remove", isDestructive: true) {
                model.requestBackgroundItemRemoval(item)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.configURL) }
    }

    var extensionsView: some View {
        VStack(spacing: 0) {
            header(
                title: "System",
                subtitle: "Manage login items, background activity, and extensions",
                trailing: AnyView(
                    refreshControl(for: .extensions, action: model.scanExtensions)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "puzzlepiece.extension",
                title: "Extensions are installed with their respective apps",
                detail: "Please use system settings or the associated application to disable extensions to avoid damaging signatures and automatic updates.",
                buttonTitle: "Open Extension Settings"
            )

            inventorySearchField(placeholder: "Search extensions, owning apps, or bundle IDs")

            if model.isLoading(.extensions) && model.installedExtensions.isEmpty {
                inventoryLoadingView(title: "Inspecting installed apps…")
            } else if filteredExtensionGroups.isEmpty {
                ContentUnavailableView(
                    (inventorySearch.isEmpty ? "No Extensions Found" : "No matching extensions").localized,
                    systemImage: "puzzlepiece.extension",
                    description: Text(
                        (inventorySearch.isEmpty
                            ? "No components found in installed apps or common extension folders"
                            : "Try another search term").localized
                    )
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(filteredExtensionGroups) { group in
                            extensionSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    var filteredExtensionGroups: [ExtensionGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.installedExtensions : model.installedExtensions.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.ownerName?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \InstalledExtension.kind)
        return InstalledExtensionKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return ExtensionGroup(kind: kind, items: items)
        }
    }

    func extensionSection(_ group: ExtensionGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.kind.rawValue,
                subtitle: extensionKindExplanation(group.kind),
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                extensionRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    func extensionRow(_ item: InstalledExtension) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    if let owner = item.ownerName { Text(owner) }
                    if let version = item.version { Text("Version \(version)") }
                    if item.ownerName == nil && item.version == nil { Text(item.bundleURL.path) }
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("The application does not exist")
            }
            if let identifier = item.bundleIdentifier {
                Text(identifier).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            inventoryTextAction("Show") { reveal(item.bundleURL) }
            if item.ownerApplicationURL == nil {
                inventoryTextAction("Remove", isDestructive: true) {
                    model.requestExtensionRemoval(item)
                }
            } else {
                inventoryTextAction("Uninstall App") {
                    applicationSearch = item.ownerName ?? ""
                    model.changeMode(.uninstall)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.bundleURL) }
    }

    func inventoryManagementBanner(
        icon: String,
        title: String,
        detail: String,
        buttonTitle: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(detail.localized).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(buttonTitle, action: openLoginItemsSettings).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(11)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 16).padding(.top, 12)
    }

    var rebuildDatabaseTipBanner: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text("When to Rebuild Database".localized)
                    .font(.system(size: 12, weight: .semibold))
                Text("Use this after uninstalling an app if it still appears under Background Activity or Login Items. macOS often cannot delete a single leftover record; rebuilding clears the whole database so remaining apps can register again after a restart.".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    var systemInventoryTabs: some View {
        Picker("Item Type", selection: Binding(
            get: { model.mode },
            set: { newMode in
                inventorySearch = ""
                model.changeMode(newMode)
            }
        )) {
            Text("Login Items").tag(FeatureMode.loginItems)
            Text("Background Activity").tag(FeatureMode.backgroundActivity)
            Text("Extensions").tag(FeatureMode.extensions)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    func inventorySearchField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $inventorySearch).textFieldStyle(.plain)
            if !inventorySearch.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .contentShape(Rectangle())
                    .onTapGesture { inventorySearch = "" }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text("Clear".localized))
            }
        }
        .padding(.horizontal, 12).frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .padding(16)
    }

    func inventoryLoadingView(title: String) -> some View {
        VStack(spacing: 13) {
            ProgressView().controlSize(.large)
            Text(title.localized).font(.system(size: 13, weight: .medium))
            Text("Reads component information without changing system settings").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func compactInventoryEmptyState(title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized).font(.system(size: 13, weight: .semibold))
                    Text(detail.localized).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
    }

    func inventorySectionHeader(title: String, subtitle: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(subtitle.localized).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Text-based row actions avoid ButtonStyle (especially BorderlessButtonStyle),
    /// which has crashed SwiftUI layout inside ForEach on macOS 26.
    func inventoryTextAction(
        _ title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Text(title.localized)
            .font(.caption)
            .foregroundStyle(isDestructive ? Color.red : Color.accentColor)
            .fixedSize()
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(title.localized))
    }

    func inventoryBadge(_ title: String, color: Color) -> some View {
        Text(title.localized)
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).frame(height: 21)
            .background(color.opacity(0.10), in: Capsule())
    }

    func missingBadge(_ title: String) -> some View {
        inventoryBadge(title, color: .red)
            .help("No matching file was found at the recorded path or among installed apps; this may be an uninstall leftover.")
    }

    var loginApplicationRemovalMessage: String {
        guard let item = model.loginApplicationRemovalCandidate else {
            return L10n.string("This will be removed from macOS Login Items.")
        }
        let missing = item.assessment == .likelyResidue ? L10n.string("The corresponding file no longer exists.") : ""
        return L10n.format("%@ “%@” will be removed from Login Items. App files will not be deleted.", missing, item.name)
    }

    var backgroundItemRemovalMessage: String {
        guard let item = model.backgroundItemRemovalCandidate else {
            return L10n.string("The launch configuration will be moved to Trash.")
        }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("The target program was not found; this may be an uninstall leftover.")
            : item.assessment.explanation.localized + L10n.string(".")
        let base = L10n.format(
            "%@ “%@”'s launch configuration will be moved to Trash. Running processes will not be terminated.",
            assessment,
            item.label
        )
        switch item.domain {
        case .sharedAgent, .daemon:
            return base + " " + L10n.string("macOS will ask for an administrator password because this file is outside your home folder.")
        case .userAgent:
            return base
        }
    }

    var registeredBackgroundTaskRemovalMessage: String {
        guard let item = model.registeredBackgroundTaskRemovalCandidate else {
            return L10n.string("The app leftover in Trash will be permanently deleted.")
        }
        return L10n.format("“%@” is already in Trash. Continuing permanently deletes this app leftover and cannot be undone; the macOS background record may disappear after you sign in again.", item.name)
    }

    var extensionRemovalMessage: String {
        guard let item = model.extensionRemovalCandidate else { return L10n.string("The extension will be moved to Trash.") }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("No matching owning app was found; this may be an uninstall leftover.")
            : item.assessment.explanation.localized + L10n.string(".")
        return L10n.format("%@ “%@” will be moved to Trash. Its features will no longer load after you sign in again.", assessment, item.name)
    }

    func extensionKindExplanation(_ kind: InstalledExtensionKind) -> String {
        switch kind {
        case .system: "Use modern system extension technologies like DriverKit"
        case .network: "Participate in VPN, filtering or network connections"
        case .safari: "Powering Safari with web and browser functionality"
        case .finder: "Provide menu or sync status in Finder"
        case .quickLook: "Provides file previews and thumbnails"
        case .spotlight: "Help Spotlight read specific file formats"
        case .share: "Shown in system sharing menu"
        case .app: "Functional components provided by the owning application"
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.LoginItems-Settings.extension"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
