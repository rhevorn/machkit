import AppKit
import MachKitCore
import SwiftUI

private struct StatusBarSnapshot {
    var cpuPercent = 0.0
    var usedMemory: Int64 = 0
    var physicalMemory: Int64 = 0
    var downloadBytesPerSecond = 0.0
    var uploadBytesPerSecond = 0.0
    var networkInterfaceName: String?
}

fileprivate struct TransferHistoryPoint: Identifiable {
    let id = UUID()
    let download: Double
    let upload: Double
}

@MainActor
final class StatusBarMonitor: ObservableObject {
    @Published private var snapshot = StatusBarSnapshot()
    @Published fileprivate private(set) var transferHistory: [TransferHistoryPoint] = []

    private let systemMonitor: SystemMonitorService
    private var monitoringTask: Task<Void, Never>?
    private var isEnabled = false
    private var isPresented = false

    init(systemMonitor: SystemMonitorService = .shared) {
        self.systemMonitor = systemMonitor
    }

    var cpuPercent: Double { snapshot.cpuPercent }

    var memoryPercent: Double {
        guard snapshot.physicalMemory > 0 else { return 0 }
        return Double(snapshot.usedMemory) / Double(snapshot.physicalMemory) * 100
    }

    var memoryValueText: String {
        ByteCountFormatter.string(fromByteCount: snapshot.usedMemory, countStyle: .memory)
    }

    var memoryTotalText: String {
        ByteCountFormatter.string(fromByteCount: snapshot.physicalMemory, countStyle: .memory)
    }

    var networkInterfaceName: String? { snapshot.networkInterfaceName }

    var totalNetworkBytesPerSecond: Double {
        snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
    }

    var downloadText: String { Self.formatRate(snapshot.downloadBytesPerSecond) }
    var uploadText: String { Self.formatRate(snapshot.uploadBytesPerSecond) }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        updateMonitoringState()
    }

    func setPresented(_ presented: Bool) {
        isPresented = presented
        updateMonitoringState()
    }

    private func updateMonitoringState() {
        isEnabled && isPresented ? start() : stop()
    }

    private func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let performance = await systemMonitor.sampleSystemSummary()
                let network = await systemMonitor.sampleTransferRate()
                guard !Task.isCancelled else { return }
                snapshot = StatusBarSnapshot(
                    cpuPercent: performance.cpuPercent,
                    usedMemory: performance.usedMemory,
                    physicalMemory: performance.physicalMemory,
                    downloadBytesPerSecond: network.downloadBytesPerSecond,
                    uploadBytesPerSecond: network.uploadBytesPerSecond,
                    networkInterfaceName: network.interfaceName
                )
                transferHistory.append(
                    TransferHistoryPoint(
                        download: network.downloadBytesPerSecond,
                        upload: network.uploadBytesPerSecond
                    )
                )
                if transferHistory.count > 36 {
                    transferHistory.removeFirst(transferHistory.count - 36)
                }
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
            }
        }
    }

    private func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    fileprivate static func formatRate(_ bytes: Double) -> String {
        let value = max(0, bytes)
        if value < 1_000 { return "\(Int(value.rounded())) B/s" }
        if value < 1_000_000 { return "\(formatNumber(value / 1_000)) KB/s" }
        if value < 1_000_000_000 { return "\(formatNumber(value / 1_000_000)) MB/s" }
        return "\(formatNumber(value / 1_000_000_000)) GB/s"
    }

    private static func formatNumber(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }
}

struct StatusBarMenuView: View {
    @ObservedObject var monitor: StatusBarMonitor
    var model: CleanerViewModel?
    @Environment(\.openWindow) private var openWindow
    @State private var livePulse = false

    private let panelWidth: CGFloat = 372

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider().opacity(0.45)

            metricsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            networkSection
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Divider().opacity(0.45)

            actionBar
                .padding(14)
        }
        .frame(width: panelWidth)
        .background(statusBarBackground)
        .onAppear {
            monitor.setPresented(true)
            livePulse = true
        }
        .onDisappear { monitor.setPresented(false) }
    }

    private var statusBarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.07),
                    Color.clear,
                    Color.purple.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: openMachKit) {
                HStack(spacing: 10) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MachKit")
                            .font(.system(size: 15, weight: .semibold))
                        Text("System Usage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.22))
                        .frame(width: 14, height: 14)
                        .scaleEffect(livePulse ? 1.35 : 0.85)
                        .opacity(livePulse ? 0 : 0.9)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: livePulse)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
                Text("Live")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit")
            .accessibilityLabel(Text("Quit"))
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            StatusBarRingMetric(
                title: "CPU",
                value: "\(Int(monitor.cpuPercent.rounded()))%",
                progress: monitor.cpuPercent / 100,
                tint: cpuTint(for: monitor.cpuPercent),
                footnote: cpuFootnote(for: monitor.cpuPercent)
            )
            StatusBarRingMetric(
                title: "Memory",
                value: "\(Int(monitor.memoryPercent.rounded()))%",
                progress: monitor.memoryPercent / 100,
                tint: memoryTint(for: monitor.memoryPercent),
                footnote: "\(monitor.memoryValueText) / \(monitor.memoryTotalText)"
            )
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Network", systemImage: "network")
                    .font(.system(size: 13, weight: .semibold))
                if let interface = monitor.networkInterfaceName {
                    Text(interface)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
                Spacer(minLength: 4)
            }

            HStack(spacing: 8) {
                networkRateTile(
                    title: "Download",
                    symbol: "arrow.down",
                    value: monitor.downloadText,
                    tint: .cyan
                )
                networkRateTile(
                    title: "Upload",
                    symbol: "arrow.up",
                    value: monitor.uploadText,
                    tint: .orange
                )
            }

            TransferHistoryChart(points: monitor.transferHistory)
                .frame(height: 88)
        }
        .padding(12)
        .background(cardBackground)
    }

    private func networkRateTile(title: String, symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button(action: openMachKit) {
                Label("Open MachKit", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button(action: openPerformance) {
                Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    private func cpuTint(for percent: Double) -> Color {
        percent >= 85 ? .orange : .blue
    }

    private func memoryTint(for percent: Double) -> Color {
        percent >= 90 ? .red : (percent >= 75 ? .orange : .purple)
    }

    private func cpuFootnote(for percent: Double) -> String {
        switch percent {
        case 85...: L10n.string("High load")
        case 50..<85: L10n.string("Moderate load")
        default: L10n.string("Light load")
        }
    }

    private func openMachKit() {
        MachKitAppLifecycle.showInForeground()
        openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
        MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
    }

    private func openPerformance() {
        model?.changeMode(.performance)
        openMachKit()
    }
}

private struct StatusBarRingMetric: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color
    let footnote: String?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.14), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.55), tint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.35), value: progress)
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 78, height: 78)

            Text(title.localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

private struct TransferHistoryChart: View {
    let points: [TransferHistoryPoint]

    var body: some View {
        Canvas { context, size in
                let inset: CGFloat = 4
                let chartRect = CGRect(
                    x: inset,
                    y: inset,
                    width: size.width - inset * 2,
                    height: size.height - inset * 2
                )
                let peak = max(points.flatMap { [$0.download, $0.upload] }.max() ?? 0, 1)

                for fraction in [0.25, 0.5, 0.75] {
                    var grid = Path()
                    let y = chartRect.minY + chartRect.height * fraction
                    grid.move(to: CGPoint(x: chartRect.minX, y: y))
                    grid.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                    context.stroke(grid, with: .color(.secondary.opacity(0.1)), lineWidth: 1)
                }

                if points.count > 1 {
                    drawSeries(
                        value: \.download,
                        stroke: .cyan,
                        fill: Color.cyan.opacity(0.18),
                        peak: peak,
                        rect: chartRect,
                        context: &context
                    )
                    drawSeries(
                        value: \.upload,
                        stroke: .orange,
                        fill: Color.orange.opacity(0.14),
                        peak: peak,
                        rect: chartRect,
                        context: &context
                    )
                } else {
                    var placeholder = Path()
                    let midY = chartRect.midY
                    placeholder.move(to: CGPoint(x: chartRect.minX, y: midY))
                    placeholder.addLine(to: CGPoint(x: chartRect.maxX, y: midY))
                    context.stroke(
                        placeholder,
                        with: .color(.secondary.opacity(0.2)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }
            }
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    chartLegend(color: .cyan, label: "Download")
                    chartLegend(color: .orange, label: "Upload")
                }
                .padding(6)
        }
        .accessibilityLabel("Network")
    }

    private func chartLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label.localized)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func drawSeries(
        value: KeyPath<TransferHistoryPoint, Double>,
        stroke: Color,
        fill: Color,
        peak: Double,
        rect: CGRect,
        context: inout GraphicsContext
    ) {
        var line = Path()
        var area = Path()
        for (index, point) in points.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
            let ratio = min(max(point[keyPath: value] / peak, 0), 1)
            let y = rect.maxY - rect.height * ratio
            let location = CGPoint(x: x, y: y)
            if index == 0 {
                line.move(to: location)
                area.move(to: CGPoint(x: x, y: rect.maxY))
                area.addLine(to: location)
            } else {
                line.addLine(to: location)
                area.addLine(to: location)
            }
        }
        if let lastX = points.indices.last.map({ rect.minX + rect.width * CGFloat($0) / CGFloat(max(points.count - 1, 1)) }) {
            area.addLine(to: CGPoint(x: lastX, y: rect.maxY))
            area.closeSubpath()
            context.fill(area, with: .color(fill))
        }
        context.stroke(
            line,
            with: .color(stroke),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }
}

struct MachKitCommands: Commands {
    let model: CleanerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                model.changeMode(.settings)
                MachKitAppLifecycle.showInForeground()
                openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
                MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
