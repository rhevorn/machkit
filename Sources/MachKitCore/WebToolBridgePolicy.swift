import Foundation

/// Pure policy helpers for embedded H5 tool WKWebView bridges.
/// Keep AppKit / WebKit out of this type so behavior stays unit-testable.
public enum WebToolBridgePolicy: Sendable {
    public static let maxClipboardUTF8Bytes = 5_000_000
    /// Tool prefs and paste history (e.g. JSON formatter keeps recent pastes).
    public static let maxStorageUTF8Bytes = 2_097_152
    public static let maxSaveFileBytes = 100 * 1_024 * 1_024
    public static let developmentServerHost = "127.0.0.1"
    public static let developmentServerPort = 4174

    public static func isSafeStorageKey(_ key: String) -> Bool {
        guard (1...64).contains(key.count) else { return false }
        return key.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar == "."
                || scalar == "_"
                || scalar == "-"
        }
    }

    /// Relative path under the app resource root (no leading slash).
    /// Allows only the active tool folder and the shared Vite `WebTools/assets/` tree.
    public static func isAllowedBundledResourcePath(_ relativePath: String, toolID: String) -> Bool {
        let trimmedToolID = toolID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToolID.isEmpty,
              !trimmedToolID.contains("/"),
              !trimmedToolID.contains("\\"),
              !trimmedToolID.contains("..") else {
            return false
        }

        var normalized = relativePath
        while normalized.hasPrefix("/") {
            normalized.removeFirst()
        }
        guard !normalized.isEmpty else { return false }

        let segments = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !segments.contains(".."), !segments.contains("") else { return false }

        if normalized.hasPrefix("WebTools/assets/") {
            return true
        }
        let toolPrefix = "WebTools/tools/\(trimmedToolID)/"
        return normalized.hasPrefix(toolPrefix)
    }

    public static func isTrustedToolPage(
        url: URL?,
        entryFile: String,
        allowDevelopmentServer: Bool
    ) -> Bool {
        guard let url else { return false }
        if url.scheme == "machkit-tool", url.host == "app" {
            let expectedPath = "/" + entryFile
            return url.path == expectedPath
        }
        guard allowDevelopmentServer else { return false }
        let developmentPath = entryFile.hasPrefix("WebTools/")
            ? String(entryFile.dropFirst("WebTools/".count))
            : entryFile
        return url.scheme == "http"
            && url.host == developmentServerHost
            && url.port == developmentServerPort
            && url.path == "/\(developmentPath)"
    }

    /// Safari content-blocker JSON: block all http(s), optionally allow local Vite.
    public static func contentBlockerRulesJSON(allowDevelopmentServer: Bool) -> String {
        var rules: [[String: Any]] = [
            [
                "trigger": ["url-filter": "^https?://"],
                "action": ["type": "block"]
            ]
        ]
        if allowDevelopmentServer {
            rules.append([
                "trigger": [
                    "url-filter": "^http://127\\.0\\.0\\.1:4174/"
                ],
                "action": ["type": "ignore-previous-rules"]
            ])
        }
        guard JSONSerialization.isValidJSONObject(rules),
              let data = try? JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    public static func sanitizedBootstrapToken(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// Initializes the small, immutable preference surface exposed to bundled tools.
    /// Interaction behavior (including standard WebKit context menus) stays owned by
    /// the host instead of being intercepted by page JavaScript.
    public static func bootstrapScript(localeIdentifier: String, appearance: String) -> String {
        let preferences = sanitizedPreferences(
            localeIdentifier: localeIdentifier,
            appearance: appearance
        )
        return """
        window.__MACHKIT__ = Object.freeze({ locale: '\(preferences.locale)', appearance: '\(preferences.appearance)' });
        (function () {
          var appearance = window.__MACHKIT__.appearance;
          var root = document.documentElement;
          if (appearance === 'light' || appearance === 'dark') {
            root.dataset.appearance = appearance;
            root.style.colorScheme = appearance;
          } else {
            delete root.dataset.appearance;
            root.style.colorScheme = '';
          }
        })();
        """
    }

    public static func sanitizedPreferences(
        localeIdentifier: String,
        appearance: String
    ) -> (locale: String, appearance: String) {
        let locale = sanitizedBootstrapToken(localeIdentifier)
        let safeLocale = locale.isEmpty ? "en" : locale
        let sanitizedAppearance = sanitizedBootstrapToken(appearance)
        let safeAppearance = ["system", "light", "dark"].contains(sanitizedAppearance)
            ? sanitizedAppearance
            : "system"
        return (safeLocale, safeAppearance)
    }
}
