# Sift

Sift 是一款安全优先的 macOS 本地管理工具，用于分析存储占用、检查磁盘垃圾、卸载应用、管理开发端口，以及检查登录项和扩展。

登录项、后台活动和扩展统一收纳在“登录项与扩展”入口中，并通过分段标签快速切换。

它不会把“大文件”或“无法识别的内容”直接当作垃圾。扫描结果会按风险分类，删除操作需要用户确认，并优先使用系统废纸篓保留恢复能力。

## 主要功能

### 垃圾清理

- 扫描缓存、日志、旧安装包和可重新生成的开发工具文件。
- 支持 npm、Python、Cargo 和 Xcode 等常见开发环境。
- 安全项目可以默认选中；需要判断的项目必须人工确认。
- 支持查看每个候选文件的路径、大小和修改时间。

### 软件卸载

- 盘点用户应用、App Store 应用、第三方应用和系统应用。
- 识别 Homebrew、npm、pip、Cargo 等包管理器安装的命令行工具。
- 卸载应用时查找缓存、日志、偏好设置、容器和应用数据等关联内容。
- 应用及选中的关联文件统一移入废纸篓。
- 扫描结果会在当前运行期间缓存，需要时可手动刷新。

### 存储分析

- 显示磁盘总容量、已用空间和可用空间。
- 按应用程序、文稿、下载、图片、音乐、影片、开发文件、系统与应用数据等类别汇总常见目录。
- 保留超过 500 MB 的大文件明细，点击可以在 Finder 中查看。
- 进入页面后由用户点击“开始分析”，不会自动扫描。
- 分析结果只读取文件路径和大小，不会读取文件内容，也不会自动删除任何内容。

### 性能监控

- 每 2 秒显示系统 CPU 使用率、内存压力、缓存、压缩内存和交换空间。
- 提供最近 60 秒趋势，以及按 CPU 或内存排序的高占用应用列表。
- 显示 GPU、统一内存、Neural Engine 和 Apple Intelligence 可用状态；不使用不稳定接口伪造 GPU 或 NPU 占用率。
- 离开页面或手动暂停后停止采样，不在后台持续占用资源。
- 提供保守的“智能释放”：只请求 macOS 处理已标记为可自动终止且当前未使用的后台 App，并归还 Sift 自身堆中的可回收页面；不会清空系统缓存、强制结束普通进程或承诺固定的释放量。
- 判断内存状态仍应优先关注内存压力和交换空间；可用内存较少本身不代表需要优化。

### 端口管理

- 使用 macOS 自带的 `lsof` 显示 TCP 监听端口和 UDP 本地绑定，不把 UDP 远程连接误报为监听端口。
- 显示端口、绑定地址、暴露范围、PID、进程名、可执行文件、工作目录和启动命令。
- 支持按协议和对外暴露范围筛选，也可以搜索端口、PID、进程、路径或命令。
- 经确认后可向当前用户拥有的非系统进程发送 `SIGTERM`；进程无响应时可以选择 `SIGKILL` 强制结束。
- 不允许结束 Sift 自身、其他用户的进程或明确位于系统管理目录中的进程。
- `launchd`、容器运行时或监护脚本可能自动重启已结束的进程，此时应继续检查对应的启动来源。

### 登录项

- 显示登录当前账户后由 macOS 自动打开的 App。
- 检查登录项指向的应用文件是否仍然存在；仅在文件缺失时显示警告。
- 经确认后可从 macOS 登录项中移除，但不会删除应用文件。
- 部分新式登录项仍需在“系统设置 → 通用 → 登录项与扩展”中管理。

### 后台活动

- 使用 Apple 官方 `sfltool dumpbtm` 读取 macOS Background Task Management 记录；刷新时由 Sift 通过 macOS 原生授权接口请求管理员权限，不借助 `osascript` 提权。
- 能发现应用已经移入废纸篓、但仍显示在“App 后台活动”中的历史登记。
- 读取当前用户和全局的 `LaunchAgents`、`LaunchDaemons` 配置。
- “自动启动”表示配置加载后由 `launchd` 启动项目；“退出后重启”表示进程退出后系统会尝试再次启动。
- 检查后台配置指向的程序是否存在，仅对缺失文件标记“文件不存在”。
- 经确认后可将后台配置移入废纸篓；已经运行的进程不会被强制终止。
- macOS 没有公开的第三方单项删除接口。若记录指向当前用户废纸篓中的 App，可在确认后永久移除这份残留；纯数据库记录可选择整体重建。执行 `resetbtm` 前会明确说明它会重置全部登录项和后台活动记录，并提示完成后重启 Mac。

### 扩展

- 盘点系统、网络、Safari、Finder、共享、Quick Look 和 Spotlight 扩展。
- 尝试将独立扩展与已安装应用进行匹配，辅助判断卸载残留。
- 独立扩展可经确认后移入废纸篓。
- 应用包内部的扩展不会单独拆除，以免破坏代码签名；应通过卸载所属应用处理。

## 安全设计

- 扫描和分析均在本机完成。
- 垃圾扫描只读取文件属性，不上传文件内容。
- 扫描规则限制在明确目录内，并拒绝父目录穿越和符号链接越界。
- “需确认”项目不会默认选中。
- 删除操作使用系统废纸篓，不执行永久删除。
- 系统应用受到保护，应用内置扩展不会被单独破坏。
- 结束端口进程前会显示确认；默认建议正常结束，强制结束可能造成未保存数据丢失。
- 不安装 privileged helper；受管理员权限保护的项目可能需要在系统设置或 Finder 中处理。

## 系统要求

- macOS 14 或更高版本
- Swift 6 / Xcode 16 或兼容工具链
- 部分用户目录需要在“系统设置 → 隐私与安全性 → 完全磁盘访问权限”中授权
- 读取和移除登录项需要允许 Sift 控制“系统事件”；也可以跳过授权，直接在系统设置中管理

## Xcode 构建与调试

项目包含正式的 macOS App 工程。打开工程：

```bash
open Sift.xcodeproj
```

在 Xcode 顶部选择 `Sift App` Scheme 和 `My Mac` 运行目标：

- `⌘R`：构建并启动 `Sift.app`，支持断点调试。
- `⌘B`：只构建 App。
- `⌘U`：运行 `SiftCoreTests` 测试。
- `Product → Show Build Folder in Finder`：在 Finder 中查看生成的 App。
- `Product → Archive`：创建发布归档；正式分发前需要在 Target 的 Signing & Capabilities 中选择开发者团队和签名证书。

也可以在终端构建一个可直接查看和运行的 Debug App：

```bash
xcodebuild \
  -project Sift.xcodeproj \
  -scheme "Sift App" \
  -configuration Debug \
  -derivedDataPath build/XcodeDerivedData \
  build

open build/XcodeDerivedData/Build/Products/Debug/Sift.app
```

App 使用固定 Bundle Identifier `dev.sift.app`，包含 Info.plist、Apple Events 权限说明、Entitlements 和完整的 macOS App Icon。为支持端口/进程管理和本地系统盘点，App Sandbox 默认关闭。

界面支持简体中文和英文。点击主窗口侧边栏的“设置”，可以按分类管理偏好；目前支持选择跟随系统、简体中文或英文，以及跟随系统、浅色或深色外观，修改会立即应用。

## Swift Package 开发

`Package.swift` 只负责可复用、可测试的核心库。macOS App 统一由 Xcode 工程运行，避免出现两个 App Scheme：

```bash
swift build
```

运行测试：

```bash
swift test
```

## 项目结构

```text
App/
├── Sources/       SwiftUI 应用、界面和状态管理
├── Info.plist     App Bundle 元数据和权限说明
└── Sift.entitlements

Sources/
└── SiftCore/      扫描、风险判断、清理和系统盘点逻辑

Resources/
├── Assets.xcassets/ macOS App Icon 和资源
└── Localizable.xcstrings 中英文界面文本

Tests/
└── SiftCoreTests/ 安全边界与产品行为测试

Sift.xcodeproj/    正式 macOS App 工程、App Target、测试 Target 和共享 Scheme
```

## 当前状态

Sift 目前处于开发阶段。执行清理前请检查候选项目，尤其是偏好设置、应用数据、容器、全局登录项和无法确认归属的扩展。
