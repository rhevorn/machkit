import SwiftUI
import WebKit

struct WebToolView: View {
    let tool: DeveloperTool
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if case let .bundledWeb(entryFile) = tool.presentation {
                BundledWebView(entryFile: entryFile, localeIdentifier: locale.identifier)
            } else {
                ContentUnavailableView(
                    "Web tool not found".localized,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle(tool.localizedTitle)
    }
}

private struct BundledWebView: NSViewRepresentable {
    let entryFile: String
    let localeIdentifier: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(context.coordinator, forURLScheme: "sift-tool")
        configuration.userContentController.add(context.coordinator, name: "copy")
        configuration.userContentController.add(context.coordinator, name: "closeTool")
        let safeLocale = localeIdentifier.filter {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: "window.__SIFT__ = Object.freeze({ locale: '\(safeLocale.isEmpty ? "en" : safeLocale)' });",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        load(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "copy")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "closeTool")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(allowedRoot: Bundle.main.resourceURL)
    }

    private func load(in webView: WKWebView) {
        guard let resourceRoot = Bundle.main.resourceURL?.standardizedFileURL else {
            webView.loadHTMLString("<main><h2>Web tool not found</h2></main>", baseURL: nil)
            return
        }
        let url = resourceRoot.appendingPathComponent(entryFile).standardizedFileURL
        let isInsideBundle = url.path.hasPrefix(resourceRoot.path + "/")
        guard isInsideBundle, FileManager.default.fileExists(atPath: url.path) else {
            webView.loadHTMLString("<main><h2>Web tool not found</h2></main>", baseURL: nil)
            return
        }
        guard let toolURL = URL(string: "sift-tool://app/\(entryFile)") else {
            webView.loadHTMLString("<main><h2>Web tool not found</h2></main>", baseURL: nil)
            return
        }
        webView.load(URLRequest(url: toolURL))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKURLSchemeHandler {
        private let allowedRoot: URL?

        init(allowedRoot: URL?) {
            self.allowedRoot = allowedRoot?.standardizedFileURL
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "copy":
                guard let payload = message.body as? [String: Any], let text = payload["text"] as? String else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            case "closeTool":
                message.webView?.window?.performClose(nil)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let requestURL = urlSchemeTask.request.url,
                  requestURL.scheme == "sift-tool",
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
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.scheme == "about" || url.scheme == "sift-tool" {
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
