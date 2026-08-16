import { groupedWebsiteTools, localizedWebsiteTools } from "./tool-catalog.js";
import { fallbackRelease } from "./release.js";

export const site = Object.freeze({
  name: "MachKit",
  origin: "https://machkit.app",
  repositoryURL: "https://github.com/rhevorn/machkit",
  downloadURL: fallbackRelease.downloadURL,
});

export const supportedLocales = Object.freeze(["en", "zh-CN"]);

export const featurePages = Object.freeze([
  {
    id: "storage-cleanup",
    slug: "features/storage-cleanup",
    image: "cleanup.webp",
    locales: {
      en: {
        title: "Mac Storage Analysis & Safe Cleanup — MachKit",
        description: "Understand disk usage, inspect large folders, and clean regenerable caches, logs, installers, developer files, and app leftovers with conservative defaults.",
        eyebrow: "Storage and cleanup",
        heading: "Find what uses space before deciding what to remove.",
        lead: "MachKit combines a readable storage overview with an explainable cleanup scan. It helps you move from a full disk to the folders and candidates responsible without turning cleanup into a blind one-click action.",
        highlights: [
          ["Storage analysis", "Compare disk categories, browse folders by size, and drill into the directory hierarchy."],
          ["Explainable findings", "See the path, size, file count, age rule, and reason behind each cleanup candidate."],
          ["Conservative removal", "Uncertain findings stay unselected and supported removals normally go to Trash."],
        ],
        sections: [
          {
            title: "Follow disk usage from overview to folder",
            body: "Start with capacity and storage health, then inspect the home folder or choose a narrower location. MachKit keeps the directory context visible so large folders are understandable instead of appearing as an unexplained total.",
            items: ["Disk capacity and available space", "Folder sizes with hierarchical navigation", "Large files and practical category breakdowns"],
          },
          {
            title: "Clean only what the scan can explain",
            body: "Cleanup rules focus on content that is old, regenerable, or clearly associated with an uninstalled app. Protected paths are blocked, recent files are preserved by age limits, and review items are not selected automatically.",
            items: ["Caches, logs, old installers, and developer build files", "Uninstall leftovers separated for review", "Selected files moved to Trash where supported"],
          },
          {
            title: "Built for inspection, not a magic score",
            body: "MachKit does not claim that every cache is harmful or that a single number describes Mac health. It exposes the evidence and keeps the final decision with you.",
            items: ["No account or cloud scan", "File metadata stays on the Mac", "Visible safety boundaries before removal"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 存储分析与安全清理 — MachKit",
        description: "查看磁盘占用和大目录，并以保守默认规则清理可重新生成的缓存、日志、安装包、开发文件与应用卸载残留。",
        eyebrow: "存储与清理",
        heading: "先找到空间去了哪里，再决定要不要清理。",
        lead: "MachKit 把清晰的存储概览和可解释的清理扫描放在一起。从磁盘快满开始，逐层找到真正占用空间的目录与候选项，而不是把清理做成不可理解的一键操作。",
        highlights: [
          ["存储分析", "比较磁盘分类、按大小浏览目录，并沿文件夹层级继续查看。"],
          ["说明每项发现", "查看路径、大小、文件数量、时间规则以及被列为候选项的原因。"],
          ["保守移除", "不确定项目默认不选择，支持的移除操作通常会进入废纸篓。"],
        ],
        sections: [
          {
            title: "从磁盘概览逐层找到具体目录",
            body: "先查看容量、可用空间和存储健康，再分析个人文件夹或选择一个更明确的位置。MachKit 始终保留目录上下文，让大文件夹不再只是一个无法解释的数字。",
            items: ["磁盘容量与可用空间", "按大小排列并支持逐层导航的文件夹", "大文件和实用的存储分类"],
          },
          {
            title: "只清理能够说明原因的内容",
            body: "清理规则聚焦于过期、可重新生成，或明确属于已卸载应用的内容。受保护路径会被阻止，时间限制会保留近期文件，需要确认的项目不会自动勾选。",
            items: ["缓存、日志、旧安装包和开发构建文件", "单独列出需要确认的卸载残留", "支持的操作把所选文件移入废纸篓"],
          },
          {
            title: "用于检查，而不是制造一个魔法分数",
            body: "MachKit 不会宣称所有缓存都有问题，也不会用一个数字概括 Mac 的健康情况。它展示判断依据，并把最终决定留给你。",
            items: ["无需账户或云端扫描", "文件元数据留在本机", "移除前展示明确的安全边界"],
          },
        ],
      },
    },
  },
  {
    id: "app-uninstaller",
    slug: "features/app-uninstaller",
    image: "apps.webp",
    locales: {
      en: {
        title: "Mac App Uninstaller & Software Inventory — MachKit",
        description: "Browse installed Mac apps and command-line tools, inspect their source and disk usage, and uninstall apps with selected related support files.",
        eyebrow: "Apps and uninstall",
        heading: "Understand installed software before removing it.",
        lead: "MachKit brings applications, command-line tools, package-manager context, and possible related files into one inventory. You can see what is installed, where it came from, and what an uninstall would change.",
        highlights: [
          ["One inventory", "Browse App Store, third-party, user, system, and command-line software together."],
          ["Useful context", "Inspect version, location, source, disk usage, identifiers, and package-manager guidance."],
          ["Selective uninstall", "Review related support files and choose which confirmed items should be removed."],
        ],
        sections: [
          {
            title: "See more than an icon and an app name",
            body: "Search and filter installed software while keeping its path, version, source, and size available. Command-line tools are included so the inventory reflects the software developers and technical users actually maintain.",
            items: ["Application and command-line software categories", "Version, location, source, and disk usage", "Search across names, identifiers, and paths"],
          },
          {
            title: "Keep removal explicit",
            body: "Related preferences, caches, logs, containers, and support files are presented as selectable findings. MachKit does not silently remove every matching path, and package-managed software receives guidance appropriate to its manager.",
            items: ["Selectable related files", "Conservative residue detection", "Package-manager commands instead of invented deletion steps"],
          },
          {
            title: "Recoverable where macOS allows it",
            body: "Supported file removals normally move content to Trash. Protected locations and ambiguous binaries remain outside automatic removal so an uninstall stays understandable and reversible where possible.",
            items: ["Protected-path validation", "Ambiguous items require review", "No remote inventory upload"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 应用卸载与软件清单 — MachKit",
        description: "查看 Mac App 与命令行工具的来源、位置和磁盘占用，并在确认后连同选中的关联支持文件一起卸载。",
        eyebrow: "应用与卸载",
        heading: "移除软件之前，先弄清楚它安装了什么。",
        lead: "MachKit 将应用、命令行工具、包管理器信息和可能的关联文件整理成一份清单。你可以看清安装了什么、来自哪里，以及一次卸载会改变哪些内容。",
        highlights: [
          ["统一清单", "一起查看 App Store、第三方、用户、系统和命令行软件。"],
          ["实用信息", "检查版本、位置、来源、磁盘占用、标识符和包管理器建议。"],
          ["选择性卸载", "查看关联支持文件，只移除经过确认和选择的项目。"],
        ],
        sections: [
          {
            title: "不只显示图标和应用名称",
            body: "搜索和筛选已安装软件，同时保留路径、版本、来源和大小等信息。命令行工具也包含在内，让清单更符合开发者和技术用户实际维护的软件环境。",
            items: ["应用与命令行软件分类", "版本、位置、来源和磁盘占用", "按名称、标识符和路径搜索"],
          },
          {
            title: "让每一次移除都清楚明确",
            body: "偏好设置、缓存、日志、容器和支持文件会作为可选择的发现项展示。MachKit 不会静默删除所有相似路径；由包管理器安装的软件会提供对应的处理建议。",
            items: ["可选择的关联文件", "保守判断可能的残留", "优先提供包管理器命令，而不是猜测删除步骤"],
          },
          {
            title: "在 macOS 允许时保持可恢复",
            body: "支持的文件移除操作通常会进入废纸篓。受保护位置和含义不明确的二进制文件不会被自动处理，让卸载尽可能清楚且可恢复。",
            items: ["受保护路径验证", "不明确项目必须确认", "不上传软件清单"],
          },
        ],
      },
    },
  },
  {
    id: "network-inspector",
    slug: "features/network-inspector",
    image: "network.webp",
    locales: {
      en: {
        title: "Mac Network Inspector & Port Monitor — MachKit",
        description: "Inspect Mac network traffic, active connections, listening ports, routes, interfaces, VPN or TUN devices, proxies, and related processes locally.",
        eyebrow: "Network inspection",
        heading: "See how your Mac is connected, from speed to process.",
        lead: "MachKit collects the network details usually scattered across Activity Monitor, System Settings, and terminal commands, then presents them in one readable workspace without sending connection data elsewhere.",
        highlights: [
          ["Live activity", "Follow upload and download speed, active interfaces, and per-process traffic."],
          ["Connections and ports", "Inspect remote connections, listeners, protocols, addresses, and owning processes."],
          ["Routing context", "See default routes, interface selection, VPN or TUN devices, and proxy state."],
        ],
        sections: [
          {
            title: "Connect traffic to the process responsible",
            body: "Instead of showing only a total transfer rate, MachKit connects network activity with applications and processes. Filters make it easier to move from a busy connection to the executable and endpoint behind it.",
            items: ["Real-time upload and download rates", "Per-process traffic", "Local and remote endpoint details"],
          },
          {
            title: "Inspect listeners without memorizing commands",
            body: "Listening TCP ports and bound UDP ports are presented with protocol, address, process, and common service context. Process actions use safety checks and avoid system or unverified targets.",
            items: ["Listening TCP and bound UDP ports", "Common developer-service descriptions", "Protected process termination boundaries"],
          },
          {
            title: "Understand why traffic takes a route",
            body: "Review default and destination-specific routes alongside VPN, TUN, and proxy information. This makes common local development, corporate network, and debugging questions easier to answer.",
            items: ["Active interfaces and addresses", "Default and destination route lookup", "VPN, TUN, and proxy visibility"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 网络检查与端口监控 — MachKit",
        description: "在本机查看 Mac 网络流量、活动连接、监听端口、路由、接口、VPN/TUN 设备、代理以及相关进程。",
        eyebrow: "网络检查",
        heading: "从网速到进程，看清你的 Mac 如何连接网络。",
        lead: "MachKit 把通常分散在活动监视器、系统设置和终端命令中的网络信息整理进一个易读的工作区，而且不会把连接数据发送到其他地方。",
        highlights: [
          ["实时活动", "查看上传下载速度、活动接口和各进程的网络流量。"],
          ["连接与端口", "检查远程连接、监听服务、协议、地址和所属进程。"],
          ["路由上下文", "了解默认路由、接口选择、VPN/TUN 设备和代理状态。"],
        ],
        sections: [
          {
            title: "把网络流量对应到具体进程",
            body: "MachKit 不只显示一个总传输速度，还会把网络活动对应到应用和进程。通过筛选，可以从一条繁忙连接继续找到背后的可执行文件与目标地址。",
            items: ["实时上传与下载速率", "按进程统计的流量", "本地和远程端点信息"],
          },
          {
            title: "无需记忆命令也能检查监听端口",
            body: "监听中的 TCP 端口和已绑定的 UDP 端口会连同协议、地址、进程和常见服务说明一起展示。进程操作包含安全检查，并避开系统进程或无法验证的目标。",
            items: ["监听 TCP 与已绑定 UDP 端口", "常见开发服务说明", "受保护的进程结束边界"],
          },
          {
            title: "理解流量为什么走这条路由",
            body: "把默认路由、指定目标路由与 VPN、TUN、代理信息放在一起查看，更容易回答本地开发、公司网络和连接调试中的常见问题。",
            items: ["活动接口与地址", "默认路由和指定目标路由查询", "VPN、TUN 与代理状态"],
          },
        ],
      },
    },
  },
  {
    id: "utilities",
    slug: "utilities",
    image: "tools.webp",
    locales: {
      en: {
        title: "Practical Local Utilities for Mac — MachKit",
        description: "A growing collection of focused Mac utilities for text, data, images, networking, diagnostics, and everyday tasks—all running locally.",
        eyebrow: "A toolkit designed to grow",
        heading: "Small, practical tools should live in one dependable place.",
        lead: "MachKit is building a growing catalog of focused local utilities for text, data, images, networking, diagnostics, and everyday tasks. Each tool solves one concrete problem, shares the same native shell, language, theme, shortcuts, and privacy model, and stays close without becoming another browser tab or subscription.",
        highlights: [
          ["Useful by design", "Each utility starts with a real recurring task instead of a broad feature checklist."],
          ["One consistent system", "Tools share search, global shortcuts, appearance, localization, clipboard feedback, and local storage."],
          ["Ready to expand", "New utilities join the catalog without adding another standalone app or a different interaction model."],
        ],
        catalogTitle: "Every tool, with a clear introduction",
        catalogIntro: "Browse the full catalog by category. Each utility includes a short summary, a fuller introduction, and the concrete jobs it is meant to cover.",
        catalog: localizedWebsiteTools("en"),
        catalogGroups: groupedWebsiteTools("en"),
        sections: [
          {
            title: "Useful well beyond software development",
            body: "The catalog is not limited to programming syntax. It includes focused utilities that remove repetitive steps from writing, content handling, data preparation, networking, troubleshooting, and daily Mac use.",
            items: ["Text, data, and image tools", "Network and certificate inspection", "Everyday workflow helpers"],
          },
          {
            title: "Local, searchable, and one shortcut away",
            body: "Open the full tool list, search by name or keyword, or assign a global keyboard shortcut to a frequently used utility. Inputs remain local and tools do not require an account.",
            items: ["Tool catalog and keyword search", "Per-tool global shortcuts", "Local clipboard and preference integration"],
          },
          {
            title: "A shared foundation keeps growth coherent",
            body: "Common UI components, localization checks, theme tokens, native bridge contracts, and per-tool tests make it possible to add more utilities without every tool becoming its own inconsistent mini-app.",
            items: ["Shared typography and interaction patterns", "English, Chinese, Japanese, Korean, and European languages", "Input limits, error states, and automated tests"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 本地实用工具合集 — MachKit",
        description: "持续增长的 Mac 本地实用工具合集，覆盖文本、数据、图片、网络、诊断和日常任务，全部在本机运行。",
        eyebrow: "为持续扩展而设计的工具箱",
        heading: "小而实用的工具，应该集中在一个可靠的地方。",
        lead: "MachKit 正在建立一套持续增长的本地实用工具目录，覆盖文本、数据、图片、网络、诊断和日常任务。每个工具解决一个明确问题，并共享同一套原生窗口、语言、主题、快捷键和隐私规则，不必再增加浏览器标签、独立 App 或订阅。",
        highlights: [
          ["从实际需求出发", "每个工具都源于一个反复出现的具体任务，而不是为了堆砌功能。"],
          ["一致的使用方式", "工具共享搜索、全局快捷键、外观、多语言、复制反馈和本地存储。"],
          ["可以持续扩展", "新工具直接加入统一目录，不会变成另一个交互完全不同的独立 App。"],
        ],
        catalogTitle: "每个工具都有清晰介绍",
        catalogIntro: "按分类浏览完整目录。每个工具都包含简短摘要、完整介绍，以及它具体能解决哪些问题。",
        catalog: localizedWebsiteTools("zh-CN"),
        catalogGroups: groupedWebsiteTools("zh-CN"),
        sections: [
          {
            title: "用途不局限于软件开发",
            body: "工具目录不局限于编程语法。它也用于减少写作、内容处理、数据准备、网络检查、故障排查和日常 Mac 使用中的重复步骤。",
            items: ["文本、数据与图片工具", "网络与证书检查", "日常工作流辅助"],
          },
          {
            title: "本地处理、快速搜索、一个快捷键即可打开",
            body: "你可以打开完整工具列表、按名称或关键词搜索，也可以给常用工具设置全局键盘快捷键。输入内容留在本机，使用工具不需要账户。",
            items: ["工具目录与关键词搜索", "每个工具可配置全局快捷键", "本地剪贴板和偏好设置集成"],
          },
          {
            title: "共享基础让持续增长仍然保持一致",
            body: "统一的 UI 组件、多语言检查、主题变量、原生桥接协议和单工具测试，让更多工具可以持续加入，而不会变成一组互不一致的小网页。",
            items: ["统一字体与交互方式", "支持中英文、日韩及多种欧洲语言", "输入限制、错误状态和自动化测试"],
          },
        ],
      },
    },
  },
]);

export function localizedPath(page, locale) {
  const prefix = locale === "zh-CN" ? "/zh-CN" : "";
  return `${prefix}/${page.slug}/`;
}

export function localizedURL(page, locale) {
  return `${site.origin}${localizedPath(page, locale)}`;
}

export function findFeaturePage(pathname) {
  const normalized = pathname.endsWith("/") ? pathname : `${pathname}/`;
  for (const page of featurePages) {
    for (const locale of supportedLocales) {
      if (localizedPath(page, locale) === normalized) return { page, locale };
    }
  }
  return null;
}
