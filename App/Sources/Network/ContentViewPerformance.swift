import AppKit
import Charts
import MachKitCore
import SwiftUI

extension ContentView {
    var performanceView: some View {
        VStack(spacing: 0) {
            header(
                title: "Performance",
                subtitle: "Monitor CPU, GPU, memory, disk, network, and top apps locally"
            )
            .padding(MachKitLayout.pageMargin)

            if let snapshot = model.performanceSnapshot {
                performanceContent(snapshot)
            } else {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("Collecting performance data…").font(.system(size: 14, weight: .semibold))
                    Text("The first CPU sample takes about 2 seconds").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func performanceContent(_ snapshot: PerformanceSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        cpuMetricCard(snapshot)
                        gpuMetricCard(snapshot)
                    }
                    VStack(spacing: 12) {
                        cpuMetricCard(snapshot)
                        gpuMetricCard(snapshot)
                    }
                }
                neuralEngineAndMemoryMetricCard(snapshot)
                systemActivityCard(snapshot)
                computeHardwareCard(snapshot.computeHardware)
                performanceTrendCard
                resourceApplicationList(snapshot)
                Text("Data updates locally every 2 seconds. GPU and Neural Engine metrics use SoCMetrics (IOReport) on Apple Silicon; per-GPU-core bars reflect chip-level active residency because macOS does not expose per-core utilization. Neural Engine percentage is estimated from power draw, not a system utilization counter. App CPU is shown as a share of total system capacity; network rates aggregate helper processes into their parent app. Sampling stops when you leave this page. App rankings include identifiable graphical app processes only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, MachKitLayout.pageMargin)
            .padding(.bottom, MachKitLayout.pageMargin)
        }
    }

    private func compactMetricProgressRow<Trailing: View>(
        title: String,
        icon: String,
        progress: Double?,
        tint: Color,
        valueText: String,
        detail: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let clamped = min(1, max(0, progress ?? 0))
        let barTint = clamped >= 0.85 ? Color.orange : tint
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                trailing()
                Spacer(minLength: 4)
                Text(valueText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(progress == nil ? .secondary : .primary)
            }
            if progress != nil {
                ProgressView(value: clamped, total: 1)
                    .tint(barTint)
            } else {
                ProgressView(value: 0, total: 1)
                    .tint(Color.secondary.opacity(0.25))
            }
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    func neuralEngineAndMemoryMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let memoryColor = memoryPressureColor(snapshot.memoryPressureLevel)
        let pressurePercent = snapshot.memoryPressure * 100
        let hasNE = snapshot.hasNeuralEngine
        let nePercent = snapshot.neuralEnginePercent
        return VStack(alignment: .leading, spacing: 12) {
            if hasNE {
                compactMetricProgressRow(
                    title: "Neural Engine",
                    icon: "brain.head.profile",
                    progress: nePercent.map { $0 / 100 },
                    tint: .purple,
                    valueText: nePercent.map { L10n.percent($0) } ?? "—",
                    detail: nePercent != nil
                        ? "\(L10n.string("Estimated")) · \(snapshot.neuralEnginePowerWatts.map { L10n.format("%.2f W", $0) } ?? "—")"
                        : "Neural Engine power counters are unavailable on this Mac."
                ) {
                    if nePercent != nil {
                        performanceStatusBadge("Live", color: .purple)
                    } else {
                        performanceStatusBadge("Unavailable", color: .secondary)
                    }
                }
            }

            compactMetricProgressRow(
                title: "Memory Usage",
                icon: "memorychip.fill",
                progress: snapshot.memoryPressure,
                tint: memoryColor,
                valueText: L10n.percent(pressurePercent),
                detail: "\(formatted(snapshot.usedMemory)) / \(formatted(snapshot.physicalMemory))"
            ) {
                Button { showingMemoryHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Understand macOS memory management")
                .popover(isPresented: $showingMemoryHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("What Does Smart Release Do?", systemImage: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("macOS handles hidden apps that are marked for automatic termination and currently unused, while MachKit returns reclaimable pages from its own heap.")
                            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Text("Regular foreground apps are not quit, processes are not force terminated, and administrator privileges are not required.")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(MachKitLayout.cardPadding)
                    .frame(width: 340, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                performanceStatusBadge(snapshot.memoryPressureLevel.rawValue, color: memoryColor)
            }

            HStack(spacing: 10) {
                Text("Cached \(formatted(snapshot.cachedMemory))")
                Text("Compressed \(formatted(snapshot.compressedMemory))")
                Text("Swap \(formatted(snapshot.swapUsed))")
                Spacer(minLength: 4)
                Button(action: model.optimizeMemory) {
                    if model.isOptimizingMemory {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("Smart Release", systemImage: "wand.and.sparkles")
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isOptimizingMemory)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(MachKitLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func performanceStatusBadge(_ text: String, color: Color) -> some View {
        Text(text.localized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, MachKitLayout.controlSpacing)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    func cpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("CPU", systemImage: "cpu.fill").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                Label(thermalStateText(snapshot.thermalState), systemImage: "thermometer.medium")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(height: 20, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(L10n.percent(snapshot.cpuPercent))
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Spacer(minLength: 0)
            }
            .frame(height: 38, alignment: .leading)

            if snapshot.cpuCores.isEmpty {
                ProgressView(value: snapshot.cpuPercent, total: 100)
                    .tint(snapshot.cpuPercent > 85 ? Color.orange : Color.accentColor)
                Text("Total System Usage")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                usageCoreBars(cpuCoreBarItems(snapshot.cpuCores))
                HStack(spacing: 10) {
                    Text("Per-core usage")
                    Spacer(minLength: 4)
                    ForEach(cpuClusterLegend(snapshot), id: \.self) { name in
                        Label(PerformanceMonitor.localizedClusterName(name), systemImage: "circle.fill")
                            .foregroundStyle(cpuClusterLegendColor(name))
                    }
                    if snapshot.cpuCores.contains(where: { $0.kind == .standard }) {
                        Label("Core", systemImage: "circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(L10n.format("User %@", percentText(snapshot.cpuUserPercent)))
                Text(L10n.format("System %@", percentText(snapshot.cpuSystemPercent)))
                Spacer(minLength: 0)
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(MachKitLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private struct CoreBarItem: Identifiable {
        let index: Int
        let percent: Double
        let label: String
        let color: Color
        let helpText: String
        var id: Int { index }
    }

    private func cpuCoreBarItems(_ cores: [CPUCoreUsage]) -> [CoreBarItem] {
        cores.map { core in
            CoreBarItem(
                index: core.index,
                percent: core.percent,
                label: coreBarLabel(core, compact: cores.count > 16),
                color: coreBarColor(core),
                helpText: L10n.format("Core %lld · %@", core.index + 1, L10n.percent(core.percent.rounded()))
            )
        }
    }

    private func usageCoreBars(_ bars: [CoreBarItem]) -> some View {
        GeometryReader { geometry in
            let spacing: CGFloat = bars.count > 12 ? 2 : 3
            let barWidth = max(
                4,
                (geometry.size.width - spacing * CGFloat(max(bars.count - 1, 0))) / CGFloat(max(bars.count, 1))
            )
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(bars) { bar in
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(bar.color.opacity(0.18))
                            .frame(width: barWidth, height: geometry.size.height - 14)
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(bar.color)
                                    .frame(
                                        width: barWidth,
                                        height: max(2, (geometry.size.height - 14) * bar.percent / 100)
                                    )
                            }
                        Text(bar.label)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: barWidth)
                    }
                    .help(bar.helpText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 78)
        .accessibilityElement(children: .contain)
    }

    func cpuCoreBars(_ cores: [CPUCoreUsage]) -> some View {
        usageCoreBars(cpuCoreBarItems(cores))
    }

    func coreBarColor(_ core: CPUCoreUsage) -> Color {
        let base = cpuClusterLegendColor(core.clusterName)
        return core.percent > 85 ? .orange : base
    }

    func cpuClusterLegend(_ snapshot: PerformanceSnapshot) -> [String] {
        if !snapshot.computeHardware.cpuClusters.isEmpty {
            return snapshot.computeHardware.cpuClusters
                .filter { cluster in snapshot.cpuCores.contains { $0.clusterName == cluster.name } }
                .map(\.name)
        }
        var seen = Set<String>()
        return snapshot.cpuCores.compactMap { core in
            guard seen.insert(core.clusterName).inserted else { return nil }
            return core.clusterName
        }
    }

    func cpuClusterLegendColor(_ clusterName: String) -> Color {
        switch clusterName.lowercased() {
        case "super":
            return .purple
        case "performance":
            return Color.accentColor
        case "efficiency":
            return .teal
        default:
            return Color.accentColor
        }
    }

    func coreBarLabel(_ core: CPUCoreUsage, compact: Bool) -> String {
        if compact { return "\(core.index + 1)" }
        return "\(coreBarPrefix(core.clusterName))\(core.clusterIndex + 1)"
    }

    func coreBarPrefix(_ clusterName: String) -> String {
        switch clusterName.lowercased() {
        case "super":
            return "S"
        case "performance":
            return "P"
        case "efficiency":
            return "E"
        default:
            return "C"
        }
    }

    func gpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let gpuLive = snapshot.gpuPercent != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("GPU", systemImage: "display").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                Text((gpuLive ? "Live" : "Unavailable").localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gpuLive ? Color.blue : Color.secondary)
            }
            .frame(height: 20, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.gpuPercent.map { L10n.percent($0) } ?? "—")
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Spacer(minLength: 0)
            }
            .frame(height: 38, alignment: .leading)

            if snapshot.gpuCores.isEmpty {
                if let gpuPercent = snapshot.gpuPercent {
                    ProgressView(value: gpuPercent, total: 100)
                        .tint(gpuPercent > 85 ? Color.orange : Color.blue)
                } else {
                    Text("The graphics driver does not expose live utilization on this Mac.")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } else {
                usageCoreBars(gpuCoreBarItems(snapshot.gpuCores))
            }
            HStack(spacing: 18) {
                compactMetric("Renderer", value: optionalPercentText(snapshot.gpuRendererPercent))
                compactMetric("Tiler", value: optionalPercentText(snapshot.gpuTilerPercent))
                if let frequency = snapshot.gpuFrequencyMHz {
                    compactMetric("Frequency", value: L10n.format("%lld MHz", Int64(frequency.rounded())))
                }
                compactMetric("GPU Memory", value: snapshot.gpuMemoryBytes > 0 ? formatted(snapshot.gpuMemoryBytes) : "—")
                Spacer(minLength: 0)
            }
        }
        .padding(MachKitLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func gpuCoreBarItems(_ cores: [GPUCoreUsage]) -> [CoreBarItem] {
        cores.map { core in
            CoreBarItem(
                index: core.index,
                percent: core.percent,
                label: "\(core.index + 1)",
                color: core.percent > 85 ? .orange : .blue,
                helpText: L10n.format("GPU core %lld · %@", core.index + 1, L10n.percent(core.percent.rounded()))
            )
        }
    }

    func systemActivityCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("System Activity", systemImage: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 18) {
                activityGroup(
                    title: "Disk I/O",
                    icon: "internaldrive",
                    firstLabel: "Read",
                    firstValue: formatNetworkRate(snapshot.diskReadBytesPerSecond),
                    secondLabel: "Write",
                    secondValue: formatNetworkRate(snapshot.diskWriteBytesPerSecond),
                    color: .orange
                )
                activityGroup(
                    title: "Network",
                    icon: "network",
                    firstLabel: "Down",
                    firstValue: formatNetworkRate(snapshot.networkDownloadBytesPerSecond),
                    secondLabel: "Up",
                    secondValue: formatNetworkRate(snapshot.networkUploadBytesPerSecond),
                    color: .green
                )
            }
            Divider()
            HStack(spacing: 18) {
                compactMetric("Load Average", value: loadAverageText(snapshot.loadAverages))
                compactMetric("Processes", value: snapshot.processCount.formatted())
                compactMetric("Uptime", value: uptimeText(snapshot.systemUptime))
                Spacer(minLength: 0)
            }
        }
        .padding(MachKitLayout.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func activityGroup(
        title: String,
        icon: String,
        firstLabel: String,
        firstValue: String,
        secondLabel: String,
        secondValue: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title.localized, systemImage: icon).foregroundStyle(color)
                .font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                Text(firstLabel.localized).foregroundStyle(.secondary)
                Text(firstValue).monospacedDigit()
            }
            HStack(spacing: 6) {
                Text(secondLabel.localized).foregroundStyle(.secondary)
                Text(secondValue).monospacedDigit()
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func compactMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.localized).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1)
        }
    }

    func percentText(_ value: Double) -> String {
        L10n.percent(value)
    }

    func optionalPercentText(_ value: Double?) -> String {
        value.map(percentText) ?? "—"
    }

    func loadAverageText(_ values: [Double]) -> String {
        guard !values.isEmpty else { return "—" }
        return values.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " / ")
    }

    func uptimeText(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = totalMinutes / 60 % 24
        let minutes = totalMinutes % 60
        if days > 0 { return L10n.format("%lldd %lldh", days, hours) }
        if hours > 0 { return L10n.format("%lldh %lldm", hours, minutes) }
        return L10n.format("%lldm", minutes)
    }

    func computeHardwareCard(_ hardware: ComputeHardwareInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compute Hardware")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).padding(.top, MachKitLayout.bannerPadding).padding(.bottom, MachKitLayout.controlSpacing)
            computeHardwareRow(
                icon: "cpu",
                title: "CPU",
                subtitle: L10n.format("%@ · %@", hardware.cpuName, cpuCoreSummary(hardware)),
                status: hardware.hasUnifiedMemory
                    ? "Apple Silicon"
                    : L10n.format("%lld threads", hardware.logicalCores),
                color: .orange
            )
            Divider().padding(.leading, 57)
            computeHardwareRow(
                icon: "display",
                title: "GPU",
                subtitle: hardware.recommendedGPUWorkingSet > 0
                    ? L10n.format("%@ · Recommended working set %@", hardware.gpuName, formatted(hardware.recommendedGPUWorkingSet))
                    : hardware.gpuName,
                status: hardware.hasUnifiedMemory ? "Unified Memory" : "Dedicated Memory",
                color: .blue
            )
            Divider().padding(.leading, 57)
            computeHardwareRow(
                icon: "sparkles",
                title: "Apple Intelligence",
                subtitle: hardware.appleIntelligence.detail,
                status: hardware.appleIntelligence.rawValue,
                color: hardware.appleIntelligence.isUsable ? .green : .purple
            )
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func cpuCoreSummary(_ hardware: ComputeHardwareInfo) -> String {
        if hardware.cpuClusters.count > 1 {
            let parts = hardware.cpuClusters.map {
                L10n.format(
                    "%lld %@",
                    Int64($0.physicalCores),
                    PerformanceMonitor.localizedClusterName($0.name)
                )
            }
            return L10n.format(
                "%lld cores (%@)",
                hardware.physicalCores,
                parts.joined(separator: " + ")
            )
        }
        if hardware.performanceCores > 0, hardware.efficiencyCores > 0 {
            return L10n.format(
                "%lld cores (%lldP + %lldE)",
                hardware.physicalCores,
                hardware.performanceCores,
                hardware.efficiencyCores
            )
        }
        if hardware.logicalCores > hardware.physicalCores {
            return L10n.format(
                "%lld cores · %lld threads",
                hardware.physicalCores,
                hardware.logicalCores
            )
        }
        return L10n.format("%lld cores", hardware.physicalCores)
    }

    func computeHardwareRow(icon: String, title: String, subtitle: String, status: String, color: Color) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.12))
                Image(systemName: icon).foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(subtitle.localized).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(status.localized)
                .font(.caption.weight(.semibold)).foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 55)
    }

    var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 60 Seconds").font(.system(size: 14, weight: .semibold))
                Spacer()
                Label("CPU", systemImage: "circle.fill").foregroundStyle(Color.orange)
                Label("GPU", systemImage: "circle.fill").foregroundStyle(Color.blue)
                Label("Memory Usage", systemImage: "circle.fill").foregroundStyle(Color.purple)
            }
            .font(.caption)
            Chart(model.performanceHistory) { point in
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Color.orange)
                .interpolationMethod(.catmullRom)
                if let gpuPercent = point.gpuPercent {
                    LineMark(
                        x: .value("Time", point.sampledAt),
                        y: .value("GPU", gpuPercent),
                        series: .value("Metric", "GPU")
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                }
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("Memory Usage", point.memoryPressurePercent),
                    series: .value("Metric", "Memory Usage")
                )
                .foregroundStyle(Color.purple)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel { if let number = value.as(Int.self) { Text(L10n.percent(number)) } }
                }
            }
            .frame(height: 138)
        }
        .padding(MachKitLayout.cardPadding)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func resourceApplicationList(_ snapshot: PerformanceSnapshot) -> some View {
        let applications = snapshot.applications.sorted { lhs, rhs in
            switch performanceSort {
            case .cpu:
                lhs.cpuPercentOfSystem > rhs.cpuPercentOfSystem
            case .memory:
                lhs.memoryBytes > rhs.memoryBytes
            case .network:
                lhs.networkBytesPerSecond > rhs.networkBytesPerSecond
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Resource-Using Apps").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Sort", selection: $performanceSort) {
                    ForEach(PerformanceSort.allCases) { sort in Text(sort.rawValue.localized).tag(sort) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Sort")
                .frame(width: 220)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Apps").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 70, alignment: .trailing)
                    Text("Memory").frame(width: 92, alignment: .trailing)
                    Text("Network").frame(width: 88, alignment: .trailing)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(height: 32)
                Divider()
                ForEach(Array(applications.prefix(12).enumerated()), id: \.element.id) { index, application in
                    resourceApplicationRow(application)
                    if index < min(applications.count, 12) - 1 { Divider().padding(.leading, 48) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    func resourceApplicationRow(_ application: ApplicationResourceUsage) -> some View {
        HStack(spacing: 10) {
            Group {
                if let url = application.bundleURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    Image(systemName: "app.fill").resizable().scaledToFit().padding(5).foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(application.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("PID \(application.processIdentifier)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.percent(application.cpuPercentOfSystem, fractionDigits: 1))
                .font(.system(size: 12)).monospacedDigit().frame(width: 70, alignment: .trailing)
                .help(L10n.string("Share of total CPU capacity across all cores."))
            Text(formatted(application.memoryBytes))
                .font(.system(size: 12)).monospacedDigit().frame(width: 92, alignment: .trailing)
            Text(formatNetworkRate(application.networkBytesPerSecond))
                .font(.system(size: 12)).monospacedDigit().frame(width: 88, alignment: .trailing)
                .foregroundStyle(application.networkBytesPerSecond > 0 ? Color.blue : .secondary)
        }
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 48)
        .contextMenu {
            if let url = application.bundleURL { Button("Show in Finder") { reveal(url) } }
        }
    }

    func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: .green
        case .elevated: .orange
        case .critical: .red
        }
    }

    func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Thermal State Normal")
        case .fair: L10n.string("Thermal State Elevated")
        case .serious: L10n.string("Thermal State High")
        case .critical: L10n.string("Thermal State Critical")
        @unknown default: L10n.string("Thermal State Unknown")
        }
    }

    func thermalStateShortText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Normal")
        case .fair: L10n.string("Elevated")
        case .serious: L10n.string("High")
        case .critical: L10n.string("Critical")
        @unknown default: L10n.string("Unknown")
        }
    }

    func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair, .serious: .orange
        case .critical: .red
        @unknown default: .secondary
        }
    }
}

