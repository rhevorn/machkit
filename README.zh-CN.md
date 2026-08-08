# Sift

[English](README.md) · [简体中文](README.zh-CN.md)

一款隐私优先的 macOS 本地管理工具，用于存储分析、垃圾清理、软件卸载、端口管理，以及登录项与扩展检查。

所有处理都在本机完成。扫描只读取文件元数据，风险项默认不勾选，删除统一移入废纸篓。

<p align="center">
  <img src="Website/public/assets/img10.png" alt="Sift 浅色模式总览界面" width="900" />
</p>

<p align="center">
  <img src="Website/public/assets/img11.png" alt="Sift 浅色模式清理结果" width="900" />
</p>

## 功能

- **垃圾清理** — 扫描缓存、日志、应用残留和可重新生成的开发文件，并区分可安全清理与需确认项
- **软件卸载** — 卸载应用时一并处理关联支持文件
- **存储分析** — 按类别查看磁盘占用，并可继续进入大目录
- **性能监控** — 查看 CPU、内存压力和高占用进程
- **端口管理** — 检查监听端口，并可结束当前用户拥有的进程
- **登录项与扩展** — 在同一入口查看登录项、后台活动和系统扩展

## 系统要求

- macOS 14 或更高版本
- 从源码构建需要 Xcode 16 / Swift 6
- 部分用户目录可能需要「完全磁盘访问权限」

## 安装

当前发布包是**未签名**的 ad-hoc 构建，首次用双击打开会被 macOS Gatekeeper 拦截。

1. 从 [GitHub Releases](https://github.com/rhevorn/sift/releases/latest) 下载 `Sift-*-macOS.zip`。
2. 解压后，将 `Sift.app` 移到「应用程序」文件夹（`/Applications`）。
3. 用下面任一方式打开：
   - 右键点击 `Sift.app` → **打开** → 再点 **打开**
   - 或打开 **系统设置 → 隐私与安全性**，在被拦截提示处选择 **仍要打开**
4. 首次成功启动后，之后就可以像普通 App 一样从「应用程序」或 Spotlight 打开。

## 构建

打开 Xcode 工程，选择 `Sift App` Scheme 运行：

```bash
open Sift.xcodeproj
```

或在终端构建：

```bash
xcodebuild \
  -project Sift.xcodeproj \
  -scheme "Sift App" \
  -configuration Debug \
  -derivedDataPath build/XcodeDerivedData \
  build

open build/XcodeDerivedData/Build/Products/Debug/Sift.app
```

核心库测试：

```bash
swift test
```

## 本地化

英文为源语言。界面另支持简体中文、繁体中文、日语、韩语、西班牙语、法语、德语、巴西葡萄牙语和俄语。

## 项目结构

```text
App/                 SwiftUI 界面、偏好设置与状态管理
Sources/SiftCore/    扫描、风险判断、清理与系统盘点逻辑
Resources/           App Icon 与 Localizable.xcstrings
Tests/SiftCoreTests/ 核心行为与安全边界测试
Sift.xcodeproj/      macOS App 工程
Website/             产品官网
```

## 参与贡献

欢迎提交 Issue 和 Pull Request。请保持改动聚焦；涉及删除或结束进程的操作，优先采用本地、可撤销的方式。

## 许可证

[MIT](LICENSE)
