import AppKit
import Charts
import SiftCore
import SwiftUI

private enum SoftwareTab: String, CaseIterable, Identifiable {
    case all = "全部"
    case appStore = "App Store"
    case thirdParty = "第三方"
    case user = "用户"
    case system = "系统"
    case commandLine = "命令行"
    var id: String { rawValue }
}

private enum PerformanceSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "内存"
    var id: String { rawValue }
}

private enum PortFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case tcp = "TCP"
    case udp = "UDP"
    case exposed = "对外开放"
    var id: String { rawValue }
}

private struct LoginItemGroup: Identifiable {
    let domain: LoginItemDomain
    let items: [LoginItem]
    var id: LoginItemDomain { domain }
}

private struct ExtensionGroup: Identifiable {
    let kind: InstalledExtensionKind
    let items: [InstalledExtension]
    var id: InstalledExtensionKind { kind }
}

struct ContentView: View {
    @AppStorage(AppPreferenceKey.language) private var languageRawValue = AppLanguage.system.rawValue
    @StateObject private var model = CleanerViewModel()
    @StateObject private var permissions = PermissionManager()
    @State private var expandedGroups: Set<String> = []
    @State private var applicationSearch = ""
    @State private var softwareTab: SoftwareTab = .all
    @State private var selectedCommandLineTool: CommandLineTool?
    @State private var hoveredSoftwareID: String?
    @State private var inventorySearch = ""
    @State private var performanceSort: PerformanceSort = .cpu
    @State private var showingMemoryHelp = false
    @State private var portSearch = ""
    @State private var portFilter: PortFilter = .all
    @State private var selectedPort: ListeningPort?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch model.mode {
                case .home: homeView
                case .junk: junkView
                case .uninstall: uninstallView
                case .files: filesView
                case .performance: performanceView
                case .ports: portsView
                case .loginItems: loginItemsView
                case .backgroundActivity: backgroundActivityView
                case .extensions: extensionsView
                case .settings: AppSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea(.container, edges: .top)
        .confirmationDialog("将所选文件移入废纸篓？", isPresented: $model.showCleanConfirmation) {
            Button("移入废纸篓", role: .destructive, action: model.cleanConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(model.selectedCount) 项，\(formatted(model.selectedBytes))。")
        }
        .sheet(item: $model.uninstallCandidate) { app in
            applicationDetails(app)
        }
        .sheet(item: $selectedCommandLineTool) { tool in
            commandLineToolDetails(tool)
        }
        .sheet(item: $selectedPort) { port in
            portDetails(port)
        }
        .confirmationDialog("确认卸载这个应用？", isPresented: $model.showAppRemovalConfirmation) {
            Button("移入废纸篓", role: .destructive, action: model.uninstallConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text("应用程序和已勾选的关联文件都会移入废纸篓。")
        }
        .confirmationDialog("移除这个登录项？", isPresented: $model.showLoginApplicationRemovalConfirmation) {
            Button("移除", role: .destructive, action: model.removeLoginApplicationConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text(loginApplicationRemovalMessage)
        }
        .confirmationDialog("移除这个后台项目？", isPresented: $model.showBackgroundItemRemovalConfirmation) {
            Button("移入废纸篓", role: .destructive, action: model.removeBackgroundItemConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text(backgroundItemRemovalMessage)
        }
        .confirmationDialog("永久移除这个后台残留？", isPresented: $model.showRegisteredBackgroundTaskRemovalConfirmation) {
            Button("永久移除", role: .destructive, action: model.removeRegisteredBackgroundTaskConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text(registeredBackgroundTaskRemovalMessage)
        }
        .confirmationDialog("重建全部后台任务数据库？", isPresented: $model.showBackgroundDatabaseResetConfirmation) {
            Button("重建数据库", role: .destructive, action: model.resetBackgroundTaskDatabaseConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会重置全部登录项和后台活动记录，不只清理当前残留。仍然安装的 App 之后会重新登记，部分允许或禁止状态可能需要重新确认。完成后需要重启 Mac。")
        }
        .confirmationDialog("移除这个扩展？", isPresented: $model.showExtensionRemovalConfirmation) {
            Button("移入废纸篓", role: .destructive, action: model.removeExtensionConfirmed)
            Button("取消", role: .cancel) {}
        } message: {
            Text(extensionRemovalMessage)
        }
        .confirmationDialog("结束这个进程？", isPresented: $model.showPortTerminationConfirmation) {
            Button("正常结束", role: .destructive) { model.terminatePortProcess(force: false) }
            Button("强制结束", role: .destructive) { model.terminatePortProcess(force: true) }
            Button("取消", role: .cancel) {}
        } message: {
            Text(portTerminationMessage)
        }
        .alert("操作失败", isPresented: $model.showRemovalFailure) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.removalFailureMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
        .onChange(of: languageRawValue) { _, _ in
            model.refreshLocalizedStatus()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            brandMark.padding(.top, 52).padding(.bottom, 18)
            sideButton(.home, icon: "house.fill")
            sideButton(.junk, icon: "paintbrush.fill")
            sideButton(.uninstall, icon: "app.badge.checkmark")
            sideButton(.files, icon: "chart.pie.fill")
            sideButton(.performance, icon: "gauge.with.dots.needle.67percent")
            sideButton(.ports, icon: "network")
            systemInventorySideButton
            Spacer()
            sideButton(.settings, icon: "gearshape.fill")
            Button(action: {}) {
                VStack(spacing: 5) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 16))
                    Text("反馈").font(.system(size: 10))
                }
                .frame(width: 60, height: 48)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.bottom, 10)
        }
        .frame(width: 82)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var brandMark: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 42, height: 42)
            .help("Sift")
    }

    private func sideButton(_ mode: FeatureMode, icon: String) -> some View {
        Button {
            inventorySearch = ""
            model.changeMode(mode)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                Text(mode.rawValue.localized).font(.system(size: 10))
            }
            .foregroundStyle(model.mode == mode ? Color.accentColor : Color.secondary)
            .frame(width: 64, height: 56)
            .background {
                if model.mode == mode {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if model.mode == mode {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var systemInventorySideButton: some View {
        let isSelected = [.loginItems, .backgroundActivity, .extensions].contains(model.mode)
        return Button {
            inventorySearch = ""
            if !isSelected { model.changeMode(.loginItems) }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "switch.2").font(.system(size: 17, weight: .medium))
                Text("登录项与扩展").font(.system(size: 9))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 68, height: 56)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var homeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header(title: "概览", subtitle: "这台 Mac 的实时状态与常用工具")
                homeStorageOverview
                if !permissions.hasFullDiskAccess {
                    permissionCard
                }

                HStack {
                    Text("实时状态").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("自动更新").font(.caption).foregroundStyle(.secondary)
                    }
                }

                homeMetrics
                homeQuickAction

                HStack(alignment: .firstTextBaseline) {
                    Text("常用工具").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("本机处理，不上传数据").font(.caption).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    homeToolTile(
                        title: "垃圾清理", subtitle: "缓存、日志与开发工具垃圾",
                        icon: "paintbrush.fill", color: .blue, mode: .junk
                    )
                    homeToolTile(
                        title: "存储分析", subtitle: "磁盘分类、目录占用与大文件",
                        icon: "chart.pie.fill", color: .indigo, mode: .files
                    )
                    homeToolTile(
                        title: "软件卸载", subtitle: "应用、命令行工具与关联残留",
                        icon: "app.badge.checkmark", color: .purple, mode: .uninstall
                    )
                    homeToolTile(
                        title: "性能监控", subtitle: "CPU、内存压力与高占用应用",
                        icon: "gauge.with.dots.needle.67percent", color: .mint, mode: .performance
                    )
                    homeToolTile(
                        title: "端口管理", subtitle: "查看并结束遗忘的开发服务",
                        icon: "network", color: .orange, mode: .ports
                    )
                    homeToolTile(
                        title: "登录项与扩展", subtitle: "启动项、后台活动与应用扩展",
                        icon: "switch.2", color: .cyan, mode: .loginItems
                    )
                }
            }
            .padding(18)
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 20))
                .foregroundStyle(permissions.hasFullDiskAccess ? .green : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(permissions.hasFullDiskAccess ? "已获得完全磁盘访问权限" : "需要完全磁盘访问权限")
                    .font(.system(size: 13, weight: .semibold))
                Text(permissions.hasFullDiskAccess
                     ? "可以扫描受保护的用户目录；文件内容不会上传。"
                     : "用于发现应用缓存和残留。需要在系统设置中手动开启。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !permissions.hasFullDiskAccess {
                Button("打开系统设置", action: permissions.openFullDiskAccessSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background { RoundedRectangle(cornerRadius: 9).fill((permissions.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.08)) }
    }

    private var homeStorageOverview: some View {
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
                    Text(storage.totalCapacity > 0 ? "\(percent)%" : "—")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("已使用").font(.system(size: 9)).foregroundStyle(.secondary)
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
                    Label("已用 \(formatted(storage.usedCapacity))", systemImage: "internaldrive.fill")
                    Label("可用 \(formatted(storage.availableCapacity))", systemImage: "checkmark.circle")
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            Button("查看存储", action: { model.changeMode(.files) })
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(18)
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

    private var homeMetrics: some View {
        let snapshot = model.performanceSnapshot
        let exposedPorts = model.listeningPorts.filter { $0.exposure != .loopback }.count
        let memoryColor = snapshot.map { memoryPressureColor($0.memoryPressureLevel) } ?? .secondary
        return HStack(spacing: 10) {
            homeMetricCard(
                title: "CPU",
                value: snapshot.map { "\(Int($0.cpuPercent.rounded()))%" } ?? "—",
                detail: "系统使用率",
                icon: "cpu",
                color: .blue
            )
            homeMetricCard(
                title: "内存压力",
                value: snapshot.map { "\(Int(($0.memoryPressure * 100).rounded()))%" } ?? "—",
                detail: snapshot?.memoryPressureLevel.rawValue ?? "正在读取",
                icon: "memorychip",
                color: memoryColor
            )
            homeMetricCard(
                title: "对外端口",
                value: model.hasLoadedPortSnapshot ? String(exposedPorts) : "—",
                detail: model.hasLoadedPortSnapshot ? "当前监听" : "正在检查",
                icon: "network",
                color: exposedPorts > 0 ? .orange : .green
            )
            homeMetricCard(
                title: "可清理空间",
                value: model.cleanableBytes.map(formatted) ?? "—",
                detail: model.cleanableBytes == nil ? "等待扫描" : "最近一次结果",
                icon: "sparkles",
                color: .purple
            )
        }
    }

    private func homeMetricCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
                    .background(color.opacity(0.11), in: Circle())
                Spacer(minLength: 4)
                Text(title.localized).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(verbatim: value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            Text(detail.localized).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var homeQuickAction: some View {
        HStack(spacing: 13) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("快速清理").font(.system(size: 13, weight: .semibold))
                Text(homeQuickActionDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: performQuickAction) {
                HStack(spacing: 6) {
                    if model.isScanning { ProgressView().controlSize(.small) }
                    Text(homeQuickActionButtonTitle.localized)
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.isScanning)
        }
        .padding(13)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }

    private var homeQuickActionDescription: String {
        if model.isScanning { return L10n.string("正在查找可安全清理的缓存和日志…") }
        guard let cleanableBytes = model.cleanableBytes else {
            return L10n.string("扫描缓存、日志和可重新生成的开发工具文件")
        }
        if cleanableBytes == 0 { return L10n.string("最近一次扫描没有发现可清理内容") }
        return L10n.format("最近一次扫描发现 %@ 可清理内容", formatted(cleanableBytes))
    }

    private var homeQuickActionButtonTitle: String {
        if model.isScanning { return "正在扫描" }
        if model.selectedCount > 0 { return "清理所选" }
        return model.cleanableBytes == nil ? "开始扫描" : "重新扫描"
    }

    private func homeToolTile(
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
            .padding(12).frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func homeStorageColor(_ fraction: Double) -> Color {
        if fraction >= 0.93 { return .red }
        if fraction >= 0.84 { return .orange }
        return .green
    }

    private func homeStorageIcon(_ fraction: Double) -> String {
        if fraction >= 0.93 { return "exclamationmark.triangle.fill" }
        if fraction >= 0.84 { return "externaldrive.badge.exclamationmark" }
        return "checkmark.circle.fill"
    }

    private func homeStorageTitle(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return "正在读取存储状态…" }
        if storage.usedFraction >= 0.93 { return "Mac 存储空间不足" }
        if storage.usedFraction >= 0.84 { return "存储空间正在变紧" }
        return "Mac 存储状态良好"
    }

    private func homeStorageDescription(_ storage: SystemStorageSnapshot) -> String {
        guard storage.totalCapacity > 0 else { return L10n.string("正在读取系统磁盘容量") }
        return L10n.format(
            "还有 %@ 可用，共 %@",
            formatted(storage.availableCapacity),
            formatted(storage.totalCapacity)
        )
    }

    private var junkView: some View {
        VStack(spacing: 0) {
            header(
                title: "垃圾清理",
                subtitle: "缓存、日志、安装包与开发工具垃圾",
                trailing: AnyView(
                    Group {
                        if model.isScanning {
                            Button("取消", role: .cancel, action: model.cancelScan)
                        } else if !model.items.isEmpty {
                            compactScanButton
                        }
                    }
                )
            )
                .padding(18)
            if model.isScanning {
                scanningView
            } else if model.items.isEmpty {
                junkEmptyView
            } else {
                junkDetailList
                Divider()
                HStack {
                    Text("已选择 \(model.selectedCount) 项，\(formatted(model.selectedBytes))")
                    Spacer()
                    cleanSelectionButton
                }.padding(12)
            }
        }
    }

    private var junkEmptyView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.16), Color.cyan.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 176, height: 176)
                Circle()
                    .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                    .frame(width: 146, height: 146)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.22))
                    .font(.system(size: 62, weight: .light))
            }
            .padding(.bottom, 24)

            Text("给 Mac 做一次轻量清理")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("扫描缓存、日志和开发工具残留，确认明细后再清理")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 7)

            HStack(spacing: 18) {
                scanPromise(icon: "lock.shield", text: "本地扫描")
                scanPromise(icon: "checkmark.circle", text: "逐项确认")
                scanPromise(icon: "arrow.uturn.backward.circle", text: "废纸篓可恢复")
            }
            .padding(.vertical, 22)

            Button(action: scanJunk) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                    Text("开始扫描")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
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

    private func scanPromise(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var compactScanButton: some View {
        Button(action: scanJunk) {
            Label("重新扫描", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(Color.accentColor.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private var cleanSelectionButton: some View {
        Button(action: model.requestClean) {
            HStack(spacing: 7) {
                Image(systemName: "trash")
                Text("清理所选")
                Text(formatted(model.selectedBytes))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(height: 34)
            .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.selectedIDs.isEmpty)
        .opacity(model.selectedIDs.isEmpty ? 0.45 : 1)
    }

    private var scanningView: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().stroke(Color.accentColor.opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: max(model.scanProgress, 0.025))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .medium)).foregroundStyle(Color.accentColor)
            }
            .frame(width: 112, height: 112)

            VStack(spacing: 7) {
                Text("正在扫描\(model.currentScanCategory)")
                    .font(.title3.weight(.semibold))
                Text("只读取文件属性，不读取或上传文件内容")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ProgressView(value: model.scanProgress)
                .frame(width: 330)

            HStack(spacing: 34) {
                scanMetric(title: "已检查", value: "\(model.inspectedFileCount) 个文件")
                Divider().frame(height: 34)
                scanMetric(title: "已发现", value: "\(model.discoveredFileCount) 项")
                Divider().frame(height: 34)
                scanMetric(title: "可清理", value: formatted(model.discoveredBytes))
            }
            Button("取消扫描", role: .cancel, action: model.cancelScan)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scanMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 14, weight: .semibold)).monospacedDigit()
            Text(title.localized).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var junkDetailList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(model.junkGroups) { group in
                    DisclosureGroup(isExpanded: expansionBinding(group.id)) {
                        groupDetails(group)
                    } label: {
                        HStack(spacing: 11) {
                            Toggle("", isOn: groupSelectionBinding(group)).labelsHidden()
                            Image(systemName: group.risk == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(group.risk == .safe ? .green : .orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.title.localized).font(.system(size: 14, weight: .semibold))
                                Text("\(group.items.count) 个文件 · \(group.explanation.localized)")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(formatted(group.bytes)).monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .padding(14)
                    .background { RoundedRectangle(cornerRadius: 9).fill(Color(nsColor: .controlBackgroundColor)) }
                }
            }.padding(14)
        }
    }

    private func groupDetails(_ group: JunkScanGroup) -> some View {
        let visibleItems = Array(group.items.prefix(100))
        return VStack(spacing: 0) {
            Divider().padding(.leading, 44)
            ForEach(visibleItems) { item in
                junkFileRow(item)
                if item.id != visibleItems.last?.id { Divider().padding(.leading, 72) }
            }
            if group.items.count > visibleItems.count {
                HStack {
                    Image(systemName: "info.circle")
                    Text("为保证流畅，当前显示最大的 100 项；整组选中仍包含全部 \(group.items.count) 项。")
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
    }

    private func junkFileRow(_ item: ScanItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selectionBinding(item)).labelsHidden()
            Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).lineLimit(1)
                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            if let date = item.modifiedAt {
                Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Text(formatted(item.bytes)).font(.caption).monospacedDigit().frame(width: 72, alignment: .trailing)
        }.padding(.vertical, 8).padding(.horizontal, 4)
    }

    private func expansionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(id) },
            set: { expanded in
                if expanded { expandedGroups.insert(id) }
                else { expandedGroups.remove(id) }
            }
        )
    }

    private func groupSelectionBinding(_ group: JunkScanGroup) -> Binding<Bool> {
        Binding(
            get: { model.isGroupSelected(group) },
            set: { model.setGroup(group, selected: $0) }
        )
    }

    private var uninstallView: some View {
        VStack(spacing: 0) {
            header(
                title: "软件卸载",
                subtitle: "已自动读取这台 Mac 上的应用",
                trailing: AnyView(
                    HStack(spacing: 12) {
                        Text("\(model.applications.count) 个应用 · \(model.commandLineTools.count) 个命令行工具")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Button(action: model.scanInstalledApplications) {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .disabled(model.isScanning)
                    }
                )
            )
                .padding(18)
            if model.applications.isEmpty && model.isScanning {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("正在读取已安装应用…").font(.system(size: 13, weight: .medium))
                    Text("通常只需要几秒钟").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索应用", text: $applicationSearch).textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 9)

                    softwareCategoryTabs

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if softwareTab != .commandLine {
                                ForEach(filteredApplicationGroups) { group in applicationSection(group) }
                            }
                            if softwareTab == .all || softwareTab == .commandLine {
                                ForEach(filteredCommandLineGroups, id: \.manager) { group in
                                    commandLineSection(manager: group.manager, tools: group.tools)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private var softwareCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(SoftwareTab.allCases) { tab in
                    Button { withAnimation(.easeOut(duration: 0.16)) { softwareTab = tab } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: softwareTabIcon(tab))
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue.localized).font(.system(size: 11, weight: .semibold))
                            Text("\(softwareTabCount(tab))")
                                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                                .padding(.horizontal, 5).frame(height: 17)
                                .background(
                                    softwareTab == tab ? Color.white.opacity(0.18) : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .foregroundStyle(softwareTab == tab ? Color.white : Color.primary.opacity(0.72))
                        .padding(.horizontal, 10).frame(height: 32)
                        .background {
                            Capsule(style: .continuous)
                                .fill(softwareTab == tab ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        }
                        .overlay {
                            if softwareTab != tab {
                                Capsule().stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    private func softwareTabIcon(_ tab: SoftwareTab) -> String {
        switch tab {
        case .all: "square.grid.2x2"
        case .appStore: "bag"
        case .thirdParty: "shippingbox"
        case .user: "person.crop.circle"
        case .system: "apple.logo"
        case .commandLine: "terminal"
        }
    }

    private func softwareTabCount(_ tab: SoftwareTab) -> Int {
        switch tab {
        case .all: model.applications.count + model.commandLineTools.count
        case .appStore: model.applicationGroups.first(where: { $0.category == .appStore })?.applications.count ?? 0
        case .thirdParty: model.applicationGroups.first(where: { $0.category == .thirdParty })?.applications.count ?? 0
        case .user: model.applicationGroups.first(where: { $0.category == .user })?.applications.count ?? 0
        case .system: model.applicationGroups.first(where: { $0.category == .system })?.applications.count ?? 0
        case .commandLine: model.commandLineTools.count
        }
    }

    private var filteredApplicationGroups: [ApplicationGroup] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = model.applicationGroups.filter { group in
            switch softwareTab {
            case .all: true
            case .appStore: group.category == .appStore
            case .thirdParty: group.category == .thirdParty
            case .user: group.category == .user
            case .system: group.category == .system
            case .commandLine: false
            }
        }
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let matches = group.applications.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
            return matches.isEmpty ? nil : ApplicationGroup(category: group.category, applications: matches)
        }
    }

    private var filteredCommandLineGroups: [(manager: CommandLineToolManager, tools: [CommandLineTool])] {
        let query = applicationSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let tools = query.isEmpty ? model.commandLineTools : model.commandLineTools.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.manager.rawValue.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: tools, by: \.manager)
        return CommandLineToolManager.allCases.compactMap { manager in
            guard let matches = grouped[manager], !matches.isEmpty else { return nil }
            return (manager, matches)
        }
    }

    private func applicationSection(_ group: ApplicationGroup) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.category.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text(group.category.subtitle.localized).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(group.applications.count) 个 · \(formatted(group.bytes))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(group.applications) { app in
                applicationRow(app)
                if app.id != group.applications.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func applicationRow(_ app: InstalledApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if let version = app.version { Text("版本 \(version)") }
                    Text(app.bundleURL.deletingLastPathComponent().path)
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(app.bytes > 0 ? formatted(app.bytes) : "—")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 62, alignment: .trailing)
            if model.isSystemApplication(app) {
                Text("系统保护").font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(width: 58)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).frame(width: 58)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(
            hoveredSoftwareID == app.id ? Color.accentColor.opacity(0.055) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onHover { hovering in hoveredSoftwareID = hovering ? app.id : nil }
        .onTapGesture { model.prepareUninstall(app) }
    }

    private func commandLineSection(manager: CommandLineToolManager, tools: [CommandLineTool]) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.rawValue.localized).font(.system(size: 13, weight: .semibold))
                    Text("由包管理器安装的命令行工具").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tools.count) 个 · \(formatted(tools.reduce(0) { $0 + $1.bytes }))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider()
            ForEach(tools) { tool in
                HStack(spacing: 12) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.name).font(.system(size: 13, weight: .medium))
                        Text(tool.version.map { "版本 \($0) · \(tool.installURL.path)" } ?? tool.installURL.path)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(formatted(tool.bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(
                    hoveredSoftwareID == tool.id ? Color.accentColor.opacity(0.055) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onHover { hovering in hoveredSoftwareID = hovering ? tool.id : nil }
                .onTapGesture { selectedCommandLineTool = tool }
                if tool.id != tools.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func applicationDetails(_ app: InstalledApplication) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.title3.weight(.semibold))
                    Text("应用详情与关联数据").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    detailValue(title: "版本", value: app.version ?? L10n.string("未知"))
                    detailValue(title: "Bundle ID", value: app.bundleIdentifier ?? L10n.string("未知"))
                    detailValue(title: "安装位置", value: app.bundleURL.path)
                    detailValue(title: "应用大小", value: formatted(app.bytes))
                    Divider().padding(.vertical, 5)
                    if model.uninstallResidues.isEmpty {
                        Text("没有发现关联残留文件。").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        Text("关联文件").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                        ForEach(model.uninstallResidues) { residue in
                            uninstallItem(title: residue.kind.rawValue, detail: residue.url.path, bytes: residue.bytes, selected: residueSelectionBinding(residue))
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Label("可从废纸篓恢复", systemImage: "arrow.uturn.backward.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("关闭") { model.uninstallCandidate = nil }
                if !model.isSystemApplication(app) {
                    Button("卸载应用…", role: .destructive) { model.showAppRemovalConfirmation = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }

    private func detailValue(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.localized).font(.caption).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            Text(value).font(.system(size: 12)).textSelection(.enabled)
            Spacer()
        }
    }

    private func commandLineToolDetails(_ tool: CommandLineTool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill").font(.system(size: 28)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.name).font(.title3.weight(.semibold))
                    Text(tool.manager.rawValue.localized).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            detailValue(title: "版本", value: tool.version ?? L10n.string("未识别"))
            detailValue(title: "安装位置", value: tool.installURL.path)
            detailValue(title: "占用空间", value: formatted(tool.bytes))
            detailValue(title: "卸载命令", value: uninstallCommand(for: tool))
            Text("命令行工具由包管理器维护。Sift 只展示建议命令，不直接删除其目录，以免破坏依赖关系。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack { Spacer(); Button("关闭") { selectedCommandLineTool = nil }.keyboardShortcut(.defaultAction) }
        }
        .padding(22).frame(width: 520, height: 310)
    }

    private func uninstallCommand(for tool: CommandLineTool) -> String {
        tool.manager.uninstallCommand(name: tool.name, version: tool.version)
            ?? L10n.string("无法确认包归属，请手动检查后处理")
    }

    private func uninstallItem(title: String, detail: String, bytes: Int64, selected: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selected).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formatted(bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func residueSelectionBinding(_ residue: ApplicationResidue) -> Binding<Bool> {
        Binding(
            get: { model.selectedResidueIDs.contains(residue.id) },
            set: { selected in
                if selected { model.selectedResidueIDs.insert(residue.id) }
                else { model.selectedResidueIDs.remove(residue.id) }
            }
        )
    }

    private var loginItemsView: some View {
        VStack(spacing: 0) {
            header(
                title: "登录项与扩展",
                subtitle: "管理登录项、后台活动与应用扩展",
                trailing: AnyView(
                    Button(action: model.scanLoginItems) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isScanning)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "person.badge.key",
                title: "与 macOS 登录项保持一致",
                detail: "这里显示登录后自动打开的 App；部分新式项目只能在系统设置中管理。",
                buttonTitle: "打开登录项设置"
            )

            inventorySearchField(placeholder: "搜索登录项或应用路径")

            if model.isScanning && model.loginApplications.isEmpty {
                inventoryLoadingView(title: "正在读取登录项…")
            } else if let error = model.loginApplicationsError, model.loginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: "无法读取登录项",
                    detail: error,
                    icon: "exclamationmark.triangle"
                )
            } else if filteredLoginApplications.isEmpty {
                compactInventoryEmptyState(
                    title: inventorySearch.isEmpty ? "没有登录项" : "没有匹配的登录项",
                    detail: inventorySearch.isEmpty ? "可以在系统设置中添加登录时打开的 App" : "请尝试其他关键词",
                    icon: "person.badge.key"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        inventorySectionHeader(
                            title: "登录时打开",
                            subtitle: "登录当前账户后自动打开",
                            count: filteredLoginApplications.count
                        )
                        Divider()
                        ForEach(filteredLoginApplications) { item in
                            loginApplicationRow(item)
                            if item.id != filteredLoginApplications.last?.id { Divider().padding(.leading, 66) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredLoginApplications: [LoginApplication] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.loginApplications }
        return model.loginApplications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func loginApplicationRow(_ item: LoginApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? L10n.string("路径不可用"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("文件不存在")
            }
            if item.isHidden {
                inventoryBadge("启动后隐藏", color: .secondary)
            }
            if let url = item.applicationURL {
                Button("显示") { reveal(url) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
            Button("移除", role: .destructive) { model.requestLoginApplicationRemoval(item) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var backgroundActivityView: some View {
        VStack(spacing: 0) {
            header(
                title: "登录项与扩展",
                subtitle: "管理登录项、后台活动与应用扩展",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            model.showBackgroundDatabaseResetConfirmation = true
                        } label: {
                            Label("重建数据库", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(action: model.scanBackgroundActivity) {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isScanning)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "waveform.path.ecg",
                title: "后台活动说明",
                detail: "“自动启动”表示配置加载后启动；“退出后重启”表示进程退出后 launchd 会尝试再次启动。",
                buttonTitle: "打开后台设置"
            )

            inventorySearchField(placeholder: "搜索后台项目、标签或路径")

            if model.isScanning && model.backgroundItems.isEmpty && model.registeredBackgroundTasks.isEmpty {
                inventoryLoadingView(title: "正在读取后台活动…")
            } else if filteredBackgroundItemGroups.isEmpty && filteredRegisteredBackgroundTasks.isEmpty {
                ContentUnavailableView(
                    inventorySearch.isEmpty ? "没有发现后台项目" : "没有匹配的后台项目",
                    systemImage: "waveform.path.ecg",
                    description: Text(model.backgroundTaskScanError ?? (inventorySearch.isEmpty ? "没有发现后台任务或 launchd 配置" : "请尝试其他关键词"))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if let notice = model.backgroundDatabaseNotice {
                            HStack(spacing: 9) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(notice).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if let error = model.backgroundTaskScanError {
                            HStack(spacing: 9) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                Text(error).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        }
                        if !filteredRegisteredBackgroundTasks.isEmpty {
                            registeredBackgroundTaskSection
                        }
                        ForEach(filteredBackgroundItemGroups) { group in
                            backgroundItemSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredRegisteredBackgroundTasks: [RegisteredBackgroundTask] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.registeredBackgroundTasks }
        return model.registeredBackgroundTasks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.teamIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.applicationURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var registeredBackgroundTaskSection: some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: "App 后台活动",
                subtitle: "macOS 后台任务管理数据库中的 App 记录",
                count: filteredRegisteredBackgroundTasks.count
            )
            Divider()
            ForEach(filteredRegisteredBackgroundTasks) { item in
                registeredBackgroundTaskRow(item)
                if item.id != filteredRegisteredBackgroundTasks.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func registeredBackgroundTaskRow(_ item: RegisteredBackgroundTask) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.applicationURL?.path ?? "/Applications"))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.applicationURL?.path ?? item.bundleIdentifier ?? L10n.string("系统记录"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge(item.isRemovableTrashResidue(home: FileManager.default.homeDirectoryForCurrentUser)
                    ? "废纸篓记录"
                    : "应用不存在")
            }
            if let url = item.applicationURL {
                Button("显示") { reveal(url) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
            if item.isRemovableTrashResidue(home: FileManager.default.homeDirectoryForCurrentUser) {
                Button("移除", role: .destructive) { model.requestRegisteredBackgroundTaskRemoval(item) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var filteredBackgroundItemGroups: [LoginItemGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.backgroundItems : model.backgroundItems.filter {
            $0.label.localizedCaseInsensitiveContains(query)
                || $0.configURL.path.localizedCaseInsensitiveContains(query)
                || ($0.executableURL?.path.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \LoginItem.domain)
        return LoginItemDomain.allCases.compactMap { domain in
            guard let items = grouped[domain], !items.isEmpty else { return nil }
            return LoginItemGroup(domain: domain, items: items)
        }
    }

    private func backgroundItemSection(_ group: LoginItemGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.domain.rawValue,
                subtitle: group.domain.explanation,
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                backgroundItemRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func backgroundItemRow(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.executableURL?.path ?? item.configURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.executableURL?.path ?? item.configURL.path)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("文件不存在")
            }
            if item.runsAtLoad {
                inventoryBadge("自动启动", color: .blue)
                    .help("配置被 launchd 加载后自动启动。用户代理通常在登录时加载，后台服务通常在开机时加载。")
            }
            if item.keepsAlive {
                inventoryBadge("退出后重启", color: .orange)
                    .help("进程退出或崩溃后，launchd 会根据条件尝试再次启动。")
            }
            Button("显示") { reveal(item.configURL) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            Button("移除", role: .destructive) { model.requestBackgroundItemRemoval(item) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.configURL) }
    }

    private var extensionsView: some View {
        VStack(spacing: 0) {
            header(
                title: "登录项与扩展",
                subtitle: "管理登录项、后台活动与应用扩展",
                trailing: AnyView(
                    Button(action: model.scanExtensions) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isScanning)
                )
            )
            .padding(18)

            systemInventoryTabs

            inventoryManagementBanner(
                icon: "puzzlepiece.extension",
                title: "扩展随所属应用安装",
                detail: "停用扩展请使用系统设置或所属应用，避免破坏签名与自动更新。",
                buttonTitle: "打开扩展设置"
            )

            inventorySearchField(placeholder: "搜索扩展、所属应用或 Bundle ID")

            if model.isScanning && model.installedExtensions.isEmpty {
                inventoryLoadingView(title: "正在检查已安装应用…")
            } else if filteredExtensionGroups.isEmpty {
                ContentUnavailableView(
                    inventorySearch.isEmpty ? "没有发现扩展" : "没有匹配的扩展",
                    systemImage: "puzzlepiece.extension",
                    description: Text(inventorySearch.isEmpty ? "没有在已安装应用和常用扩展目录中发现组件" : "请尝试其他关键词")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredExtensionGroups) { group in
                            extensionSection(group)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
    }

    private var filteredExtensionGroups: [ExtensionGroup] {
        let query = inventorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? model.installedExtensions : model.installedExtensions.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.ownerName?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
        let grouped = Dictionary(grouping: matches, by: \InstalledExtension.kind)
        return InstalledExtensionKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return ExtensionGroup(kind: kind, items: items)
        }
    }

    private func extensionSection(_ group: ExtensionGroup) -> some View {
        VStack(spacing: 0) {
            inventorySectionHeader(
                title: group.kind.rawValue,
                subtitle: extensionKindExplanation(group.kind),
                count: group.items.count
            )
            Divider()
            ForEach(group.items) { item in
                extensionRow(item)
                if item.id != group.items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
    }

    private func extensionRow(_ item: InstalledExtension) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.bundleURL.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    if let owner = item.ownerName { Text(owner) }
                    if let version = item.version { Text("版本 \(version)") }
                    if item.ownerName == nil && item.version == nil { Text(item.bundleURL.path) }
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.assessment == .likelyResidue {
                missingBadge("所属应用不存在")
            }
            if let identifier = item.bundleIdentifier {
                Text(identifier).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            Button("显示") { reveal(item.bundleURL) }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            if item.ownerApplicationURL == nil {
                Button("移除", role: .destructive) { model.requestExtensionRemoval(item) }
                    .buttonStyle(.borderless).font(.caption).fixedSize()
            } else {
                Button("卸载应用") {
                    applicationSearch = item.ownerName ?? ""
                    model.changeMode(.uninstall)
                }
                .buttonStyle(.borderless).font(.caption).fixedSize()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { reveal(item.bundleURL) }
    }

    private func inventoryManagementBanner(
        icon: String,
        title: String,
        detail: String,
        buttonTitle: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(detail.localized).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(buttonTitle, action: openLoginItemsSettings).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(11)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private var systemInventoryTabs: some View {
        Picker("项目类型", selection: Binding(
            get: { model.mode },
            set: { newMode in
                inventorySearch = ""
                model.changeMode(newMode)
            }
        )) {
            Text("登录项").tag(FeatureMode.loginItems)
            Text("后台活动").tag(FeatureMode.backgroundActivity)
            Text("扩展").tag(FeatureMode.extensions)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func inventorySearchField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $inventorySearch).textFieldStyle(.plain)
            if !inventorySearch.isEmpty {
                Button { inventorySearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .padding(16)
    }

    private func inventoryLoadingView(title: String) -> some View {
        VStack(spacing: 13) {
            ProgressView().controlSize(.large)
            Text(title.localized).font(.system(size: 13, weight: .medium))
            Text("只读取组件信息，不修改系统配置").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactInventoryEmptyState(title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized).font(.system(size: 13, weight: .semibold))
                    Text(detail.localized).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
    }

    private func inventorySectionHeader(title: String, subtitle: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized).font(.system(size: 13, weight: .semibold))
                Text(subtitle.localized).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count) 个").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func inventoryBadge(_ title: String, color: Color) -> some View {
        Text(title.localized)
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).frame(height: 21)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func missingBadge(_ title: String) -> some View {
        inventoryBadge(title, color: .red)
            .help("没有在记录路径或已安装应用中找到对应文件，可能是卸载残留。")
    }

    private var loginApplicationRemovalMessage: String {
        guard let item = model.loginApplicationRemovalCandidate else {
            return L10n.string("将从 macOS 登录项中移除。")
        }
        let missing = item.assessment == .likelyResidue ? L10n.string("对应文件已经不存在。") : ""
        return L10n.format("%@“%@”将从登录项中移除，此操作不会删除应用文件。", missing, item.name)
    }

    private var backgroundItemRemovalMessage: String {
        guard let item = model.backgroundItemRemovalCandidate else { return L10n.string("启动配置将移入废纸篓。") }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("没有找到目标程序，可能是卸载残留。")
            : item.assessment.explanation.localized + L10n.string("。")
        return L10n.format("%@“%@”的启动配置将移入废纸篓；已运行的进程不会被强制终止。", assessment, item.label)
    }

    private var registeredBackgroundTaskRemovalMessage: String {
        guard let item = model.registeredBackgroundTaskRemovalCandidate else {
            return L10n.string("废纸篓中的 App 残留将被永久删除。")
        }
        return L10n.format("“%@”已经位于废纸篓。继续会永久删除该 App 残留，无法撤销；macOS 的后台记录可能要重新登录后才会消失。", item.name)
    }

    private var extensionRemovalMessage: String {
        guard let item = model.extensionRemovalCandidate else { return L10n.string("扩展将移入废纸篓。") }
        let assessment = item.assessment == .likelyResidue
            ? L10n.string("没有找到匹配的所属应用，可能是卸载残留。")
            : item.assessment.explanation.localized + L10n.string("。")
        return L10n.format("%@“%@”将移入废纸篓，重新登录后相关功能将不再加载。", assessment, item.name)
    }

    private func extensionKindExplanation(_ kind: InstalledExtensionKind) -> String {
        switch kind {
        case .system: "使用 DriverKit 等现代系统扩展技术"
        case .network: "参与 VPN、过滤或网络连接"
        case .safari: "为 Safari 提供网页与浏览器功能"
        case .finder: "在 Finder 中提供菜单或同步状态"
        case .quickLook: "提供文件预览与缩略图"
        case .spotlight: "帮助 Spotlight 读取特定文件格式"
        case .share: "显示在系统共享菜单中"
        case .app: "由所属应用提供的功能组件"
        }
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.LoginItems-Settings.extension"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private var portsView: some View {
        VStack(spacing: 0) {
            header(
                title: "端口管理",
                subtitle: "查看 TCP 监听端口、UDP 绑定及其进程"
            )
            .padding(18)

            if model.isScanning, model.listeningPorts.isEmpty {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("正在读取端口与进程信息…")
                        .font(.system(size: 14, weight: .semibold))
                    Text("使用 macOS 自带的 lsof 在本机扫描")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                portListContent
            }
        }
    }

    private var portListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    portSummaryItem(
                        title: "端口",
                        value: "\(model.listeningPorts.count)",
                        icon: "network",
                        color: .blue
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "进程",
                        value: "\(Set(model.listeningPorts.map(\.processIdentifier)).count)",
                        icon: "terminal.fill",
                        color: .indigo
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "TCP",
                        value: "\(model.listeningPorts.filter { $0.transport == .tcp }.count)",
                        icon: "arrow.left.arrow.right",
                        color: .mint
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "对外开放",
                        value: "\(model.listeningPorts.filter { $0.exposure != .loopback }.count)",
                        icon: "exclamationmark.shield.fill",
                        color: .orange
                    )
                }
                .padding(.vertical, 11)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }

                if let error = model.portScanError {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索端口、进程、PID、路径或启动命令", text: $portSearch)
                            .textFieldStyle(.plain)
                        if !portSearch.isEmpty {
                            Button { portSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 11).frame(height: 34)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                    Picker("筛选", selection: $portFilter) {
                        ForEach(PortFilter.allCases) { filter in
                            Text(filter.rawValue.localized).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 278)
                }

                if filteredPorts.isEmpty {
                    ContentUnavailableView(
                        portSearch.isEmpty ? "没有发现端口" : "没有匹配结果",
                        systemImage: "network.slash",
                        description: Text(portSearch.isEmpty ? "当前没有可显示的 TCP 监听端口或 UDP 绑定" : "尝试其他端口号、进程名或路径")
                    )
                    .frame(minHeight: 260)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("端口").frame(width: 104, alignment: .leading)
                            Text("绑定地址").frame(width: 142, alignment: .leading)
                            Text("进程").frame(maxWidth: .infinity, alignment: .leading)
                            Text("范围").frame(width: 80, alignment: .leading)
                            Color.clear.frame(width: 74)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 13).frame(height: 34)
                        Divider()
                        ForEach(Array(filteredPorts.enumerated()), id: \.element.id) { index, port in
                            portRow(port)
                            if index < filteredPorts.count - 1 { Divider().padding(.leading, 13) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }

                Label(
                    "正常结束会发送 SIGTERM，让进程自行清理后退出。强制结束可能造成未保存数据丢失；launchd、容器或监护脚本也可能自动重启进程。",
                    systemImage: "info.circle"
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var filteredPorts: [ListeningPort] {
        let query = portSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.listeningPorts.filter { port in
            let matchesFilter: Bool
            switch portFilter {
            case .all: matchesFilter = true
            case .tcp: matchesFilter = port.transport == .tcp
            case .udp: matchesFilter = port.transport == .udp
            case .exposed: matchesFilter = port.exposure != .loopback
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            let searchable = [
                String(port.port),
                String(port.processIdentifier),
                port.processName,
                port.processDescription.localized,
                port.localAddress,
                port.executableURL?.path ?? "",
                port.workingDirectoryURL?.path ?? "",
                port.commandLine ?? ""
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    private func portSummaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    private var portSummaryDivider: some View {
        Divider()
            .frame(height: 34)
    }

    private func portRow(_ port: ListeningPort) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(verbatim: String(port.port)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(port.transport.rawValue.localized)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(port.transport == .tcp ? Color.blue : Color.purple)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((port.transport == .tcp ? Color.blue : Color.purple).opacity(0.10), in: Capsule())
            }
            .frame(width: 104, alignment: .leading)

            Text(port.localAddress)
                .font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                .frame(width: 142, alignment: .leading)

            Button { selectedPort = port } label: {
                HStack(spacing: 9) {
                    processIcon(port)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(port.processName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(port.processDescription.localized)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("PID \(port.processIdentifier) · \(portProcessSubtitle(port))")
                            .font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(port.exposure.rawValue.localized)
                .font(.caption.weight(.medium)).foregroundStyle(portExposureColor(port.exposure))
                .frame(width: 80, alignment: .leading)

            Button("结束") { model.requestPortTermination(port) }
                .buttonStyle(.borderless)
                .foregroundStyle(port.canTerminate ? Color.red : Color.secondary)
                .disabled(!port.canTerminate)
                .help((port.protectionReason ?? "结束占用此端口的整个进程").localized)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 68)
        .contextMenu {
            Button("查看进程详情") { selectedPort = port }
            if let executableURL = port.executableURL {
                Button("在 Finder 中显示可执行文件") { reveal(executableURL) }
            }
            if let workingDirectoryURL = port.workingDirectoryURL {
                Button("打开工作目录") { NSWorkspace.shared.open(workingDirectoryURL) }
            }
            Divider()
            Button("结束进程", role: .destructive) { model.requestPortTermination(port) }
                .disabled(!port.canTerminate)
        }
    }

    @ViewBuilder
    private func processIcon(_ port: ListeningPort) -> some View {
        if let executableURL = port.executableURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: executableURL.path))
                .resizable().frame(width: 28, height: 28)
        } else {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.secondary).frame(width: 28, height: 28)
        }
    }

    private func portProcessSubtitle(_ port: ListeningPort) -> String {
        if let workingDirectoryURL = port.workingDirectoryURL { return workingDirectoryURL.path }
        if let executableURL = port.executableURL { return executableURL.path }
        return port.commandLine ?? L10n.string("进程路径未知")
    }

    private func portExposureColor(_ exposure: PortExposure) -> Color {
        switch exposure {
        case .loopback: .green
        case .network: .blue
        case .allInterfaces: .orange
        }
    }

    private func portDetails(_ port: ListeningPort) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                processIcon(port)
                VStack(alignment: .leading, spacing: 3) {
                    Text(port.processName).font(.title3.weight(.semibold))
                    Text(port.processDescription.localized).font(.caption).foregroundStyle(.secondary)
                    Text("PID \(port.processIdentifier)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Text(verbatim: "\(port.transport.rawValue) \(port.localAddress):\(String(port.port))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }

            VStack(spacing: 0) {
                portDetailRow("进程描述", value: port.processDescription.localized)
                Divider().padding(.leading, 104)
                portDetailRow("监听范围", value: port.exposure.rawValue.localized)
                Divider().padding(.leading, 104)
                portDetailRow("可执行文件", value: port.executableURL?.path ?? L10n.string("无法读取"))
                Divider().padding(.leading, 104)
                portDetailRow("工作目录", value: port.workingDirectoryURL?.path ?? L10n.string("无法读取"))
                Divider().padding(.leading, 104)
                portDetailRow("启动命令", value: port.commandLine ?? L10n.string("无法读取"))
                Divider().padding(.leading, 104)
                portDetailRow("用户 UID", value: String(port.ownerUserID))
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

            if let reason = port.protectionReason {
                Label(reason.localized, systemImage: "lock.shield.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("结束操作会终止整个进程，并释放该进程占用的全部端口。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                if let executableURL = port.executableURL {
                    Button("显示可执行文件") { reveal(executableURL) }
                }
                if let workingDirectoryURL = port.workingDirectoryURL {
                    Button("打开工作目录") { NSWorkspace.shared.open(workingDirectoryURL) }
                }
                Spacer()
                Button("关闭", role: .cancel) { selectedPort = nil }
                Button("结束进程", role: .destructive) {
                    selectedPort = nil
                    model.requestPortTermination(port)
                }
                .disabled(!port.canTerminate)
            }
        }
        .padding(20)
        .frame(width: 620)
    }

    private func portDetailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title.localized).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
    }

    private var portTerminationMessage: String {
        guard let port = model.portTerminationCandidate else { return "" }
        return L10n.format(
            "%@（PID %d）正在占用 %@ %@:%@。正常结束更安全；只有进程无响应时才使用强制结束。",
            port.processName,
            port.processIdentifier,
            port.transport.rawValue,
            port.localAddress,
            String(port.port)
        )
    }

    private var performanceView: some View {
        VStack(spacing: 0) {
            header(
                title: "性能监控",
                subtitle: "本地查看 CPU、内存压力与高占用应用",
                trailing: AnyView(
                    Button {
                        if model.isPerformanceMonitoring {
                            model.stopPerformanceMonitoring()
                        } else {
                            model.startPerformanceMonitoring()
                        }
                    } label: {
                        Label(model.isPerformanceMonitoring ? "暂停" : "继续", systemImage: model.isPerformanceMonitoring ? "pause.fill" : "play.fill")
                    }
                )
            )
            .padding(18)

            if let snapshot = model.performanceSnapshot {
                performanceContent(snapshot)
            } else {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("正在采集性能数据…").font(.system(size: 14, weight: .semibold))
                    Text("第一次 CPU 采样约需 2 秒").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func performanceContent(_ snapshot: PerformanceSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    cpuMetricCard(snapshot)
                    memoryMetricCard(snapshot)
                }
                computeHardwareCard(snapshot.computeHardware)
                performanceTrendCard
                resourceApplicationList(snapshot)
                Text("数据每 2 秒在本机更新一次；离开此页面或点击暂停后会停止采样。应用排行只显示当前可识别的图形应用进程。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func cpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("CPU", systemImage: "cpu.fill").font(.system(size: 14, weight: .semibold))
                Spacer()
                Circle().fill(model.isPerformanceMonitoring ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(model.isPerformanceMonitoring ? "实时" : "已暂停")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.cpuPercent.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            }
            ProgressView(value: snapshot.cpuPercent, total: 100)
                .tint(snapshot.cpuPercent > 85 ? Color.orange : Color.accentColor)
            HStack {
                Text("系统总使用率")
                Spacer()
                Label(thermalStateText(snapshot.thermalState), systemImage: "thermometer.medium")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func memoryMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let color = memoryPressureColor(snapshot.memoryPressureLevel)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 6) {
                Label("内存压力", systemImage: "memorychip.fill").font(.system(size: 14, weight: .semibold))
                Button { showingMemoryHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("了解 macOS 的内存管理")
                .popover(isPresented: $showingMemoryHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("智能释放会做什么？", systemImage: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("由 macOS 处理已标记为可自动终止、当前又未使用的隐藏 App，同时归还 Sift 自身堆中可回收的页面。")
                            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Text("不会退出普通前台 App，不会强制结束进程，也不需要管理员权限。")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 340, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(snapshot.memoryPressureLevel.rawValue.localized)
                    .font(.caption.weight(.semibold)).foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(formatted(snapshot.usedMemory))
                    .font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("/ \(formatted(snapshot.physicalMemory))")
                    .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: snapshot.memoryPressure, total: 1).tint(color)
            HStack(spacing: 9) {
                Text("缓存 \(formatted(snapshot.cachedMemory))")
                Text("交换 \(formatted(snapshot.swapUsed))")
                Spacer(minLength: 4)
                Button(action: model.optimizeMemory) {
                    if model.isOptimizingMemory {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("智能释放", systemImage: "wand.and.sparkles")
                    }
                }
                .frame(minWidth: 76)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isOptimizingMemory)
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func computeHardwareCard(_ hardware: ComputeHardwareInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("计算硬件")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 8)
            computeHardwareRow(
                icon: "display",
                title: "GPU",
                subtitle: hardware.recommendedGPUWorkingSet > 0
                    ? L10n.format("%@ · 建议工作集 %@", hardware.gpuName, formatted(hardware.recommendedGPUWorkingSet))
                    : hardware.gpuName,
                status: hardware.hasUnifiedMemory ? "统一内存" : "独立显存",
                color: .blue
            )
            Divider().padding(.leading, 50)
            computeHardwareRow(
                icon: "brain.head.profile",
                title: "Neural Engine",
                subtitle: hardware.neuralEngineAvailable ? "可供 Core ML 调度使用" : "没有检测到可用的神经网络引擎",
                status: hardware.neuralEngineAvailable ? "可用" : "不可用",
                color: hardware.neuralEngineAvailable ? .purple : .secondary
            )
            Divider().padding(.leading, 50)
            appleIntelligenceRow(hardware.appleIntelligenceState)
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func computeHardwareRow(icon: String, title: String, subtitle: String, status: String, color: Color) -> some View {
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
        .padding(.horizontal, 14).frame(minHeight: 55)
    }

    private func appleIntelligenceRow(_ state: AppleIntelligenceState) -> some View {
        let presentation = appleIntelligencePresentation(state)
        return computeHardwareRow(
            icon: "sparkles",
            title: "Apple Intelligence",
            subtitle: presentation.explanation,
            status: presentation.status,
            color: presentation.color
        )
    }

    private func appleIntelligencePresentation(_ state: AppleIntelligenceState) -> (status: String, explanation: String, color: Color) {
        switch state {
        case .available:
            ("可用", "系统本地语言模型已准备好，可供支持的 App 使用", .green)
        case .notEnabled:
            ("未开启", "设备支持，但尚未在系统设置中开启 Apple Intelligence", .orange)
        case .deviceNotEligible:
            ("设备不支持", "当前 Mac 不符合 Apple Intelligence 的硬件要求", .secondary)
        case .modelNotReady:
            ("模型未就绪", "模型可能仍在准备，或当前语言与地区暂不可用", .orange)
        case .unsupportedSystem:
            ("系统不支持", "需要 macOS 26 或更高版本才能检查系统语言模型", .secondary)
        case .unknown:
            ("状态未知", "系统没有返回可识别的可用状态", .secondary)
        }
    }

    private var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近 60 秒").font(.system(size: 14, weight: .semibold))
                Spacer()
                Label("CPU", systemImage: "circle.fill").foregroundStyle(Color.accentColor)
                Label("内存压力", systemImage: "circle.fill").foregroundStyle(Color.purple)
            }
            .font(.caption)
            Chart(model.performanceHistory) { point in
                LineMark(
                    x: .value("时间", point.sampledAt),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("指标", "CPU")
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("时间", point.sampledAt),
                    y: .value("内存压力", point.memoryPressurePercent),
                    series: .value("指标", "内存压力")
                )
                .foregroundStyle(Color.purple)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)%") } }
                }
            }
            .frame(height: 138)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resourceApplicationList(_ snapshot: PerformanceSnapshot) -> some View {
        let applications = snapshot.applications.sorted { lhs, rhs in
            performanceSort == .cpu ? lhs.cpuPercent > rhs.cpuPercent : lhs.memoryBytes > rhs.memoryBytes
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("资源占用最高的应用").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("排序", selection: $performanceSort) {
                    ForEach(PerformanceSort.allCases) { sort in Text(sort.rawValue.localized).tag(sort) }
                }
                .pickerStyle(.segmented).frame(width: 150)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("应用").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 70, alignment: .trailing)
                    Text("内存").frame(width: 92, alignment: .trailing)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 13).frame(height: 32)
                Divider()
                ForEach(Array(applications.prefix(12).enumerated()), id: \.element.id) { index, application in
                    resourceApplicationRow(application)
                    if index < min(applications.count, 12) - 1 { Divider().padding(.leading, 48) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func resourceApplicationRow(_ application: ApplicationResourceUsage) -> some View {
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
            Text("\(application.cpuPercent.formatted(.number.precision(.fractionLength(1))))%")
                .font(.system(size: 12)).monospacedDigit().frame(width: 70, alignment: .trailing)
            Text(formatted(application.memoryBytes))
                .font(.system(size: 12)).monospacedDigit().frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, 13).frame(minHeight: 48)
        .contextMenu {
            if let url = application.bundleURL { Button("在 Finder 中显示") { reveal(url) } }
        }
    }

    private func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: .green
        case .elevated: .orange
        case .critical: .red
        }
    }

    private func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("温度正常")
        case .fair: L10n.string("温度稍高")
        case .serious: L10n.string("温度较高")
        case .critical: L10n.string("温度过高")
        @unknown default: L10n.string("温度未知")
        }
    }

    private var filesView: some View {
        VStack(spacing: 0) {
            header(
                title: "存储分析",
                subtitle: "了解磁盘、常见目录与大文件的空间占用",
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button("选择目录", action: model.chooseFolder)
                        if model.isScanning {
                            Button("取消", role: .cancel, action: model.cancelScan)
                        } else if model.storageAnalysis != nil {
                            Button(action: model.scanStorageAnalysis) {
                                Label("刷新", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                )
            )
                .padding(18)
            if let analysis = model.storageAnalysis {
                storageAnalysisContent(analysis)
            } else if model.isScanning {
                storageAnalysisLoading
            } else {
                storageAnalysisEmptyView
            }
        }
    }

    private var storageAnalysisEmptyView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.indigo.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 176, height: 176)
                Circle().stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
                    .frame(width: 146, height: 146)
                Image(systemName: "chart.pie.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.20))
                    .font(.system(size: 62, weight: .light))
            }
            .padding(.bottom, 24)

            Text("了解 Mac 的空间都用在哪里")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("统计常见目录并按内容分类，同时列出占用较大的文件")
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 7)

            HStack(spacing: 18) {
                scanPromise(icon: "lock.shield", text: "本地分析")
                scanPromise(icon: "eye.slash", text: "不读取内容")
                scanPromise(icon: "trash.slash", text: "不会自动删除")
            }
            .padding(.vertical, 22)

            Button(action: model.scanStorageAnalysis) {
                HStack(spacing: 9) {
                    Image(systemName: "chart.pie").font(.system(size: 14, weight: .bold))
                    Text("开始分析").font(.system(size: 14, weight: .semibold))
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

    private var storageAnalysisLoading: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("正在分析\(model.currentScanCategory)")
                .font(.system(size: 15, weight: .semibold))
            Text("已检查 \(model.inspectedFileCount) 个文件 · 已统计 \(formatted(model.discoveredBytes))")
                .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            Text("只读取文件大小和路径，不读取文件内容")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func storageAnalysisContent(_ analysis: StorageAnalysis) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if model.isScanning {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("正在刷新：已检查 \(model.inspectedFileCount) 个文件")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(formatted(model.discoveredBytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(11)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }

                storageVolumeCard(analysis)

                Text("已分析目录")
                    .font(.system(size: 15, weight: .semibold))
                VStack(spacing: 0) {
                    ForEach(Array(analysis.categories.enumerated()), id: \.element.id) { index, usage in
                        storageCategoryRow(usage, maximumBytes: analysis.categories.first?.bytes ?? 0)
                        if index < analysis.categories.count - 1 { Divider().padding(.leading, 48) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                HStack(alignment: .firstTextBaseline) {
                    Text("大文件")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("超过 500 MB · 仅供查看")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if analysis.largeFiles.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("分析范围内没有超过 500 MB 的文件")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(analysis.largeFiles.prefix(50).enumerated()), id: \.element.id) { index, item in
                            Button { reveal(item.url) } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(Color.accentColor).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.url.lastPathComponent)
                                            .font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(item.url.deletingLastPathComponent().path)
                                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(formatted(item.bytes)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                                    Image(systemName: "arrow.forward.circle").foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 13).frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < min(analysis.largeFiles.count, 50) - 1 { Divider().padding(.leading, 48) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }

                Text("已统计 \(analysis.scannedFileCount) 个文件。分类容量是可读取目录的汇总；APFS 快照、系统保护内容和无法访问的目录仍会计入磁盘已用空间。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func storageVolumeCard(_ analysis: StorageAnalysis) -> some View {
        let ratio = analysis.totalCapacity > 0
            ? min(1, Double(analysis.usedCapacity) / Double(analysis.totalCapacity))
            : 0
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("系统磁盘").font(.system(size: 14, weight: .semibold))
                    Text("已使用 \(formatted(analysis.usedCapacity))，共 \(formatted(analysis.totalCapacity))")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatted(analysis.availableCapacity)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    Text("可用空间").font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: ratio)
                .tint(ratio > 0.9 ? Color.orange : Color.accentColor)
            HStack {
                Label("已分类 \(formatted(analysis.scannedBytes))", systemImage: "square.grid.2x2")
                Spacer()
                Text("上次分析 \(model.lastScanText)")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func storageCategoryRow(_ usage: StorageCategoryUsage, maximumBytes: Int64) -> some View {
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
                    Text(usage.category.rawValue.localized).font(.system(size: 12, weight: .medium))
                    Text("\(usage.fileCount) 个文件").font(.caption2).foregroundStyle(.secondary)
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

    private func storageCategoryIcon(_ category: StorageCategoryKind) -> String {
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

    private func storageCategoryColor(_ category: StorageCategoryKind) -> Color {
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

    private func header(title: String, subtitle: String, trailing: AnyView? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 18, weight: .semibold))
                Text(subtitle.localized).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(); trailing
        }
    }

    private var junkSummary: String {
        model.items.isEmpty
            ? L10n.string("扫描缓存与日志")
            : L10n.format("可清理 %@", formatted(model.selectedBytes))
    }

    private func scanHome() { model.mode = .home; model.selectHomeAndScan() }
    private func scanJunk() { model.mode = .junk; if model.root == nil { model.selectHomeAndScan() } else { model.scan() } }
    private func performQuickAction() {
        if model.items.isEmpty || model.selectedCount == 0 { scanHome() }
        else { model.requestClean() }
    }
    private func selectionBinding(_ item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { model.isItemSelected(item) },
            set: { model.setItem(item, selected: $0) }
        )
    }
    private func formatted(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
