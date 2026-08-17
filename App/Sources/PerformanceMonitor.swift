import AppKit
import Darwin
import Foundation
import IOKit
import Metal
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ComputeHardwareInfo: Sendable {
    let cpuName: String
    let physicalCores: Int
    let logicalCores: Int
    let performanceCores: Int
    let efficiencyCores: Int
    let gpuName: String
    let gpuCoreCount: Int?
    let hasUnifiedMemory: Bool
    let recommendedGPUWorkingSet: Int64
    let appleIntelligence: AppleIntelligenceStatus
}

enum AppleIntelligenceStatus: String, Sendable {
    case available = "Available"
    case notEnabled = "Not enabled"
    case modelNotReady = "Model not ready"
    case deviceNotSupported = "Device not supported"
    case requiresNewerOS = "Requires macOS 15.1+"
    case checkSystemSettings = "Check System Settings"
    case unavailable = "Unavailable"

    var isUsable: Bool { self == .available }

    var detail: String {
        switch self {
        case .available:
            return "On-device Apple Intelligence is ready"
        case .notEnabled:
            return "Turn on Apple Intelligence in System Settings"
        case .modelNotReady:
            return "The on-device model is still downloading or preparing"
        case .deviceNotSupported:
            return "This Mac does not support Apple Intelligence"
        case .requiresNewerOS:
            return "Update macOS to use Apple Intelligence"
        case .checkSystemSettings:
            return "Hardware looks eligible — confirm in System Settings"
        case .unavailable:
            return "Apple Intelligence is currently unavailable"
        }
    }
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

struct CPUCoreUsage: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case performance
        case efficiency
        case standard
    }

    let index: Int
    let percent: Double
    let kind: Kind

    var id: Int { index }
}

struct PerformanceSnapshot: Sendable {
    let sampledAt: Date
    let cpuPercent: Double
    let cpuUserPercent: Double
    let cpuSystemPercent: Double
    let cpuCores: [CPUCoreUsage]
    let gpuPercent: Double?
    let gpuRendererPercent: Double?
    let gpuTilerPercent: Double?
    let gpuMemoryBytes: Int64
    let physicalMemory: Int64
    let usedMemory: Int64
    let cachedMemory: Int64
    let compressedMemory: Int64
    let swapUsed: Int64
    let memoryPressure: Double
    let memoryPressureLevel: MemoryPressureLevel
    let diskReadBytesPerSecond: Double
    let diskWriteBytesPerSecond: Double
    let networkDownloadBytesPerSecond: Double
    let networkUploadBytesPerSecond: Double
    let loadAverages: [Double]
    let processCount: Int
    let systemUptime: TimeInterval
    let thermalState: ProcessInfo.ThermalState
    let computeHardware: ComputeHardwareInfo
    let applications: [ApplicationResourceUsage]
}

struct SystemPerformanceSummary: Sendable {
    let cpuPercent: Double
    let physicalMemory: Int64
    let usedMemory: Int64
}

struct PerformanceHistoryPoint: Identifiable, Sendable {
    let id = UUID()
    let sampledAt: Date
    let cpuPercent: Double
    let gpuPercent: Double?
    let memoryPressurePercent: Double
}

/// Serializes mutable counter baselines off the main actor. Sampling walks
/// IOKit and the process list, so it must never block SwiftUI or screenshot
/// gesture delivery.
actor PerformanceMonitor {
    private struct CPULoad {
        let total: Double
        let user: Double
        let system: Double
    }

    private struct CounterSample {
        let first: UInt64
        let second: UInt64
        let sampledAt: Date
    }

    private struct TransferRate {
        let first: Double
        let second: Double
    }

    private struct GPUUsage {
        let device: Double?
        let renderer: Double?
        let tiler: Double?
        let memoryBytes: Int64
        let coreCount: Int?
    }

    private struct ProcessSample {
        let cpuTime: UInt64
        let sampledAt: Date
    }

    private struct CachedCPUInfo {
        let name: String
        let physicalCores: Int
        let logicalCores: Int
        let performanceCores: Int
        let efficiencyCores: Int
        let performanceLogicalCores: Int
        let efficiencyLogicalCores: Int
    }

    private var previousCPUTicks: [UInt64]?
    private var previousPerCoreTicks: [[UInt64]]?
    private var previousProcessSamples: [pid_t: ProcessSample] = [:]
    private var previousDiskSample: CounterSample?
    private var previousNetworkSample: CounterSample?
    private lazy var cpuInfo: CachedCPUInfo = Self.readCPUInfo()
    private lazy var gpuInfo: (name: String, unifiedMemory: Bool, workingSet: Int64) = {
        guard let device = MTLCreateSystemDefaultDevice() else { return ("Metal GPU not detected", false, 0) }
        return (device.name, device.hasUnifiedMemory, Int64(device.recommendedMaxWorkingSetSize))
    }()

    func sampleSystemSummary() -> SystemPerformanceSummary {
        let memory = sampleMemory()
        return SystemPerformanceSummary(
            cpuPercent: sampleCPU().total,
            physicalMemory: memory.total,
            usedMemory: memory.used
        )
    }

    func sample() -> PerformanceSnapshot {
        let now = Date()
        let cpu = sampleCPU()
        let cpuCores = sampleCPUCores()
        let gpuUsage = sampleGPUUsage()
        let memory = sampleMemory()
        let disk = sampleDiskTransfer(at: now)
        let network = sampleNetworkTransfer(at: now)
        let applications = sampleApplications(at: now)
        let cpuInfo = cpuInfo
        let gpu = gpuInfo
        return PerformanceSnapshot(
            sampledAt: now,
            cpuPercent: cpu.total,
            cpuUserPercent: cpu.user,
            cpuSystemPercent: cpu.system,
            cpuCores: cpuCores,
            gpuPercent: gpuUsage.device,
            gpuRendererPercent: gpuUsage.renderer,
            gpuTilerPercent: gpuUsage.tiler,
            gpuMemoryBytes: gpuUsage.memoryBytes,
            physicalMemory: memory.total,
            usedMemory: memory.used,
            cachedMemory: memory.cached,
            compressedMemory: memory.compressed,
            swapUsed: sampleSwapUsed(),
            memoryPressure: memory.pressure,
            memoryPressureLevel: memory.level,
            diskReadBytesPerSecond: disk.first,
            diskWriteBytesPerSecond: disk.second,
            networkDownloadBytesPerSecond: network.first,
            networkUploadBytesPerSecond: network.second,
            loadAverages: sampleLoadAverages(),
            processCount: sampleProcessCount(),
            systemUptime: ProcessInfo.processInfo.systemUptime,
            thermalState: ProcessInfo.processInfo.thermalState,
            computeHardware: ComputeHardwareInfo(
                cpuName: cpuInfo.name.isEmpty ? gpu.name : cpuInfo.name,
                physicalCores: cpuInfo.physicalCores,
                logicalCores: cpuInfo.logicalCores,
                performanceCores: cpuInfo.performanceCores,
                efficiencyCores: cpuInfo.efficiencyCores,
                gpuName: gpu.name,
                gpuCoreCount: gpuUsage.coreCount,
                hasUnifiedMemory: gpu.unifiedMemory,
                recommendedGPUWorkingSet: gpu.workingSet,
                appleIntelligence: Self.appleIntelligenceStatus(hasUnifiedMemory: gpu.unifiedMemory)
            ),
            applications: applications
        )
    }

    private static func appleIntelligenceStatus(hasUnifiedMemory: Bool) -> AppleIntelligenceStatus {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotSupported
            case .unavailable(.appleIntelligenceNotEnabled):
                return .notEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        }
        #endif

        #if arch(arm64)
        if #available(macOS 15.1, *) {
            // Foundation Models API is macOS 26+; on Sequoia we can only confirm hardware eligibility.
            return hasUnifiedMemory ? .checkSystemSettings : .deviceNotSupported
        }
        return .requiresNewerOS
        #else
        return .deviceNotSupported
        #endif
    }

    private static func readCPUInfo() -> CachedCPUInfo {
        let brand = sysctlString("machdep.cpu.brand_string")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let physical = max(1, sysctlInt("hw.physicalcpu") ?? ProcessInfo.processInfo.processorCount)
        let logical = max(physical, sysctlInt("hw.logicalcpu") ?? ProcessInfo.processInfo.processorCount)
        let performance = sysctlInt("hw.perflevel0.physicalcpu") ?? 0
        let efficiency = sysctlInt("hw.perflevel1.physicalcpu") ?? 0
        let performanceLogical = sysctlInt("hw.perflevel0.logicalcpu") ?? performance
        let efficiencyLogical = sysctlInt("hw.perflevel1.logicalcpu") ?? efficiency
        let name: String
        if !brand.isEmpty {
            name = brand
        } else if let device = MTLCreateSystemDefaultDevice()?.name, !device.isEmpty {
            // Apple Silicon often leaves brand_string empty; Metal device name is the chip.
            name = device
        } else {
            name = "CPU"
        }
        return CachedCPUInfo(
            name: name,
            physicalCores: physical,
            logicalCores: logical,
            performanceCores: performance,
            efficiencyCores: efficiency,
            performanceLogicalCores: performanceLogical,
            efficiencyLogicalCores: efficiencyLogical
        )
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        let utf8 = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }

    private func sampleCPU() -> CPULoad {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return CPULoad(total: 0, user: 0, system: 0) }
        let ticks = withUnsafeBytes(of: info.cpu_ticks) {
            Array($0.bindMemory(to: natural_t.self)).map(UInt64.init)
        }
        guard ticks.count >= Int(CPU_STATE_MAX) else { return CPULoad(total: 0, user: 0, system: 0) }
        defer { previousCPUTicks = ticks }
        guard let previousCPUTicks, previousCPUTicks.count == ticks.count else {
            return CPULoad(total: 0, user: 0, system: 0)
        }

        let deltas = zip(ticks, previousCPUTicks).map { current, previous in current >= previous ? current - previous : 0 }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return CPULoad(total: 0, user: 0, system: 0) }
        let idle = deltas[Int(CPU_STATE_IDLE)]
        let user = deltas[Int(CPU_STATE_USER)] + deltas[Int(CPU_STATE_NICE)]
        let system = deltas[Int(CPU_STATE_SYSTEM)]
        return CPULoad(
            total: Self.percentage(total - idle, of: total),
            user: Self.percentage(user, of: total),
            system: Self.percentage(system, of: total)
        )
    }

    private static func percentage(_ value: UInt64, of total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(100, max(0, Double(value) / Double(total) * 100))
    }

    private func sampleCPUCores() -> [CPUCoreUsage] {
        var cpuCount: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfoArray,
            &numCpuInfo
        )
        guard kr == KERN_SUCCESS, let cpuInfoArray, cpuCount > 0 else { return [] }
        defer {
            let bytes = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfoArray)), bytes)
        }

        let stateCount = Int(CPU_STATE_MAX)
        var currentTicks: [[UInt64]] = []
        currentTicks.reserveCapacity(Int(cpuCount))
        for coreIndex in 0..<Int(cpuCount) {
            let base = coreIndex * stateCount
            var ticks = [UInt64](repeating: 0, count: stateCount)
            for state in 0..<stateCount {
                ticks[state] = UInt64(cpuInfoArray[base + state])
            }
            currentTicks.append(ticks)
        }

        defer { previousPerCoreTicks = currentTicks }

        let performanceLogical = max(0, cpuInfo.performanceLogicalCores)
        let hasPESplit = performanceLogical > 0 && performanceLogical < currentTicks.count

        guard let previousPerCoreTicks, previousPerCoreTicks.count == currentTicks.count else {
            return currentTicks.indices.map { index in
                CPUCoreUsage(
                    index: index,
                    percent: 0,
                    kind: coreKind(index: index, performanceLogical: performanceLogical, hasPESplit: hasPESplit)
                )
            }
        }

        return currentTicks.indices.map { index in
            let deltas = zip(currentTicks[index], previousPerCoreTicks[index]).map { current, previous in
                current >= previous ? current - previous : 0
            }
            let total = deltas.reduce(0, +)
            let idle = deltas.indices.contains(Int(CPU_STATE_IDLE)) ? deltas[Int(CPU_STATE_IDLE)] : 0
            let percent = total > 0 ? min(100, max(0, Double(total - idle) / Double(total) * 100)) : 0
            return CPUCoreUsage(
                index: index,
                percent: percent,
                kind: coreKind(index: index, performanceLogical: performanceLogical, hasPESplit: hasPESplit)
            )
        }
    }

    private func coreKind(index: Int, performanceLogical: Int, hasPESplit: Bool) -> CPUCoreUsage.Kind {
        guard hasPESplit else { return .standard }
        return index < performanceLogical ? .performance : .efficiency
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

    private func sampleGPUUsage() -> GPUUsage {
        let statistics = registryDictionaries(matching: "IOAccelerator", property: "PerformanceStatistics")
        let coreCount = registryNumbers(matching: "IOAccelerator", property: "gpu-core-count")
            .map(\.intValue)
            .filter { $0 > 0 }
            .max()
        let device = maximumNumber(in: statistics, keys: ["Device Utilization %", "GPU Activity(%)"])
        let renderer = maximumNumber(in: statistics, keys: ["Renderer Utilization %"])
        let tiler = maximumNumber(in: statistics, keys: ["Tiler Utilization %"])
        let memory = statistics.reduce(Int64(0)) { partial, dictionary in
            let inUse = Self.int64Value(dictionary["In use system memory"])
            let driver = Self.int64Value(dictionary["In use system memory (driver)"])
            return partial + max(0, inUse) + max(0, driver)
        }
        return GPUUsage(
            device: device.map(Self.clampedPercentage),
            renderer: renderer.map(Self.clampedPercentage),
            tiler: tiler.map(Self.clampedPercentage),
            memoryBytes: memory,
            coreCount: coreCount
        )
    }

    private func sampleDiskTransfer(at now: Date) -> TransferRate {
        let statistics = registryDictionaries(matching: "IOBlockStorageDriver", property: "Statistics")
        let read = statistics.reduce(UInt64(0)) { partial, dictionary in
            partial &+ Self.uint64Value(dictionary["Bytes (Read)"])
        }
        let written = statistics.reduce(UInt64(0)) { partial, dictionary in
            partial &+ Self.uint64Value(dictionary["Bytes (Write)"])
        }
        let current = CounterSample(first: read, second: written, sampledAt: now)
        defer { previousDiskSample = current }
        return Self.transferRate(current: current, previous: previousDiskSample)
    }

    private func sampleNetworkTransfer(at now: Date) -> TransferRate {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return TransferRate(first: 0, second: 0)
        }
        defer { freeifaddrs(pointer) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            let interface = item.pointee
            if let address = interface.ifa_addr,
               Int32(address.pointee.sa_family) == AF_LINK,
               interface.ifa_flags & UInt32(IFF_UP) != 0,
               interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                received &+= UInt64(data.ifi_ibytes)
                sent &+= UInt64(data.ifi_obytes)
            }
            current = interface.ifa_next
        }

        let sample = CounterSample(first: received, second: sent, sampledAt: now)
        defer { previousNetworkSample = sample }
        return Self.transferRate(current: sample, previous: previousNetworkSample)
    }

    private func registryDictionaries(matching className: String, property: String) -> [[String: Any]] {
        registryValues(matching: className, property: property).compactMap { $0 as? [String: Any] }
    }

    private func registryNumbers(matching className: String, property: String) -> [NSNumber] {
        registryValues(matching: className, property: property).compactMap { $0 as? NSNumber }
    }

    private func registryValues(matching className: String, property: String) -> [Any] {
        guard let matching = IOServiceMatching(className) else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [Any] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let value = IORegistryEntryCreateCFProperty(
                service,
                property as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() {
                result.append(value)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    private func maximumNumber(in dictionaries: [[String: Any]], keys: [String]) -> Double? {
        dictionaries.lazy.compactMap { dictionary in
            keys.lazy.compactMap { key in
                (dictionary[key] as? NSNumber)?.doubleValue
            }.first
        }.max()
    }

    private static func transferRate(current: CounterSample, previous: CounterSample?) -> TransferRate {
        guard let previous else { return TransferRate(first: 0, second: 0) }
        let elapsed = current.sampledAt.timeIntervalSince(previous.sampledAt)
        guard elapsed > 0 else { return TransferRate(first: 0, second: 0) }
        let first = current.first >= previous.first ? current.first - previous.first : 0
        let second = current.second >= previous.second ? current.second - previous.second : 0
        return TransferRate(first: Double(first) / elapsed, second: Double(second) / elapsed)
    }

    private static func clampedPercentage(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func uint64Value(_ value: Any?) -> UInt64 {
        guard let number = value as? NSNumber else { return 0 }
        return number.uint64Value
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        guard let number = value as? NSNumber else { return 0 }
        return number.int64Value
    }

    private func sampleLoadAverages() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        let count = getloadavg(&values, Int32(values.count))
        guard count > 0 else { return [] }
        return Array(values.prefix(Int(count)))
    }

    private func sampleProcessCount() -> Int {
        max(0, Int(proc_listallpids(nil, 0)))
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
