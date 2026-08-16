import Foundation
import MachKitCore

@MainActor
final class CurlLabWebBridge {
    static let shared = CurlLabWebBridge()

    private init() {}

    func handle(_ payload: [String: Any]) async -> [String: Any] {
        let requestID = payload["requestID"] as? String ?? ""
        let action = payload["action"] as? String ?? ""
        guard action == "run" else {
            return ["requestID": requestID, "ok": false, "error": "Unsupported curlLab action."]
        }

        let timeout = (payload["timeout"] as? NSNumber)?.doubleValue
            ?? CurlLabRunner.defaultTimeoutSeconds
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return ["requestID": requestID, "ok": false, "error": "Invalid cURL Lab payload."]
        }
        let result = await CurlLabRunner.run(payloadJSON: data, timeout: timeout)
        return ["requestID": requestID, "ok": true, "result": result.asDictionary()]
    }
}
