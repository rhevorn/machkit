import {
  groupedWebsiteTools,
  localizedTool,
  localizedWebsiteTools,
  websiteToolCatalog,
} from "./tool-catalog.js";
import type {
  LocalizedToolGroup,
  LocalizedWebsiteTool,
  WebsiteTool,
} from "./tool-catalog.js";
import { fallbackRelease } from "./release.js";

export type SiteLocale = "en" | "zh-CN";

export type FeatureSection = {
  title: string;
  body: string;
  items: readonly string[];
};

export type FeaturePageLocaleCopy = {
  title: string;
  description: string;
  eyebrow: string;
  heading: string;
  lead: string;
  highlights: ReadonlyArray<readonly [string, string] | readonly string[]>;
  sections: readonly FeatureSection[];
  catalogTitle?: string;
  catalogIntro?: string;
  catalog?: readonly LocalizedWebsiteTool[];
  catalogGroups?: readonly LocalizedToolGroup[];
};

export type FeaturePage = {
  readonly id: string;
  readonly slug: string;
  readonly image: string;
  readonly kind?: "feature" | "tool";
  readonly locales: Record<SiteLocale, FeaturePageLocaleCopy>;
};

export const site = Object.freeze({
  name: "MachKit",
  origin: "https://machkit.app",
  repositoryURL: "https://github.com/rhevorn/machkit",
  downloadURL: fallbackRelease.downloadURL,
});

export const supportedLocales = Object.freeze(["en", "zh-CN"] as const satisfies readonly SiteLocale[]);

const primaryFeaturePages = Object.freeze([
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
    id: "screenshot",
    slug: "features/screenshot",
    image: "tools.webp",
    locales: {
      en: {
        title: "Mac Screenshot Tool with Local Annotation — MachKit",
        description: "Capture a screen region from a global shortcut, then annotate it with shapes, arrows, pen, highlight, mosaic, and text before copying or saving locally.",
        eyebrow: "Screenshot and annotation",
        heading: "Capture, annotate, and continue without leaving your current app.",
        lead: "MachKit provides a native Mac screenshot workflow for the moments when you need to explain what is on screen. Press the global shortcut, select a region in place, add the annotations you need, and finish directly to the clipboard or a PNG file.",
        highlights: [
          ["Region capture", "Select exactly the part of the screen you need without opening the MachKit window first."],
          ["Annotation in place", "Add rectangles, ellipses, arrows, freehand marks, highlights, mosaic, and multiple text labels."],
          ["Local export", "Press Return or confirm to copy the finished image, or save it as a PNG on your Mac."],
        ],
        sections: [
          {
            title: "Start from anywhere with one shortcut",
            body: "The default Command-Shift-A shortcut starts region capture over the app you are currently using. The desktop is captured once and stays visually stable while you select and annotate, so the MachKit main window does not interrupt the workflow.",
            items: ["Global Command-Shift-A shortcut", "Region selection over the current app", "Escape to cancel without saving"],
          },
          {
            title: "Use the right mark for the explanation",
            body: "Choose geometric shapes for structure, an arrow for direction, pen or highlight for emphasis, mosaic for sensitive areas, and text for context. Tool-specific size controls show the actual stroke or mosaic footprint before you draw.",
            items: ["Rectangle, ellipse, arrow, pen, and highlight", "6 px, 12 px, and 24 px drawing or mosaic sizes", "Multiple editable text labels without a background fill"],
          },
          {
            title: "Keep screen content on your Mac",
            body: "Capture and annotation are performed locally. MachKit does not upload the screenshot, require an account, or send the selected content to a cloud editor.",
            items: ["No cloud upload", "Copy directly to the clipboard", "Save a local PNG when needed"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 区域截图与本地标注工具 — MachKit",
        description: "使用全局快捷键框选屏幕区域，再用形状、箭头、画笔、高亮、马赛克和文字标注，最后在本地复制或保存。",
        eyebrow: "截图与标注",
        heading: "不用离开当前 App，完成截图、标注和复制。",
        lead: "MachKit 提供一套原生 Mac 区域截图流程，适合需要马上说明屏幕内容的时刻。按下全局快捷键，就地框选区域，添加需要的标注，再直接复制到剪贴板或保存为 PNG。",
        highlights: [
          ["区域框选", "不必先打开 MachKit 主窗口，直接选择真正需要的屏幕内容。"],
          ["就地标注", "添加矩形、椭圆、箭头、涂鸦、高亮、马赛克和多个文字标签。"],
          ["本地导出", "按回车或点击确认即可复制成图，也可以在 Mac 上保存为 PNG。"],
        ],
        sections: [
          {
            title: "从任意 App 用一个快捷键开始",
            body: "默认的 Command-Shift-A 快捷键会在当前 App 上方启动区域截图。桌面只捕获一次，并在框选和标注期间保持画面稳定，MachKit 主窗口不会打断当前流程。",
            items: ["全局 Command-Shift-A 快捷键", "直接框选当前 App 的内容", "按 Escape 取消且不保存"],
          },
          {
            title: "根据说明内容选择合适的标注",
            body: "用几何形状标出结构、用箭头指示方向、用画笔或高亮强调重点、用马赛克遮挡敏感内容，再用文字补充上下文。每种工具的大小选项都会展示实际笔触或马赛克范围。",
            items: ["矩形、椭圆、箭头、画笔与高亮", "6 px、12 px、24 px 画笔或马赛克大小", "可添加多个、没有背景色的文字标签"],
          },
          {
            title: "让屏幕内容留在你的 Mac 上",
            body: "截图与标注都在本机完成。MachKit 不上传截图、不要求账户，也不会把选择的内容发送到云端编辑器。",
            items: ["无需上传到云端", "直接复制到剪贴板", "需要时保存本地 PNG"],
          },
        ],
      },
    },
  },
  {
    id: "performance-monitor",
    slug: "features/performance-monitor",
    image: "performance.webp",
    locales: {
      en: {
        title: "Mac Performance Monitor for CPU & Memory — MachKit",
        description: "Monitor CPU, memory pressure, thermal state, disk and network throughput, and resource-heavy Mac apps locally in one native workspace.",
        eyebrow: "Performance monitoring",
        heading: "Understand system pressure, not just isolated percentages.",
        lead: "MachKit combines live CPU, memory, thermal, disk, network, and per-app activity in one native Mac performance view. Sampling stays local and pauses when the relevant workspace is no longer active.",
        highlights: [
          ["Live system state", "Follow CPU, memory pressure, thermal state, disk throughput, and network throughput."],
          ["Application context", "Find running apps using the most CPU, memory, or network capacity."],
          ["Efficient sampling", "Reuse shared baselines and slow inactive refreshes to avoid becoming the workload being measured."],
        ],
        sections: [
          {
            title: "See pressure alongside usage",
            body: "CPU percentages are only one part of performance. MachKit places processor activity next to memory pressure, physical memory, compressed memory, and thermal state so a slowdown has useful context.",
            items: ["System and per-core CPU activity", "Used, cached, and compressed memory", "Memory pressure and thermal state"],
          },
          {
            title: "Connect resource use to running apps",
            body: "Per-application rankings help identify the software responsible for current pressure. Helper processes inside an app bundle can be grouped with the parent application where the operating system exposes enough context.",
            items: ["Per-app CPU and memory", "Application network activity", "Readable app identity instead of PID-only output"],
          },
          {
            title: "Keep monitoring local and proportionate",
            body: "Metrics come from macOS APIs and local system tools. MachKit does not upload performance samples, and inactive views reduce their refresh cadence instead of continuously performing full snapshots.",
            items: ["No telemetry or cloud dashboard", "Shared sampling baselines", "Reduced work while the app or page is inactive"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac CPU、内存与性能监控 — MachKit",
        description: "在一个原生工作区中，本地查看 CPU、内存压力、散热状态、磁盘与网络吞吐，以及资源占用较高的 Mac App。",
        eyebrow: "性能监控",
        heading: "理解系统压力，而不只是几个孤立的百分比。",
        lead: "MachKit 在一个原生 Mac 性能界面中整合 CPU、内存、散热、磁盘、网络和应用活动。采样始终留在本机，离开相关工作区后会暂停或降低刷新频率。",
        highlights: [
          ["实时系统状态", "查看 CPU、内存压力、散热状态、磁盘吞吐和网络吞吐。"],
          ["对应具体应用", "找到当前占用 CPU、内存或网络资源最多的运行中 App。"],
          ["克制的采样", "复用共享基线并降低非活动状态刷新频率，避免监控本身成为负担。"],
        ],
        sections: [
          {
            title: "把压力和使用量放在一起看",
            body: "CPU 百分比只是性能的一部分。MachKit 将处理器活动、内存压力、物理内存、压缩内存和散热状态放在一起，为卡顿提供更有用的上下文。",
            items: ["系统与各核心 CPU 活动", "已用、缓存与压缩内存", "内存压力与散热状态"],
          },
          {
            title: "把资源使用对应到运行中的 App",
            body: "应用排行帮助找到当前压力来自哪里。在系统能够提供足够上下文时，位于 App 包内的辅助进程会归并到对应应用。",
            items: ["各 App 的 CPU 与内存", "应用网络活动", "显示可读的 App 身份，而不只是 PID"],
          },
          {
            title: "让监控保持本地且适度",
            body: "指标来自 macOS API 和本地系统工具。MachKit 不上传性能样本，非活动界面会降低刷新频率，而不是持续进行完整采样。",
            items: ["没有遥测或云端面板", "共享采样基线", "App 或页面不活动时减少工作量"],
          },
        ],
      },
    },
  },
  {
    id: "system-inspector",
    slug: "features/system-inspector",
    image: "system.webp",
    locales: {
      en: {
        title: "Mac Login Items & Background Activity Inspector — MachKit",
        description: "Inspect Mac login items, registered background tasks, application extensions, source paths, and confirmed leftovers from one local system workspace.",
        eyebrow: "System inspection",
        heading: "Make background activity visible before changing it.",
        lead: "MachKit organizes login items, background registrations, application extensions, and possible leftovers into a searchable local inventory. It keeps source paths and ownership context visible before offering a system setting or removal action.",
        highlights: [
          ["Unified inventory", "Review login items, background activity, and app extensions without hunting through separate settings."],
          ["Source context", "Search by application, label, identifier, or path and see where an entry comes from."],
          ["Conservative action", "Open the relevant macOS setting or remove only confirmed, policy-approved leftovers."],
        ],
        sections: [
          {
            title: "Bring scattered registrations together",
            body: "Background software can appear through several macOS mechanisms. MachKit groups the available records by purpose while retaining the labels, paths, application identity, and status needed to understand them.",
            items: ["Login items and launch registrations", "Registered background activity", "Application and system extensions"],
          },
          {
            title: "Search with the original source still visible",
            body: "Filtering does not reduce an entry to a friendly label alone. Source paths and owning applications remain available so similarly named items can be distinguished before any action.",
            items: ["Search names, labels, identifiers, and paths", "Reveal related files where supported", "Open the relevant macOS settings"],
          },
          {
            title: "Avoid turning inspection into blind removal",
            body: "MachKit separates active registrations from likely remnants and validates removal targets against its safety policy. Ambiguous or protected entries remain outside automatic removal.",
            items: ["Clear active-versus-leftover status", "Protected-path and ownership checks", "Trash-first removal where supported"],
          },
        ],
      },
      "zh-CN": {
        title: "Mac 登录项与后台活动检查 — MachKit",
        description: "在一个本地系统工作区中检查 Mac 登录项、已注册后台任务、应用扩展、来源路径和经过确认的残留。",
        eyebrow: "系统检查",
        heading: "先让后台活动变得可见，再决定是否改变它。",
        lead: "MachKit 将登录项、后台注册、应用扩展和可能的残留整理成可搜索的本地清单。在打开系统设置或提供移除操作前，始终保留来源路径和所属应用等上下文。",
        highlights: [
          ["统一清单", "不用在多处设置之间寻找，即可检查登录项、后台活动和应用扩展。"],
          ["保留来源", "按应用、标签、标识符或路径搜索，并看清每个项目来自哪里。"],
          ["保守操作", "打开对应的 macOS 设置，或只移除经过确认且符合安全策略的残留。"],
        ],
        sections: [
          {
            title: "集中查看分散的系统注册",
            body: "后台软件可能通过多种 macOS 机制出现。MachKit 按用途整理系统能够提供的记录，同时保留理解它们所需的标签、路径、应用身份和状态。",
            items: ["登录项与启动注册", "已注册后台活动", "应用扩展与系统扩展"],
          },
          {
            title: "搜索时仍然看得到原始来源",
            body: "筛选不会只留下一个友好名称。来源路径和所属应用仍然可见，因此可以在操作前区分名称相近的项目。",
            items: ["搜索名称、标签、标识符和路径", "在支持时显示关联文件", "打开对应的 macOS 设置"],
          },
          {
            title: "不要把检查变成盲目移除",
            body: "MachKit 区分活动中的注册和可能的残留，并通过安全策略验证移除目标。含义不明确或受保护的项目不会进入自动移除。",
            items: ["明确区分活动项目与残留", "受保护路径与所有权检查", "支持时优先移入废纸篓"],
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
        title: "19 Practical Mac Tools in One Local App — MachKit",
        description: "Use 19 focused Mac tools for text, data, images, networking, security, diagnostics, and everyday tasks. Everything runs locally in one native app.",
        eyebrow: "A toolkit designed to grow",
        heading: "Small, practical tools should live in one dependable place.",
        lead: "MachKit brings 19 focused Mac tools into one native, searchable catalog for text, data, images, networking, security, diagnostics, and everyday tasks. Alongside that catalog, a native screenshot workflow lets you capture any region from a global shortcut, annotate with shapes, arrows, highlight, mosaic, and text, then copy or save—without another window or cloud upload. Each tool shares the same shell, language, theme, shortcuts, and privacy model.",
        highlights: [
          ["Native screenshot", "Freeze the desktop, annotate in place, and export to the clipboard or a file—entirely on your Mac."],
          ["Useful by design", "Each utility starts with a real recurring task instead of a broad feature checklist."],
          ["One consistent system", "Tools share search, global shortcuts, appearance, localization, clipboard feedback, and local storage."],
        ],
        catalogTitle: "Every tool, with a clear introduction",
        catalogIntro: "Browse the full catalog by category. Each utility includes a short summary, a fuller introduction, and the concrete jobs it is meant to cover.",
        catalog: localizedWebsiteTools("en"),
        catalogGroups: groupedWebsiteTools("en"),
        sections: [
          {
            title: "Capture and annotate without leaving your flow",
            body: "MachKit’s screenshot tool is built for the moment you need to explain something on screen. Trigger it from a global shortcut, drag a region, mark it up with rectangles, ellipses, arrows, pen, highlight, mosaic, or text, then copy or save. The capture stays local and does not require opening the main window.",
            items: ["Global shortcut region capture", "Shapes, arrows, highlight, mosaic, and text", "Copy to clipboard or save a PNG"],
          },
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
        ],
      },
      "zh-CN": {
        title: "Mac 本地实用工具合集 — MachKit",
        description: "持续增长的 Mac 本地实用工具合集，覆盖文本、数据、图片、网络、诊断和日常任务，并提供可标注的原生区域截图，全部在本机运行。",
        eyebrow: "为持续扩展而设计的工具箱",
        heading: "小而实用的工具，应该集中在一个可靠的地方。",
        lead: "MachKit 正在建立一套持续增长的本地实用工具目录，覆盖文本、数据、图片、网络、诊断和日常任务。同时，原生截图流程支持用全局快捷键框选任意区域，再用形状、箭头、高亮、马赛克和文字标注，然后复制或保存——不必另开窗口，也不会上传到云端。每个工具共享同一套原生窗口、语言、主题、快捷键和隐私规则。",
        highlights: [
          ["原生截图", "冻结桌面、就地标注，再导出到剪贴板或文件，全程留在本机。"],
          ["从实际需求出发", "每个工具都源于一个反复出现的具体任务，而不是为了堆砌功能。"],
          ["一致的使用方式", "工具共享搜索、全局快捷键、外观、多语言、复制反馈和本地存储。"],
        ],
        catalogTitle: "每个工具都有清晰介绍",
        catalogIntro: "按分类浏览完整目录。每个工具都包含简短摘要、完整介绍，以及它具体能解决哪些问题。",
        catalog: localizedWebsiteTools("zh-CN"),
        catalogGroups: groupedWebsiteTools("zh-CN"),
        sections: [
          {
            title: "不打断当前工作流的截图与标注",
            body: "MachKit 的截图功能面向你需要马上说明屏幕内容的时刻。用全局快捷键唤起，拖选区域，用矩形、椭圆、箭头、画笔、高亮、马赛克或文字标注，再复制或保存。截图留在本机，也不必打开主窗口。",
            items: ["全局快捷键区域截图", "形状、箭头、高亮、马赛克与文字", "复制到剪贴板或保存 PNG"],
          },
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
        ],
      },
    },
  },
]);

function toolFeaturePage(tool: WebsiteTool): FeaturePage {
  const en = localizedTool(tool, "en");
  const zh = localizedTool(tool, "zh-CN");
  return Object.freeze({
    id: `tool-${tool.id}`,
    slug: `tools/${tool.id}`,
    image: "tools.webp",
    kind: "tool",
    locales: {
      en: {
        title: `${en.title} for Mac — Local Utility in MachKit`,
        description: `${en.summary} Use it locally in the free, open-source MachKit app for macOS.`,
        eyebrow: en.category,
        heading: `${en.title}, available locally on your Mac.`,
        lead: en.introduction,
        highlights: en.highlights.map((highlight, index) => [
          highlight,
          index === 0
            ? `Start the core ${en.title} workflow without leaving the MachKit toolbox.`
            : index === 1
              ? "Keep the working input and generated result on the Mac."
              : "Copy or continue with the result from the same consistent utility window.",
        ]),
        sections: [
          {
            title: `What ${en.title} is designed to do`,
            body: en.introduction,
            items: en.highlights,
          },
          {
            title: "Keep sensitive working data out of online converters",
            body: "MachKit runs this utility as bundled local content. It does not require an account, analytics service, remote script, or cloud storage for the tool input.",
            items: ["Bundled with the native Mac app", "No analytics or advertising", "No upload required for local transformations"],
          },
          {
            title: "Use one utility without installing another standalone app",
            body: `${en.title} shares MachKit’s searchable tool catalog, light and dark appearance, localization, clipboard feedback, and configurable global shortcuts.`,
            items: [`Part of the ${en.category} category`, "Searchable from the MachKit tools workspace", "Available through an optional global shortcut"],
          },
        ],
      },
      "zh-CN": {
        title: `${zh.title} Mac 本地工具 — MachKit`,
        description: `${zh.summary} 在免费开源的 MachKit macOS App 中本地使用。`,
        eyebrow: zh.category,
        heading: `在 Mac 本机使用${zh.title}。`,
        lead: zh.introduction,
        highlights: zh.highlights.map((highlight, index) => [
          highlight,
          index === 0
            ? `无需离开 MachKit 工具箱即可开始${zh.title}的核心流程。`
            : index === 1
              ? "输入内容和生成结果始终留在当前 Mac。"
              : "在同一套一致的工具窗口中复制结果或继续处理。",
        ]),
        sections: [
          {
            title: `${zh.title}用于解决什么问题`,
            body: zh.introduction,
            items: zh.highlights,
          },
          {
            title: "避免把工作内容交给在线转换网站",
            body: "MachKit 将这个工具作为本地内容打包运行。处理输入时不需要账户、分析服务、远程脚本或云端存储。",
            items: ["随原生 Mac App 本地打包", "没有分析和广告", "本地转换无需上传"],
          },
          {
            title: "无需再安装一个独立小工具",
            body: `${zh.title}与 MachKit 的工具搜索、深浅色外观、多语言、复制反馈和可配置全局快捷键共用同一套体验。`,
            items: [`属于${zh.category}分类`, "可从 MachKit 工具工作区搜索", "可以配置全局快捷键"],
          },
        ],
      },
    },
  });
}

export const toolFeaturePages = Object.freeze(
  websiteToolCatalog.map((tool) => toolFeaturePage(tool)),
);

export const featurePages = Object.freeze([
  ...primaryFeaturePages,
  ...toolFeaturePages,
]);

export function localizedPath(page: Pick<FeaturePage, "slug">, locale: SiteLocale): string {
  const prefix = locale === "zh-CN" ? "/zh-CN" : "";
  return `${prefix}/${page.slug}/`;
}

export function localizedURL(page: Pick<FeaturePage, "slug">, locale: SiteLocale): string {
  return `${site.origin}${localizedPath(page, locale)}`;
}

export function findFeaturePage(
  pathname: string,
): { page: FeaturePage; locale: SiteLocale } | null {
  const normalized = pathname.endsWith("/") ? pathname : `${pathname}/`;
  for (const page of featurePages as readonly FeaturePage[]) {
    for (const locale of supportedLocales) {
      if (localizedPath(page, locale) === normalized) return { page, locale };
    }
  }
  return null;
}
