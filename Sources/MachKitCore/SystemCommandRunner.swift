import Darwin
import Foundation

struct SystemCommandOutput: Sendable {
    let status: Int32
    let text: String
}

enum SystemCommandRunnerError: LocalizedError, Equatable {
    case timedOut(executable: String, seconds: TimeInterval)
    case cancelled

    var errorDescription: String? {
        switch self {
        case let .timedOut(executable, seconds):
            "\(URL(fileURLWithPath: executable).lastPathComponent) timed out after \(seconds.formatted()) seconds."
        case .cancelled:
            "The system command was canceled."
        }
    }
}

enum SystemCommandRunner {
    private static let pollingInterval: TimeInterval = 0.05
    private static let terminationGracePeriod: TimeInterval = 0.5
    private static let maximumOutputBytes = 16 * 1_024 * 1_024

    static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 10,
        environment: [String: String] = [:]
    ) throws -> SystemCommandOutput {
        let process = Process()
        let outputPipe = Pipe()
        let outputBuffer = LockedCommandOutput(maximumBytes: maximumOutputBytes)
        let completion = DispatchSemaphore(value: 0)
        let outputHandle = outputPipe.fileHandleForReading

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, preferred in preferred }
        }
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { outputBuffer.append(data) }
        }
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            outputHandle.readabilityHandler = nil
            throw error
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while process.isRunning {
            if Task.isCancelled {
                stop(process, completion: completion)
                outputHandle.readabilityHandler = nil
                throw SystemCommandRunnerError.cancelled
            }
            if Date() >= deadline {
                stop(process, completion: completion)
                outputHandle.readabilityHandler = nil
                throw SystemCommandRunnerError.timedOut(executable: executable, seconds: timeout)
            }
            _ = completion.wait(timeout: .now() + pollingInterval)
        }

        outputHandle.readabilityHandler = nil
        outputBuffer.append(outputHandle.readDataToEndOfFile())
        return SystemCommandOutput(
            status: process.terminationStatus,
            text: String(decoding: outputBuffer.data, as: UTF8.self)
        )
    }

    private static func stop(_ process: Process, completion: DispatchSemaphore) {
        guard process.isRunning else { return }
        process.terminate()
        if completion.wait(timeout: .now() + terminationGracePeriod) == .timedOut, process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
            _ = completion.wait(timeout: .now() + terminationGracePeriod)
        }
    }
}

private final class LockedCommandOutput: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var storage = Data()

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let remaining = maximumBytes - storage.count
        if remaining > 0 { storage.append(data.prefix(remaining)) }
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
