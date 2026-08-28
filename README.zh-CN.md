# MachKit

[English](README.md) · [简体中文](README.zh-CN.md)

一款隐私优先的 macOS 本地管理工具，用于存储分析、垃圾清理、软件卸载、系统监控、网络检查、区域截图标注，以及持续增长的本地实用工具。

MachKit 不使用分析服务或云端后台。扫描只读取本机文件元数据，风险项默认不勾选；可恢复内容会移入废纸篓，只有界面明确标注为永久删除的操作才会直接删除。网络诊断与 cURL 实验室仅在用户主动执行时从当前 Mac 直接发起请求。

<p align="center">
  <table cellpadding="12" cellspacing="0">
    <tr>
      <td align="center" bgcolor="#e8e8ed">
        <img src="Website/public/assets/overview-zh-CN.webp" alt="MachKit 总览界面" width="900" />
      </td>
    </tr>
  </table>
</p>

## 功能

- **垃圾清理** — 查找缓存、日志、应用残留和开发文件，风险项默认不勾选
- **应用** — 查看 App 和命令行工具，并连同支持文件一起卸载
- **存储分析** — 看清磁盘占用和大目录
- **监控** — 查看 CPU、内存压力、温度状态和高占用 App（详见 [监控说明](docs/monitoring.md)）
- **网络** — 查看流量、连接、监听端口、路由、VPN/TUN 和代理
- **系统** — 查看登录项、后台活动和扩展
- **菜单栏** — 常驻轻量监控，显示 CPU、内存、网速和快捷操作
- **截图** — 全局快捷键框选任意区域，冻结桌面后用矩形、椭圆、箭头、画笔、高亮、马赛克和文字标注，再复制或保存；全程留在本机，不必另开窗口
- **实用工具** — 可从 Tools 工作区、菜单或全局快捷键打开专注的本地工具：
  - **Hosts 管理** — 查看 `/etc/hosts`，在公共配置与多环境映射间安全切换
  - **时间戳转换** — 在日期与 Unix 时间戳之间转换，支持单位和时区
  - **JSON 格式化** — 格式化、压缩、键排序，并用路径表达式查询
  - **编解码** — Base64、Base32、Base62、Hex、URL、HTML、Unicode、转义与 Hash
  - **字符串生成** — 在本地生成 UUID v1–v7、ULID、Nano ID、十六进制字符串和随机字符串
  - **正则实验室** — 匹配高亮、分组捕获与常用替换
  - **文本 Diff** — 左右对比文本并高亮行级差异
  - **IP / CIDR** — 本地查看 IPv4 / IPv6 地址或计算 IPv4 CIDR 范围
  - **Cron 表达式** — 编写五段 cron 并预览接下来的执行时间
  - **颜色实验室** — 本地转换 HEX / RGB / HSL / HSV 并检查对比度
  - **二维码** — 本地从文本或 URL 生成二维码
  - **URL 实验室** — 解析与拼装 URL，编辑查询参数与哈希
  - **进制换算** — 本地转换进制与字节单位
  - **图片处理** — 转换格式，并按质量、目标大小或尺寸控制输出
  - **JWT 实验室** — 在本地解码、检查和创建 JSON Web Token
  - **chmod 实验室** — 转换 Unix 权限模式并预览符号权限变化
  - **证书实验室** — 在本地检查证书、CSR 和证书链
  - **cURL 实验室** — 构建、解析、编辑，并由用户主动从当前 Mac 直接发送 cURL 请求
  - **连接追踪** — 追踪目标地址如何解析并通过 Mac 路由
  - **端口扫描** — 扫描任意 TCP 端口或范围，显示进度和开放端口

## 系统要求

- macOS 14 或更高版本
- 从源码构建需要 Xcode 16 / Swift 6
- 构建内嵌 H5 工具需要 Node.js 24 / npm
- 部分用户目录可能需要「完全磁盘访问权限」
- 写入 hosts 时需要管理员认证

## 安装

维护者配置 Apple 发布凭据后，MachKit 发布包会使用 Developer ID 签名并经过 Apple 公证；没有配置凭据时，发布工作流会生成 ad-hoc 签名、未经公证的构建，并在 Release Notes 中明确标注。源码构建使用本机 Xcode 的签名配置。

1. 从 [GitHub Releases](https://github.com/rhevorn/machkit/releases/latest) 下载 `MachKit-*-macOS.zip`。
2. 解压后，将 `MachKit.app` 移到「应用程序」文件夹（`/Applications`）。
3. 从「应用程序」或 Spotlight 打开 MachKit。

## 构建

首次构建先安装锁定的前端依赖，再打开 Xcode 工程并运行 `MachKit App` Scheme：

```bash
cd Tool && npm ci && cd ..
open MachKit.xcodeproj
```

或在终端构建：

```bash
xcodebuild \
  -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -derivedDataPath build/XcodeDerivedData \
  build

open build/XcodeDerivedData/Build/Products/Debug/MachKit.app
```

核心库测试：

```bash
swift test
```

开发内嵌 H5 工具时启动本地服务：

```bash
cd Tool
npm ci
npm run dev
```

Debug 构建可从本地 Vite 服务热更新加载工具；Release 构建始终使用打包进 `Resources/WebTools` 的产物。新增工具见 [Tool/README.md](Tool/README.md)。

## 发布

本地构建统一使用 `dev`。正式发布以 Git tag 作为版本唯一来源：推送 `v0.9.0` 后，工作流会将 App 版本覆盖为 `CFBundleShortVersionString=0.9.0`，GitHub Actions 运行编号作为 `CFBundleVersion`。工作流会校验版本，再明确选择两种模式之一：签名与公证 secrets 全部配置时，生成 Developer ID 签名、经过公证并装订票据的 ZIP；完全没有配置时，生成 ad-hoc 签名、未经公证的 ZIP。如果只配置一部分 secrets，工作流会失败而不是静默降级。已有 tag 也可以通过工作流的手动输入重新构建。

```bash
git tag v0.9.0
git push origin v0.9.0
```

## 本地化

英文为源语言。界面另支持简体中文、繁体中文、日语、韩语、西班牙语、法语、德语、巴西葡萄牙语和俄语。内嵌 Web 工具与原生界面共用语言和外观偏好。

## 项目结构

```text
App/                 SwiftUI 界面、偏好设置、工具壳层、原生桥接与截图
Sources/MachKitCore/    扫描、风险判断、清理、hosts、系统盘点与几何辅助
Tool/                H5 实用工具（Vite + React），打包进 Resources/WebTools
Resources/           App Icon 与 Localizable.xcstrings
Tests/MachKitCoreTests/ 核心行为与安全边界测试
MachKit.xcodeproj/      macOS App 工程
Website/             产品官网
```

## 参与贡献

欢迎提交 Issue 和 Pull Request。开发环境、检查命令与安全规则见 [CONTRIBUTING.md](CONTRIBUTING.md)；安全漏洞请按 [SECURITY.md](SECURITY.md) 私密报告。

## 许可证

[MIT](LICENSE)
