import { groupedWebsiteTools, localizedWebsiteTools } from "./tool-catalog.js";

export const messages = {
  en: {
    meta: {
      title: "MachKit — Free Mac Cleaner, Screenshot & Utility Tools",
      description: "Free, open-source Mac cleanup and utility app for storage analysis, safe cleaning, app uninstall, system monitoring, screenshots, networking, and 19 local tools.",
    },
    nav: {
      capabilities: "Capabilities",
      screens: "Product",
      safety: "Safety",
      tools: "Tools",
      github: "GitHub",
      download: "Download",
    },
    controls: {
      language: "View in Chinese",
      theme: "Switch color theme",
    },
    hero: {
      eyebrow: "Native macOS utility",
      title: "Keep your Mac understandable.",
      description: "MachKit is a free, open-source Mac cleanup and utility app for storage analysis, app removal, system monitoring, networking, annotated screenshots, and 19 practical local tools.",
      primary: "Download for macOS",
      secondary: "View source",
      compatibility: "Free and open source · macOS 14 or later",
      previewAlt: "MachKit cleanup workspace showing local scan categories and the start scan action",
    },
    introduction: {
      kicker: "One practical workspace",
      title: "The useful system details macOS leaves scattered.",
      paragraphs: [
        "A storage question should not require jumping between Finder, System Settings, Activity Monitor, and Terminal. MachKit collects the information you actually need, explains it in plain language, and keeps the next action close by.",
        "It is not a one-click optimizer. You can inspect paths, sizes, processes, routes, related files, and the reason behind every cleanup recommendation before deciding what to do.",
        "MachKit is the project’s correct name; people also find it by searching for Mackit or Mach Kit. Whether you need a careful Mac cleaner, an annotated screenshot tool, or a collection of practical Mac tools, it is the same free open-source app.",
      ],
    },
    capabilities: {
      kicker: "What MachKit covers",
      title: "A focused tool for each part of your Mac.",
      description: "Use one area at a time, or move between them without losing context.",
      groups: [
        {
          tone: "blue",
          title: "Understand",
          body: "Start with a readable picture of the machine in front of you.",
          items: [
            ["Overview", "Storage health, CPU, memory pressure, network speed, thermal state, and quick actions."],
            ["Storage", "Disk categories, folder sizes, and large files with drill-down navigation.", "./features/storage-cleanup/"],
            ["Performance", "Live resource usage and the apps placing the most pressure on your Mac.", "./features/performance-monitor/"],
          ],
        },
        {
          tone: "green",
          title: "Maintain",
          body: "Recover space and remove software without hiding the details.",
          items: [
            ["Cleanup", "Caches, logs, old installers, developer files, and uninstall leftovers.", "./features/storage-cleanup/"],
            ["Apps", "Installed apps, command-line tools, and selectable related support files.", "./features/app-uninstaller/"],
            ["Safe removal", "Review uncertain items first; supported operations move files to Trash."],
          ],
        },
        {
          tone: "orange",
          title: "Inspect",
          body: "See the background activity that is usually difficult to find.",
          items: [
            ["Network", "Traffic, connections, listening ports, routes, VPN/TUN, and proxies.", "./features/network-inspector/"],
            ["System", "Login items, background tasks, application extensions, and possible residues.", "./features/system-inspector/"],
            ["Menu bar", "Quick access to MachKit features without hunting for the dock icon."],
          ],
        },
        {
          tone: "purple",
          title: "Utilities",
          body: "Keep capture and everyday helpers one shortcut away.",
          items: [
            ["Screenshot", "Capture a region from anywhere, annotate with shapes, arrows, highlight, mosaic, and text, then copy or save locally.", "./features/screenshot/"],
            ["Hosts Manager", "Inspect and switch shared or environment-specific host mappings.", "./utilities/"],
            ["Global shortcuts", "Open the tool list, a utility, or screenshot capture from anywhere on your Mac."],
          ],
        },
      ],
    },
    screens: {
      kicker: "Real product, real data",
      title: "Look closely before you act.",
      description: "Each workspace is designed around the question you are trying to answer, with the underlying detail still available when you need it.",
      tabs: {
        overview: {
          label: "Overview",
          title: "See what needs attention now.",
          features: [
            "Check disk capacity, available space, and overall storage health.",
            "Follow CPU, memory pressure, network speed, and thermal state live.",
            "Start a cleanup or open the most frequently used workspaces directly.",
          ],
          alt: "MachKit overview showing storage health, live status, and common tools",
        },
        cleanup: {
          label: "Cleanup",
          title: "Understand every cleanup candidate.",
          features: [
            "Scan caches, logs, old installers, developer files, and uninstall leftovers.",
            "Separate safe-to-clean content from findings that require review.",
            "Inspect file counts, sizes, and reasons before moving selected items to Trash.",
          ],
          alt: "MachKit cleanup results with safe and review categories",
        },
        apps: {
          label: "Apps",
          title: "See installed software in context.",
          features: [
            "Browse App Store, third-party, user, system, and command-line software.",
            "Search apps and inspect their version, location, source, and disk usage.",
            "Uninstall apps with selected related files or follow package-manager guidance.",
          ],
          alt: "MachKit apps workspace showing installed apps and software categories",
        },
        storage: {
          label: "Storage",
          title: "Follow disk usage down to the folder.",
          features: [
            "Compare used and available capacity across the system disk.",
            "Browse folders by size and move through the directory hierarchy.",
            "Analyze the home folder or choose another folder when you need a narrower view.",
          ],
          alt: "MachKit storage analysis showing folder sizes",
        },
        performance: {
          label: "Performance",
          title: "Understand pressure, not just percentages.",
          features: [
            "Monitor CPU, memory usage, pressure level, and thermal state live.",
            "Compare CPU and memory trends across the last 60 seconds.",
            "Find the apps using the most resources and release reclaimable memory.",
          ],
          alt: "MachKit Performance workspace showing CPU, memory, and resource-heavy apps",
        },
        network: {
          label: "Network",
          title: "Trace what your Mac is connected to.",
          features: [
            "Inspect active interfaces, addresses, and real-time upload and download speed.",
            "Review app traffic, active connections, listening ports, and routes.",
            "See the default interface, VPN/TUN devices, and current proxy state.",
          ],
          alt: "MachKit network overview showing interfaces and traffic",
        },
        tools: {
          label: "Tools",
          title: "Keep useful local utilities nearby.",
          features: [
            "Capture any screen region with a global shortcut, annotate it, and copy or save without leaving your current app.",
            "Manage hosts mappings for shared and environment-specific setups.",
            "Convert timestamps, format and query JSON, and encode or decode text.",
            "Search tools quickly and assign global keyboard shortcuts to frequent actions.",
          ],
          alt: "MachKit tools workspace with practical local utilities",
        },
        settings: {
          label: "Settings",
          title: "Keep the app aligned with your workflow.",
          features: [
            "Choose the app language and follow the system appearance or use a fixed theme.",
            "Control menu bar access and the global shortcuts used for tools and screenshots.",
            "Clear locally stored preferences and tool data when you want a fresh start.",
          ],
          alt: "MachKit settings showing language, appearance, shortcuts, and local data controls",
        },
        system: {
          label: "System",
          title: "Make background activity visible.",
          features: [
            "Review login items, registered background tasks, and application extensions.",
            "Search entries by application name, label, or source path.",
            "Open the relevant macOS settings or remove confirmed leftovers safely.",
          ],
          alt: "MachKit system workspace showing background activity",
        },
      },
    },
    safety: {
      kicker: "Designed for informed changes",
      title: "Useful automation, visible boundaries.",
      description: "MachKit automates the tedious discovery work, not the decision. Before a destructive action, it shows what will change and asks you to confirm it.",
      principles: [
        ["Local by default", "File metadata and scan results stay on your Mac. The app does not require an account or cloud service."],
        ["Conservative selection", "Uncertain cleanup findings are left unselected, protected locations are blocked, and paths are validated before removal."],
        ["Recoverable where possible", "Cleanup and app removal normally move selected files to Trash so they can be restored if needed."],
      ],
    },
    tools: {
      kicker: "Practical local utilities",
      title: "A growing toolkit on its own page.",
      description: "MachKit keeps focused utilities for text, data, images, networking, diagnostics, and everyday work in one searchable catalog—plus a native screenshot workflow you can trigger from anywhere. Every tool shares the app’s appearance, language, shortcuts, and local-first privacy model—and each utility has a clear introduction on the tools page.",
      principles: [
        ["One focused job", "Each utility solves a concrete, recurring task."],
        ["Native screenshot", "Region capture, annotation, mosaic, and clipboard export stay on your Mac."],
        ["Room to grow", "New tools join the catalog without adding another standalone app."],
      ],
      count: `${localizedWebsiteTools("en").length} tools across ${groupedWebsiteTools("en").length} categories`,
      preview: groupedWebsiteTools("en").map((group) => [
        group.category,
        `${group.tools.length} tools · ${group.tools.slice(0, 3).map((tool) => tool.title).join(", ")}`,
      ]),
      explore: "Open the tools page",
    },
    openSource: {
      kicker: "Open source",
      title: "The safety rules are part of the product.",
      description: "MachKit’s scan rules, protected-path checks, privileged operations, and release workflow are available to inspect. Issues and focused contributions are welcome.",
      primary: "Browse the code",
      secondary: "Download latest release",
    },
    footer: {
      description: "A native, privacy-first toolbox for understanding and maintaining your Mac.",
      platform: "macOS 14+",
      releases: "Releases",
      issues: "Issues",
      tools: "Tools",
      license: "MIT License",
      local: "Everything runs on your Mac",
    },
  },
  "zh-CN": {
    meta: {
      title: "MachKit — Mac 存储分析、应用卸载与系统工具",
      description: "免费开源的 macOS 系统工具，支持存储分析、安全清理、应用卸载、系统监控、网络检查、区域截图标注，以及持续增长的本地实用工具。",
    },
    nav: {
      capabilities: "功能",
      screens: "产品",
      safety: "安全",
      tools: "工具",
      github: "GitHub",
      download: "下载",
    },
    controls: {
      language: "View in English",
      theme: "切换颜色主题",
    },
    hero: {
      eyebrow: "原生 macOS 工具",
      title: "更清楚地了解和维护你的 Mac。",
      description: "MachKit 将存储、应用卸载、系统监控、网络、系统项目、垃圾清理和区域截图标注集中在一个清晰的工作区中，并提供一套持续增长的本地实用工具。",
      primary: "下载 macOS 版",
      secondary: "查看源码",
      compatibility: "免费且开源 · 需要 macOS 14 或更高版本",
      previewAlt: "MachKit 清理工作区，显示本地扫描分类和开始扫描操作",
    },
    introduction: {
      kicker: "一个实用的工作区",
      title: "把 macOS 分散的系统信息集中起来。",
      paragraphs: [
        "查看一次存储问题，不应该在访达、系统设置、活动监视器和终端之间反复切换。MachKit 整理真正有用的信息，用易懂的方式说明，并把下一步操作放在合适的位置。",
        "它不是一个含糊的一键优化器。你可以先查看路径、大小、进程、路由、关联文件以及每条清理建议的原因，再决定是否操作。",
        "项目的正确名称是 MachKit，也有人通过 Mackit 或 Mach Kit 找到它。无论你需要 Mac 清理、区域截图还是一组本地实用工具，指向的都是这款免费开源 App。",
      ],
    },
    capabilities: {
      kicker: "MachKit 可以做什么",
      title: "Mac 的每个部分，都有一个专注的工具。",
      description: "一次处理一个问题，也可以在不同功能之间保持上下文。",
      groups: [
        {
          tone: "blue",
          title: "了解",
          body: "先获得一张清晰、易读的当前系统概览。",
          items: [
            ["总览", "存储健康、CPU、内存压力、网速、散热状态和快捷操作。"],
            ["存储", "磁盘分类、文件夹大小和大文件，支持逐层查看。", "./features/storage-cleanup/"],
            ["性能", "实时资源使用情况，以及占用最高的应用。", "./features/performance-monitor/"],
          ],
        },
        {
          tone: "green",
          title: "维护",
          body: "释放空间、移除软件，同时保留必要的细节。",
          items: [
            ["垃圾清理", "缓存、日志、旧安装包、开发文件和卸载残留。", "./features/storage-cleanup/"],
            ["应用", "已安装 App、命令行工具和可选择的关联支持文件。", "./features/app-uninstaller/"],
            ["安全移除", "不确定项目先确认；支持的操作会将文件移入废纸篓。"],
          ],
        },
        {
          tone: "orange",
          title: "检查",
          body: "看清通常难以发现的后台活动。",
          items: [
            ["网络", "流量、连接、监听端口、路由、VPN/TUN 和代理。", "./features/network-inspector/"],
            ["系统", "登录项、后台任务、应用扩展和可能的残留。", "./features/system-inspector/"],
            ["菜单栏", "常驻菜单栏，快速打开功能，无需在程序坞里找图标。"],
          ],
        },
        {
          tone: "purple",
          title: "实用工具",
          body: "让截图标注和日常小工具随时可以打开。",
          items: [
            ["截图", "从任意位置框选屏幕区域，用形状、箭头、高亮、马赛克和文字标注，再本地复制或保存。", "./features/screenshot/"],
            ["Hosts 管理", "查看并切换公共或指定环境的 hosts 映射。", "./utilities/"],
            ["全局快捷键", "在 Mac 的任意位置打开工具列表、指定工具或截图。"],
          ],
        },
      ],
    },
    screens: {
      kicker: "真实产品，真实数据",
      title: "操作之前，先看清楚。",
      description: "每个工作区都围绕一个实际问题设计，同时在需要时保留底层细节。",
      tabs: {
        overview: {
          label: "总览",
          title: "快速找到现在值得关注的内容。",
          features: [
            "查看磁盘容量、可用空间和整体存储健康状态。",
            "实时了解 CPU、内存压力、网速和散热状态。",
            "直接开始清理，或打开最常用的功能工作区。",
          ],
          alt: "MachKit 总览界面，显示存储健康、实时状态和常用工具",
        },
        cleanup: {
          label: "清理",
          title: "理解每一个清理候选项。",
          features: [
            "扫描缓存、日志、旧安装包、开发文件和卸载残留。",
            "区分可安全清理的内容和需要确认的发现项。",
            "移动到废纸篓前查看文件数量、大小和发现原因。",
          ],
          alt: "MachKit 清理结果，包含安全项和需确认项",
        },
        apps: {
          label: "应用",
          title: "结合来源了解已安装的软件。",
          features: [
            "分类查看 App Store、第三方、用户、系统和命令行软件。",
            "搜索应用并检查版本、位置、来源和磁盘占用。",
            "卸载 App 与选中的关联文件，或查看包管理器处理建议。",
          ],
          alt: "MachKit 应用工作区，显示已安装应用和软件分类",
        },
        storage: {
          label: "存储",
          title: "从整块磁盘逐层找到占用空间的目录。",
          features: [
            "比较系统磁盘的已用空间和可用容量。",
            "按大小浏览文件夹，并沿着目录层级继续查看。",
            "分析个人文件夹，也可以选择其他目录缩小范围。",
          ],
          alt: "MachKit 存储分析，显示文件夹大小",
        },
        performance: {
          label: "性能",
          title: "理解系统压力，而不只是百分比。",
          features: [
            "实时监控 CPU、内存用量、压力等级和温度状态。",
            "对比最近 60 秒的 CPU 与内存变化趋势。",
            "找到资源占用最高的应用，并释放可回收内存。",
          ],
          alt: "MachKit 性能工作区，显示 CPU、内存和高占用应用",
        },
        network: {
          label: "网络",
          title: "看清你的 Mac 正在连接什么。",
          features: [
            "查看活动网络接口、地址和实时上传下载速度。",
            "检查应用流量、活动连接、监听端口和路由。",
            "了解默认接口、VPN/TUN 设备和当前代理状态。",
          ],
          alt: "MachKit 网络总览，显示接口和流量",
        },
        tools: {
          label: "工具",
          title: "让常用实用工具随时可用。",
          features: [
            "用全局快捷键框选任意屏幕区域，标注后复制或保存，无需离开当前 App。",
            "管理公共环境和指定环境的 Hosts 映射。",
            "转换时间戳、格式化和查询 JSON、编码或解码文本。",
            "快速搜索工具，并为常用操作设置全局键盘快捷键。",
          ],
          alt: "MachKit 工具工作区，包含实用的本地小工具",
        },
        settings: {
          label: "设置",
          title: "让应用适应你的使用习惯。",
          features: [
            "选择应用语言，并跟随系统外观或固定使用浅色、深色模式。",
            "管理菜单栏入口，以及工具列表和截图使用的全局快捷键。",
            "需要重新开始时，清除保存在本机的偏好设置与工具数据。",
          ],
          alt: "MachKit 设置，显示语言、外观、快捷键和本地数据选项",
        },
        system: {
          label: "系统",
          title: "看清后台活动。",
          features: [
            "检查登录项、已注册后台任务和应用扩展。",
            "按应用名称、标签或来源路径搜索项目。",
            "打开相关 macOS 设置，或安全移除已确认的残留。",
          ],
          alt: "MachKit 系统工作区，显示后台活动",
        },
      },
    },
    safety: {
      kicker: "为知情操作而设计",
      title: "实用的自动化，清晰的安全边界。",
      description: "MachKit 自动完成繁琐的发现工作，但不替你做决定。进行破坏性操作前，它会清楚展示变化并请求确认。",
      principles: [
        ["默认本地处理", "文件元数据和扫描结果始终留在 Mac 上，无需账户或云服务。"],
        ["保守选择", "不确定的清理项目默认不选中，受保护位置会被阻止，移除前会验证路径。"],
        ["尽量可恢复", "垃圾清理和应用卸载通常会把选中的文件移入废纸篓，必要时可以恢复。"],
      ],
    },
    tools: {
      kicker: "本地实用工具",
      title: "持续增长的工具箱，单独成页。",
      description: "MachKit 把文本、数据、图片、网络、诊断和日常工作中的专注小工具集中到一个可搜索的目录，并提供可从任意位置触发的原生截图标注流程。所有工具共享 App 的外观、语言、快捷键和本地优先隐私规则，并在工具页为每一个工具提供清晰介绍。",
      principles: [
        ["一次解决一个问题", "每个工具都针对一个明确、反复出现的任务。"],
        ["原生截图", "区域框选、标注、马赛克和剪贴板导出都留在本机完成。"],
        ["可以持续增长", "新增工具直接加入目录，不再增加另一个独立 App。"],
      ],
      count: `${localizedWebsiteTools("zh-CN").length} 个工具 · ${groupedWebsiteTools("zh-CN").length} 个分类`,
      preview: groupedWebsiteTools("zh-CN").map((group) => [
        group.category,
        `${group.tools.length} 个工具 · ${group.tools.slice(0, 3).map((tool) => tool.title).join("、")}`,
      ]),
      explore: "打开工具页面",
    },
    openSource: {
      kicker: "开源",
      title: "安全规则本身就是产品的一部分。",
      description: "MachKit 的扫描规则、受保护路径检查、特权操作和发布流程都可以检查。欢迎提交问题和范围明确的贡献。",
      primary: "查看源码",
      secondary: "下载最新版本",
    },
    footer: {
      description: "一款原生、隐私优先的 Mac 系统工具箱。",
      platform: "macOS 14+",
      releases: "版本发布",
      issues: "问题反馈",
      tools: "工具",
      license: "MIT 许可证",
      local: "所有处理都在你的 Mac 上完成",
    },
  },
};
