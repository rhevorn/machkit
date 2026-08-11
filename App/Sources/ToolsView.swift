import SwiftUI

struct ToolsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var shortcutStore = ToolShortcutStore.shared
    @State private var searchText = ""
    @State private var shortcutTool: DeveloperTool?

    private var filteredTools: [DeveloperTool] {
        DeveloperToolRegistry.all.filter { $0.matches(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Developer Tools".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if filteredTools.isEmpty {
                        ContentUnavailableView(
                            "No matching tools".localized,
                            systemImage: "magnifyingglass",
                            description: Text("Try another search term".localized)
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: 14)],
                            alignment: .leading,
                            spacing: 14
                        ) {
                            ForEach(filteredTools) { tool in
                                toolCard(tool)
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $shortcutTool) { tool in
            ToolShortcutEditor(tool: tool, store: shortcutStore)
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tools".localized).font(.system(size: 18, weight: .semibold))
                Text("A growing collection of focused utilities for developers".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tools".localized, text: $searchText)
                    .textFieldStyle(.plain)
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
            .frame(width: 230, height: 30)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            }
        }
        .padding(18)
    }

    private func toolCard(_ tool: DeveloperTool) -> some View {
        HStack(spacing: 10) {
            Button { open(tool) } label: {
                HStack(spacing: 15) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(tool.color.opacity(0.12))
                        Image(systemName: tool.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(tool.color)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tool.localizedTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(tool.localizedDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { shortcutTool = tool } label: {
                if let shortcut = shortcutStore.shortcut(for: tool.id) {
                    Text(shortcut.displayText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .frame(minWidth: 30, minHeight: 25)
                        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.plain)
            .help("Set Shortcut".localized)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        }
    }

    private func open(_ tool: DeveloperTool) {
        switch tool.presentation {
        case let .native(windowID): openWindow(id: windowID)
        case .bundledWeb: openWindow(id: "web-tool", value: tool.id)
        }
    }
}

private struct ToolShortcutEditor: View {
    let tool: DeveloperTool
    @ObservedObject var store: ToolShortcutStore
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: ToolShortcut

    init(tool: DeveloperTool, store: ToolShortcutStore) {
        self.tool = tool
        self.store = store
        _shortcut = State(initialValue: store.shortcut(for: tool.id) ?? ToolShortcut(key: ""))
    }

    private var conflictingTool: DeveloperTool? {
        guard let id = store.conflictingToolID(for: shortcut, excluding: tool.id) else { return nil }
        return DeveloperToolRegistry.tool(id: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcut".localized)
                    .font(.system(size: 18, weight: .semibold))
                Text(tool.localizedTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("Key".localized)
                    .frame(width: 64, alignment: .leading)
                TextField("K", text: $shortcut.key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .onChange(of: shortcut.key) { _, value in
                        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if normalized.count > 1 { shortcut.key = String(normalized.suffix(1)) }
                    }
                Text(shortcut.displayText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(minWidth: 70, alignment: .leading)
            }

            HStack(spacing: 18) {
                Toggle("⌘", isOn: $shortcut.command)
                Toggle("⇧", isOn: $shortcut.shift)
                Toggle("⌥", isOn: $shortcut.option)
                Toggle("⌃", isOn: $shortcut.control)
            }
            .toggleStyle(.checkbox)

            if let conflictingTool {
                Text(String(format: "This shortcut is already assigned to %@.".localized, conflictingTool.localizedTitle))
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            } else if !shortcut.key.isEmpty && !shortcut.isValid {
                Text("Use one key and at least one modifier.".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Clear Shortcut".localized) {
                    store.set(nil, for: tool.id)
                    dismiss()
                }
                .disabled(store.shortcut(for: tool.id) == nil)

                Spacer()
                Button("Cancel".localized) { dismiss() }
                Button("Done".localized) {
                    if store.set(shortcut, for: tool.id) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!shortcut.isValid || conflictingTool != nil)
            }
        }
        .padding(24)
        .frame(width: 470)
    }
}
