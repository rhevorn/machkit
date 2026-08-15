import Foundation
import MachKitCore

@MainActor
final class ConnectionTraceWebBridge {
    static let shared = ConnectionTraceWebBridge()

    private init() {}

    func handle(_ payload: [String: Any]) async -> [String: Any] {
        let requestID = payload["requestID"] as? String ?? ""
        let action = payload["action"] as? String ?? ""
        guard action == "probe" else {
            return ["requestID": requestID, "ok": false, "error": "Unsupported connectionTrace action."]
        }

        let target = payload["target"] as? String ?? ""
        let mode = payload["mode"] as? String ?? "full"
        let result = await ConnectionTrace.probe(target: target, mode: mode)
        return ["requestID": requestID, "ok": true, "result": result]
    }
}
