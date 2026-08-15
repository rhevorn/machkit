import AppKit
import Carbon.HIToolbox
import SwiftUI

enum DeveloperToolPresentation: Equatable {
    case bundledWeb(entryFile: String)
}

enum DeveloperToolCapability: String, Hashable {
    case clipboard
    case hosts
    case contentFit
}

struct DeveloperTool: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let keywords: [String]
    let icon: String
    let color: Color
    let defaultWindowSize: CGSize
    let minimumWindowSize: CGSize
    let windowFrameVersion: Int
    let capabilities: Set<DeveloperToolCapability>
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
            defaultWindowSize: CGSize(width: 800, height: 540),
            minimumWindowSize: CGSize(width: 720, height: 460),
            windowFrameVersion: 2,
            capabilities: [.clipboard, .hosts],
            presentation: .bundledWeb(entryFile: "WebTools/tools/hosts-manager/index.html")
        ),
        DeveloperTool(
            id: "timestamp-converter",
            title: "Timestamp Converter",
            description: "Convert dates and Unix timestamps across units and time zones",
            keywords: ["timestamp", "unix", "date", "time zone", "时间戳", "日期", "时区"],
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            color: .purple,
            defaultWindowSize: CGSize(width: 700, height: 620),
            minimumWindowSize: CGSize(width: 640, height: 460),
            windowFrameVersion: 3,
            capabilities: [.clipboard, .contentFit],
            presentation: .bundledWeb(entryFile: "WebTools/tools/timestamp-converter/index.html")
        ),
        DeveloperTool(
            id: "json-formatter",
            title: "JSON Formatter",
            description: "Format, minify, and query JSON with path expressions",
            keywords: ["json", "format", "minify", "path", "jsonpath", "格式化", "压缩", "路径"],
            icon: "curlybraces",
            color: .orange,
            defaultWindowSize: CGSize(width: 1000, height: 640),
            minimumWindowSize: CGSize(width: 720, height: 520),
            windowFrameVersion: 2,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/json-formatter/index.html")
        ),
        DeveloperTool(
            id: "codec",
            title: "Codec",
            description: "Encode and decode Base64, Base32, Base62, Hex, URL, HTML, Unicode, Escape, and Hash",
            keywords: [
                "base64", "base32", "base62", "hex", "url", "html", "unicode", "escape", "hash",
                "encode", "decode", "md5", "sha", "编码", "解码", "哈希", "实体", "转义", "反转义"
            ],
            icon: "lock.rectangle.on.rectangle",
            color: .teal,
            defaultWindowSize: CGSize(width: 1000, height: 640),
            minimumWindowSize: CGSize(width: 800, height: 520),
            windowFrameVersion: 5,
            capabilities: [.clipboard, .contentFit],
            presentation: .bundledWeb(entryFile: "WebTools/tools/codec/index.html")
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
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "space" || key == " " ? "space" : value
    }

    var keyEquivalent: KeyEquivalent? {
        if normalizedKey == "space" { return .space }
        guard normalizedKey.count == 1, let character = normalizedKey.first else { return nil }
        return KeyEquivalent(character)
    }

    var carbonKeyCode: UInt32? {
        let code: Int?
        switch normalizedKey {
        case "space": code = kVK_Space
        case "a": code = kVK_ANSI_A
        case "b": code = kVK_ANSI_B
        case "c": code = kVK_ANSI_C
        case "d": code = kVK_ANSI_D
        case "e": code = kVK_ANSI_E
        case "f": code = kVK_ANSI_F
        case "g": code = kVK_ANSI_G
        case "h": code = kVK_ANSI_H
        case "i": code = kVK_ANSI_I
        case "j": code = kVK_ANSI_J
        case "k": code = kVK_ANSI_K
        case "l": code = kVK_ANSI_L
        case "m": code = kVK_ANSI_M
        case "n": code = kVK_ANSI_N
        case "o": code = kVK_ANSI_O
        case "p": code = kVK_ANSI_P
        case "q": code = kVK_ANSI_Q
        case "r": code = kVK_ANSI_R
        case "s": code = kVK_ANSI_S
        case "t": code = kVK_ANSI_T
        case "u": code = kVK_ANSI_U
        case "v": code = kVK_ANSI_V
        case "w": code = kVK_ANSI_W
        case "x": code = kVK_ANSI_X
        case "y": code = kVK_ANSI_Y
        case "z": code = kVK_ANSI_Z
        case "0": code = kVK_ANSI_0
        case "1": code = kVK_ANSI_1
        case "2": code = kVK_ANSI_2
        case "3": code = kVK_ANSI_3
        case "4": code = kVK_ANSI_4
        case "5": code = kVK_ANSI_5
        case "6": code = kVK_ANSI_6
        case "7": code = kVK_ANSI_7
        case "8": code = kVK_ANSI_8
        case "9": code = kVK_ANSI_9
        case "-": code = kVK_ANSI_Minus
        case "=": code = kVK_ANSI_Equal
        case "[": code = kVK_ANSI_LeftBracket
        case "]": code = kVK_ANSI_RightBracket
        case ";": code = kVK_ANSI_Semicolon
        case "'": code = kVK_ANSI_Quote
        case ",": code = kVK_ANSI_Comma
        case ".": code = kVK_ANSI_Period
        case "/": code = kVK_ANSI_Slash
        case "\\": code = kVK_ANSI_Backslash
        case "`": code = kVK_ANSI_Grave
        default: code = nil
        }
        return code.map(UInt32.init)
    }

    var modifiers: SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        if command { result.insert(.command) }
        if shift { result.insert(.shift) }
        if option { result.insert(.option) }
        if control { result.insert(.control) }
        return result
    }

    var isValid: Bool {
        carbonKeyCode != nil && !modifiers.isEmpty
    }

    var displayText: String {
        guard isValid else { return "" }
        var value = ""
        if control { value += "⌃" }
        if option { value += "⌥" }
        if shift { value += "⇧" }
        if command { value += "⌘" }
        return value + (normalizedKey == "space" ? "Space".localized : normalizedKey.uppercased())
    }
}

@MainActor
final class ToolShortcutStore: ObservableObject {
    static let shared = ToolShortcutStore()
    static let toolListID = "__tools-list"

    @Published private(set) var shortcuts: [String: ToolShortcut]
    private let defaults: UserDefaults
    private let storageKey = "developerToolShortcutsV1"
    private let toolListDefaultKey = "developerToolListShortcutDefaultV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loadedShortcuts: [String: ToolShortcut]
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: ToolShortcut].self, from: data) {
            loadedShortcuts = saved.filter { $0.value.isValid }
        } else {
            loadedShortcuts = [:]
        }
        if !defaults.bool(forKey: toolListDefaultKey) {
            let defaultShortcut = ToolShortcut(
                key: "space",
                command: false,
                option: true
            )
            let isAlreadyUsed = loadedShortcuts.contains { id, shortcut in
                id != Self.toolListID
                    && shortcut.normalizedKey == defaultShortcut.normalizedKey
                    && shortcut.modifiers == defaultShortcut.modifiers
            }
            if loadedShortcuts[Self.toolListID] == nil, !isAlreadyUsed {
                loadedShortcuts[Self.toolListID] = defaultShortcut
            }
            defaults.set(true, forKey: toolListDefaultKey)
        }
        shortcuts = loadedShortcuts
        persist()
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

    func targetName(for targetID: String) -> String {
        if targetID == Self.toolListID { return "Tools".localized }
        return DeveloperToolRegistry.tool(id: targetID)?.localizedTitle ?? targetID
    }

    @discardableResult
    func set(_ shortcut: ToolShortcut?, for toolID: String) -> Bool {
        let previousShortcut = shortcuts[toolID]
        if let shortcut {
            guard shortcut.isValid, conflictingToolID(for: shortcut, excluding: toolID) == nil else { return false }
            shortcuts[toolID] = shortcut
        } else {
            shortcuts.removeValue(forKey: toolID)
        }
        let unavailableTargets = GlobalHotKeyManager.shared.refresh(with: shortcuts)
        if shortcut != nil, unavailableTargets.contains(toolID) {
            shortcuts[toolID] = previousShortcut
            GlobalHotKeyManager.shared.refresh(with: shortcuts)
            return false
        }
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private let globalHotKeySignature: OSType = 0x4D4B4954 // MKIT

private let globalHotKeyEventHandler: EventHandlerUPP = { _, event, _ in
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == globalHotKeySignature else { return status }
    let identifier = hotKeyID.id
    DispatchQueue.main.async {
        GlobalHotKeyManager.shared.handle(identifier: identifier)
    }
    return noErr
}

@MainActor
final class GlobalHotKeyManager: ObservableObject {
    static let shared = GlobalHotKeyManager()

    @Published private(set) var unavailableTargetIDs: Set<String> = []
    private var eventHandler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private var targetsByIdentifier: [UInt32: String] = [:]
    private var action: ((String) -> Void)?
    private var pendingTargetID: String?

    private init() {}

    func start() {
        installEventHandlerIfNeeded()
        refresh(with: ToolShortcutStore.shared.shortcuts)
    }

    func configure(action: @escaping (String) -> Void) {
        self.action = action
        installEventHandlerIfNeeded()
        refresh(with: ToolShortcutStore.shared.shortcuts)
        if let pendingTargetID {
            self.pendingTargetID = nil
            action(pendingTargetID)
        }
    }

    @discardableResult
    func refresh(with shortcuts: [String: ToolShortcut]) -> Set<String> {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
        targetsByIdentifier.removeAll()
        installEventHandlerIfNeeded()

        var unavailableTargets: Set<String> = []
        for (offset, entry) in shortcuts.sorted(by: { $0.key < $1.key }).enumerated() {
            guard let keyCode = entry.value.carbonKeyCode else { continue }
            let identifier = UInt32(offset + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                carbonModifiers(for: entry.value),
                EventHotKeyID(signature: globalHotKeySignature, id: identifier),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                registrations.append(reference)
                targetsByIdentifier[identifier] = entry.key
            } else {
                unavailableTargets.insert(entry.key)
            }
        }
        unavailableTargetIDs = unavailableTargets
        return unavailableTargets
    }

    func handle(identifier: UInt32) {
        guard let targetID = targetsByIdentifier[identifier] else { return }
        if let action {
            action(targetID)
        } else {
            pendingTargetID = targetID
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    private func carbonModifiers(for shortcut: ToolShortcut) -> UInt32 {
        var modifiers: UInt32 = 0
        if shortcut.command { modifiers |= UInt32(cmdKey) }
        if shortcut.shift { modifiers |= UInt32(shiftKey) }
        if shortcut.option { modifiers |= UInt32(optionKey) }
        if shortcut.control { modifiers |= UInt32(controlKey) }
        return modifiers
    }
}

struct DeveloperToolCommands: Commands {
    @ObservedObject var model: CleanerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Tools") {
            toolListCommand
            Divider()
            ForEach(DeveloperToolRegistry.all) { tool in
                command(for: tool)
            }
        }
    }

    @ViewBuilder
    private var toolListCommand: some View {
        Button("Open Tool List".localized, action: openToolList)
    }

    @ViewBuilder
    private func command(for tool: DeveloperTool) -> some View {
        Button(tool.localizedTitle) { open(tool) }
    }

    private func open(_ tool: DeveloperTool) {
        MachKitAppLifecycle.showInForeground()
        openWindow(id: "web-tool", value: tool.id)
        MachKitAppLifecycle.bringWindowToFront(titled: tool.localizedTitle)
    }

    private func openToolList() {
        model.changeMode(.tools)
        MachKitAppLifecycle.showInForeground()
        openWindow(id: "main")
        MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
    }
}
