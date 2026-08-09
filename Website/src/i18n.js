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
        body: "Review caches, logs, app leftovers, and developer files before moving them to Trash.",
      },
      apps: {
        title: "Complete uninstall",
        body: "Find apps, command-line tools, and related support files for cleaner removal.",
      },
      storage: {
        title: "Storage insights",
        body: "See what uses disk space and drill into large folders.",
      },
      performance: {
        title: "Live performance",
        body: "Monitor CPU, memory pressure, and resource-heavy apps.",
      },
      network: {
        title: "Network",
        body: "View traffic, connections, listening ports, routes, VPN/TUN, and proxy status.",
      },
      system: {
        title: "System inventory",
        body: "Review login items, background activity, and extensions.",
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
        body: "检查缓存、日志、应用残留和开发文件，再移入废纸篓。",
      },
      apps: {
        title: "完整卸载",
        body: "查找 App、命令行工具及其支持文件，卸载更干净。",
      },
      storage: {
        title: "存储分析",
        body: "看清磁盘空间去向，并进入大目录继续查看。",
      },
      performance: {
        title: "实时性能",
        body: "监控 CPU、内存压力和高占用 App。",
      },
      network: {
        title: "网络",
        body: "查看流量、连接、监听端口、路由、VPN/TUN 和代理。",
      },
      system: {
        title: "系统盘点",
        body: "查看登录项、后台活动和扩展。",
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
