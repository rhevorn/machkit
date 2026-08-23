import AppKit
import MachKitCore
import SwiftUI

private struct StatusBarSnapshot {
    var cpuPercent = 0.0
    var usedMemory: Int64 = 0
    var physicalMemory: Int64 = 0
    var memoryPressure = 0.0
    var memoryPressureLevel: MemoryPressureLevel = .normal
    var thermalState = ProcessInfo.ThermalState.nominal
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

    var compactMemoryDetailText: String {
        let used = memoryValueText
        let total = memoryTotalText
        let usedParts = used.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let totalParts = total.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if usedParts.count == 2, totalParts.count == 2, usedParts[1] == totalParts[1] {
            return "\(usedParts[0])/\(totalParts[0]) \(usedParts[1])"
        }
        return "\(used)/\(total)"
    }

    var memoryPressurePercent: Double { snapshot.memoryPressure * 100 }

    var memoryPressureLevel: MemoryPressureLevel { snapshot.memoryPressureLevel }

    var thermalState: ProcessInfo.ThermalState { snapshot.thermalState }

    var networkInterfaceName: String? { snapshot.networkInterfaceName }

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
                async let performanceSample = systemMonitor.sampleSystemSummary()
                async let dashboardSample = systemMonitor.sampleDashboardMetrics()
                async let networkSample = systemMonitor.sampleTransferRate()
                let performance = await performanceSample
                let dashboard = await dashboardSample
                let network = await networkSample
                guard !Task.isCancelled else { return }
                snapshot = StatusBarSnapshot(
                    cpuPercent: performance.cpuPercent,
                    usedMemory: performance.usedMemory,
                    physicalMemory: performance.physicalMemory,
                    memoryPressure: dashboard.memoryPressure,
                    memoryPressureLevel: dashboard.memoryPressureLevel,
                    thermalState: dashboard.thermalState,
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
    @StateObject private var systemColorScheme = SystemColorSchemeObserver()
    @State private var livePulse = false

    private let panelWidth: CGFloat = 352

    private var colorScheme: ColorScheme { systemColorScheme.colorScheme }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider()

            VStack(spacing: 8) {
                metricsGrid
                networkSection
            }
            .padding(10)

            Divider()

            actionBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: panelWidth)
        .preferredColorScheme(systemColorScheme.colorScheme)
        .background {
            MenuBarPopoverBackground(colorScheme: systemColorScheme.colorScheme)
        }
        .background(MenuBarPopoverWindowConfigurator(colorScheme: systemColorScheme.colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            monitor.setPresented(true)
            livePulse = true
        }
        .onDisappear { monitor.setPresented(false) }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(StatusBarChrome.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(StatusBarChrome.cardStroke, lineWidth: 0.5)
            }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: openMachKit) {
                HStack(spacing: 7) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("MachKit")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                    .opacity(livePulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: livePulse)
                Text("Live")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit")
            .accessibilityLabel(Text("Quit"))
        }
    }

    private var metricsGrid: some View {
        HStack(spacing: 5) {
            StatusBarCompactMetric(
                title: "CPU",
                value: "\(Int(monitor.cpuPercent.rounded()))%",
                detail: cpuFootnote(for: monitor.cpuPercent),
                progress: monitor.cpuPercent / 100,
                icon: "cpu",
                tint: cpuTint(for: monitor.cpuPercent)
            )
            StatusBarCompactMetric(
                title: "Memory",
                value: "\(Int(monitor.memoryPressurePercent.rounded()))%",
                detail: monitor.compactMemoryDetailText,
                progress: monitor.memoryPressurePercent / 100,
                icon: "memorychip",
                tint: memoryTint(for: monitor.memoryPressurePercent)
            )
            StatusBarCompactMetric(
                title: "Thermal",
                value: thermalShortText(monitor.thermalState),
                detail: L10n.string("Live"),
                progress: nil,
                icon: "thermometer.medium",
                tint: thermalTint(monitor.thermalState)
            )
        }
    }

    private var networkInterfaceDetail: String {
        if let interface = monitor.networkInterfaceName {
            return interface
        }
        return L10n.string("Network")
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(networkInterfaceDetail)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 10) {
                    networkRateLabel(icon: "arrow.down", color: StatusBarChrome.downloadAccent(for: colorScheme), value: monitor.downloadText)
                    networkRateLabel(icon: "arrow.up", color: StatusBarChrome.uploadAccent(for: colorScheme), value: monitor.uploadText)
                }
            }
            TransferHistoryChart(points: monitor.transferHistory, colorScheme: colorScheme)
                .frame(height: 56)
        }
        .padding(8)
        .background(cardBackground)
    }

    private func networkRateLabel(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 6) {
            Button(action: openMachKit) {
                Label("Open MachKit", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button(action: openPerformance) {
                Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func cpuTint(for percent: Double) -> Color {
        percent >= 85 ? .orange : .blue
    }

    private func memoryTint(for percent: Double) -> Color {
        percent >= 90 ? .red : (percent >= 75 ? .orange : .purple)
    }

    private func thermalTint(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair, .serious: .orange
        case .critical: .red
        @unknown default: .secondary
        }
    }

    private func thermalShortText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Normal")
        case .fair: L10n.string("Elevated")
        case .serious: L10n.string("High")
        case .critical: L10n.string("Critical")
        @unknown default: L10n.string("Unknown")
        }
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

private struct StatusBarCompactMetric: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double?
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title.localized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let progress {
                MetricProgressBar(progress: progress, tint: tint)
            }
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StatusBarChrome.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StatusBarChrome.cardStroke, lineWidth: 0.5)
                }
        }
    }
}

private struct MetricProgressBar: View {
    let progress: Double
    let tint: Color

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.08))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * clamped, clamped > 0 ? 2 : 0))
                }
            }
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }
}

private struct TransferHistoryChart: View {
    let points: [TransferHistoryPoint]
    let colorScheme: ColorScheme

    private var downloadStroke: Color { StatusBarChrome.downloadAccent(for: colorScheme) }
    private var uploadStroke: Color { StatusBarChrome.uploadAccent(for: colorScheme) }
    private var downloadFill: Color { downloadStroke.opacity(colorScheme == .dark ? 0.28 : 0.18) }
    private var uploadFill: Color { uploadStroke.opacity(colorScheme == .dark ? 0.24 : 0.14) }
    private var gridOpacity: Double { colorScheme == .dark ? 0.16 : 0.1 }
    private var chartInsetFill: Color { Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04) }

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
                    context.stroke(grid, with: .color(.secondary.opacity(gridOpacity)), lineWidth: 1)
                }

                if points.count > 1 {
                    drawSeries(
                        value: \.download,
                        stroke: downloadStroke,
                        fill: downloadFill,
                        peak: peak,
                        rect: chartRect,
                        context: &context
                    )
                    drawSeries(
                        value: \.upload,
                        stroke: uploadStroke,
                        fill: uploadFill,
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
            .background(chartInsetFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("Network")
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

private enum StatusBarChrome {
    static var cardFill: Color {
        Color(nsColor: .quaternarySystemFill)
    }

    static var cardStroke: Color {
        Color(nsColor: .separatorColor).opacity(0.35)
    }

    static func downloadAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.35, green: 0.82, blue: 0.98) : .cyan
    }

    static func uploadAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.72, blue: 0.35) : .orange
    }
}

private struct MenuBarPopoverBackground: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        applyStyle(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        applyStyle(to: nsView)
    }

    private func applyStyle(to view: NSVisualEffectView) {
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        view.needsDisplay = true
    }
}

private struct MenuBarPopoverWindowConfigurator: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
    }

    private func configureWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.appearance = nil
            window.contentView?.needsDisplay = true
        }
    }
}

@MainActor
private final class SystemColorSchemeObserver: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme

    private var appearanceObservation: NSKeyValueObservation?

    init() {
        colorScheme = Self.resolveColorScheme()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let next = Self.resolveColorScheme()
        guard next != colorScheme else { return }
        colorScheme = next
    }

    private static func resolveColorScheme() -> ColorScheme {
        let style = CFPreferencesCopyAppValue(
            "AppleInterfaceStyle" as CFString,
            kCFPreferencesAnyApplication
        ) as? String
        return style == "Dark" ? .dark : .light
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
