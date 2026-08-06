import AppKit
import Darwin
import Foundation
import Metal

struct ComputeHardwareInfo: Sendable {
    let gpuName: String
    let hasUnifiedMemory: Bool
    let recommendedGPUWorkingSet: Int64
}

enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case elevated = "Elevated"
    case critical = "Critical"
}

struct ApplicationResourceUsage: Identifiable, Sendable {
    let processIdentifier: pid_t
    let name: String
    let bundleURL: URL?
    let cpuPercent: Double
    let memoryBytes: Int64

    var id: pid_t { processIdentifier }
}

struct PerformanceSnapshot: Sendable {
    let sampledAt: Date
    let cpuPercent: Double
    let physicalMemory: Int64
    let usedMemory: Int64
    let cachedMemory: Int64
    let compressedMemory: Int64
    let swapUsed: Int64
    let memoryPressure: Double
    let memoryPressureLevel: MemoryPressureLevel
    let thermalState: ProcessInfo.ThermalState
    let computeHardware: ComputeHardwareInfo
    let applications: [ApplicationResourceUsage]
}

struct PerformanceHistoryPoint: Identifiable, Sendable {
    let id = UUID()
    let sampledAt: Date
    let cpuPercent: Double
    let memoryPressurePercent: Double
}

final class PerformanceMonitor {
    private struct ProcessSample {
        let cpuTime: UInt64
        let sampledAt: Date
    }

    private var previousCPUTicks: [UInt64]?
    private var previousProcessSamples: [pid_t: ProcessSample] = [:]
    private lazy var gpuInfo: (name: String, unifiedMemory: Bool, workingSet: Int64) = {
        guard let device = MTLCreateSystemDefaultDevice() else { return ("Metal GPU not detected", false, 0) }
        return (device.name, device.hasUnifiedMemory, Int64(device.recommendedMaxWorkingSetSize))
    }()
    func sample() -> PerformanceSnapshot {
        let now = Date()
        let cpuPercent = sampleCPUPercent()
        let memory = sampleMemory()
        let applications = sampleApplications(at: now)
        return PerformanceSnapshot(
            sampledAt: now,
            cpuPercent: cpuPercent,
            physicalMemory: memory.total,
            usedMemory: memory.used,
            cachedMemory: memory.cached,
            compressedMemory: memory.compressed,
            swapUsed: sampleSwapUsed(),
            memoryPressure: memory.pressure,
            memoryPressureLevel: memory.level,
            thermalState: ProcessInfo.processInfo.thermalState,
            computeHardware: ComputeHardwareInfo(
                gpuName: gpuInfo.name,
                hasUnifiedMemory: gpuInfo.unifiedMemory,
                recommendedGPUWorkingSet: gpuInfo.workingSet
            ),
            applications: applications
        )
    }

    private func sampleCPUPercent() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let ticks = withUnsafeBytes(of: info.cpu_ticks) {
            Array($0.bindMemory(to: natural_t.self)).map(UInt64.init)
        }
        guard ticks.count >= Int(CPU_STATE_MAX) else { return 0 }
        defer { previousCPUTicks = ticks }
        guard let previousCPUTicks, previousCPUTicks.count == ticks.count else { return 0 }

        let deltas = zip(ticks, previousCPUTicks).map { current, previous in current >= previous ? current - previous : 0 }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return 0 }
        let idle = deltas[Int(CPU_STATE_IDLE)]
        return min(100, max(0, Double(total - idle) / Double(total) * 100))
    }

    private func sampleMemory() -> (total: Int64, used: Int64, cached: Int64, compressed: Int64, pressure: Double, level: MemoryPressureLevel) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, total > 0 else {
            return (total, 0, 0, 0, 0, .normal)
        }

        var hostPageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &hostPageSize) == KERN_SUCCESS else {
            return (total, 0, 0, 0, 0, .normal)
        }
        let pageSize = Int64(hostPageSize)
        let active = Int64(stats.active_count) * pageSize
        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize
        let cached = (Int64(stats.inactive_count) + Int64(stats.purgeable_count) + Int64(stats.speculative_count)) * pageSize
        let reclaimable = min(total, Int64(stats.free_count) * pageSize + cached)
        let used = min(total, max(0, active + wired + compressed))
        let pressure = min(1, max(0, 1 - Double(reclaimable) / Double(total)))
        let level: MemoryPressureLevel = pressure < 0.75 ? .normal : (pressure < 0.9 ? .elevated : .critical)
        return (total, used, cached, compressed, pressure, level)
    }

    private func sampleSwapUsed() -> Int64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        return result == 0 ? Int64(usage.xsu_used) : 0
    }

    private func sampleApplications(at now: Date) -> [ApplicationResourceUsage] {
        var nextSamples: [pid_t: ProcessSample] = [:]
        var results: [ApplicationResourceUsage] = []
        for application in NSWorkspace.shared.runningApplications where application.processIdentifier > 0 {
            let pid = application.processIdentifier
            var taskInfo = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let readSize = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, infoSize)
            guard readSize == infoSize else { continue }

            let cpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            let processSample = ProcessSample(cpuTime: cpuTime, sampledAt: now)
            nextSamples[pid] = processSample
            let cpuPercent: Double
            if let previous = previousProcessSamples[pid] {
                let elapsed = now.timeIntervalSince(previous.sampledAt)
                let cpuDelta = cpuTime >= previous.cpuTime ? cpuTime - previous.cpuTime : 0
                cpuPercent = elapsed > 0 ? Double(cpuDelta) / 1_000_000_000 / elapsed * 100 : 0
            } else {
                cpuPercent = 0
            }
            let name = application.localizedName
                ?? application.bundleURL?.deletingPathExtension().lastPathComponent
                ?? L10n.format("Process %d", pid)
            results.append(ApplicationResourceUsage(
                processIdentifier: pid,
                name: name,
                bundleURL: application.bundleURL,
                cpuPercent: max(0, cpuPercent),
                memoryBytes: Int64(taskInfo.pti_resident_size)
            ))
        }
        previousProcessSamples = nextSamples
        return results.sorted { lhs, rhs in
            if abs(lhs.cpuPercent - rhs.cpuPercent) > 0.1 { return lhs.cpuPercent > rhs.cpuPercent }
            return lhs.memoryBytes > rhs.memoryBytes
        }
    }

}
