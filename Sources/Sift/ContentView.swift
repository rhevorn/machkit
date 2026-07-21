import AppKit
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
    @StateObject private var model = CleanerViewModel()
    @StateObject private var permissions = PermissionManager()
    @State private var expandedGroups: Set<String> = []
    @State private var applicationSearch = ""
    @State private var softwareTab: SoftwareTab = .all
    @State private var selectedCommandLineTool: CommandLineTool?
    @State private var hoveredSoftwareID: String?
    @State private var inventorySearch = ""

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
                case .loginItems: loginItemsView
                case .backgroundActivity: backgroundActivityView
                case .extensions: extensionsView
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
        .alert("操作失败", isPresented: $model.showRemovalFailure) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.removalFailureMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            brandMark.padding(.top, 52).padding(.bottom, 18)
            sideButton(.home, icon: "house.fill")
            sideButton(.junk, icon: "paintbrush.fill")
            sideButton(.uninstall, icon: "app.badge.checkmark")
            sideButton(.files, icon: "internaldrive")
            systemInventorySideButton
            Spacer()
            Button(action: {}) {
                VStack(spacing: 5) {
                    Image(systemName: "gearshape").font(.system(size: 17))
                    Text("设置").font(.system(size: 10))
                }
                .frame(width: 60, height: 50)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.secondary)
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
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.12, green: 0.43, blue: 0.92))
            Image(systemName: "sparkles").foregroundStyle(.white).font(.system(size: 18, weight: .semibold))
        }.frame(width: 38, height: 38).help("Sift")
    }

    private func sideButton(_ mode: FeatureMode, icon: String) -> some View {
        Button {
            inventorySearch = ""
            model.changeMode(mode)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                Text(mode.rawValue).font(.system(size: 10))
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
            VStack(spacing: 14) {
                header(title: "Sift", subtitle: "安静、可靠地管理 Mac 存储空间")
                permissionCard
                healthCard
                quickActionCard
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    homeTile(title: "垃圾清理", subtitle: junkSummary, icon: "paintbrush", mode: .junk)
                    homeTile(title: "软件卸载", subtitle: "查找应用与关联残留", icon: "app.badge.checkmark", mode: .uninstall)
                    homeTile(title: "大文件", subtitle: "查找超过 500 MB 的文件", icon: "doc.badge.ellipsis", mode: .files)
                    homeTile(title: "开发工具缓存", subtitle: "npm、Python、Cargo、Xcode", icon: "chevron.left.forwardslash.chevron.right", mode: .junk)
                    homeTile(title: "登录项", subtitle: "管理登录时自动打开的 App", icon: "person.badge.key", mode: .loginItems)
                    homeTile(title: "后台活动", subtitle: "检查后台代理与服务", icon: "waveform.path.ecg", mode: .backgroundActivity)
                    homeTile(title: "扩展", subtitle: "盘点应用、系统与浏览器扩展", icon: "puzzlepiece.extension", mode: .extensions)
                }
            }.padding(18)
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

    private var healthCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.10))
                Image(systemName: model.items.isEmpty ? "desktopcomputer" : "checkmark.shield.fill")
                    .font(.system(size: 25)).foregroundStyle(Color.accentColor)
            }.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.items.isEmpty ? "Mac 需要一次存储检查" : "Mac 存储状态良好")
                    .font(.system(size: 16, weight: .semibold))
                Text(model.items.isEmpty ? "扫描可安全清理的缓存和日志" : "发现 \(formatted(model.totalBytes)) 可清理内容")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("立即检查", action: scanHome).buttonStyle(.bordered)
        }
        .padding(16)
        .background { RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)) }
    }

    private var quickActionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("快速清理", systemImage: "bolt.fill").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(model.items.isEmpty ? "等待扫描" : "可清理 \(formatted(model.selectedBytes))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Button(action: performQuickAction) {
                HStack {
                    if model.isScanning { ProgressView().controlSize(.small).tint(.white) }
                    Text(model.isScanning ? "正在扫描" : (model.items.isEmpty ? "扫描" : "清理所选项目"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isScanning)
        }
        .padding(16)
        .background { RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)) }
    }

    private func homeTile(title: String, subtitle: String, icon: String, mode: FeatureMode) -> some View {
        Button { model.changeMode(mode) } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Color.accentColor).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 78)
            .background { RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)) }
        }.buttonStyle(.plain)
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
            Text(title).font(.caption).foregroundStyle(.secondary)
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
                                Text(group.title).font(.system(size: 14, weight: .semibold))
                                Text("\(group.items.count) 个文件 · \(group.explanation)")
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
                            Text(tab.rawValue).font(.system(size: 11, weight: .semibold))
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
                    Text(group.category.rawValue).font(.system(size: 13, weight: .semibold))
                    Text(group.category.subtitle).font(.caption2).foregroundStyle(.secondary)
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
                    Text(manager.rawValue).font(.system(size: 13, weight: .semibold))
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
                    detailValue(title: "版本", value: app.version ?? "未知")
                    detailValue(title: "Bundle ID", value: app.bundleIdentifier ?? "未知")
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
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
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
                    Text(tool.manager.rawValue).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            detailValue(title: "版本", value: tool.version ?? "未识别")
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
            ?? "无法确认包归属，请手动检查后处理"
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
                Text(item.applicationURL?.path ?? "路径不可用")
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
                Text(item.applicationURL?.path ?? item.bundleIdentifier ?? "系统记录")
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
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
            Text(title).font(.system(size: 13, weight: .medium))
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
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
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
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count) 个").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func inventoryBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).frame(height: 21)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func missingBadge(_ title: String) -> some View {
        inventoryBadge(title, color: .red)
            .help("没有在记录路径或已安装应用中找到对应文件，可能是卸载残留。")
    }

    private var loginApplicationRemovalMessage: String {
        guard let item = model.loginApplicationRemovalCandidate else { return "将从 macOS 登录项中移除。" }
        let missing = item.assessment == .likelyResidue ? "对应文件已经不存在。" : ""
        return "\(missing)“\(item.name)”将从登录项中移除，此操作不会删除应用文件。"
    }

    private var backgroundItemRemovalMessage: String {
        guard let item = model.backgroundItemRemovalCandidate else { return "启动配置将移入废纸篓。" }
        let assessment = item.assessment == .likelyResidue
            ? "没有找到目标程序，可能是卸载残留。"
            : item.assessment.explanation + "。"
        return "\(assessment)“\(item.label)”的启动配置将移入废纸篓；已运行的进程不会被强制终止。"
    }

    private var registeredBackgroundTaskRemovalMessage: String {
        guard let item = model.registeredBackgroundTaskRemovalCandidate else {
            return "废纸篓中的 App 残留将被永久删除。"
        }
        return "“\(item.name)”已经位于废纸篓。继续会永久删除该 App 残留，无法撤销；macOS 的后台记录可能要重新登录后才会消失。"
    }

    private var extensionRemovalMessage: String {
        guard let item = model.extensionRemovalCandidate else { return "扩展将移入废纸篓。" }
        let assessment = item.assessment == .likelyResidue
            ? "没有找到匹配的所属应用，可能是卸载残留。"
            : item.assessment.explanation + "。"
        return "\(assessment)“\(item.name)”将移入废纸篓，重新登录后相关功能将不再加载。"
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

    private var filesView: some View {
        VStack(spacing: 0) {
            header(title: "文件扫描", subtitle: "查看占用空间较大的文件", trailing: AnyView(Button("选择目录", action: model.chooseFolder)))
                .padding(18)
            Divider()
            if model.items.isEmpty {
                ContentUnavailableView("选择要扫描的目录", systemImage: "internaldrive", description: Text("查找超过 500 MB 的文件"))
            } else {
                List(model.items) { item in
                    HStack { Image(systemName: "doc"); Text(item.url.lastPathComponent); Spacer(); Text(formatted(item.bytes)).monospacedDigit() }
                }
            }
        }
    }

    private func header(title: String, subtitle: String, trailing: AnyView? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(); trailing
        }
    }

    private var junkSummary: String { model.items.isEmpty ? "扫描缓存与日志" : "可清理 \(formatted(model.selectedBytes))" }

    private func scanHome() { model.mode = .home; model.selectHomeAndScan() }
    private func scanJunk() { model.mode = .junk; if model.root == nil { model.selectHomeAndScan() } else { model.scan() } }
    private func performQuickAction() {
        if model.items.isEmpty { scanHome() }
        else { model.requestClean() }
    }
    private func selectionBinding(_ item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { model.isItemSelected(item) },
            set: { model.setItem(item, selected: $0) }
        )
    }
    private func formatted(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
