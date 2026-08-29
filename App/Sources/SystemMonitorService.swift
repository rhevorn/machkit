import Foundation
import MachKitCore

/// Shared sampling entry point so performance and home dashboard reuse
/// one monitor instance, consistent counter baselines, and short-lived nettop cache.
actor SystemMonitorService {
    static let shared = SystemMonitorService()

    private let performanceMonitor = PerformanceMonitor()
    private let networkScanner = NetworkScanner()

    private var cachedProcessRates: [Int32: (download: Double, upload: Double)] = [:]
    private var cachedProcessRatesAt: Date?
    private let processRatesCacheTTL: TimeInterval = 1.5

    private init() {}

    func samplePerformanceSnapshot() async -> PerformanceSnapshot {
        let rates = await processTrafficRates()
        return await performanceMonitor.sample(applicationNetworkRates: rates)
    }

    func sampleDashboardMetrics() async -> DashboardMetricsSnapshot {
        await performanceMonitor.sampleDashboardMetrics()
    }

    func sampleSystemSummary() async -> SystemPerformanceSummary {
        await performanceMonitor.sampleSystemSummary()
    }

    func sampleTransferRate() async -> NetworkTransferRate {
        await networkScanner.sampleTransferRate()
    }

    func scanNetwork() async -> NetworkSnapshot {
        await networkScanner.scan()
    }

    func route(to query: String) async -> NetworkRouteLookup {
        await networkScanner.route(to: query)
    }

    private func processTrafficRates() async -> [Int32: (download: Double, upload: Double)] {
        if let cachedProcessRatesAt,
           Date().timeIntervalSince(cachedProcessRatesAt) < processRatesCacheTTL {
            return cachedProcessRates
        }
        let rates = await networkScanner.sampleProcessTrafficRates()
        cachedProcessRates = rates
        cachedProcessRatesAt = Date()
        return rates
    }
}
