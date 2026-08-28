import AppKit
import Carbon.HIToolbox
import SwiftUI

enum DeveloperToolPresentation: Equatable {
    case bundledWeb(entryFile: String)
}

enum DeveloperToolCapability: String, Hashable {
    case clipboard
    case hosts
    case storage
    case connectionTrace
    case portScan
    case files
    case curlLab
}

/// Shared web-tool window size presets (width + default/minimum height).
enum WebToolWidthClass: String, Equatable {
    case compact
    case regular
    case wide

    /// Bump to invalidate remembered frames after sizing policy changes.
    static let frameEpoch = 8

    var width: CGFloat {
        switch self {
        case .compact: 720
        case .regular: 840
        case .wide: 1040
        }
    }

    var height: CGFloat {
        switch self {
        case .compact: 560
        case .regular: 640
        case .wide: 720
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .compact: 640
        case .regular: 720
        case .wide: 860
        }
    }

    var minimumHeight: CGFloat {
        switch self {
        case .compact: 480
        case .regular: 520
        case .wide: 580
        }
    }

    var defaultSize: CGSize { CGSize(width: width, height: height) }
    var minimumSize: CGSize { CGSize(width: minimumWidth, height: minimumHeight) }
}

struct DeveloperTool: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let keywords: [String]
    let icon: String
    let widthClass: WebToolWidthClass
    let capabilities: Set<DeveloperToolCapability>
    let presentation: DeveloperToolPresentation

    var localizedTitle: String { title.localized }
    var localizedDescription: String { description.localized }

    var defaultWindowSize: CGSize { widthClass.defaultSize }
    var minimumWindowSize: CGSize { widthClass.minimumSize }

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
            id: "json-formatter",
            title: "JSON Formatter",
            description: "Format, minify, and query JSON with path expressions",
            keywords: ["json", "format", "minify", "path", "jsonpath", "格式化", "压缩", "路径"],
            icon: "curlybraces",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/json-formatter/index.html")
        ),
        DeveloperTool(
            id: "timestamp-converter",
            title: "Timestamp Converter",
            description: "Convert dates and Unix timestamps across units and time zones",
            keywords: ["timestamp", "unix", "date", "time zone", "时间戳", "日期", "时区"],
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            widthClass: .compact,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/timestamp-converter/index.html")
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
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/codec/index.html")
        ),
        DeveloperTool(
            id: "string-generator",
            title: "String Generator",
            description: "Generate UUIDs, random IDs, and passwords locally",
            keywords: [
                "uuid", "ulid", "nanoid", "guid", "random", "id", "hex", "objectid", "string",
                "password", "passwd", "secret", "生成", "随机", "密码", "字符串", "字串"
            ],
            icon: "textformat.abc",
            widthClass: .compact,
            capabilities: [.clipboard, .storage],
            presentation: .bundledWeb(entryFile: "WebTools/tools/string-generator/index.html")
        ),
        DeveloperTool(
            id: "hosts-manager",
            title: "Hosts Manager",
            description: "View the system hosts file and switch mappings between development environments",
            keywords: ["hosts", "dns", "environment", "domain", "network", "域名", "环境"],
            icon: "network.badge.shield.half.filled",
            widthClass: .regular,
            capabilities: [.clipboard, .hosts],
            presentation: .bundledWeb(entryFile: "WebTools/tools/hosts-manager/index.html")
        ),
        DeveloperTool(
            id: "url-lab",
            title: "URL Lab",
            description: "Parse and rebuild URLs with query and hash editing",
            keywords: [
                "url", "uri", "query", "querystring", "hash", "encode",
                "链接", "网址", "参数"
            ],
            icon: "link",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/url-lab/index.html")
        ),
        DeveloperTool(
            id: "regex-lab",
            title: "Regex Lab",
            description: "Highlight matches, inspect capture groups, and try common replacements",
            keywords: [
                "regex", "regexp", "regular expression", "match", "replace", "capture", "group",
                "正则", "正則", "匹配", "替换", "取代", "分组", "捕获"
            ],
            icon: "text.magnifyingglass",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/regex-lab/index.html")
        ),
        DeveloperTool(
            id: "text-diff",
            title: "Text Diff",
            description: "Compare two texts side by side with line-level highlighting",
            keywords: [
                "diff", "compare", "difference", "patch", "merge", "text",
                "对比", "差異", "差异", "比较", "差分"
            ],
            icon: "square.split.2x1",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/text-diff/index.html")
        ),
        DeveloperTool(
            id: "data-format",
            title: "Data Format",
            description: "Convert between JSON, YAML, and TOML locally",
            keywords: [
                "json", "yaml", "yml", "toml", "convert", "format",
                "转换", "格式", "数据"
            ],
            icon: "arrow.left.arrow.right",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/data-format/index.html")
        ),
        DeveloperTool(
            id: "number-base",
            title: "Unit Converter",
            description: "Convert bases, bytes, time, length, mass, temperature, and more locally",
            keywords: [
                "binary", "octal", "decimal", "hex", "byte", "kib", "mib",
                "time", "length", "mass", "temperature", "angle", "speed", "area",
                "进制", "字节", "换算", "单位", "时间", "长度", "温度"
            ],
            icon: "number",
            widthClass: .compact,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/number-base/index.html")
        ),
        DeveloperTool(
            id: "cron-expression",
            title: "Cron Expression",
            description: "Build five-field cron schedules and preview upcoming runs",
            keywords: [
                "cron", "schedule", "crontab", "timer", "job",
                "定时", "计划任务", "表达式"
            ],
            icon: "calendar.badge.clock",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/cron-expression/index.html")
        ),
        DeveloperTool(
            id: "ip-cidr",
            title: "IP / CIDR Calculator",
            description: "Calculate IPv4 network details, ranges, and membership checks",
            keywords: [
                "ip", "cidr", "subnet", "netmask", "network", "broadcast",
                "网段", "掩码", "子网", "地址"
            ],
            icon: "point.3.connected.trianglepath.dotted",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/ip-cidr/index.html")
        ),
        DeveloperTool(
            id: "ip-inspector",
            title: "IP Inspector",
            description: "Inspect IPv4 and IPv6 addresses, kinds, and reverse DNS labels",
            keywords: [
                "ip", "ipv4", "ipv6", "address", "arpa", "inspector",
                "解析", "地址"
            ],
            icon: "network",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/ip-inspector/index.html")
        ),
        DeveloperTool(
            id: "color-lab",
            title: "Color Lab",
            description: "Convert HEX, RGB, HSL, and HSV with local contrast checks",
            keywords: [
                "color", "hex", "rgb", "hsl", "hsv", "contrast", "picker",
                "颜色", "色彩", "色值", "对比度"
            ],
            icon: "paintpalette",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/color-lab/index.html")
        ),
        DeveloperTool(
            id: "image-process",
            title: "Image Tools",
            description: "Convert formats and control output by quality, target size, or dimensions",
            keywords: [
                "image", "convert", "compress", "jpeg", "png", "webp", "resize", "batch",
                "quality", "target size", "dimensions",
                "图片", "处理", "转换", "压缩", "批量", "质量", "尺寸"
            ],
            icon: "photo.on.rectangle.angled",
            widthClass: .wide,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/image-process/index.html")
        ),
        DeveloperTool(
            id: "qr-code",
            title: "QR Code",
            description: "Generate QR codes from text or URLs locally",
            keywords: [
                "qr", "qrcode", "barcode", "scan", "encode",
                "二维码", "QR", "条码"
            ],
            icon: "qrcode",
            widthClass: .compact,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/qr-code/index.html")
        ),
        DeveloperTool(
            id: "jwt-lab",
            title: "JWT Lab",
            description: "Decode JWT headers and payloads locally without uploading tokens",
            keywords: [
                "jwt", "token", "auth", "bearer", "claims", "exp",
                "令牌", "鉴权", "解码"
            ],
            icon: "key.horizontal",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/jwt-lab/index.html")
        ),
        DeveloperTool(
            id: "chmod-lab",
            title: "chmod Lab",
            description: "Convert Unix file modes between octal, symbolic, and permission bits",
            keywords: [
                "chmod", "permission", "unix", "octal", "rwx",
                "权限", "文件权限"
            ],
            icon: "lock.shield",
            widthClass: .compact,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/chmod-lab/index.html")
        ),
        DeveloperTool(
            id: "cert-lab",
            title: "Certificate Lab",
            description: "Inspect PEM certificates, validity, fingerprints, and SANs locally",
            keywords: [
                "certificate", "pem", "crt", "x509", "ssl", "tls", "fingerprint",
                "证书", "公钥"
            ],
            icon: "checkmark.seal",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/cert-lab/index.html")
        ),
        DeveloperTool(
            id: "text-lab",
            title: "Text Lab",
            description: "Trim, dedupe, sort, and transform text lines locally",
            keywords: [
                "text", "dedupe", "sort", "trim", "lines", "case",
                "文本", "去重", "排序"
            ],
            icon: "text.alignleft",
            widthClass: .regular,
            capabilities: [.clipboard],
            presentation: .bundledWeb(entryFile: "WebTools/tools/text-lab/index.html")
        ),
        DeveloperTool(
            id: "curl-lab",
            title: "cURL Lab",
            description: "Visually edit HTTP requests and convert to or from cURL",
            keywords: [
                "curl", "http", "request", "fetch", "header", "api",
                "请求", "接口"
            ],
            icon: "network",
            widthClass: .wide,
            capabilities: [.clipboard, .files, .curlLab],
            presentation: .bundledWeb(entryFile: "WebTools/tools/curl-lab/index.html")
        ),
        DeveloperTool(
            id: "connection-trace",
            title: "Connection Trace",
            description: "Trace DNS lookup and HTTP/TLS connection timing for a host",
            keywords: [
                "dns", "resolve", "tls", "http", "latency", "curl", "trace", "connect",
                "域名", "解析", "连接", "耗时"
            ],
            icon: "antenna.radiowaves.left.and.right",
            widthClass: .regular,
            capabilities: [.clipboard, .connectionTrace],
            presentation: .bundledWeb(entryFile: "WebTools/tools/connection-trace/index.html")
        ),
        DeveloperTool(
            id: "port-scan",
            title: "Port Scanner",
            description: "Scan any TCP port or range with progress and open-port results",
            keywords: [
                "port", "scan", "tcp", "open", "service", "range", "network",
                "端口", "扫描", "开放", "服务"
            ],
            icon: "dot.radiowaves.left.and.right",
            widthClass: .regular,
            capabilities: [.clipboard, .portScan],
            presentation: .bundledWeb(entryFile: "WebTools/tools/port-scan/index.html")
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
    private let screenshotDefaultsKey = "screenshotShortcutDefaultsV4"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loadedShortcuts: [String: ToolShortcut]
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: ToolShortcut].self, from: data) {
            loadedShortcuts = saved.filter { $0.value.isValid }
        } else {
            loadedShortcuts = [:]
        }
        let previousRegionShortcut = loadedShortcuts.removeValue(forKey: "__screenshot-region")
        loadedShortcuts.removeValue(forKey: "__screenshot-window")
        if loadedShortcuts[ScreenshotAction.capture.rawValue] == nil,
           let previousRegionShortcut {
            loadedShortcuts[ScreenshotAction.capture.rawValue] = previousRegionShortcut
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
        if !defaults.bool(forKey: screenshotDefaultsKey) {
            Self.installScreenshotDefaults(into: &loadedShortcuts)
            defaults.set(true, forKey: screenshotDefaultsKey)
        }
        shortcuts = loadedShortcuts
        persist()
    }

    private static func installScreenshotDefaults(
        into shortcuts: inout [String: ToolShortcut]
    ) {
        let action = ScreenshotAction.capture
        let previousDefault = ToolShortcut(key: "4", command: true, option: true)
        let shortcut = ToolShortcut(key: "a", command: true, shift: true)
        let current = shortcuts[action.rawValue]
        guard current == nil || current == previousDefault else { return }
        let isAlreadyUsed = shortcuts.contains { id, existing in
            id != action.rawValue
                && existing.normalizedKey == shortcut.normalizedKey
                && existing.modifiers == shortcut.modifiers
        }
        if !isAlreadyUsed {
            shortcuts[action.rawValue] = shortcut
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

    func targetName(for targetID: String) -> String {
        if targetID == Self.toolListID { return "Tools".localized }
        if let action = ScreenshotAction(rawValue: targetID) {
            return action.localizedTitle
        }
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
        MachKitAppLifecycle.bringToolWindowToFront(toolID: tool.id, titled: tool.localizedTitle)
    }

    private func openToolList() {
        MachKitAppLifecycle.toggleToolList(
            isShowingTools: model.mode == .tools,
            showTools: { model.changeMode(.tools) },
            openMainWindow: { openWindow(id: MachKitAppLifecycle.mainWindowSceneID) }
        )
    }
}
