export const messages = {
  en: {
    meta: {
      title: "Sift — A native toolbox for your Mac",
      description: "Understand storage, uninstall apps, inspect performance and networks, manage system items, and use local developer tools from one open-source macOS app.",
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
      description: "Sift brings storage, app removal, performance, networking, system items, cleanup, and everyday developer utilities into one clear workspace.",
      primary: "Download for macOS",
      secondary: "View source",
      compatibility: "Free and open source · macOS 14 or later",
      previewAlt: "Sift overview showing storage health, live system status, and common tools",
    },
    introduction: {
      kicker: "One practical workspace",
      title: "The useful system details macOS leaves scattered.",
      paragraphs: [
        "A storage question should not require jumping between Finder, System Settings, Activity Monitor, and Terminal. Sift collects the information you actually need, explains it in plain language, and keeps the next action close by.",
        "It is not a one-click optimizer. You can inspect paths, sizes, processes, routes, related files, and the reason behind every cleanup recommendation before deciding what to do.",
      ],
    },
    capabilities: {
      kicker: "What Sift covers",
      title: "A focused tool for each part of your Mac.",
      description: "Use one area at a time, or move between them without losing context.",
      groups: [
        {
          tone: "blue",
          title: "Understand",
          body: "Start with a readable picture of the machine in front of you.",
          items: [
            ["Overview", "Storage health, CPU, memory pressure, network speed, thermal state, and quick actions."],
            ["Storage", "Disk categories, folder sizes, and large files with drill-down navigation."],
            ["Performance", "Live resource usage and the apps placing the most pressure on your Mac."],
          ],
        },
        {
          tone: "green",
          title: "Maintain",
          body: "Recover space and remove software without hiding the details.",
          items: [
            ["Cleanup", "Caches, logs, old installers, developer files, and uninstall leftovers."],
            ["Apps", "Installed apps, command-line tools, and selectable related support files."],
            ["Safe removal", "Review uncertain items first; supported operations move files to Trash."],
          ],
        },
        {
          tone: "orange",
          title: "Inspect",
          body: "See the background activity that is usually difficult to find.",
          items: [
            ["Network", "Traffic, connections, listening ports, routes, VPN/TUN, and proxies."],
            ["System", "Login items, background tasks, application extensions, and possible residues."],
            ["Menu bar", "CPU, memory, network speed, and quick access without opening the main window."],
          ],
        },
        {
          tone: "purple",
          title: "Build",
          body: "Keep small, frequently used developer utilities one shortcut away.",
          items: [
            ["Hosts Manager", "Inspect and switch shared or environment-specific host mappings."],
            ["Data tools", "Convert timestamps, format and query JSON, and encode or decode text."],
            ["Global shortcuts", "Open the tool list or a specific utility from anywhere on your Mac."],
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
          alt: "Sift overview showing storage health, live status, and common tools",
        },
        cleanup: {
          label: "Cleanup",
          title: "Understand every cleanup candidate.",
          features: [
            "Scan caches, logs, old installers, developer files, and uninstall leftovers.",
            "Separate safe-to-clean content from findings that require review.",
            "Inspect file counts, sizes, and reasons before moving selected items to Trash.",
          ],
          alt: "Sift cleanup results with safe and review categories",
        },
        apps: {
          label: "Apps",
          title: "See installed software in context.",
          features: [
            "Browse App Store, third-party, user, system, and command-line software.",
            "Search apps and inspect their version, location, source, and disk usage.",
            "Uninstall apps with selected related files or follow package-manager guidance.",
          ],
          alt: "Sift apps workspace showing installed apps and software categories",
        },
        storage: {
          label: "Storage",
          title: "Follow disk usage down to the folder.",
          features: [
            "Compare used and available capacity across the system disk.",
            "Browse folders by size and move through the directory hierarchy.",
            "Analyze the home folder or choose another folder when you need a narrower view.",
          ],
          alt: "Sift storage analysis showing folder sizes",
        },
        performance: {
          label: "Performance",
          title: "Understand pressure, not just percentages.",
          features: [
            "Monitor CPU, memory usage, pressure level, and thermal state live.",
            "Compare CPU and memory trends across the last 60 seconds.",
            "Find the apps using the most resources and release reclaimable memory.",
          ],
          alt: "Sift performance workspace showing CPU, memory, and resource-heavy apps",
        },
        network: {
          label: "Network",
          title: "Trace what your Mac is connected to.",
          features: [
            "Inspect active interfaces, addresses, and real-time upload and download speed.",
            "Review app traffic, active connections, listening ports, and routes.",
            "See the default interface, VPN/TUN devices, and current proxy state.",
          ],
          alt: "Sift network overview showing interfaces and traffic",
        },
        tools: {
          label: "Tools",
          title: "Keep everyday developer utilities nearby.",
          features: [
            "Manage hosts mappings for shared and environment-specific setups.",
            "Convert timestamps, format and query JSON, and encode or decode text.",
            "Search tools quickly and assign global keyboard shortcuts to frequent actions.",
          ],
          alt: "Sift developer tools workspace showing four local utilities",
        },
        system: {
          label: "System",
          title: "Make background activity visible.",
          features: [
            "Review login items, registered background tasks, and application extensions.",
            "Search entries by application name, label, or source path.",
            "Open the relevant macOS settings or remove confirmed leftovers safely.",
          ],
          alt: "Sift system workspace showing background activity",
        },
      },
    },
    safety: {
      kicker: "Designed for informed changes",
      title: "Useful automation, visible boundaries.",
      description: "Sift automates the tedious discovery work, not the decision. Before a destructive action, it shows what will change and asks you to confirm it.",
      principles: [
        ["Local by default", "File metadata and scan results stay on your Mac. The app does not require an account or cloud service."],
        ["Conservative selection", "Uncertain cleanup findings are left unselected, protected locations are blocked, and paths are validated before removal."],
        ["Recoverable where possible", "Cleanup and app removal normally move selected files to Trash so they can be restored if needed."],
      ],
    },
    tools: {
      kicker: "Local developer utilities",
      title: "Small tools without another website or subscription.",
      description: "Sift includes a growing set of focused utilities. They share the app’s appearance and language, run locally, and can be opened from the Tools workspace, the menu, or global shortcuts.",
      items: [
        ["Hosts Manager", "Manage shared and per-environment mappings with explicit write permission."],
        ["Timestamp Converter", "Convert dates and Unix timestamps across units and time zones."],
        ["JSON Formatter", "Format, minify, sort keys, and query values with path expressions."],
        ["Codec", "Base64, Base32, Base62, Hex, URL, HTML, Unicode, escape, and hash utilities."],
      ],
    },
    openSource: {
      kicker: "Open source",
      title: "The safety rules are part of the product.",
      description: "Sift’s scan rules, protected-path checks, privileged operations, and release workflow are available to inspect. Issues and focused contributions are welcome.",
      primary: "Browse the code",
      secondary: "Download latest release",
    },
    footer: {
      description: "A native, privacy-first toolbox for understanding and maintaining your Mac.",
      platform: "macOS 14+",
      releases: "Releases",
      issues: "Issues",
      license: "MIT License",
      local: "Everything runs on your Mac",
    },
  },
  "zh-CN": {
    meta: {
      title: "Sift — 原生 Mac 系统工具箱",
      description: "在一个开源 macOS App 中查看存储、卸载应用、检查性能与网络、管理系统项目，并使用本地开发者工具。",
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
      description: "Sift 将存储、应用卸载、性能、网络、系统项目、垃圾清理和常用开发者工具集中在一个清晰的工作区中。",
      primary: "下载 macOS 版",
      secondary: "查看源码",
      compatibility: "免费且开源 · 需要 macOS 14 或更高版本",
      previewAlt: "Sift 总览界面，显示存储健康、实时系统状态和常用工具",
    },
    introduction: {
      kicker: "一个实用的工作区",
      title: "把 macOS 分散的系统信息集中起来。",
      paragraphs: [
        "查看一次存储问题，不应该在访达、系统设置、活动监视器和终端之间反复切换。Sift 整理真正有用的信息，用易懂的方式说明，并把下一步操作放在合适的位置。",
        "它不是一个含糊的一键优化器。你可以先查看路径、大小、进程、路由、关联文件以及每条清理建议的原因，再决定是否操作。",
      ],
    },
    capabilities: {
      kicker: "Sift 可以做什么",
      title: "Mac 的每个部分，都有一个专注的工具。",
      description: "一次处理一个问题，也可以在不同功能之间保持上下文。",
      groups: [
        {
          tone: "blue",
          title: "了解",
          body: "先获得一张清晰、易读的当前系统概览。",
          items: [
            ["总览", "存储健康、CPU、内存压力、网速、散热状态和快捷操作。"],
            ["存储", "磁盘分类、文件夹大小和大文件，支持逐层查看。"],
            ["性能", "实时资源使用情况，以及占用最高的应用。"],
          ],
        },
        {
          tone: "green",
          title: "维护",
          body: "释放空间、移除软件，同时保留必要的细节。",
          items: [
            ["垃圾清理", "缓存、日志、旧安装包、开发文件和卸载残留。"],
            ["应用", "已安装 App、命令行工具和可选择的关联支持文件。"],
            ["安全移除", "不确定项目先确认；支持的操作会将文件移入废纸篓。"],
          ],
        },
        {
          tone: "orange",
          title: "检查",
          body: "看清通常难以发现的后台活动。",
          items: [
            ["网络", "流量、连接、监听端口、路由、VPN/TUN 和代理。"],
            ["系统", "登录项、后台任务、应用扩展和可能的残留。"],
            ["菜单栏", "无需打开主窗口即可查看 CPU、内存、网速和快捷操作。"],
          ],
        },
        {
          tone: "purple",
          title: "开发",
          body: "让常用的小型开发者工具随时可以打开。",
          items: [
            ["Hosts 管理", "查看并切换公共或指定环境的 hosts 映射。"],
            ["数据工具", "转换时间戳、格式化和查询 JSON、编码或解码文本。"],
            ["全局快捷键", "在 Mac 的任意位置打开工具列表或指定工具。"],
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
          alt: "Sift 总览界面，显示存储健康、实时状态和常用工具",
        },
        cleanup: {
          label: "清理",
          title: "理解每一个清理候选项。",
          features: [
            "扫描缓存、日志、旧安装包、开发文件和卸载残留。",
            "区分可安全清理的内容和需要确认的发现项。",
            "移动到废纸篓前查看文件数量、大小和发现原因。",
          ],
          alt: "Sift 清理结果，包含安全项和需确认项",
        },
        apps: {
          label: "应用",
          title: "结合来源了解已安装的软件。",
          features: [
            "分类查看 App Store、第三方、用户、系统和命令行软件。",
            "搜索应用并检查版本、位置、来源和磁盘占用。",
            "卸载 App 与选中的关联文件，或查看包管理器处理建议。",
          ],
          alt: "Sift 应用工作区，显示已安装应用和软件分类",
        },
        storage: {
          label: "存储",
          title: "从整块磁盘逐层找到占用空间的目录。",
          features: [
            "比较系统磁盘的已用空间和可用容量。",
            "按大小浏览文件夹，并沿着目录层级继续查看。",
            "分析个人文件夹，也可以选择其他目录缩小范围。",
          ],
          alt: "Sift 存储分析，显示文件夹大小",
        },
        performance: {
          label: "性能",
          title: "理解系统压力，而不只是百分比。",
          features: [
            "实时监控 CPU、内存用量、压力等级和温度状态。",
            "对比最近 60 秒的 CPU 与内存变化趋势。",
            "找到资源占用最高的应用，并释放可回收内存。",
          ],
          alt: "Sift 性能工作区，显示 CPU、内存和高占用应用",
        },
        network: {
          label: "网络",
          title: "看清你的 Mac 正在连接什么。",
          features: [
            "查看活动网络接口、地址和实时上传下载速度。",
            "检查应用流量、活动连接、监听端口和路由。",
            "了解默认接口、VPN/TUN 设备和当前代理状态。",
          ],
          alt: "Sift 网络总览，显示接口和流量",
        },
        tools: {
          label: "工具",
          title: "让常用开发者工具随时可用。",
          features: [
            "管理公共环境和指定环境的 Hosts 映射。",
            "转换时间戳、格式化和查询 JSON、编码或解码文本。",
            "快速搜索工具，并为常用操作设置全局键盘快捷键。",
          ],
          alt: "Sift 开发者工具工作区，显示四个本地工具",
        },
        system: {
          label: "系统",
          title: "看清后台活动。",
          features: [
            "检查登录项、已注册后台任务和应用扩展。",
            "按应用名称、标签或来源路径搜索项目。",
            "打开相关 macOS 设置，或安全移除已确认的残留。",
          ],
          alt: "Sift 系统工作区，显示后台活动",
        },
      },
    },
    safety: {
      kicker: "为知情操作而设计",
      title: "实用的自动化，清晰的安全边界。",
      description: "Sift 自动完成繁琐的发现工作，但不替你做决定。进行破坏性操作前，它会清楚展示变化并请求确认。",
      principles: [
        ["默认本地处理", "文件元数据和扫描结果始终留在 Mac 上，无需账户或云服务。"],
        ["保守选择", "不确定的清理项目默认不选中，受保护位置会被阻止，移除前会验证路径。"],
        ["尽量可恢复", "垃圾清理和应用卸载通常会把选中的文件移入废纸篓，必要时可以恢复。"],
      ],
    },
    tools: {
      kicker: "本地开发者工具",
      title: "小工具不必再打开一个网站或订阅一项服务。",
      description: "Sift 内置一组持续扩展的专注工具。它们与 App 共用外观和语言，在本地运行，并可从工具工作区、菜单或全局快捷键打开。",
      items: [
        ["Hosts 管理", "通过明确的写入权限管理公共和不同环境的映射。"],
        ["时间戳转换", "在不同单位和时区之间转换日期与 Unix 时间戳。"],
        ["JSON 格式化", "格式化、压缩、键排序，并用路径表达式查询数据。"],
        ["编解码", "支持 Base64、Base32、Base62、Hex、URL、HTML、Unicode、转义和 Hash。"],
      ],
    },
    openSource: {
      kicker: "开源",
      title: "安全规则本身就是产品的一部分。",
      description: "Sift 的扫描规则、受保护路径检查、特权操作和发布流程都可以检查。欢迎提交问题和范围明确的贡献。",
      primary: "查看源码",
      secondary: "下载最新版本",
    },
    footer: {
      description: "一款原生、隐私优先的 Mac 系统工具箱。",
      platform: "macOS 14+",
      releases: "版本发布",
      issues: "问题反馈",
      license: "MIT 许可证",
      local: "所有处理都在你的 Mac 上完成",
    },
  },
};
