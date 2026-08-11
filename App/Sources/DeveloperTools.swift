import AppKit
import SwiftUI

enum DeveloperToolPresentation: Equatable {
    case native(windowID: String)
    case bundledWeb(entryFile: String)
}

struct DeveloperTool: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let keywords: [String]
    let icon: String
    let color: Color
    let presentation: DeveloperToolPresentation

    var localizedTitle: String { title.localized }
    var localizedDescription: String { description.localized }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return ([localizedTitle, localizedDescription] + keywords).contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }
}

enum DeveloperToolRegistry {
    static let all: [DeveloperTool] = [
        DeveloperTool(
            id: "hosts-manager",
            title: "Hosts Manager",
            description: "View the system hosts file and switch mappings between development environments",
            keywords: ["hosts", "dns", "environment", "domain", "network", "域名", "环境"],
            icon: "network.badge.shield.half.filled",
            color: .blue,
            presentation: .native(windowID: "hosts-manager")
        ),
        DeveloperTool(
            id: "timestamp-converter",
            title: "Timestamp Converter",
            description: "Convert dates and Unix timestamps across units and time zones",
            keywords: ["timestamp", "unix", "date", "time zone", "时间戳", "日期", "时区"],
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            color: .purple,
            presentation: .bundledWeb(entryFile: "WebTools/tools/timestamp-converter/index.html")
        )
    ]

    static func tool(id: String) -> DeveloperTool? {
        all.first { $0.id == id }
    }
}

struct ToolShortcut: Codable, Equatable {
    var key: String
    var command = true
    var shift = false
    var option = false
    var control = false

    var normalizedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var keyEquivalent: KeyEquivalent? {
        guard normalizedKey.count == 1, let character = normalizedKey.first else { return nil }
        return KeyEquivalent(character)
    }

    var modifiers: EventModifiers {
        var result: EventModifiers = []
        if command { result.insert(.command) }
        if shift { result.insert(.shift) }
        if option { result.insert(.option) }
        if control { result.insert(.control) }
        return result
    }

    var isValid: Bool {
        keyEquivalent != nil && !modifiers.isEmpty
    }

    var displayText: String {
        guard isValid else { return "" }
        var value = ""
        if control { value += "⌃" }
        if option { value += "⌥" }
        if shift { value += "⇧" }
        if command { value += "⌘" }
        return value + normalizedKey.uppercased()
    }
}

@MainActor
final class ToolShortcutStore: ObservableObject {
    static let shared = ToolShortcutStore()

    @Published private(set) var shortcuts: [String: ToolShortcut]
    private let defaults: UserDefaults
    private let storageKey = "developerToolShortcutsV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: ToolShortcut].self, from: data) {
            shortcuts = saved.filter { $0.value.isValid }
        } else {
            shortcuts = [:]
        }
    }

    func shortcut(for toolID: String) -> ToolShortcut? {
        shortcuts[toolID]
    }

    func conflictingToolID(for shortcut: ToolShortcut, excluding toolID: String) -> String? {
        guard shortcut.isValid else { return nil }
        return shortcuts.first {
            $0.key != toolID && $0.value.normalizedKey == shortcut.normalizedKey && $0.value.modifiers == shortcut.modifiers
        }?.key
    }

    @discardableResult
    func set(_ shortcut: ToolShortcut?, for toolID: String) -> Bool {
        if let shortcut {
            guard shortcut.isValid, conflictingToolID(for: shortcut, excluding: toolID) == nil else { return false }
            shortcuts[toolID] = shortcut
        } else {
            shortcuts.removeValue(forKey: toolID)
        }
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct DeveloperToolCommands: Commands {
    @ObservedObject var shortcutStore: ToolShortcutStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Tools") {
            ForEach(DeveloperToolRegistry.all) { tool in
                command(for: tool)
            }
        }
    }

    @ViewBuilder
    private func command(for tool: DeveloperTool) -> some View {
        if let shortcut = shortcutStore.shortcut(for: tool.id),
           let key = shortcut.keyEquivalent {
            Button(tool.localizedTitle) { open(tool) }
                .keyboardShortcut(key, modifiers: shortcut.modifiers)
        } else {
            Button(tool.localizedTitle) { open(tool) }
        }
    }

    private func open(_ tool: DeveloperTool) {
        switch tool.presentation {
        case let .native(windowID):
            openWindow(id: windowID)
        case .bundledWeb:
            openWindow(id: "web-tool", value: tool.id)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
