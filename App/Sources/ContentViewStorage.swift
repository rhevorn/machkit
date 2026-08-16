import AppKit
import Charts
import MachKitCore
import SwiftUI

extension ContentView {
    var filesView: some View {
        VStack(spacing: 0) {
            header(
                title: "Storage",
                subtitle: "See where disk space goes — categories, large files, and folders",
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button("Choose Folder", action: model.chooseFolder)
                        if model.isStorageAnalyzing {
                            Button("Cancel", role: .cancel, action: model.cancelScan)
                        } else if model.storageAnalysis != nil {
                            refreshControl(for: .files, action: model.scanStorageAnalysis)
                        }
                    }
                )
            )
            .padding(18)
            if let analysis = model.storageAnalysis {
                storageAnalysisContent(analysis)
            } else if model.isStorageAnalyzing {
                storageAnalysisLoading
            } else {
                storageAnalysisEmptyView
            }
        }
    }

    var storageAnalysisEmptyView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.indigo.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 150, height: 150)
                Circle().stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                    .frame(width: 124, height: 124)
                Image(systemName: "chart.pie.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.20))
                    .font(.system(size: 52, weight: .light))
            }
            .padding(.bottom, 24)

            Text("Understand where your disk space goes".localized)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Local analysis of categories, large files, and folder usage — nothing is uploaded or deleted".localized)
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 18) {
                scanPromise(icon: "lock.shield", text: "Local Analysis")
                scanPromise(icon: "square.grid.2x2", text: "Categories")
                scanPromise(icon: "doc.badge.ellipsis", text: "Large Files")
            }
            .padding(.vertical, 22)

            Button(action: model.scanStorageAnalysis) {
                HStack(spacing: 9) {
                    Image(systemName: "chart.pie").font(.system(size: 14, weight: .bold))
                    Text("Start Analysis".localized).font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 214, height: 46)
                .background {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.12, green: 0.43, blue: 0.96), Color(red: 0.18, green: 0.58, blue: 0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 12, y: 5)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var storageAnalysisLoading: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(model.currentScanCategory.isEmpty
                 ? L10n.string("Analyzing storage…")
                 : model.currentScanCategory)
                .font(.system(size: 15, weight: .semibold))
            if model.storageInspectedFiles > 0 {
                Text(L10n.format(
                    "%lld files · %@",
                    Int64(model.storageInspectedFiles),
                    formatted(model.storageScannedBytes)
                ))
                .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text("Building a folder overview first, then categorizing files".localized)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text("Reads paths and sizes only — not file contents".localized)
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func storageAnalysisContent(_ analysis: StorageAnalysis) -> some View {
        VStack(spacing: 0) {
            Picker("Storage section", selection: $storageTab) {
                ForEach(StorageBrowseTab.allCases) { tab in
                    Text(tab.rawValue.localized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if model.isStorageAnalyzing {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.currentScanCategory.isEmpty
                                     ? L10n.string("Updating analysis…")
                                     : model.currentScanCategory)
                                    .font(.system(size: 12, weight: .medium))
                                if model.storageInspectedFiles > 0 {
                                    Text(L10n.format(
                                        "%lld files · %@",
                                        Int64(model.storageInspectedFiles),
                                        formatted(model.storageScannedBytes)
                                    ))
                                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                            Spacer()
                        }
                        .padding(11)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    }

                    storageVolumeCard(analysis)
                    storageInsightCard(analysis)

                    switch storageTab {
                    case .overview:
                        storageOverviewSections(analysis)
                    case .categories:
                        storageCategoriesSection(analysis)
                    case .largeFiles:
                        storageLargeFilesSection(analysis)
                    case .folders:
                        storageFoldersSection(analysis)
                    }

                    Text("Sizes summarize readable content. Protected or cloud-only items may be undercounted. Storage analysis never deletes files — use Cleanup for safe removals.".localized)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    func storageInsightCard(_ analysis: StorageAnalysis) -> some View {
        let insight = storageInsightText(analysis)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.orange)
                .font(.system(size: 14))
            Text(insight)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                model.changeMode(.junk)
            } label: {
                Label("Open Cleanup".localized, systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    func storageInsightText(_ analysis: StorageAnalysis) -> String {
        if let top = analysis.categories.first, analysis.scannedBytes > 0 {
            let percent = Int((Double(top.bytes) / Double(analysis.scannedBytes) * 100).rounded())
            if let large = analysis.largeFiles.first {
                return L10n.format(
                    "%@ is about %lld%% of scanned space. Largest file: %@ (%@).",
                    top.category.titleKey.localized,
                    Int64(percent),
                    large.url.lastPathComponent,
                    formatted(large.bytes)
                )
            }
            return L10n.format(
                "%@ is about %lld%% of scanned space across %lld files.",
                top.category.titleKey.localized,
                Int64(percent),
                Int64(top.fileCount)
            )
        }
        if let topFolder = analysis.directories.first {
            return L10n.format(
                "Largest folder here is %@ (%@).",
                topFolder.url.lastPathComponent,
                formatted(topFolder.bytes)
            )
        }
        return L10n.string("Scan finished. Browse categories, large files, or folders below.")
    }

    func storageOverviewSections(_ analysis: StorageAnalysis) -> some View {
        Group {
            if !analysis.categories.isEmpty {
                storageSectionHeader(
                    title: "Categories",
                    detail: L10n.format("%lld groups", Int64(analysis.categories.count)),
                    actionTitle: "See All"
                ) { storageTab = .categories }
                storageCategoryChart(analysis)
                VStack(spacing: 0) {
                    ForEach(Array(analysis.categories.prefix(4).enumerated()), id: \.element.id) { index, usage in
                        storageCategoryRow(usage, maximumBytes: analysis.categories.first?.bytes ?? 1)
                        if index < min(3, analysis.categories.count - 1) {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }

            if !analysis.largeFiles.isEmpty {
                storageSectionHeader(
                    title: "Large Files",
                    detail: L10n.format("%lld files ≥ 500 MB", Int64(analysis.largeFiles.count)),
                    actionTitle: "See All"
                ) { storageTab = .largeFiles }
                VStack(spacing: 0) {
                    ForEach(Array(analysis.largeFiles.prefix(5).enumerated()), id: \.element.id) { index, item in
                        storageLargeFileRow(item)
                        if index < min(4, analysis.largeFiles.count - 1) {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }

            if !analysis.directories.isEmpty {
                storageSectionHeader(
                    title: "Folders",
                    detail: "Top level · Sorted by size",
                    actionTitle: "Browse"
                ) { storageTab = .folders }
                VStack(spacing: 0) {
                    ForEach(Array(analysis.directories.prefix(6).enumerated()), id: \.element.id) { index, usage in
                        storageDirectoryRow(usage)
                        if index < min(5, analysis.directories.count - 1) {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    func storageSectionHeader(
        title: String,
        detail: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.localized).font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(detail.localized).font(.caption).foregroundStyle(.secondary)
            Button(actionTitle.localized, action: action)
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
        }
    }

    func storageCategoriesSection(_ analysis: StorageAnalysis) -> some View {
        Group {
            if analysis.categories.isEmpty {
                storageEmptyPanel(
                    title: "No categories yet",
                    detail: model.isStorageAnalyzing
                        ? "Category breakdown appears after the deep scan finishes."
                        : "Run analysis again to categorize files."
                )
            } else {
                storageCategoryChart(analysis)
                VStack(spacing: 0) {
                    ForEach(Array(analysis.categories.enumerated()), id: \.element.id) { index, usage in
                        storageCategoryRow(usage, maximumBytes: analysis.categories.first?.bytes ?? 1)
                        if index < analysis.categories.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    func storageCategoryChart(_ analysis: StorageAnalysis) -> some View {
        let slices = analysis.categories.filter { $0.bytes > 0 }
        return HStack(alignment: .center, spacing: 16) {
            Chart(slices) { usage in
                SectorMark(
                    angle: .value("Bytes", usage.bytes),
                    innerRadius: .ratio(0.56),
                    angularInset: 1.2
                )
                .foregroundStyle(storageCategoryColor(usage.category))
            }
            .chartLegend(.hidden)
            .frame(width: 148, height: 148)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices.prefix(6)) { usage in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(storageCategoryColor(usage.category))
                            .frame(width: 8, height: 8)
                        Text(usage.category.titleKey.localized)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(formatted(usage.bytes))
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func storageLargeFilesSection(_ analysis: StorageAnalysis) -> some View {
        Group {
            if analysis.largeFiles.isEmpty {
                storageEmptyPanel(
                    title: "No large files found",
                    detail: "Nothing at or above 500 MB in the scanned folder."
                )
            } else {
                HStack {
                    Text("Files ≥ 500 MB".localized).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(L10n.format("%lld files", Int64(analysis.largeFiles.count)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(analysis.largeFiles.enumerated()), id: \.element.id) { index, item in
                        storageLargeFileRow(item)
                        if index < analysis.largeFiles.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    func storageLargeFileRow(_ item: ScanItem) -> some View {
        Button {
            reveal(item.url.deletingLastPathComponent())
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.12))
                    Image(systemName: "doc.fill").foregroundStyle(Color.purple)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(formatted(item.bytes))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                Image(systemName: "arrow.forward.circle").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 13).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reveal in Finder")
    }

    func storageFoldersSection(_ analysis: StorageAnalysis) -> some View {
        Group {
            if !model.storagePath.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(model.storagePath.enumerated()), id: \.element.path) { index, url in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Button(index == 0 ? L10n.string("Home Folder") : url.lastPathComponent) {
                            model.navigateStorage(to: url)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(index == model.storagePath.count - 1)
                    }
                    Spacer()
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Folders".localized).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Top Level · Sorted by Size".localized).font(.caption).foregroundStyle(.secondary)
            }

            if analysis.directories.isEmpty {
                storageEmptyPanel(title: "No folders here", detail: "This directory has no readable subfolders.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(analysis.directories.enumerated()), id: \.element.id) { index, usage in
                        storageDirectoryRow(usage)
                        if index < analysis.directories.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    func storageEmptyPanel(title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title.localized).font(.system(size: 14, weight: .semibold))
            Text(detail.localized).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func storageDirectoryRow(_ usage: StorageDirectoryUsage) -> some View {
        Button {
            if usage.url == analysisRootURL { reveal(usage.url) }
            else { model.openStorageDirectory(usage.url) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.11))
                    Image(systemName: storageDirectoryIcon(usage.url.lastPathComponent))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(usage.url == analysisRootURL
                         ? L10n.string("files in user directory")
                         : usage.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(usage.explanation.localized)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(formatted(usage.bytes))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 13).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var analysisRootURL: URL? {
        model.storagePath.last ?? model.storageAnalysis?.analyzedRoots.first
    }

    func storageDirectoryIcon(_ name: String) -> String {
        switch name {
        case "Desktop": "desktopcomputer"
        case "Documents": "doc.fill"
        case "Downloads": "arrow.down.circle.fill"
        case "Library": "books.vertical.fill"
        case "Movies": "film.fill"
        case "Music": "music.note"
        case "Pictures": "photo.fill"
        case "Applications": "app.fill"
        case ".Trash": "trash.fill"
        case "Public": "person.2.fill"
        default: "folder.fill"
        }
    }

    func storageVolumeCard(_ analysis: StorageAnalysis) -> some View {
        let ratio = analysis.totalCapacity > 0
            ? min(1, Double(analysis.usedCapacity) / Double(analysis.totalCapacity))
            : 0
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("System Disk".localized).font(.system(size: 14, weight: .semibold))
                    Text(L10n.format(
                        "%@ used of %@",
                        formatted(analysis.usedCapacity),
                        formatted(analysis.totalCapacity)
                    ))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatted(analysis.availableCapacity)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    Text("Available Space".localized).font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: ratio)
                .tint(ratio > 0.9 ? Color.orange : Color.accentColor)
            HStack {
                Label(
                    L10n.format("%@ scanned", formatted(analysis.scannedBytes)),
                    systemImage: "square.grid.2x2"
                )
                if analysis.inaccessibleItemCount > 0 {
                    Text("·")
                    Text(L10n.format("%lld skipped", Int64(analysis.inaccessibleItemCount)))
                }
                Spacer()
                Text(L10n.format("Last analyzed %@", model.lastScanText))
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func storageCategoryRow(_ usage: StorageCategoryUsage, maximumBytes: Int64) -> some View {
        let fraction = maximumBytes > 0 ? Double(usage.bytes) / Double(maximumBytes) : 0
        let color = storageCategoryColor(usage.category)
        return HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.13))
                Image(systemName: storageCategoryIcon(usage.category)).foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(usage.category.titleKey.localized).font(.system(size: 12, weight: .medium))
                    Text(L10n.format("%lld files", Int64(usage.fileCount)))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                GeometryReader { geometry in
                    Capsule().fill(Color.secondary.opacity(0.10))
                        .overlay(alignment: .leading) {
                            Capsule().fill(color).frame(width: max(3, geometry.size.width * fraction))
                        }
                }
                .frame(height: 5)
            }
            Spacer()
            Text(formatted(usage.bytes)).font(.system(size: 12, weight: .medium)).monospacedDigit()
        }
        .padding(.horizontal, 13).frame(minHeight: 55)
    }

    func storageCategoryIcon(_ category: StorageCategoryKind) -> String {
        switch category {
        case .applications: "app.fill"
        case .documents: "doc.fill"
        case .downloads: "arrow.down.circle.fill"
        case .pictures: "photo.fill"
        case .music: "music.note"
        case .movies: "film.fill"
        case .developer: "hammer.fill"
        case .systemData: "gearshape.2.fill"
        case .other: "archivebox.fill"
        }
    }

    func storageCategoryColor(_ category: StorageCategoryKind) -> Color {
        switch category {
        case .applications: .blue
        case .documents: .indigo
        case .downloads: .cyan
        case .pictures: .pink
        case .music: .purple
        case .movies: .orange
        case .developer: .mint
        case .systemData: .gray
        case .other: .brown
        }
    }


    func header(title: String, subtitle: String, trailing: AnyView? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 18, weight: .semibold))
                Text(subtitle.localized).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(); trailing
        }
    }

    func refreshControl(for mode: FeatureMode, action: @escaping () -> Void) -> some View {
        let isRefreshing = model.isLoading(mode)
        return HStack(spacing: 7) {
            Text(model.lastUpdatedText(for: mode))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            Button(action: action) {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .help("Update Now")
            .accessibilityLabel(Text((isRefreshing ? "Updating" : "Update Now").localized))
            .disabled(isRefreshing)
        }
    }

    func autoUpdateIndicator(active: Bool, detail: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text((active ? "Auto Updating" : "Automatic updates paused").localized)
                .font(.caption.weight(.medium))
            Text("· \(detail)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    var junkSummary: String {
        model.items.isEmpty
            ? L10n.string("Scan Caches and Logs")
            : L10n.format("%@ cleanable", formatted(model.selectedBytes))
    }

    func scanHome() { model.mode = .home; model.selectHomeAndScan() }
    func scanJunk() { model.mode = .junk; if model.root == nil { model.selectHomeAndScan() } else { model.scan() } }
    func performQuickAction() {
        if model.items.isEmpty || model.selectedCount == 0 { scanHome() }
        else { model.requestClean() }
    }
    func selectionBinding(_ item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { model.isItemSelected(item) },
            set: { model.setItem(item, selected: $0) }
        )
    }
    func formatted(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
