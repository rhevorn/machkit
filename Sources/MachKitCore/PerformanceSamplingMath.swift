import Foundation

public enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case elevated = "Elevated"
    case critical = "Critical"
}

public struct MemoryPressureEstimate: Sendable {
    public let usedBytes: Int64
    public let cachedBytes: Int64
    public let compressedBytes: Int64
    public let pressure: Double
    public let level: MemoryPressureLevel

    public init(
        usedBytes: Int64,
        cachedBytes: Int64,
        compressedBytes: Int64,
        pressure: Double,
        level: MemoryPressureLevel
    ) {
        self.usedBytes = usedBytes
        self.cachedBytes = cachedBytes
        self.compressedBytes = compressedBytes
        self.pressure = pressure
        self.level = level
    }
}

public enum PerformanceSamplingMath {
    public static func percentage(_ value: UInt64, of total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(100, max(0, Double(value) / Double(total) * 100))
    }

    public static func clampedPercentage(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    public static func transferRate(
        currentFirst: UInt64,
        currentSecond: UInt64,
        previousFirst: UInt64?,
        previousSecond: UInt64?,
        elapsed: TimeInterval
    ) -> (first: Double, second: Double) {
        guard elapsed > 0,
              let previousFirst,
              let previousSecond
        else { return (0, 0) }
        let first = currentFirst >= previousFirst ? currentFirst - previousFirst : 0
        let second = currentSecond >= previousSecond ? currentSecond - previousSecond : 0
        return (Double(first) / elapsed, Double(second) / elapsed)
    }

    public static func memoryPressure(
        totalBytes: Int64,
        activeBytes: Int64,
        wiredBytes: Int64,
        compressedBytes: Int64,
        inactiveBytes: Int64,
        purgeableBytes: Int64,
        speculativeBytes: Int64,
        freeBytes: Int64
    ) -> MemoryPressureEstimate {
        guard totalBytes > 0 else {
            return MemoryPressureEstimate(
                usedBytes: 0,
                cachedBytes: 0,
                compressedBytes: 0,
                pressure: 0,
                level: .normal
            )
        }
        let cached = inactiveBytes + purgeableBytes + speculativeBytes
        let reclaimable = min(totalBytes, freeBytes + cached)
        let used = min(totalBytes, max(0, activeBytes + wiredBytes + compressedBytes))
        let pressure = min(1, max(0, 1 - Double(reclaimable) / Double(totalBytes)))
        let level: MemoryPressureLevel = pressure < 0.75 ? .normal : (pressure < 0.9 ? .elevated : .critical)
        return MemoryPressureEstimate(
            usedBytes: used,
            cachedBytes: cached,
            compressedBytes: compressedBytes,
            pressure: pressure,
            level: level
        )
    }

    public static func processCPUPercent(
        cpuTimeNanoseconds: UInt64,
        previousCPUTimeNanoseconds: UInt64?,
        elapsed: TimeInterval,
        logicalCoreCount: Int
    ) -> (perCore: Double, ofSystem: Double) {
        guard elapsed > 0, let previousCPUTimeNanoseconds else { return (0, 0) }
        let cpuDelta = cpuTimeNanoseconds >= previousCPUTimeNanoseconds
            ? cpuTimeNanoseconds - previousCPUTimeNanoseconds
            : 0
        let perCore = Double(cpuDelta) / 1_000_000_000 / elapsed * 100
        let cores = max(1, logicalCoreCount)
        let ofSystem = perCore / Double(cores)
        return (max(0, perCore), max(0, ofSystem))
    }

    public static func estimatedNeuralEnginePercent(fromWatts watts: Double?, referenceWatts: Double = 8) -> Double? {
        guard let watts, referenceWatts > 0 else { return nil }
        return clampedPercentage(watts / referenceWatts * 100)
    }

    public static func mainProcessPIDByBundlePath(
        bundlePathAndPIDPairs: [(bundlePath: String, pid: Int32)]
    ) -> [String: Int32] {
        var result: [String: Int32] = [:]
        for pair in bundlePathAndPIDPairs {
            if result[pair.bundlePath] == nil {
                result[pair.bundlePath] = pair.pid
            }
        }
        return result
    }

    public static func aggregateNetworkRatesByMainProcessPID(
        rates: [Int32: (download: Double, upload: Double)],
        mainProcessPIDByBundlePath: [String: Int32],
        bundlePathForPID: (Int32) -> String?
    ) -> [Int32: (download: Double, upload: Double)] {
        var aggregated: [Int32: (download: Double, upload: Double)] = [:]
        for (pid, rate) in rates {
            let ownerPID: Int32
            if let bundlePath = bundlePathForPID(pid),
               let mappedPID = mainProcessPIDByBundlePath[bundlePath] {
                ownerPID = mappedPID
            } else if mainProcessPIDByBundlePath.values.contains(pid) {
                ownerPID = pid
            } else {
                continue
            }
            let existing = aggregated[ownerPID] ?? (0, 0)
            aggregated[ownerPID] = (existing.download + rate.download, existing.upload + rate.upload)
        }
        return aggregated
    }
}
