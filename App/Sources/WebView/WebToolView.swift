import SwiftUI
import WebKit
import MachKitCore

struct WebToolView: View {
    let tool: DeveloperTool
    @Environment(\.locale) private var locale
    @AppStorage(AppPreferenceKey.appearance) private var appearanceRawValue = AppAppearance.system.rawValue

    var body: some View {
        Group {
            if case let .bundledWeb(entryFile) = tool.presentation {
                BundledWebView(
                    toolID: tool.id,
                    entryFile: entryFile,
                    capabilities: tool.capabilities,
                    localeIdentifier: locale.identifier,
                    appearance: appearanceRawValue
                )
            } else {
                ContentUnavailableView(
                    "Web tool not found".localized,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle(tool.localizedTitle)
        .background(
            ToolWindowConfigurator(
                toolID: tool.id,
                defaultSize: tool.defaultWindowSize,
                minimumSize: tool.minimumWindowSize,
                frameVersion: WebToolWidthClass.frameEpoch
            )
        )
    }
}

private struct ToolWindowConfigurator: NSViewRepresentable {
    let toolID: String
    let defaultSize: CGSize
    let minimumSize: CGSize
    let frameVersion: Int

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(window: view.window, context: context) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(window: view.window, context: context) }
    }

    private func configure(window: NSWindow?, context: Context) {
        guard let window, context.coordinator.configuredWindow !== window else { return }
        context.coordinator.configuredWindow = window
        window.titlebarSeparatorStyle = .none
        window.contentMinSize = minimumSize

        let autosaveName = "MachKit.WebTool.v\(frameVersion).\(toolID)"
        let restoredPreviousFrame = window.setFrameUsingName(autosaveName)
        window.setFrameAutosaveName(autosaveName)
        if !restoredPreviousFrame {
            window.setContentSize(defaultSize)
            window.center()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }
}

private struct BundledWebView: NSViewRepresentable {
    let toolID: String
    let entryFile: String
    let capabilities: Set<DeveloperToolCapability>
    let localeIdentifier: String
    let appearance: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(context.coordinator, forURLScheme: "machkit-tool")
        configuration.userContentController.addScriptMessageHandler(
            context.coordinator,
            contentWorld: .page,
            name: "bridge"
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.bootstrapScript(localeIdentifier: localeIdentifier, appearance: appearance),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.localeIdentifier = localeIdentifier
        context.coordinator.appearance = appearance
        context.coordinator.loadInitialPage(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.applyPreferencesIfNeeded(
            in: webView,
            localeIdentifier: localeIdentifier,
            appearance: appearance
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "bridge")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            toolID: toolID,
            allowedRoot: Bundle.main.resourceURL,
            entryFile: entryFile,
            capabilities: capabilities
        )
    }

    private static func sanitized(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func bootstrapScript(localeIdentifier: String, appearance: String) -> String {
        let locale = sanitized(localeIdentifier)
        let theme = sanitized(appearance)
        let safeLocale = locale.isEmpty ? "en" : locale
        let safeAppearance = ["system", "light", "dark"].contains(theme) ? theme : "system"
        return """
        window.__MACHKIT__ = Object.freeze({ locale: '\(safeLocale)', appearance: '\(safeAppearance)' });
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply, WKURLSchemeHandler {
        private let toolID: String
        private let allowedRoot: URL?
        private let entryFile: String
        private let capabilities: Set<DeveloperToolCapability>
        private var isUsingDevelopmentServer = false
        private let hostsBridge = HostsWebBridge.shared
        private let connectionTraceBridge = ConnectionTraceWebBridge.shared
        private let portScanBridge = PortScanWebBridge.shared
        private let curlLabBridge = CurlLabWebBridge.shared
        var localeIdentifier = "en"
        var appearance = AppAppearance.system.rawValue

        init(
            toolID: String,
            allowedRoot: URL?,
            entryFile: String,
            capabilities: Set<DeveloperToolCapability>
        ) {
            self.toolID = toolID
            self.allowedRoot = allowedRoot?.standardizedFileURL
            self.entryFile = entryFile
            self.capabilities = capabilities
        }

        func applyPreferencesIfNeeded(in webView: WKWebView, localeIdentifier: String, appearance: String) {
            let localeChanged = self.localeIdentifier != localeIdentifier
            let appearanceChanged = self.appearance != appearance
            guard localeChanged || appearanceChanged else { return }
            self.localeIdentifier = localeIdentifier
            self.appearance = appearance

            let locale = BundledWebView.sanitized(localeIdentifier)
            let theme = BundledWebView.sanitized(appearance)
            let safeLocale = locale.isEmpty ? "en" : locale
            let safeAppearance = ["system", "light", "dark"].contains(theme) ? theme : "system"
            let script = """
            if (typeof window.__MACHKIT_APPLY_PREFERENCES__ === 'function') {
              window.__MACHKIT_APPLY_PREFERENCES__({ locale: '\(safeLocale)', appearance: '\(safeAppearance)' });
            } else {
              window.__MACHKIT__ = Object.freeze({ locale: '\(safeLocale)', appearance: '\(safeAppearance)' });
              var root = document.documentElement;
              if ('\(safeAppearance)' === 'light' || '\(safeAppearance)' === 'dark') {
                root.dataset.appearance = '\(safeAppearance)';
                root.style.colorScheme = '\(safeAppearance)';
              } else {
                delete root.dataset.appearance;
                root.style.colorScheme = '';
              }
            }
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func loadInitialPage(in webView: WKWebView) {
            #if DEBUG
            let developmentPath = entryFile.hasPrefix("WebTools/")
                ? String(entryFile.dropFirst("WebTools/".count))
                : entryFile
            if let url = URL(string: "http://127.0.0.1:4174/\(developmentPath)") {
                isUsingDevelopmentServer = true
                webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
                return
            }
            #endif
            loadBundledPage(in: webView)
        }

        private func loadBundledPage(in webView: WKWebView) {
            isUsingDevelopmentServer = false
            guard let resourceRoot = allowedRoot else {
                showMissingPage(in: webView)
                return
            }
            let fileURL = resourceRoot.appendingPathComponent(entryFile).standardizedFileURL
            guard fileURL.path.hasPrefix(resourceRoot.path + "/"),
                  FileManager.default.fileExists(atPath: fileURL.path),
                  let toolURL = URL(string: "machkit-tool://app/\(entryFile)") else {
                showMissingPage(in: webView)
                return
            }
            webView.load(URLRequest(url: toolURL))
        }

        private func showMissingPage(in webView: WKWebView) {
            webView.loadHTMLString("<main><h2>Web tool not found</h2></main>", baseURL: nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
        ) {
            guard message.name == "bridge",
                  message.frameInfo.isMainFrame,
                  isTrusted(url: message.frameInfo.request.url),
                  let request = message.body as? [String: Any],
                  let protocolVersion = request["protocolVersion"] as? NSNumber,
                  protocolVersion.intValue == 1,
                  let method = request["method"] as? String,
                  let parameters = request["params"] as? [String: Any] else {
                replyHandler(nil, "Invalid bridge request.")
                return
            }

            switch method {
            case "clipboard.copy":
                guard capabilities.contains(.clipboard), let text = parameters["text"] as? String else {
                    replyHandler(nil, "Clipboard access is not available to this tool.")
                    return
                }
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(text, forType: .string) else {
                    replyHandler(nil, "Unable to write to the clipboard.")
                    return
                }
                replyHandler(["ok": true], nil)
            case "window.fitContentHeight":
                guard let height = parameters["height"] as? NSNumber,
                      let webView = message.webView else {
                    replyHandler(nil, "Content fitting is not available.")
                    return
                }
                resizeWindowToFit(webView: webView, requestedContentHeight: height.doubleValue)
                replyHandler(["ok": true], nil)
            case "storage.get":
                guard capabilities.contains(.storage),
                      let key = parameters["key"] as? String,
                      Self.isSafeStorageKey(key) else {
                    replyHandler(nil, "Storage access is not available to this tool.")
                    return
                }
                if let value = UserDefaults.standard.string(forKey: storageDefaultsKey(key)) {
                    replyHandler(["value": value], nil)
                } else {
                    replyHandler(["value": NSNull()], nil)
                }
            case "storage.set":
                guard capabilities.contains(.storage),
                      let key = parameters["key"] as? String,
                      Self.isSafeStorageKey(key),
                      let value = parameters["value"] as? String,
                      value.utf8.count <= 8_192 else {
                    replyHandler(nil, "Storage access is not available to this tool.")
                    return
                }
                UserDefaults.standard.set(value, forKey: storageDefaultsKey(key))
                replyHandler(["ok": true], nil)
            case "files.pick":
                guard capabilities.contains(.files) else {
                    replyHandler(nil, "File picking is not available to this tool.")
                    return
                }
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.resolvesAliases = true
                panel.treatsFilePackagesAsDirectories = false
                if let prompt = parameters["prompt"] as? String, !prompt.isEmpty {
                    panel.prompt = prompt
                }
                let response = panel.runModal()
                if response == .OK, let url = panel.url {
                    replyHandler([
                        "canceled": false,
                        "path": url.path,
                        "name": url.lastPathComponent
                    ], nil)
                } else {
                    replyHandler(["canceled": true], nil)
                }
            case let method where method.hasPrefix("hosts."):
                guard capabilities.contains(.hosts) else {
                    replyHandler(nil, "Hosts access is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("hosts.".count))
                payload["requestID"] = "bridge-reply"
                Task { @MainActor [weak self] in
                    guard let self else {
                        replyHandler(nil, "The tool bridge is no longer available.")
                        return
                    }
                    let response = await hostsBridge.handle(payload)
                    if response["ok"] as? Bool == true {
                        replyHandler(response["result"], nil)
                    } else {
                        replyHandler(nil, response["error"] as? String ?? "Hosts operation failed.")
                    }
                }
            case let method where method.hasPrefix("connectionTrace."):
                guard capabilities.contains(.connectionTrace) else {
                    replyHandler(nil, "Connection tracing is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("connectionTrace.".count))
                payload["requestID"] = "bridge-reply"
                Task { @MainActor [weak self] in
                    guard let self else {
                        replyHandler(nil, "The tool bridge is no longer available.")
                        return
                    }
                    let response = await connectionTraceBridge.handle(payload)
                    if response["ok"] as? Bool == true {
                        replyHandler(response["result"], nil)
                    } else {
                        replyHandler(nil, response["error"] as? String ?? "Connection trace failed.")
                    }
                }
            case let method where method.hasPrefix("portScan."):
                guard capabilities.contains(.portScan) else {
                    replyHandler(nil, "Port scanning is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("portScan.".count))
                payload["requestID"] = "bridge-reply"
                Task { @MainActor [weak self] in
                    guard let self else {
                        replyHandler(nil, "The tool bridge is no longer available.")
                        return
                    }
                    let response = await portScanBridge.handle(payload)
                    if response["ok"] as? Bool == true {
                        replyHandler(response["result"], nil)
                    } else {
                        replyHandler(nil, response["error"] as? String ?? "Port scan failed.")
                    }
                }
            case let method where method.hasPrefix("curlLab."):
                guard capabilities.contains(.curlLab) else {
                    replyHandler(nil, "cURL Lab execution is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("curlLab.".count))
                payload["requestID"] = "bridge-reply"
                Task { @MainActor [weak self] in
                    guard let self else {
                        replyHandler(nil, "The tool bridge is no longer available.")
                        return
                    }
                    let response = await curlLabBridge.handle(payload)
                    if response["ok"] as? Bool == true {
                        replyHandler(response["result"], nil)
                    } else {
                        replyHandler(nil, response["error"] as? String ?? "cURL Lab run failed.")
                    }
                }
            default:
                replyHandler(nil, "Unsupported bridge method: \(method)")
            }
        }

        private func storageDefaultsKey(_ key: String) -> String {
            "machkit.webTool.\(toolID).\(key)"
        }

        private static func isSafeStorageKey(_ key: String) -> Bool {
            guard (1...64).contains(key.count) else { return false }
            return key.unicodeScalars.allSatisfy { scalar in
                CharacterSet.alphanumerics.contains(scalar)
                    || scalar == "."
                    || scalar == "_"
                    || scalar == "-"
            }
        }

        private func isTrusted(url: URL?) -> Bool {
            guard let url else { return false }
            if url.scheme == "machkit-tool", url.host == "app" {
                let expectedPath = "/" + entryFile
                return url.path == expectedPath
            }
            #if DEBUG
            let developmentPath = entryFile.hasPrefix("WebTools/")
                ? String(entryFile.dropFirst("WebTools/".count))
                : entryFile
            return url.scheme == "http"
                && url.host == "127.0.0.1"
                && url.port == 4174
                && url.path == "/\(developmentPath)"
            #else
            return false
            #endif
        }

        @MainActor
        private func resizeWindowToFit(webView: WKWebView, requestedContentHeight: CGFloat) {
            guard requestedContentHeight.isFinite,
                  let window = webView.window,
                  let screen = window.screen ?? NSScreen.main else { return }

            let minimumHeight = max(window.contentMinSize.height, 1)
            let titlebarHeight = max(0, window.frame.height - window.contentLayoutRect.height)
            // Cap growth to most of the visible screen; user can still drag taller manually.
            let screenCap = screen.visibleFrame.height - titlebarHeight
            let maximumHeight = max(minimumHeight, floor(screenCap * 0.92))
            let targetContentHeight = min(max(requestedContentHeight, minimumHeight), maximumHeight)
            let currentContentHeight = window.contentLayoutRect.height
            guard abs(targetContentHeight - currentContentHeight) >= 2 else { return }

            let top = window.frame.maxY
            var targetFrame = window.frame
            targetFrame.size.height += targetContentHeight - currentContentHeight
            targetFrame.origin.y = top - targetFrame.height

            if targetFrame.minY < screen.visibleFrame.minY {
                targetFrame.origin.y = screen.visibleFrame.minY
            }
            if targetFrame.maxY > screen.visibleFrame.maxY {
                targetFrame.origin.y = screen.visibleFrame.maxY - targetFrame.height
            }
            window.setFrame(targetFrame, display: true, animate: window.isVisible)
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let requestURL = urlSchemeTask.request.url,
                  requestURL.scheme == "machkit-tool",
                  requestURL.host == "app",
                  let allowedRoot else {
                fail(urlSchemeTask, code: 400)
                return
            }

            let relativePath = requestURL.path.drop(while: { $0 == "/" })
            let fileURL = allowedRoot.appendingPathComponent(String(relativePath)).standardizedFileURL
            guard fileURL.path.hasPrefix(allowedRoot.path + "/"),
                  let data = try? Data(contentsOf: fileURL) else {
                fail(urlSchemeTask, code: 404)
                return
            }

            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType(for: fileURL.pathExtension),
                expectedContentLength: data.count,
                textEncodingName: isTextExtension(fileURL.pathExtension) ? "utf-8" : nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: any Error
        ) {
            guard isUsingDevelopmentServer else { return }
            loadBundledPage(in: webView)
        }

        private func fail(_ task: any WKURLSchemeTask, code: Int) {
            task.didFailWithError(NSError(domain: NSURLErrorDomain, code: code))
        }

        private func isTextExtension(_ ext: String) -> Bool {
            ["html", "js", "mjs", "css", "json", "svg"].contains(ext.lowercased())
        }

        private func mimeType(for ext: String) -> String {
            switch ext.lowercased() {
            case "html": "text/html"
            case "js", "mjs": "text/javascript"
            case "css": "text/css"
            case "json": "application/json"
            case "svg": "image/svg+xml"
            case "png": "image/png"
            case "jpg", "jpeg": "image/jpeg"
            case "webp": "image/webp"
            case "woff2": "font/woff2"
            default: "application/octet-stream"
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            #if DEBUG
            let isDevelopmentURL = url.scheme == "http"
                && url.host == "127.0.0.1"
                && url.port == 4174
            #else
            let isDevelopmentURL = false
            #endif

            if url.scheme == "about" || url.scheme == "machkit-tool" || isDevelopmentURL {
                decisionHandler(.allow)
            } else if url.isFileURL,
                      let allowedRoot,
                      url.standardizedFileURL.path.hasPrefix(allowedRoot.path + "/") {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
