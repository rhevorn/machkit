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
        // Title is owned by the window (and optionally by the page via
        // `window.setTitle`); avoid `.navigationTitle` fighting temporary titles.
        .background(
            ToolWindowConfigurator(
                toolID: tool.id,
                defaultTitle: tool.localizedTitle,
                defaultSize: tool.defaultWindowSize,
                minimumSize: tool.minimumWindowSize,
                frameVersion: WebToolWidthClass.frameEpoch
            )
        )
    }
}

private struct ToolWindowConfigurator: NSViewRepresentable {
    let toolID: String
    let defaultTitle: String
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
        guard let window else { return }
        window.identifier = MachKitAppLifecycle.toolWindowInterfaceID(for: toolID)
        guard context.coordinator.configuredWindow !== window else { return }
        context.coordinator.configuredWindow = window
        window.title = defaultTitle
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
                source: WebToolBridgePolicy.bootstrapScript(
                    localeIdentifier: localeIdentifier,
                    appearance: appearance
                ),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        Self.disableElasticScrolling(in: webView)
        context.coordinator.localeIdentifier = localeIdentifier
        context.coordinator.appearance = appearance
        context.coordinator.attachContentRulesThenLoad(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        Self.disableElasticScrolling(in: webView)
        context.coordinator.applyPreferencesIfNeeded(
            in: webView,
            localeIdentifier: localeIdentifier,
            appearance: appearance
        )
    }

    /// Trackpad rubber-banding on the page chrome feels like the whole tool is
    /// sliding even when there is nothing to scroll. Keep real overflow scrollers.
    private static func disableElasticScrolling(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            scrollView.horizontalScrollElasticity = .none
            scrollView.verticalScrollElasticity = .none
        }
        for subview in root.subviews {
            disableElasticScrolling(in: subview)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown(webView: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            toolID: toolID,
            allowedRoot: Bundle.main.resourceURL,
            entryFile: entryFile,
            capabilities: capabilities
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply, WKURLSchemeHandler {
        private let toolID: String
        private let allowedRoot: URL?
        private let entryFile: String
        private let capabilities: Set<DeveloperToolCapability>
        private var isUsingDevelopmentServer = false
        /// Set after the Vite page finishes loading. Failures after that must not
        /// fall back to bundled assets — that permanently kills HMR for the session.
        private var didLoadDevelopmentPage = false
        private let hostsBridge = HostsWebBridge.shared
        private let portScanBridge = PortScanWebBridge.shared
        private let curlLabBridge = CurlLabWebBridge.shared
        private var contentRuleList: WKContentRuleList?
        var localeIdentifier = "en"
        var appearance = AppAppearance.system.rawValue

        private static var contentRuleListTask: Task<WKContentRuleList?, Never>?

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

        func teardown(webView: WKWebView) {
            if capabilities.contains(.curlLab) {
                curlLabBridge.cancelActive(for: toolID)
            }
            if capabilities.contains(.portScan) {
                portScanBridge.cancelRunning(for: toolID)
            }
            let controller = webView.configuration.userContentController
            controller.removeScriptMessageHandler(forName: "bridge", contentWorld: .page)
            if let contentRuleList {
                controller.remove(contentRuleList)
            }
        }

        func attachContentRulesThenLoad(in webView: WKWebView) {
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                if let list = await Self.sharedContentRuleList() {
                    self.contentRuleList = list
                    webView.configuration.userContentController.add(list)
                }
                self.loadInitialPage(in: webView)
            }
        }

        private static func sharedContentRuleList() async -> WKContentRuleList? {
            if let contentRuleListTask {
                return await contentRuleListTask.value
            }
            #if DEBUG
            let allowDevelopmentServer = true
            #else
            let allowDevelopmentServer = false
            #endif
            let task = Task<WKContentRuleList?, Never> {
                let rules = WebToolBridgePolicy.contentBlockerRulesJSON(
                    allowDevelopmentServer: allowDevelopmentServer
                )
                return await withCheckedContinuation { continuation in
                    WKContentRuleListStore.default().compileContentRuleList(
                        forIdentifier: "machkit.webview.local-only.v2",
                        encodedContentRuleList: rules
                    ) { list, _ in
                        continuation.resume(returning: list)
                    }
                }
            }
            contentRuleListTask = task
            return await task.value
        }

        func applyPreferencesIfNeeded(in webView: WKWebView, localeIdentifier: String, appearance: String) {
            let localeChanged = self.localeIdentifier != localeIdentifier
            let appearanceChanged = self.appearance != appearance
            guard localeChanged || appearanceChanged else { return }
            self.localeIdentifier = localeIdentifier
            self.appearance = appearance

            let preferences = WebToolBridgePolicy.sanitizedPreferences(
                localeIdentifier: localeIdentifier,
                appearance: appearance
            )
            let safeLocale = preferences.locale
            let safeAppearance = preferences.appearance
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
                didLoadDevelopmentPage = false
                webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
                return
            }
            #endif
            loadBundledPage(in: webView)
        }

        private func loadBundledPage(in webView: WKWebView) {
            isUsingDevelopmentServer = false
            didLoadDevelopmentPage = false
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
                guard text.utf8.count <= WebToolBridgePolicy.maxClipboardUTF8Bytes else {
                    replyHandler(nil, "Clipboard content is too large.")
                    return
                }
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(text, forType: .string) else {
                    replyHandler(nil, "Unable to write to the clipboard.")
                    return
                }
                replyHandler(["ok": true], nil)
            case "clipboard.read":
                guard capabilities.contains(.clipboard) else {
                    replyHandler(nil, "Clipboard access is not available to this tool.")
                    return
                }
                let text = NSPasteboard.general.string(forType: .string) ?? ""
                guard text.utf8.count <= WebToolBridgePolicy.maxClipboardUTF8Bytes else {
                    replyHandler(nil, "Clipboard content is too large.")
                    return
                }
                replyHandler(["text": text], nil)
            case "window.fitContentHeight":
                guard let height = parameters["height"] as? NSNumber,
                      let webView = message.webView else {
                    replyHandler(nil, "Content fitting is not available.")
                    return
                }
                resizeWindowToFit(webView: webView, requestedContentHeight: height.doubleValue)
                replyHandler(["ok": true], nil)
            case "window.setTitle":
                guard let webView = message.webView,
                      let title = parameters["title"] as? String else {
                    replyHandler(nil, "Window title updates are not available.")
                    return
                }
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.utf8.count <= 200 else {
                    replyHandler(nil, "Window title is too long.")
                    return
                }
                let fallback = DeveloperToolRegistry.tool(id: toolID)?.localizedTitle ?? "MachKit"
                webView.window?.title = trimmed.isEmpty ? fallback : trimmed
                replyHandler(["ok": true], nil)
            case "storage.get":
                guard capabilities.contains(.storage),
                      let key = parameters["key"] as? String,
                      WebToolBridgePolicy.isSafeStorageKey(key) else {
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
                      WebToolBridgePolicy.isSafeStorageKey(key),
                      let value = parameters["value"] as? String,
                      value.utf8.count <= WebToolBridgePolicy.maxStorageUTF8Bytes else {
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
                panel.begin { response in
                    Task { @MainActor in
                        if response == .OK, let url = panel.url {
                            replyHandler([
                                "canceled": false,
                                "path": url.path,
                                "name": url.lastPathComponent
                            ], nil)
                        } else {
                            replyHandler(["canceled": true], nil)
                        }
                    }
                }
            case "files.save":
                guard capabilities.contains(.files) else {
                    replyHandler(nil, "File saving is not available to this tool.")
                    return
                }
                guard let name = parameters["name"] as? String,
                      let base64 = parameters["dataBase64"] as? String,
                      let data = Data(base64Encoded: base64),
                      !data.isEmpty,
                      data.count <= WebToolBridgePolicy.maxSaveFileBytes else {
                    replyHandler(nil, "Invalid file payload.")
                    return
                }
                let safeName = URL(fileURLWithPath: name).lastPathComponent
                guard !safeName.isEmpty, safeName != "/", !safeName.hasPrefix(".") else {
                    replyHandler(nil, "Invalid file name.")
                    return
                }
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.isExtensionHidden = false
                panel.nameFieldStringValue = safeName
                panel.begin { response in
                    Task { @MainActor in
                        if response == .OK, let url = panel.url {
                            do {
                                try data.write(to: url, options: .atomic)
                                replyHandler([
                                    "canceled": false,
                                    "path": url.path,
                                    "name": url.lastPathComponent
                                ], nil)
                            } catch {
                                replyHandler(nil, error.localizedDescription)
                            }
                        } else {
                            replyHandler(["canceled": true], nil)
                        }
                    }
                }
            case let method where method.hasPrefix("hosts."):
                guard capabilities.contains(.hosts) else {
                    replyHandler(nil, "Hosts access is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("hosts.".count))
                payload["requestID"] = "bridge-reply"
                payload["toolID"] = toolID
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
            case let method where method.hasPrefix("portScan."):
                guard capabilities.contains(.portScan) else {
                    replyHandler(nil, "Port scanning is not available to this tool.")
                    return
                }
                var payload = parameters
                payload["action"] = String(method.dropFirst("portScan.".count))
                payload["requestID"] = "bridge-reply"
                payload["toolID"] = toolID
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
                payload["toolID"] = toolID
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

        private func isTrusted(url: URL?) -> Bool {
            #if DEBUG
            let allowDevelopmentServer = true
            #else
            let allowDevelopmentServer = false
            #endif
            return WebToolBridgePolicy.isTrustedToolPage(
                url: url,
                entryFile: entryFile,
                allowDevelopmentServer: allowDevelopmentServer
            )
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

            let relativePath = String(requestURL.path.drop(while: { $0 == "/" }))
            guard WebToolBridgePolicy.isAllowedBundledResourcePath(relativePath, toolID: toolID) else {
                fail(urlSchemeTask, code: 403)
                return
            }

            let fileURL = allowedRoot.appendingPathComponent(relativePath).standardizedFileURL
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
            // Only fall back when the first Vite load fails (server down). After a
            // successful load, HMR full-reloads can briefly fail; switching to the
            // bundled copy would freeze the tool on stale assets for the rest of the session.
            guard isUsingDevelopmentServer, !didLoadDevelopmentPage else { return }
            loadBundledPage(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if isUsingDevelopmentServer {
                didLoadDevelopmentPage = true
            }
            BundledWebView.disableElasticScrolling(in: webView)
        }

        /// WKWebView will not open `<input type="file">` unless the UI delegate
        /// presents an open panel and always completes the handler.
        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.resolvesAliases = true
            panel.treatsFilePackagesAsDirectories = false
            panel.begin { response in
                if response == .OK {
                    completionHandler(panel.urls)
                } else {
                    completionHandler(nil)
                }
            }
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

            if url.scheme == "about" {
                decisionHandler(.allow)
            } else if url.scheme == "machkit-tool" {
                let relative = String(url.path.drop(while: { $0 == "/" }))
                if url.host == "app",
                   WebToolBridgePolicy.isAllowedBundledResourcePath(relative, toolID: toolID) {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
            } else if isDevelopmentURL {
                decisionHandler(.allow)
            } else if url.isFileURL,
                      let allowedRoot,
                      url.standardizedFileURL.path.hasPrefix(allowedRoot.path + "/") {
                let relative = String(url.standardizedFileURL.path.dropFirst(allowedRoot.path.count + 1))
                if WebToolBridgePolicy.isAllowedBundledResourcePath(relative, toolID: toolID) {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
