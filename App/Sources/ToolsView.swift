import MachKitCore
import SwiftUI

struct ToolsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @ObservedObject private var pinStore = ToolPinStore.shared
    @State private var searchText = ""
    @State private var shortcutTool: DeveloperTool?
    @State private var hoveredToolID: String?
    @State private var dropTargetID: String?
    @FocusState private var searchIsFocused: Bool

    private var availableIDs: Set<String> {
        Set(DeveloperToolRegistry.all.map(\.id))
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var toolsByID: [String: DeveloperTool] {
        Dictionary(uniqueKeysWithValues: DeveloperToolRegistry.all.map { ($0.id, $0) })
    }

    private var pinnedTools: [DeveloperTool] {
        pinStore.resolvedPinnedIDs(availableIDs: availableIDs).compactMap { toolsByID[$0] }
    }

    private var unpinnedTools: [DeveloperTool] {
        let pinned = Set(pinnedTools.map(\.id))
        return DeveloperToolRegistry.all.filter { !pinned.contains($0.id) }
    }

    private var searchResults: [DeveloperTool] {
        DeveloperToolRegistry.all.filter { $0.matches(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    if isSearching {
                        searchContent
                    } else {
                        browseContent
                    }
                }
                .padding(.horizontal, MachKitLayout.pageMargin)
                .padding(.top, MachKitLayout.bannerPadding)
                .padding(.bottom, MachKitLayout.pageMargin)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $shortcutTool) { tool in
            ToolShortcutEditor(tool: tool, store: shortcutStore)
        }
        .task {
            pinStore.prune(availableIDs: availableIDs)
            await Task.yield()
            searchIsFocused = true
        }
        .onExitCommand {
            if !searchText.isEmpty {
                searchText = ""
                searchIsFocused = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tools".localized).font(.system(size: 18, weight: .semibold))
                Text("Hosts, timestamps, JSON, codecs, and other developer utilities".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tools".localized, text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .focused($searchIsFocused)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Shortcut".localized)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MachKitLayout.pageMargin)
        .padding(.top, MachKitLayout.pageMargin)
        .padding(.bottom, MachKitLayout.controlSpacing)
    }

    @ViewBuilder
    private var searchContent: some View {
        if searchResults.isEmpty {
            ContentUnavailableView(
                "No matching tools".localized,
                systemImage: "magnifyingglass",
                description: Text("Try another search term".localized)
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            toolGrid(for: searchResults, reorderable: false)
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        VStack(alignment: .leading, spacing: MachKitLayout.sectionSpacing) {
            if !pinnedTools.isEmpty {
                VStack(alignment: .leading, spacing: MachKitLayout.controlSpacing) {
                    sectionLabel("Pinned".localized, count: pinnedTools.count)
                    toolGrid(for: pinnedTools, reorderable: true)
                }
            }

            if !unpinnedTools.isEmpty {
                VStack(alignment: .leading, spacing: MachKitLayout.controlSpacing) {
                    if !pinnedTools.isEmpty {
                        sectionLabel("All Tools".localized, count: unpinnedTools.count)
                    }
                    toolGrid(for: unpinnedTools, reorderable: false)
                }
            }
        }
    }

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(verbatim: "·")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(verbatim: "\(count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    private func toolGrid(for tools: [DeveloperTool], reorderable: Bool) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            ForEach(tools) { tool in
                ToolCard(
                    tool: tool,
                    isHovered: hoveredToolID == tool.id,
                    isPinned: pinStore.isPinned(tool.id),
                    isDropTarget: dropTargetID == tool.id,
                    shortcutHelp: shortcutHelp(for: tool),
                    onOpen: { open(tool) },
                    onShortcut: { shortcutTool = tool },
                    onTogglePin: { togglePin(tool) },
                    onHover: { hovering in
                        hoveredToolID = hovering ? tool.id : (hoveredToolID == tool.id ? nil : hoveredToolID)
                    }
                )
                .modifier(ToolCardReorderModifier(
                    enabled: reorderable,
                    toolID: tool.id,
                    onDrop: { movingID in
                        pinStore.move(movingID, before: tool.id, availableIDs: availableIDs)
                    },
                    onTargeted: { targeted in
                        if targeted {
                            dropTargetID = tool.id
                        } else if dropTargetID == tool.id {
                            dropTargetID = nil
                        }
                    }
                ))
            }
        }
    }

    private func togglePin(_ tool: DeveloperTool) {
        if pinStore.isPinned(tool.id) {
            pinStore.unpin(tool.id, availableIDs: availableIDs)
        } else {
            pinStore.pin(tool.id, availableIDs: availableIDs)
        }
    }

    private func shortcutHelp(for tool: DeveloperTool) -> String {
        guard let shortcut = shortcutStore.shortcut(for: tool.id) else {
            return "Set Shortcut".localized
        }
        return "\("Set Shortcut".localized) · \(shortcut.displayText)"
    }

    private func open(_ tool: DeveloperTool) {
        MachKitAppLifecycle.showInForeground()
        openWindow(id: "web-tool", value: tool.id)
        MachKitAppLifecycle.bringToolWindowToFront(toolID: tool.id, titled: tool.localizedTitle)
    }
}

private struct ToolCardReorderModifier: ViewModifier {
    let enabled: Bool
    let toolID: String
    let onDrop: (String) -> Void
    let onTargeted: (Bool) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(toolID)
                .dropDestination(for: String.self) { items, _ in
                    guard let movingID = items.first, movingID != toolID else { return false }
                    onDrop(movingID)
                    return true
                } isTargeted: { targeted in
                    onTargeted(targeted)
                }
        } else {
            content
        }
    }
}

private struct ToolCard: View {
    let tool: DeveloperTool
    let isHovered: Bool
    let isPinned: Bool
    let isDropTarget: Bool
    let shortcutHelp: String
    let onOpen: () -> Void
    let onShortcut: () -> Void
    let onTogglePin: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tool.accentColor)
                        .environment(\.locale, Locale(identifier: "en"))
                        .frame(width: 34, height: 34)
                        .background(tool.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.localizedTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.trailing, 44)
                        Text(tool.localizedDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, MachKitLayout.bannerPadding)
                .padding(.vertical, MachKitLayout.bannerPadding)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isHovered || isPinned ? tool.accentColor : Color.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isPinned ? 1 : 0)
                .allowsHitTesting(isHovered || isPinned)
                .help(isPinned ? "Unpin".localized : "Pin".localized)

                Button(action: onShortcut) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isHovered ? tool.accentColor : Color.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                .help(shortcutHelp)
            }
            .padding(MachKitLayout.controlSpacing)
        }
        .background {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isDropTarget
                        ? tool.accentColor.opacity(0.45)
                        : (isHovered ? tool.accentColor.opacity(0.28) : Color.primary.opacity(0.05)),
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onHover(perform: onHover)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }
}

struct ToolShortcutEditor: View {
    let targetID: String
    let title: String
    @ObservedObject var store: ToolShortcutStore
    @ObservedObject private var globalHotKeys = GlobalHotKeyManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: ToolShortcut
    @State private var registrationFailed = false

    init(tool: DeveloperTool, store: ToolShortcutStore) {
        targetID = tool.id
        title = tool.localizedTitle
        self.store = store
        _shortcut = State(initialValue: store.shortcut(for: tool.id) ?? ToolShortcut(key: ""))
    }

    init(targetID: String, title: String, store: ToolShortcutStore) {
        self.targetID = targetID
        self.title = title
        self.store = store
        _shortcut = State(initialValue: store.shortcut(for: targetID) ?? ToolShortcut(key: ""))
    }

    private var conflictingTargetName: String? {
        guard let id = store.conflictingToolID(for: shortcut, excluding: targetID) else { return nil }
        return store.targetName(for: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcut".localized)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("Key".localized)
                    .frame(width: 64, alignment: .leading)
                TextField(text: $shortcut.key, prompt: Text(verbatim: "K")) {
                    Text(verbatim: "K")
                }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .onChange(of: shortcut.key) { _, value in
                        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if value == " " {
                            shortcut.key = "space"
                        } else if normalized.lowercased() != "space", normalized.count > 1 {
                            shortcut.key = String(normalized.suffix(1))
                        }
                    }
                Text(shortcut.displayText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(minWidth: 70, alignment: .leading)
            }

            HStack(spacing: 18) {
                Toggle(isOn: $shortcut.command) { Text(verbatim: "⌘") }
                Toggle(isOn: $shortcut.shift) { Text(verbatim: "⇧") }
                Toggle(isOn: $shortcut.option) { Text(verbatim: "⌥") }
                Toggle(isOn: $shortcut.control) { Text(verbatim: "⌃") }
            }
            .toggleStyle(.checkbox)

            if let conflictingTargetName {
                Text(String(format: "This shortcut is already assigned to %@.".localized, conflictingTargetName))
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            } else if !shortcut.key.isEmpty && !shortcut.isValid {
                Text("Use one key and at least one modifier.".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if registrationFailed || globalHotKeys.unavailableTargetIDs.contains(targetID) {
                Text("This shortcut is already used by macOS or another app.".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Clear Shortcut".localized) {
                    store.set(nil, for: targetID)
                    dismiss()
                }
                .disabled(store.shortcut(for: targetID) == nil)

                Spacer()
                Button("Cancel".localized) { dismiss() }
                Button("Done".localized) {
                    if store.set(shortcut, for: targetID) {
                        dismiss()
                    } else {
                        registrationFailed = true
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!shortcut.isValid || conflictingTargetName != nil)
            }
        }
        .padding(MachKitLayout.sheetPadding)
        .frame(width: 470)
    }
}
