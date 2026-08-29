import Foundation
import MachKitCore

@MainActor
final class CurlLabWebBridge {
    static let shared = CurlLabWebBridge()

    private var activeRunID: UUID?
    private var activeToolID: String?
    private var activeTask: Task<CurlLabRunResult, Never>?

    private init() {}

    func handle(_ payload: [String: Any]) async -> [String: Any] {
        let requestID = payload["requestID"] as? String ?? ""
        let action = payload["action"] as? String ?? ""
        let toolID = normalizedToolID(payload["toolID"])

        switch action {
        case "run":
            return await run(payload: payload, requestID: requestID, toolID: toolID)
        case "cancel":
            cancelActive(for: toolID)
            return ["requestID": requestID, "ok": true, "result": ["canceled": true]]
        default:
            return ["requestID": requestID, "ok": false, "error": "Unsupported curlLab action."]
        }
    }

    /// Cancels the in-flight run when the owning tool window tears down.
    func cancelActive(for toolID: String? = nil) {
        if let toolID, let activeToolID, activeToolID != toolID {
            return
        }
        activeTask?.cancel()
        activeTask = nil
        activeRunID = nil
        activeToolID = nil
    }

    private func run(payload: [String: Any], requestID: String, toolID: String?) async -> [String: Any] {
        cancelActive()

        let timeout = (payload["timeout"] as? NSNumber)?.doubleValue
            ?? CurlLabRunner.defaultTimeoutSeconds
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return ["requestID": requestID, "ok": false, "error": "Invalid cURL Lab payload."]
        }

        let runID = UUID()
        activeRunID = runID
        activeToolID = toolID
        let task = Task {
            await CurlLabRunner.run(payloadJSON: data, timeout: timeout)
        }
        activeTask = task

        let result = await task.value
        if activeRunID == runID {
            activeTask = nil
            activeRunID = nil
            activeToolID = nil
        }
        return ["requestID": requestID, "ok": true, "result": result.asDictionary()]
    }

    private func normalizedToolID(_ raw: Any?) -> String? {
        guard let text = raw as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
