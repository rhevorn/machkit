import Foundation
import MachKitCore

@MainActor
final class PortScanWebBridge {
    static let shared = PortScanWebBridge()

    private enum State: String {
        case running
        case completed
        case cancelled
        case failed
    }

    private struct Job {
        let id: String
        let host: String
        let total: Int
        let startedAt: Date
        var updatedAt: Date
        var state: State
        var completed: Int
        var closed: Int
        var timedOut: Int
        var openPorts: [TCPPortProbeResult]
        var durationMs: Double?
        var error: String?
        var task: Task<Void, Never>?
    }

    private var jobs: [String: Job] = [:]

    private init() {}

    func handle(_ payload: [String: Any]) async -> [String: Any] {
        let requestID = payload["requestID"] as? String ?? ""
        let action = payload["action"] as? String ?? ""

        switch action {
        case "start":
            return start(payload: payload, requestID: requestID)
        case "status":
            return status(payload: payload, requestID: requestID)
        case "cancel":
            return cancel(payload: payload, requestID: requestID)
        default:
            return ["requestID": requestID, "ok": false, "error": "Unsupported portScan action."]
        }
    }

    private func start(payload: [String: Any], requestID: String) -> [String: Any] {
        let rawHost = payload["host"] as? String ?? ""
        let portExpression = payload["ports"] as? String ?? ""
        let timeout = (payload["timeoutMs"] as? NSNumber)?.intValue
            ?? TCPPortScan.defaultTimeoutMilliseconds
        let concurrency = (payload["concurrency"] as? NSNumber)?.intValue
            ?? TCPPortScan.defaultConcurrency

        do {
            let host = try TCPPortScan.normalizeHost(rawHost)
            let ports = try TCPPortScan.parsePorts(portExpression)
            pruneJobs()

            let scanID = UUID().uuidString.lowercased()
            jobs[scanID] = Job(
                id: scanID,
                host: host,
                total: ports.count,
                startedAt: Date(),
                updatedAt: Date(),
                state: .running,
                completed: 0,
                closed: 0,
                timedOut: 0,
                openPorts: [],
                durationMs: nil,
                error: nil,
                task: nil
            )

            let task = Task { [weak self] in
                do {
                    let summary = try await TCPPortScan.scan(
                        host: host,
                        portExpression: portExpression,
                        timeoutMilliseconds: timeout,
                        concurrency: concurrency
                    ) { [weak self] result in
                        await self?.record(result, scanID: scanID)
                    }
                    self?.finish(summary, scanID: scanID)
                } catch let error as TCPPortScanError {
                    self?.fail(scanID: scanID, message: error.localizedDescription, code: error.code)
                } catch {
                    self?.fail(scanID: scanID, message: error.localizedDescription, code: "failed")
                }
            }
            jobs[scanID]?.task = task

            return [
                "requestID": requestID,
                "ok": true,
                "result": ["scanID": scanID, "host": host, "total": ports.count],
            ]
        } catch let error as TCPPortScanError {
            return ["requestID": requestID, "ok": false, "error": error.code]
        } catch {
            return ["requestID": requestID, "ok": false, "error": error.localizedDescription]
        }
    }

    private func status(payload: [String: Any], requestID: String) -> [String: Any] {
        guard let scanID = payload["scanID"] as? String, let job = jobs[scanID] else {
            return ["requestID": requestID, "ok": false, "error": "scan-not-found"]
        }
        return ["requestID": requestID, "ok": true, "result": dictionary(for: job)]
    }

    private func cancel(payload: [String: Any], requestID: String) -> [String: Any] {
        guard let scanID = payload["scanID"] as? String, var job = jobs[scanID] else {
            return ["requestID": requestID, "ok": false, "error": "scan-not-found"]
        }
        job.task?.cancel()
        if job.state == .running {
            job.state = .cancelled
            job.updatedAt = Date()
            job.durationMs = Date().timeIntervalSince(job.startedAt) * 1_000
            jobs[scanID] = job
        }
        return ["requestID": requestID, "ok": true, "result": dictionary(for: job)]
    }

    private func record(_ result: TCPPortProbeResult, scanID: String) {
        guard var job = jobs[scanID], job.state == .running else { return }
        job.completed += 1
        switch result.status {
        case .open: job.openPorts.append(result)
        case .timeout: job.timedOut += 1
        case .closed, .cancelled: job.closed += 1
        }
        job.updatedAt = Date()
        jobs[scanID] = job
    }

    private func finish(_ summary: TCPPortScanSummary, scanID: String) {
        guard var job = jobs[scanID], job.state == .running else { return }
        job.state = summary.cancelled ? .cancelled : .completed
        job.completed = summary.completed
        job.closed = summary.closed
        job.timedOut = summary.timedOut
        job.openPorts = summary.openPorts
        job.durationMs = summary.durationMs
        job.updatedAt = Date()
        job.task = nil
        jobs[scanID] = job
    }

    private func fail(scanID: String, message: String, code: String) {
        guard var job = jobs[scanID], job.state == .running else { return }
        job.state = .failed
        job.error = code.isEmpty ? message : code
        job.durationMs = Date().timeIntervalSince(job.startedAt) * 1_000
        job.updatedAt = Date()
        job.task = nil
        jobs[scanID] = job
    }

    private func dictionary(for job: Job) -> [String: Any] {
        var result: [String: Any] = [
            "scanID": job.id,
            "host": job.host,
            "state": job.state.rawValue,
            "total": job.total,
            "completed": job.completed,
            "closed": job.closed,
            "timedOut": job.timedOut,
            "openPorts": job.openPorts.sorted { $0.port < $1.port }.map { $0.asDictionary() },
        ]
        if let durationMs = job.durationMs { result["durationMs"] = durationMs }
        if let error = job.error { result["error"] = error }
        return result
    }

    private func pruneJobs() {
        let finished = jobs.values
            .filter { $0.state != .running }
            .sorted { $0.updatedAt < $1.updatedAt }
        for job in finished.dropLast(8) { jobs.removeValue(forKey: job.id) }
    }
}
