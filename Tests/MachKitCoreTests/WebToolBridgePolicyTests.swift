import Foundation
import Testing
@testable import MachKitCore

@Test func webToolStorageKeysRejectUnsafeValues() {
    #expect(WebToolBridgePolicy.isSafeStorageKey("prefs.v1"))
    #expect(WebToolBridgePolicy.isSafeStorageKey("a_b-1") == true)
    #expect(WebToolBridgePolicy.isSafeStorageKey("") == false)
    #expect(WebToolBridgePolicy.isSafeStorageKey(String(repeating: "x", count: 65)) == false)
    #expect(WebToolBridgePolicy.isSafeStorageKey("has/slash") == false)
    #expect(WebToolBridgePolicy.isSafeStorageKey("has space") == false)
}

@Test func webToolBundledPathsStayInsideToolOrSharedAssets() {
    let toolID = "json-formatter"
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/tools/json-formatter/index.html",
        toolID: toolID
    ))
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/assets/mount-tool.js",
        toolID: toolID
    ))
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/tools/other-tool/index.html",
        toolID: toolID
    ) == false)
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/../Info.plist",
        toolID: toolID
    ) == false)
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "Localizable.xcstrings",
        toolID: toolID
    ) == false)
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/assets/../tools/secret/x.js",
        toolID: toolID
    ) == false)
    #expect(WebToolBridgePolicy.isAllowedBundledResourcePath(
        "WebTools/tools/json-formatter/../../assets/x.js",
        toolID: toolID
    ) == false)
}

@Test func webToolTrustedPageRequiresExactEntry() {
    let entry = "WebTools/tools/json-formatter/index.html"
    let bundled = URL(string: "machkit-tool://app/\(entry)")
    #expect(WebToolBridgePolicy.isTrustedToolPage(
        url: bundled,
        entryFile: entry,
        allowDevelopmentServer: false
    ))
    #expect(WebToolBridgePolicy.isTrustedToolPage(
        url: URL(string: "machkit-tool://app/WebTools/tools/other/index.html"),
        entryFile: entry,
        allowDevelopmentServer: false
    ) == false)
    #expect(WebToolBridgePolicy.isTrustedToolPage(
        url: URL(string: "https://example.com"),
        entryFile: entry,
        allowDevelopmentServer: true
    ) == false)

    let dev = URL(string: "http://127.0.0.1:4174/tools/json-formatter/index.html")
    #expect(WebToolBridgePolicy.isTrustedToolPage(
        url: dev,
        entryFile: entry,
        allowDevelopmentServer: true
    ))
    #expect(WebToolBridgePolicy.isTrustedToolPage(
        url: dev,
        entryFile: entry,
        allowDevelopmentServer: false
    ) == false)
}

@Test func webToolContentBlockerBlocksRemoteHTTP() throws {
    let json = WebToolBridgePolicy.contentBlockerRulesJSON(allowDevelopmentServer: false)
    let data = try #require(json.data(using: .utf8))
    let rules = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    #expect(rules.count == 1)
    let trigger = try #require(rules[0]["trigger"] as? [String: Any])
    #expect(trigger["url-filter"] as? String == "^https?://")

    let debugJSON = WebToolBridgePolicy.contentBlockerRulesJSON(allowDevelopmentServer: true)
    let debugData = try #require(debugJSON.data(using: .utf8))
    let debugRules = try #require(JSONSerialization.jsonObject(with: debugData) as? [[String: Any]])
    #expect(debugRules.count == 2)
}
