export const supportedLocales = [
  { code: "en", nativeName: "English" },
  { code: "zh-CN", nativeName: "简体中文" },
];

export const messages = {
  en: {
    nav: {
      features: "Features",
      safety: "Safety",
      github: "GitHub",
      download: "Download",
    },
    controls: {
      language: "Choose language",
      theme: "Switch color theme",
    },
    hero: {
      eyebrow: "Open source · Built for macOS",
      title: "A clearer view of your Mac.",
      description: "Understand storage, clean up safely, and manage the details macOS leaves scattered — all from one native app.",
      primary: "Download for macOS",
      secondary: "View on GitHub",
      compatibility: "macOS 14 or later · Free and open source",
    },
    productPreviewLabel: "Sift product preview",
    productPreviewAlt: "Sift showing a clear overview of Mac storage, memory, and network activity",
    trust: {
      label: "Privacy and safety principles",
      localTitle: "Local by default",
      localBody: "Your files stay on your Mac.",
      controlTitle: "You stay in control",
      controlBody: "Nothing is removed without your approval.",
      previewTitle: "Review before cleanup",
      previewBody: "See exactly what will change.",
    },
    features: {
      kicker: "Everything in one place",
      title: "The tools your Mac should already have.",
      description: "From disk space to network routes, Sift turns scattered system details into clear, useful actions.",
      cleanup: {
        title: "Safe cleanup",
        body: "Review caches, logs, installers, and developer files before moving anything to Trash.",
      },
      apps: {
        title: "Complete uninstall",
        body: "Find installed apps and their related support files, including command-line tools.",
      },
      storage: {
        title: "Storage insights",
        body: "See where space is going, browse large folders, and reveal files directly in Finder.",
      },
      performance: {
        title: "Live performance",
        body: "Track CPU, memory pressure, and resource-heavy apps without noisy background work.",
      },
      network: {
        title: "Network diagnostics",
        body: "Inspect traffic, connections, listening ports, routes, VPN/TUN interfaces, and system proxies.",
      },
      system: {
        title: "System inventory",
        body: "Review login items, background activity, and extensions from one focused view.",
      },
    },
    showcase: {
      kicker: "Clarity before cleanup",
      title: "Know exactly what will change.",
      description: "Sift separates safe, regenerable files from items that deserve a closer look. Nothing is hidden behind a single mysterious “clean” button.",
      points: [
        "Clear safe and review categories",
        "File counts, sizes, and plain-language reasons",
        "Uncertain items stay unselected by default",
      ],
      alt: "Sift cleanup results with safe and review categories",
    },
    closing: {
      kicker: "Free and open source",
      title: "Ready for a clearer Mac?",
      description: "Download the latest release and see what Sift finds.",
      action: "Download latest release",
    },
    footer: {
      description: "A privacy-first utility that makes your Mac easier to understand and maintain.",
      platform: "Native for macOS 14+",
      product: "Product",
      project: "Project",
      releases: "Releases",
      issues: "Issues",
      local: "Your data stays on your Mac",
    },
  },
  "zh-CN": {
    nav: {
      features: "功能",
      safety: "安全",
      github: "GitHub",
      download: "下载",
    },
    controls: {
      language: "选择语言",
      theme: "切换颜色主题",
    },
    hero: {
      eyebrow: "开源软件 · 专为 macOS 打造",
      title: "更清楚地了解你的 Mac。",
      description: "看懂存储占用，安全清理垃圾，集中管理 macOS 中散落的系统信息——一个原生 App 就够了。",
      primary: "下载 macOS 版",
      secondary: "在 GitHub 查看",
      compatibility: "需要 macOS 14 或更高版本 · 免费且开源",
    },
    productPreviewLabel: "Sift 产品预览",
    productPreviewAlt: "Sift 总览界面，显示存储、内存和网络活动",
    trust: {
      label: "隐私与安全原则",
      localTitle: "默认本地处理",
      localBody: "你的文件始终留在 Mac 上。",
      controlTitle: "控制权归你",
      controlBody: "未经确认，不会移除任何内容。",
      previewTitle: "清理前先检查",
      previewBody: "每项改动都清楚可见。",
    },
    features: {
      kicker: "集中于一处",
      title: "这些工具，本该是 Mac 自带的。",
      description: "从磁盘空间到网络路由，Sift 将分散的系统信息整理成清晰、可执行的操作。",
      cleanup: {
        title: "安全清理",
        body: "先检查缓存、日志、安装包和开发文件，再将内容移入废纸篓。",
      },
      apps: {
        title: "完整卸载",
        body: "查找已安装 App 及其相关支持文件，也包括命令行工具。",
      },
      storage: {
        title: "存储分析",
        body: "了解空间去向，浏览大目录，并可直接在 Finder 中定位文件。",
      },
      performance: {
        title: "实时性能",
        body: "查看 CPU、内存压力和高占用 App，不在后台制造额外负担。",
      },
      network: {
        title: "网络诊断",
        body: "查看流量、活跃连接、监听端口、路由、VPN/TUN 网卡和系统代理。",
      },
      system: {
        title: "系统盘点",
        body: "在一个专注的界面中查看登录项、后台活动和扩展。",
      },
    },
    showcase: {
      kicker: "清理之前，先看清楚",
      title: "准确知道将要发生什么。",
      description: "Sift 会区分可安全重新生成的文件和需要进一步判断的内容，不会用一个含糊的「一键清理」隐藏细节。",
      points: [
        "清晰区分安全项与需确认项",
        "展示文件数量、大小和易懂的判断依据",
        "不确定的项目默认不勾选",
      ],
      alt: "Sift 清理结果，包含安全项与需确认分类",
    },
    closing: {
      kicker: "免费且开源",
      title: "准备好让 Mac 更清爽了吗？",
      description: "下载最新版本，看看 Sift 能发现什么。",
      action: "下载最新版本",
    },
    footer: {
      description: "一款隐私优先的实用工具，让你的 Mac 更容易理解和维护。",
      platform: "原生支持 macOS 14+",
      product: "产品",
      project: "项目",
      releases: "版本发布",
      issues: "问题反馈",
      local: "你的数据始终留在 Mac 上",
    },
  },
};
