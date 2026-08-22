import Darwin
import Foundation

public enum ProcessBundlePath {
    public static func executablePath(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let utf8 = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let path = String(decoding: utf8, as: UTF8.self)
        return path.isEmpty ? nil : path
    }

    public static func bundlePath(containingExecutablePath executablePath: String, bundlePaths: [String]) -> String? {
        let normalizedExecutable = URL(fileURLWithPath: executablePath).standardizedFileURL.path
        var bestMatch: String?
        var bestLength = 0
        for bundlePath in bundlePaths {
            let normalizedBundle = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
            guard normalizedExecutable.hasPrefix(normalizedBundle + "/") || normalizedExecutable == normalizedBundle else {
                continue
            }
            if normalizedBundle.count > bestLength {
                bestLength = normalizedBundle.count
                bestMatch = normalizedBundle
            }
        }
        return bestMatch
    }
}
