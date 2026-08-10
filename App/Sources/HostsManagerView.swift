import AppKit
import Foundation
import SiftCore
import SwiftUI

enum HostsSelection: Hashable {
    case system
    case shared
    case environment(UUID)
}

private struct HostsWorkspace: Codable {
    var environments: [HostsEnvironment]
    var activeEnvironmentID: UUID?
}

private let defaultHostsEnvironments = [
    HostsEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Development"
    ),
    HostsEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Testing"
    ),
    HostsEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Production"
    )
]

@MainActor
final class HostsManagerViewModel: ObservableObject {
    @Published private(set) var sharedContent = ""
    @Published private(set) var systemContent = ""
    @Published private(set) var isLoadingSystemHosts = false
    @Published private(set) var environments: [HostsEnvironment] = []
    @Published private(set) var activeEnvironmentID: UUID?
    @Published private(set) var selected: HostsSelection = .shared
    @Published private(set) var draft = ""
    @Published private(set) var isApplying = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service = HostsSystemService()
    private let fileManager: FileManager
    private let storageURL: URL
    private var saveTask: Task<Void, Never>?
    private var hasLoaded = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        storageURL = base.appending(path: "Sift/Hosts/environments.json")
        selected = .system
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadWorkspace()
        await refreshSystemHosts()
    }

    var selectedEnvironment: HostsEnvironment? {
        guard case let .environment(id) = selected else { return nil }
        return environments.first { $0.id == id }
    }

    var activeEnvironment: HostsEnvironment? {
        guard let activeEnvironmentID else { return nil }
        return environments.first { $0.id == activeEnvironmentID }
    }

    var canDeleteSelected: Bool {
        guard let selectedEnvironment else { return false }
        return selectedEnvironment.id != activeEnvironmentID
    }

    func canActivate(_ id: UUID) -> Bool {
        environments.first(where: { $0.id == id })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
    }

    func select(_ selection: HostsSelection) {
        selected = selection
        switch selection {
        case .system:
            draft = systemContent
        case .shared:
            draft = sharedContent
        case let .environment(id):
            draft = environments.first(where: { $0.id == id })?.content ?? ""
        }
        successMessage = nil
    }

    func updateDraft(_ value: String) {
        guard selected != .system else { return }
        draft = value
        switch selected {
        case .system:
            return
        case .shared:
            sharedContent = value
            scheduleSave()
        case let .environment(id):
            guard let index = environments.firstIndex(where: { $0.id == id }) else { return }
            let wasActive = id == activeEnvironmentID
            environments[index].content = value
            if wasActive,
               value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeEnvironmentID = nil
            }
            persistWorkspace()
            if wasActive { scheduleSave() }
        }
    }

    func addEnvironment(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let environment = HostsEnvironment(name: uniqueName(name))
        environments.append(environment)
        persistWorkspace()
        select(.environment(environment.id))
    }

    func renameSelected(to rawName: String) {
        guard let selectedEnvironment,
              let index = environments.firstIndex(where: { $0.id == selectedEnvironment.id }) else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        environments[index].name = uniqueName(name, excluding: selectedEnvironment.id)
        persistWorkspace()
        if selectedEnvironment.id == activeEnvironmentID { scheduleSave(immediately: true) }
    }

    func deleteSelected() {
        guard canDeleteSelected, let selectedEnvironment else { return }
        environments.removeAll { $0.id == selectedEnvironment.id }
        persistWorkspace()
        select(.shared)
    }

    func activate(_ id: UUID) {
        guard canActivate(id), activeEnvironmentID != id else { return }
        activeEnvironmentID = id
        persistWorkspace()
        scheduleSave(immediately: true)
    }

    private func save() async {
        isApplying = true
        errorMessage = nil
        successMessage = nil
        let document = HostsDocument(
            unmanagedContent: sharedContent,
            environments: environments,
            activeEnvironmentID: activeEnvironmentID
        )
        if let error = await service.apply(document: document) {
            errorMessage = localizedMessage(for: error)
        } else {
            systemContent = (try? HostsFileComposer.rendering(document)) ?? systemContent
            successMessage = L10n.string("Done")
        }
        isApplying = false
    }

    func refreshSystemHosts() async {
        isLoadingSystemHosts = true
        saveTask?.cancel()
        await reloadFromSystem(preservingSelection: true)
        isLoadingSystemHosts = false
    }

    private func reloadFromSystem(preservingSelection: Bool) async {
        let previousSelection = selected
        let result = await service.currentContentsResult()
        systemContent = result.content
        if let detail = result.errorMessage {
            errorMessage = L10n.format("Unable to read /etc/hosts: %@", detail)
            return
        }
        do {
            sharedContent = try HostsFileComposer.removingManagedSection(from: result.content)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if preservingSelection,
               case let .environment(id) = previousSelection,
               environments.contains(where: { $0.id == id }) {
                select(previousSelection)
            } else if previousSelection == .shared {
                select(.shared)
            } else {
                select(.system)
            }
        } catch let error as HostsFileError {
            errorMessage = localizedMessage(for: error)
        } catch {
            errorMessage = L10n.format("Unable to read /etc/hosts: %@", error.localizedDescription)
        }
    }

    private func scheduleSave(immediately: Bool = false) {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(650))
            }
            guard !Task.isCancelled, let self else { return }
            await self.save()
        }
    }

    private func loadWorkspace() {
        guard let data = try? Data(contentsOf: storageURL),
              let workspace = try? JSONDecoder().decode(HostsWorkspace.self, from: data) else {
            environments = defaultHostsEnvironments
            activeEnvironmentID = nil
            return
        }
        environments = workspace.environments
        activeEnvironmentID = workspace.activeEnvironmentID
    }

    private func persistWorkspace() {
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let workspace = HostsWorkspace(
                environments: environments,
                activeEnvironmentID: activeEnvironmentID
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(workspace).write(to: storageURL, options: .atomic)
        } catch {
            errorMessage = L10n.format("Unable to save hosts environments: %@", error.localizedDescription)
        }
    }

    private func uniqueName(_ preferred: String, excluding excludedID: UUID? = nil) -> String {
        let existing = Set(environments.filter { $0.id != excludedID }.map { $0.name.lowercased() })
        guard existing.contains(preferred.lowercased()) else { return preferred }
        var suffix = 2
        while existing.contains("\(preferred) \(suffix)".lowercased()) { suffix += 1 }
        return "\(preferred) \(suffix)"
    }

    private func localizedMessage(for error: HostsFileError) -> String {
        switch error {
        case .incompleteManagedSection:
            return L10n.string("The Sift section in /etc/hosts is incomplete. Remove the broken markers manually and try again.")
        case .reservedMarker:
            return L10n.string("Host entries cannot contain Sift's reserved section markers.")
        case let .invalidEntry(line):
            return L10n.format("Line %lld is not a valid hosts entry. Use an IP address followed by one or more host names.", Int64(line))
        case .authorizationCancelled:
            return L10n.string("Administrator authorization was cancelled.")
        case let .authorizationFailed(detail):
            return L10n.format("Administrator authorization failed: %@", detail)
        case let .writeFailed(detail):
            return L10n.format("Unable to update /etc/hosts: %@", detail)
        }
    }
}

struct HostsManagerView: View {
    @ObservedObject var model: HostsManagerViewModel
    @State private var showingAddEnvironment = false
    @State private var showingRenameEnvironment = false
    @State private var showingDeleteConfirmation = false
    @State private var environmentName = ""

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            Divider()
            HStack(spacing: 0) {
                environmentSidebar
                Divider()
                editor
            }
        }
        .alert("Add Environment", isPresented: $showingAddEnvironment) {
            TextField("Environment name", text: $environmentName)
            Button("Cancel", role: .cancel) {}
            Button("Add") { model.addEnvironment(named: environmentName) }
        } message: {
            Text("Create a separate hosts configuration that you can activate when needed.")
        }
        .alert("Rename Environment", isPresented: $showingRenameEnvironment) {
            TextField("Environment name", text: $environmentName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { model.renameSelected(to: environmentName) }
        }
        .confirmationDialog("Delete this environment?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { model.deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The saved hosts entries for this environment will be removed.")
        }
        .alert("Unable to Update Hosts", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            await model.loadIfNeeded()
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hosts Manager".localized).font(.system(size: 18, weight: .semibold))
                Text("Switch local host mappings between development environments".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isApplying || model.isLoadingSystemHosts {
                ProgressView().controlSize(.small)
            } else if model.successMessage != nil {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }

    private var environmentSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarSectionTitle("System")
            environmentRow(
                title: "System Hosts".localized,
                subtitle: "Current /etc/hosts file".localized,
                selection: .system,
                isActive: true,
                icon: "doc.text"
            )
            .frame(width: 204)
            .padding(.horizontal, 8)

            sidebarSectionTitle("Shared")
            environmentRow(
                title: "Shared Configuration".localized,
                subtitle: "Included in every environment".localized,
                selection: .shared,
                isActive: model.activeEnvironmentID != nil,
                icon: "link"
            )
            .frame(width: 204)
            .padding(.horizontal, 8)

            HStack {
                sidebarSectionTitle("Environments")
                Spacer()
                Button {
                    environmentName = ""
                    showingAddEnvironment = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add Environment".localized)
            }
            .padding(.trailing, 14)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(model.environments) { environment in
                        environmentRow(
                            title: environment.name,
                            subtitle: environment.id == model.activeEnvironmentID ? "Active".localized : nil,
                            selection: .environment(environment.id),
                            isActive: environment.id == model.activeEnvironmentID,
                            icon: "server.rack"
                        )
                        .contextMenu {
                            Button("Activate Environment") {
                                model.activate(environment.id)
                            }
                            .disabled(environment.id == model.activeEnvironmentID || !model.canActivate(environment.id))
                            Button("Rename") {
                                model.select(.environment(environment.id))
                                environmentName = environment.name
                                showingRenameEnvironment = true
                            }
                            Button("Delete", role: .destructive) {
                                model.select(.environment(environment.id))
                                showingDeleteConfirmation = true
                            }
                            .disabled(environment.id == model.activeEnvironmentID)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 8)
            Label("Changes are saved automatically.".localized, systemImage: "lock.shield")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarSectionTitle(_ title: String) -> some View {
        Text(title.localized.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private func environmentRow(
        title: String,
        subtitle: String?,
        selection: HostsSelection,
        isActive: Bool,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                model.select(selection)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(model.selected == selection ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(model.selected == selection ? Color.accentColor : Color.secondary)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                        if let subtitle {
                            Text(subtitle).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                    .help("Active".localized)
            } else if case let .environment(id) = selection, model.canActivate(id) {
                Button {
                    model.activate(id)
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Activate Environment".localized)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: subtitle == nil ? 46 : 50)
        .background {
            if model.selected == selection {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08))
            }
        }
        .contentShape(Rectangle())
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: editorIcon)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(editorTitle).font(.system(size: 13, weight: .semibold))
                    Text(editorSubtitle.localized).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let successMessage = model.successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else if let active = model.activeEnvironment {
                    Text(L10n.format("Active: %@", active.name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No environment applied".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: draftBinding)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                if model.draft.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Add one mapping per line".localized)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text(verbatim: "127.0.0.1    api.example.local\n::1          ipv6.example.local")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()
            HStack {
                Label("Comments beginning with # are supported.".localized, systemImage: "info.circle")
                Spacer()
                Text(model.selected == .system ? "Read only".localized : "Changes are saved automatically.".localized)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 42)
        }
    }

    private var editorTitle: String {
        if model.selected == .system { return "System Hosts".localized }
        return model.selectedEnvironment?.name ?? "Shared Configuration".localized
    }

    private var editorSubtitle: String {
        if model.selected == .system { return "Current /etc/hosts content, read only" }
        return model.selectedEnvironment == nil
            ? "Included in every environment"
            : "Changes are saved automatically."
    }

    private var editorIcon: String {
        if model.selected == .system { return "doc.text" }
        return model.selectedEnvironment == nil ? "link" : "server.rack"
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { model.draft },
            set: { newValue in
                guard model.selected != .system else { return }
                model.updateDraft(newValue)
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
