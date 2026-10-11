import AppKit
import MachKitCore
import SwiftUI

extension ContentView {
    var homeView: some View {
        VStack(spacing: 0) {
            header(title: "Overview", subtitle: "Live status and everyday tools for this Mac")
                .padding(MachKitLayout.pageMargin)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MachKitLayout.sectionSpacing) {
                    homeStorageOverview
                    if !permissions.hasFullDiskAccess {
                        permissionCard
                    }

                    Text("Live Status").font(.system(size: 14, weight: .semibold))

                    homeMetrics
                    homeQuickAction

                    Text("Common Tools").font(.system(size: 14, weight: .semibold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        homeToolTile(
                            title: "Cleanup", subtitle: "Scan caches, logs, uninstall leftovers, and developer junk",
                            icon: "paintbrush.fill", color: .blue, mode: .junk
                        )
                        homeToolTile(
                            title: "Storage", subtitle: "Analyze disk categories, folder usage, large files, and free space",
                            icon: "chart.pie.fill", color: .indigo, mode: .files
                        )
                        homeToolTile(
                            title: "Apps", subtitle: "Uninstall apps, remove related files, and manage command-line tools",
                            icon: "app.badge.checkmark", color: .purple, mode: .uninstall
                        )
                        homeToolTile(
                            title: "Performance", subtitle: "Monitor CPU, memory pressure, thermal state, and resource-heavy apps",
                            icon: "gauge.with.dots.needle.67percent", color: .mint, mode: .performance
                        )
                        homeToolTile(
                            title: "Network", subtitle: L10n.string("Inspect live traffic, connections, ports, routes, and proxies"),
                            icon: "network", color: .orange, mode: .network
                        )
                        homeToolTile(
                            title: "Tools", subtitle: "Hosts, timestamps, JSON, codecs, and other developer utilities",
                            icon: "wrench.and.screwdriver.fill", color: .cyan, mode: .tools
                        )
                    }
                }
                .padding(.horizontal, MachKitLayout.pageMargin)
                .padding(.bottom, MachKitLayout.pageMargin)
            }
        }
    }

    var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 20))
                .foregroundStyle(permissions.hasFullDiskAccess ? .green : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text((permissions.hasFullDiskAccess ? "Full Disk Access granted" : "Full Disk Access Required").localized)
                    .font(.system(size: 13, weight: .semibold))
                Text((permissions.hasFullDiskAccess
                     ? "Allows protected user folders to be scanned. File contents are never uploaded."
                     : "Used to find app caches and leftovers. Enable it manually in System Settings.").localized)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !permissions.hasFullDiskAccess {
                Button("Open System Settings", action: permissions.openFullDiskAccessSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(MachKitLayout.bannerPadding)
        .background { RoundedRectangle(cornerRadius: 9).fill((permissions.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.08)) }
    }

    var homeStorageOverview: some View {
        let storage = model.systemStorage
        let color = homeStorageColor(storage.usedFraction)
        let percent = Int((storage.usedFraction * 100).rounded())
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: storage.totalCapacity > 0 ? max(0.015, storage.usedFraction) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(storage.totalCapacity > 0 ? L10n.percent(percent) : "—")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Used".localized).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: homeStorageIcon(storage.usedFraction))
                        .foregroundStyle(color)
                    Text(homeStorageTitle(storage).localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(homeStorageDescription(storage))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label(L10n.format("%@ Used", formatted(storage.usedCapacity)), systemImage: "internaldrive.fill")
                    Label(L10n.format("%@ Available", formatted(storage.availableCapacity)), systemImage: "checkmark.circle")
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            Button("View Storage", action: { model.changeMode(.files) })
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(MachKitLayout.heroPadding)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.13), lineWidth: 1)
        }
    }

    var homeMetrics: some View {
        let metrics = model.dashboardMetrics
        let transferRate = model.networkTransferRate
        let memoryColor = metrics.map { memoryPressureColor($0.memoryPressureLevel) } ?? .secondary
        let thermalColor = metrics.map { thermalStateColor($0.thermalState) } ?? .secondary
        return HStack(spacing: 10) {
            homeMetricCard(
                title: "CPU",
                value: metrics.map { L10n.percent($0.cpuPercent.rounded()) } ?? "—",
                detail: "System Usage",
                icon: "cpu",
                color: .blue
            )
            homeMetricCard(
                title: "Memory",
                value: metrics.map { L10n.percent(($0.memoryPressure * 100).rounded()) } ?? "—",
                detail: metrics.map { $0.memoryPressureLevel.rawValue } ?? "Loading",
                icon: "memorychip",
                color: memoryColor
            )
            homeNetworkMetricCard(transferRate)
            homeMetricCard(
                title: "Thermal",
                value: metrics.map { thermalStateShortText($0.thermalState) } ?? "—",
                detail: metrics == nil ? "Loading" : "Live",
                icon: "thermometer.medium",
                color: thermalColor
            )
        }
    }

    func homeMetricCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(detail.localized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 38, alignment: .leading)
            .layoutPriority(1)
            Spacer(minLength: 5)
            Text(verbatim: value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, MachKitLayout.bannerPadding)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func homeNetworkMetricCard(_ transferRate: NetworkTransferRate?) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cyan)
                .frame(width: 26, height: 26)
                .background(Color.cyan.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Network".localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text((transferRate == nil ? "Checking" : "Live").localized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 38, alignment: .leading)
            .layoutPriority(1)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                homeNetworkRate(
                    icon: "arrow.down",
                    value: transferRate.map { formatNetworkRate($0.downloadBytesPerSecond) } ?? "—",
                    color: .blue
                )
                homeNetworkRate(
                    icon: "arrow.up",
                    value: transferRate.map { formatNetworkRate($0.uploadBytesPerSecond) } ?? "—",
                    color: .mint
                )
            }
        }
        .padding(.horizontal, MachKitLayout.bannerPadding)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func homeNetworkRate(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    var homeQuickAction: some View {
        HStack(spacing: 13) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Quick Cleanup").font(.system(size: 13, weight: .semibold))
                Text(homeQuickActionDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: performQuickAction) {
                HStack(spacing: 6) {
                    if model.isCleanupScanning { ProgressView().controlSize(.small) }
                    Text(homeQuickActionButtonTitle.localized)
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.isCleanupScanning)
        }
        .padding(MachKitLayout.bannerPadding)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }

    var homeQuickActionDescription: String {
        if model.isCleanupScanning { return L10n.string("Looking for caches and logs that are safe to clean…") }
        guard let cleanableBytes = model.cleanableBytes else {
            return L10n.string("Scan caches, logs, and regenerable developer tool files")
        }
        if cleanableBytes == 0 { return L10n.string("The latest scan found nothing to clean") }
        return L10n.format("The latest scan found %@ of cleanable content", formatted(cleanableBytes))
    }

    var homeQuickActionButtonTitle: String {
        if model.isCleanupScanning { return "Scanning" }
        if model.selectedCount > 0 { return "Review Cleanup" }
        return model.cleanableBytes == nil ? "Start Scan" : "Scan Again"
    }

    func homeToolTile(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        mode: FeatureMode
    ) -> some View {
        Button { model.changeMode(mode) } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle.localized).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(MachKitLayout.bannerPadding).frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func homeStorageColor(_ fraction: Double) -> Color {
        if fraction >= 0.93 { return .red }
        if fraction >= 0.84 { return .orange }
        return .green
    }

    func homeStorageIcon(_ fraction: Double) -> String {
        if fraction >= 0.93 { return "exclamationmark.triangle.fill" }
        if fraction >= 0.84 { return "externaldrive.badge.exclamationmark" }
        return "checkmark.circle.fill"
    }

    func homeStorageTitle(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return "Reading storage status…" }
        if storage.usedFraction >= 0.93 { return "Your Mac is low on storage" }
        if storage.usedFraction >= 0.84 { return "Storage space is getting tight" }
        return "Mac storage looks good"
    }

    func homeStorageDescription(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return L10n.string("Reading system disk capacity") }
        return L10n.format(
            "%@ available of %@ total",
            formatted(storage.availableCapacity),
            formatted(storage.totalCapacity)
        )
    }

}

