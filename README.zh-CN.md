# Sift

[English](README.md) · [简体中文](README.zh-CN.md)

一款隐私优先的 macOS 本地管理工具，用于存储分析、垃圾清理、软件卸载、网络工具、系统盘点，以及本地开发者工具。

所有处理都在本机完成。扫描只读取文件元数据，风险项默认不勾选，删除统一移入废纸篓。

<p align="center">
  <table cellpadding="12" cellspacing="0">
    <tr>
      <td align="center" bgcolor="#e8e8ed">
        <img src="Website/public/assets/img10.png#gh-light-mode-only" alt="Sift 总览界面" width="900" />
      </td>
    </tr>
  </table>
  <table cellpadding="12" cellspacing="0">
    <tr>
      <td align="center" bgcolor="#3a3a3c">
        <img src="Website/public/assets/img20.png#gh-dark-mode-only" alt="Sift 总览界面" width="900" />
      </td>
    </tr>
  </table>
</p>

## 功能

- **垃圾清理** — 查找缓存、日志、应用残留和开发文件，风险项默认不勾选
- **应用** — 查看 App 和命令行工具，并连同支持文件一起卸载
- **存储分析** — 看清磁盘占用和大目录
- **性能监控** — 查看 CPU、内存压力和高占用 App
- **网络** — 查看流量、连接、监听端口、路由、VPN/TUN 和代理
- **系统** — 查看登录项、后台活动和扩展
- **菜单栏** — 常驻轻量监控，显示 CPU、内存、网速和快捷操作
- **开发者工具** — 可从 Tools 工作区、菜单或全局快捷键打开本地工具：
  - **Hosts 管理** — 查看 `/etc/hosts`，在公共配置与多环境映射间安全切换
  - **时间戳转换** — 在日期与 Unix 时间戳之间转换，支持单位和时区
  - **JSON 格式化** — 格式化、压缩、键排序，并用路径表达式查询
  - **编解码** — Base64、Base32、Base62、Hex、URL、HTML、Unicode、转义与 Hash

## 系统要求

- macOS 14 或更高版本
- 从源码构建需要 Xcode 16 / Swift 6
- 部分用户目录可能需要「完全磁盘访问权限」
- 写入 hosts 时需要管理员认证

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

开发 H5 工具（界面联调时可选）：

```bash
cd Tool
npm install
npm run dev
```

Debug 构建可从本地 Vite 服务热更新加载工具；Release 构建始终使用打包进 `Resources/WebTools` 的产物。新增工具见 [Tool/README.md](Tool/README.md)。

## 发布

本地构建统一使用 `dev`。正式发布以 Git tag 作为版本唯一来源：推送 `v0.9.0` 后，工作流会将 App 版本覆盖为 `CFBundleShortVersionString=0.9.0`，GitHub Actions 运行编号作为 `CFBundleVersion`。工作流会在打包和发布 ZIP 前校验这两个值。

```bash
git tag v0.9.0
git push origin v0.9.0
```

## 本地化

英文为源语言。界面另支持简体中文、繁体中文、日语、韩语、西班牙语、法语、德语、巴西葡萄牙语和俄语。内嵌 Web 工具与原生界面共用语言和外观偏好。

## 项目结构

```text
App/                 SwiftUI 界面、偏好设置、工具壳层与原生桥接
Sources/SiftCore/    扫描、风险判断、清理、hosts 与系统盘点逻辑
Tool/                H5 开发者工具（Vite + React），打包进 Resources/WebTools
Resources/           App Icon 与 Localizable.xcstrings
Tests/SiftCoreTests/ 核心行为与安全边界测试
Sift.xcodeproj/      macOS App 工程
Website/             产品官网
```

## 参与贡献

欢迎提交 Issue 和 Pull Request。请保持改动聚焦；涉及删除或结束进程的操作，优先采用本地、可撤销的方式。

## 许可证

[MIT](LICENSE)
