import Foundation
import Testing
@testable import MachKitCore

@Test func performanceSamplingMathComputesTransferRates() {
    let rates = PerformanceSamplingMath.transferRate(
        currentFirst: 2_000,
        currentSecond: 1_000,
        previousFirst: 1_000,
        previousSecond: 500,
        elapsed: 2
    )
    #expect(rates.first == 500)
    #expect(rates.second == 250)
}

@Test func performanceSamplingMathReturnsZeroWithoutBaseline() {
    let rates = PerformanceSamplingMath.transferRate(
        currentFirst: 2_000,
        currentSecond: 1_000,
        previousFirst: nil,
        previousSecond: nil,
        elapsed: 2
    )
    #expect(rates.first == 0)
    #expect(rates.second == 0)
}

@Test func performanceSamplingMathEstimatesMemoryPressure() {
    let estimate = PerformanceSamplingMath.memoryPressure(
        totalBytes: 16_000,
        activeBytes: 4_000,
        wiredBytes: 2_000,
        compressedBytes: 1_000,
        inactiveBytes: 3_000,
        purgeableBytes: 1_000,
        speculativeBytes: 1_000,
        freeBytes: 4_000
    )
    #expect(estimate.usedBytes == 7_000)
    #expect(estimate.cachedBytes == 5_000)
    #expect(estimate.level == .normal)
}

@Test func performanceSamplingMathNormalizesProcessCPU() {
    let usage = PerformanceSamplingMath.processCPUPercent(
        cpuTimeNanoseconds: 2_000_000_000,
        previousCPUTimeNanoseconds: 1_000_000_000,
        elapsed: 1,
        logicalCoreCount: 4
    )
    #expect(usage.perCore == 100)
    #expect(usage.ofSystem == 25)
}

@Test func mainProcessPIDByBundlePathKeepsFirstPIDForDuplicateBundles() {
    let map = PerformanceSamplingMath.mainProcessPIDByBundlePath(
        bundlePathAndPIDPairs: [
            ("/Applications/Safari.app", 100),
            ("/Applications/Safari.app", 200),
            ("/Applications/Mail.app", 300)
        ]
    )
    #expect(map["/Applications/Safari.app"] == 100)
    #expect(map["/Applications/Mail.app"] == 300)
}

@Test func performanceSamplingMathAggregatesNetworkRatesByBundle() {
    let aggregated = PerformanceSamplingMath.aggregateNetworkRatesByMainProcessPID(
        rates: [
            100: (download: 10, upload: 5),
            200: (download: 20, upload: 10)
        ],
        mainProcessPIDByBundlePath: [
            "/Applications/Example.app": 100
        ],
        bundlePathForPID: { pid in
            pid == 200 ? "/Applications/Example.app" : nil
        }
    )
    #expect(aggregated[100]?.download == 30)
    #expect(aggregated[100]?.upload == 15)
}

@Test func processBundlePathFindsLongestMatchingBundle() {
    let bundle = ProcessBundlePath.bundlePath(
        containingExecutablePath: "/Applications/Example.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper",
        bundlePaths: [
            "/Applications/Example.app",
            "/Applications/Other.app"
        ]
    )
    #expect(bundle == "/Applications/Example.app")
}
