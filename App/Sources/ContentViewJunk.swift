import AppKit
import Charts
import MachKitCore
import SwiftUI

extension ContentView {
    var junkView: some View {
        VStack(spacing: 0) {
            header(
                title: "Cleanup",
                subtitle: "Caches, logs, installers, and developer junk",
                trailing: AnyView(
                    Group {
                        if !model.isCleanupScanning, !model.items.isEmpty {
                            Button("Back to Cleanup Home".localized, action: returnToJunkHome)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                )
            )
            .padding(MachKitLayout.pageMargin)

            Group {
                if model.isCleanupScanning {
                    junkScanningView
                } else if model.items.isEmpty {
                    junkEmptyView
                } else {
                    VStack(spacing: 0) {
                        junkDetailList
                        Divider()
                        junkActionBar
                    }
                }
            }
        }
    }

    func focusJunkGroup(_ groupID: String) {
        expandedGroups.insert(groupID)
        junkScrollTarget = groupID
    }

    var junkSelectionControls: some View {
        HStack(spacing: 6) {
            Button("Select All", action: model.selectAllJunkItems)
                .disabled(model.items.isEmpty || model.selectedCount == model.items.count)
            Button("Deselect All", action: model.deselectAllJunkItems)
                .disabled(model.selectedIDs.isEmpty)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .controlSize(.small)
    }

    var junkActionBar: some View {
        let selectionFraction = model.totalBytes > 0
            ? min(1, Double(model.selectedBytes) / Double(model.totalBytes))
            : 0

        return VStack(spacing: 10) {
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(4, geometry.size.width * selectionFraction))
                    }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.22), value: model.selectedBytes)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format("%lld items selected", Int64(model.selectedCount)))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.format("%@ of %@", formatted(model.selectedBytes), formatted(model.totalBytes)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                junkSelectionControls
                Spacer(minLength: 8)
                Button("Scan Again", action: scanJunk)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.isCleaning)
                Button(action: model.requestClean) {
                    if model.isCleaning {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text(cleaningProgressTitle)
                        }
                    } else {
                        Label("Clean Selected", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(model.selectedIDs.isEmpty || model.isCleaning)
            }
        }
        .padding(.horizontal, MachKitLayout.pageMargin)
        .padding(.vertical, MachKitLayout.bannerPadding)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var cleaningProgressTitle: String {
        if model.cleaningTotalCount > 0 {
            return L10n.format(
                "Cleaning %lld of %lld…",
                Int64(model.cleaningProcessedCount),
                Int64(model.cleaningTotalCount)
            )
        }
        return L10n.string("Cleaning…")
    }

    var junkPermissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18))
                .foregroundStyle(Color.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Full Disk Access Required".localized)
                    .font(.system(size: 12, weight: .semibold))
                Text("Some caches may be missed without Full Disk Access. Enable it in System Settings for more complete results.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Open System Settings".localized, action: permissions.openFullDiskAccessSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(MachKitLayout.bannerPadding)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    var junkFreedBanner: some View {
        Group {
            if let freed = model.lastCleanupFreedBytes, freed > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.format("Released %@ of disk space", formatted(freed)))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .padding(MachKitLayout.bannerPadding)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var junkEmptyView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                junkFreedBanner
                if !permissions.hasFullDiskAccess {
                    junkPermissionBanner
                }
                junkEmptyHeroCard

                Text("What We Scan".localized).font(.system(size: 14, weight: .semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(junkScanPreviews) { preview in
                        junkScanPreviewTile(preview)
                    }
                }

                junkSafetyBanner

                Button(action: scanJunk) {
                    Label("Start Scan".localized, systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, MachKitLayout.pageMargin)
            .padding(.bottom, MachKitLayout.pageMargin)
        }
    }

    var junkEmptyHeroCard: some View {
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
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Give your Mac a light cleanup".localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                if let cleanable = model.cleanableBytes, cleanable > 0 {
                    Text(L10n.format(
                        "A previous scan found %@ of cleanable content. Run again to refresh results.",
                        formatted(cleanable)
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Scan caches, logs, installers, and developer leftovers. Review each group before cleaning.".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 14) {
                    Label(L10n.format("%@ Available", formatted(storage.availableCapacity)), systemImage: "internaldrive.fill")
                    Label("Local Scan".localized, systemImage: "lock.shield")
                    if let lastScan = model.lastJunkScanText {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(L10n.format("Last scanned %@", lastScan))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(MachKitLayout.heroPadding)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        }
    }

    var junkScanPreviews: [JunkScanPreview] {
        [
            .init(id: "trash", title: "Trash", icon: "trash", detail: "Items already in Trash", color: .red),
            .init(id: "app-caches", title: "App Caches", icon: "internaldrive", detail: "Browser, editor, and communication caches", color: .blue),
            .init(id: "developer-cleanup", title: "Developer Cleanup", icon: "hammer", detail: "Homebrew, Xcode, simulators, and project output", color: .green),
            .init(id: "logs-diagnostics", title: "Logs & Diagnostics", icon: "doc.text.magnifyingglass", detail: "Old user and Application Support logs", color: .brown),
            .init(id: "downloads-devices", title: "Downloads & Devices", icon: "tray.and.arrow.down", detail: "Installers, attachments, backups, and firmware", color: .cyan),
            .init(id: "leftovers", title: "App Leftovers", icon: "app.fill", detail: "Containers, support files, and LaunchAgents", color: .yellow),
            .init(id: "time-machine", title: "Time Machine", icon: "clock.arrow.circlepath", detail: "Failed backups and local snapshots", color: .orange),
            .init(id: "system-cleanup", title: "System Cleanup", icon: "lock.shield", detail: "Administrator-reviewed system caches", color: .purple),
        ]
    }

    func junkScanPreviewTile(_ preview: JunkScanPreview) -> some View {
        HStack(spacing: 11) {
            Image(systemName: preview.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(preview.color)
                .frame(width: 34, height: 34)
                .background(preview.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.title.localized)
                    .font(.system(size: 13, weight: .semibold))
                Text(preview.detail.localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(MachKitLayout.bannerPadding)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    var junkSafetyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Review before cleaning".localized).font(.system(size: 12, weight: .semibold))
                Text("MachKit reads file metadata locally. Ordinary files move to Trash; snapshots are permanently deleted only after review.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(MachKitLayout.bannerPadding)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    func scanPromise(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    var junkScanningView: some View {
        let phases = model.visibleCleanupScanPhases
        let progress = max(0, min(1, model.scanProgress))
        let percent = Int((progress * 100).rounded())

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: max(0.02, progress))
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(L10n.percent(percent))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("Scanning".localized).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.currentScanCategory.isEmpty
                             ? L10n.string("Scanning for cleanable files…")
                             : model.currentScanCategory)
                            .font(.system(size: 17, weight: .semibold))
                            .contentTransition(.opacity)
                        Text("Reads file metadata only; contents are never read or uploaded".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            junkScanInlineStat(
                                title: "Found",
                                value: formatted(model.discoveredBytes),
                                icon: "sparkles",
                                color: .blue
                            )
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            junkScanInlineStat(
                                title: "Locations",
                                value: "\(model.discoveredFileCount)",
                                icon: "folder",
                                color: .mint
                            )
                        }
                        Button("Cancel Scan".localized, role: .cancel, action: model.cancelScan)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }
                .padding(MachKitLayout.heroPadding)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.10), Color(nsColor: .controlBackgroundColor)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                }

                Text("Scan Progress".localized).font(.system(size: 14, weight: .semibold))
                ScrollViewReader { proxy in
                    junkScanPhaseTimeline(phases: phases)
                        .onChange(of: model.activeCleanupPhaseID) { _, phaseID in
                            guard let phaseID else { return }
                            // Instant jump — animated scroll thrashing during a fast
                            // re-scan (warm filesystem cache) makes the timeline flicker.
                            proxy.scrollTo(phaseID, anchor: .center)
                        }
                }
            }
            .padding(.horizontal, MachKitLayout.pageMargin)
            .padding(.bottom, MachKitLayout.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Animate only discrete category changes — never the high-frequency scanProgress
        // stream, or the whole panel re-layouts and flickers on every progress tick.
        .animation(.easeInOut(duration: 0.2), value: model.currentScanCategory)
        .animation(.easeInOut(duration: 0.2), value: model.activeCleanupPhaseID)
    }

    func junkScanInlineStat(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    func junkScanPhaseTimeline(phases: [CleanerViewModel.CleanupScanPhase]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                let isDone = model.completedCleanupPhases.contains(phase.id)
                let isActive = !isDone && model.activeCleanupPhaseID == phase.id
                let phaseColor = phaseStripColor(isDone: isDone, isActive: isActive)

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(phaseColor.opacity(0.14))
                                .frame(width: 30, height: 30)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.green)
                            } else if isActive {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: phase.icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if index < phases.count - 1 {
                            Rectangle()
                                .fill(isDone ? Color.green.opacity(0.35) : Color.secondary.opacity(0.16))
                                .frame(width: 2, height: 28)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 30)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(phase.title.localized)
                                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            Spacer()
                            if isDone {
                                Text("Done".localized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else if isActive {
                                Text("Scanning".localized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        Text(phase.summary.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if isActive {
                            ProgressView(value: model.activeCleanupPhaseProgress, total: 1)
                                .tint(Color.accentColor)
                        }
                    }
                    .padding(.bottom, index < phases.count - 1 ? 14 : 10)
                }
                .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
                .padding(.top, index == 0 ? 12 : 0)
                .id(phase.id)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func phaseStripColor(isDone: Bool, isActive: Bool) -> Color {
        if isDone { return .green }
        if isActive { return Color.accentColor }
        return .secondary
    }

    var junkDetailList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !permissions.hasFullDiskAccess {
                        junkPermissionBanner
                    }
                    junkResultHeroCard
                    junkDistributionBar
                    ForEach(model.junkGroups) { group in
                        junkGroupSection(group)
                            .id(group.id)
                    }
                    Text("Safe groups are selected by default. Review orange groups; administrator actions stay unselected.".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, MachKitLayout.pageMargin)
                .padding(.bottom, MachKitLayout.pageMargin)
            }
            .onChange(of: junkScrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                junkScrollTarget = nil
            }
        }
    }

    var junkResultHeroCard: some View {
        let selectionFraction = model.totalBytes > 0
            ? min(1, Double(model.selectedBytes) / Double(model.totalBytes))
            : 0
        let percent = Int((selectionFraction * 100).rounded())

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: max(0.015, selectionFraction))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.22), value: model.selectedBytes)
                    VStack(spacing: 1) {
                        Text(L10n.percent(percent))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("Selected".localized).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                        Text("Ready to clean".localized)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(L10n.format(
                        "%@ selected of %@ total · %lld locations",
                        formatted(model.selectedBytes),
                        formatted(model.totalBytes),
                        Int64(model.items.count)
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Label(L10n.format("%@ safe", formatted(model.safeCleanableBytes)), systemImage: "checkmark.shield")
                        if model.reviewItemCount > 0 {
                            Label(L10n.format("%lld to review", Int64(model.reviewItemCount)), systemImage: "exclamationmark.triangle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(4, geometry.size.width * selectionFraction))
                            .animation(.easeOut(duration: 0.22), value: model.selectedBytes)
                    }
            }
            .frame(height: 5)
        }
        .padding(MachKitLayout.heroPadding)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.11), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        }
    }

    var junkDistributionBar: some View {
        let groups = model.junkGroups.filter { $0.bytes > 0 }
        let total = max(Int64(1), groups.reduce(Int64(0)) { $0 + $1.bytes })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Size Breakdown".localized).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.format("%lld groups", Int64(groups.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(groups) { group in
                        let width = max(4, geometry.size.width * CGFloat(Double(group.bytes) / Double(total)))
                        Button {
                            focusJunkGroup(group.id)
                        } label: {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(junkGroupChartColor(group))
                                .frame(width: width, height: 10)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.format("%@ · %@", group.title.localized, formatted(group.bytes)))
                    }
                }
            }
            .frame(height: 10)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(groups.prefix(6)) { group in
                    Button {
                        focusJunkGroup(group.id)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(junkGroupChartColor(group))
                                .frame(width: 7, height: 7)
                            Text(group.title.localized)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(formatted(group.bytes))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(MachKitLayout.cardPadding)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    func junkGroupChartColor(_ group: JunkScanGroup) -> Color {
        switch group.id {
        case "trash": .red
        case "app-caches": .blue
        case "developer-cleanup": .green
        case "logs-diagnostics": .brown
        case "downloads-devices": .cyan
        case "leftovers": .yellow
        case "time-machine": .orange
        case "system-cleanup": .purple
        default: .accentColor
        }
    }

    func junkGroupSection(_ group: JunkScanGroup) -> some View {
        let chartColor = junkGroupChartColor(group)
        let selectedCount = model.selectedCount(in: group)
        let isFullySelected = selectedCount == group.totalCount
        let selectionIcon = selectedCount == 0
            ? "square"
            : (isFullySelected ? "checkmark.square.fill" : "minus.square.fill")

        return VStack(spacing: 0) {
            DisclosureGroup(isExpanded: expansionBinding(group.id)) {
                VStack(spacing: 0) {
                    ForEach(group.items) { item in
                        junkFileRow(item)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 66)
                        }
                    }
                    if group.totalCount > group.items.count {
                        HStack {
                            Spacer()
                            Text(L10n.format(
                                "Showing %lld of %lld locations",
                                Int64(group.items.count),
                                Int64(group.totalCount)
                            ))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
                            .padding(.vertical, MachKitLayout.controlSpacing)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Button {
                        model.setGroup(group, selected: !isFullySelected)
                    } label: {
                        Image(systemName: selectionIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedCount == 0 ? Color.secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(group.title.localized)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(chartColor.opacity(0.12))
                        Image(systemName: group.risk == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(chartColor)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title.localized)
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.format(
                            "%lld locations · %@",
                            Int64(group.totalCount),
                            group.explanation.localized
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        HStack(spacing: 8) {
                            if group.safeCount > 0 {
                                Text(L10n.format("%lld safe", Int64(group.safeCount)))
                                    .foregroundStyle(.green)
                            }
                            if group.reviewCount > 0 {
                                Text(L10n.format("%lld to review", Int64(group.reviewCount)))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption2.weight(.medium))
                    }
                    Spacer()
                    Text(formatted(group.bytes))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
                .padding(.vertical, MachKitLayout.bannerPadding)
                .contentShape(Rectangle())
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    var cleanConfirmationTitle: String {
        if model.selectedIncludesPermanentActions && !model.selectedIncludesMoveActions {
            return L10n.string("Permanently delete selected items?")
        }
        if model.selectedIncludesTrashContents {
            return L10n.string("Clean selected items?")
        }
        return L10n.string("Move selected files to Trash?")
    }

    var cleanConfirmationActionTitle: String {
        if model.selectedIncludesPermanentActions && !model.selectedIncludesMoveActions {
            return L10n.string("Delete Permanently")
        }
        return model.selectedIncludesPrivilegedActions
            ? L10n.string("Clean Selected")
            : L10n.string("Move to Trash")
    }

    var cleanConfirmationMessage: String {
        let totals = L10n.format(
            "%lld items, %@ total.",
            Int64(model.selectedCount),
            formatted(model.selectedBytes)
        )
        if model.selectedIncludesPrivilegedActions {
            return totals + " " + L10n.string("Administrator approval may be requested. Time Machine snapshots are deleted permanently; supported files are moved to Trash.")
        }
        if model.selectedIncludesTrashContents && model.selectedIncludesNonTrashContents {
            return totals + " " + L10n.string("Trash items will be permanently deleted; other items will be moved to Trash.")
        }
        if model.selectedIncludesTrashContents {
            return totals + " " + L10n.string("This permanently deletes files already in Trash and cannot be undone.")
        }
        return totals
    }

    func junkFileRow(_ item: ScanItem) -> some View {
        let isVirtual = item.rule.rootScope == .virtual
        let isDirectory = item.fileCount > 1 || item.url.pathExtension.isEmpty
        let isEstimated = item.fileCount > 1
        return HStack(spacing: 12) {
            Toggle(isOn: selectionBinding(item)) { EmptyView() }.labelsHidden()
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((isDirectory ? Color.accentColor : Color.secondary).opacity(0.11))
                Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDirectory ? Color.accentColor : .secondary)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if item.rule.risk == .review {
                        Text("Review".localized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.10), in: Capsule())
                    }
                    if isEstimated {
                        Text("Estimated size".localized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.10), in: Capsule())
                    }
                }
                Text(isVirtual ? L10n.string("Local Time Machine snapshot") : item.url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !isVirtual {
                    Text(L10n.format("%lld files", Int64(item.fileCount)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if let date = item.modifiedAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !isVirtual {
                Text(formatted(item.bytes))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
                Image(systemName: "arrow.forward.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
        .padding(.vertical, MachKitLayout.rowPaddingVertical)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isVirtual { revealJunkItem(item) }
        }
        .contextMenu {
            if !isVirtual {
                Button("Show in Finder".localized) { revealJunkItem(item) }
            }
        }
    }

    func revealJunkItem(_ item: ScanItem) {
        let isDirectory = item.fileCount > 1 || item.url.pathExtension.isEmpty
        reveal(isDirectory ? item.url : item.url.deletingLastPathComponent())
    }

    func expansionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(id) },
            set: { expanded in
                if expanded { expandedGroups.insert(id) }
                else { expandedGroups.remove(id) }
            }
        )
    }

}

