import AppKit
import MachKitCore
import SwiftUI

private struct StatusBarSnapshot {
    var cpuPercent = 0.0
    var usedMemory: Int64 = 0
    var physicalMemory: Int64 = 0
    var downloadBytesPerSecond = 0.0
    var uploadBytesPerSecond = 0.0
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
                    uploadBytesPerSecond: network.uploadBytesPerSecond
                )
                transferHistory.append(
                    TransferHistoryPoint(
                        download: network.downloadBytesPerSecond,
                        upload: network.uploadBytesPerSecond
                    )
                )
                if transferHistory.count > 30 {
                    transferHistory.removeFirst(transferHistory.count - 30)
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

    private static func formatRate(_ bytes: Double) -> String {
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(spacing: 10) {
                metricCard(
                    title: "CPU",
                    value: "\(Int(monitor.cpuPercent.rounded()))%",
                    progress: monitor.cpuPercent / 100,
                    symbol: "cpu",
                    color: .blue
                )
                metricCard(
                    title: "Memory".localized,
                    value: "\(Int(monitor.memoryPercent.rounded()))%",
                    detail: monitor.memoryValueText,
                    progress: monitor.memoryPercent / 100,
                    symbol: "memorychip",
                    color: .purple
                )
            }

            networkCard
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { monitor.setPresented(true) }
        .onDisappear { monitor.setPresented(false) }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Button(action: openMachKit) {
                HStack(spacing: 8) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                    Text("MachKit")
                        .font(.headline)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text("Live")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 14)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit")
            .accessibilityLabel(Text("Quit"))
        }
    }

    private func metricCard(
        title: String,
        value: String,
        detail: String? = nil,
        progress: Double,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            ProgressView(value: min(max(progress, 0), 1))
                .tint(color)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Network", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 12) {
                    transferValue(symbol: "arrow.down", value: monitor.downloadText, color: .cyan)
                    transferValue(symbol: "arrow.up", value: monitor.uploadText, color: .orange)
                }
            }

            TransferHistoryChart(points: monitor.transferHistory)
                .frame(height: 76)
        }
        .padding(11)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func transferValue(symbol: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    private func openMachKit() {
        MachKitAppLifecycle.showInForeground()
        openWindow(id: MachKitAppLifecycle.mainWindowSceneID)
        MachKitAppLifecycle.bringWindowToFront(titled: "MachKit")
    }
}

private struct TransferHistoryChart: View {
    let points: [TransferHistoryPoint]

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 2
            let chartSize = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
            let peak = max(points.flatMap { [$0.download, $0.upload] }.max() ?? 0, 1)

            for fraction in [0.25, 0.5, 0.75] {
                var grid = Path()
                let y = inset + chartSize.height * fraction
                grid.move(to: CGPoint(x: inset, y: y))
                grid.addLine(to: CGPoint(x: size.width - inset, y: y))
                context.stroke(grid, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
            }

            drawLine(\.download, color: .cyan, peak: peak, size: chartSize, inset: inset, context: &context)
            drawLine(\.upload, color: .orange, peak: peak, size: chartSize, inset: inset, context: &context)
        }
        .background(.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel("Network")
    }

    private func drawLine(
        _ value: KeyPath<TransferHistoryPoint, Double>,
        color: Color,
        peak: Double,
        size: CGSize,
        inset: CGFloat,
        context: inout GraphicsContext
    ) {
        guard points.count > 1 else { return }
        var path = Path()
        for (index, point) in points.enumerated() {
            let x = inset + size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
            let ratio = min(max(point[keyPath: value] / peak, 0), 1)
            let y = inset + size.height * (1 - ratio)
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
