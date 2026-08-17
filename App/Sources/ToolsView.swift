import SwiftUI

struct ToolsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @State private var searchText = ""
    @State private var shortcutTool: DeveloperTool?
    @State private var hoveredToolID: String?
    @FocusState private var searchIsFocused: Bool

    private var filteredTools: [DeveloperTool] {
        DeveloperToolRegistry.all.filter { $0.matches(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    if filteredTools.isEmpty {
                        ContentUnavailableView(
                            "No matching tools".localized,
                            systemImage: "magnifyingglass",
                            description: Text("Try another search term".localized)
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(filteredTools) { tool in
                                toolRow(tool)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $shortcutTool) { tool in
            ToolShortcutEditor(tool: tool, store: shortcutStore)
        }
        .task {
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
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func toolRow(_ tool: DeveloperTool) -> some View {
        let isHovered = hoveredToolID == tool.id

        return ZStack(alignment: .topTrailing) {
            Button { open(tool) } label: {
                HStack(spacing: 11) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .environment(\.locale, Locale(identifier: "en"))
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.localizedTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.trailing, 22)
                        Text(tool.localizedDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { shortcutTool = tool } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .help(shortcutHelp(for: tool))
            .padding(8)
        }
        .background {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isHovered ? Color.accentColor.opacity(0.22) : Color.clear,
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onHover { hovering in
            hoveredToolID = hovering ? tool.id : (hoveredToolID == tool.id ? nil : hoveredToolID)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
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
        .padding(24)
        .frame(width: 470)
    }
}
