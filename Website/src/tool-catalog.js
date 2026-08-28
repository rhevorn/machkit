export const toolCategoryOrder = Object.freeze([
  "text-data",
  "network",
  "media",
  "system",
]);

export const toolCategories = Object.freeze({
  "text-data": Object.freeze({
    en: "Text & Data",
    "zh-CN": "文本与数据",
  }),
  network: Object.freeze({
    en: "Network & Security",
    "zh-CN": "网络与安全",
  }),
  media: Object.freeze({
    en: "Images & Color",
    "zh-CN": "图像与颜色",
  }),
  system: Object.freeze({
    en: "System Helpers",
    "zh-CN": "系统辅助",
  }),
});

function tool(entry) {
  return Object.freeze(entry);
}

export const websiteToolCatalog = Object.freeze([
  tool({
    id: "hosts-manager",
    category: "network",
    en: {
      title: "Hosts Manager",
      summary: "Inspect the current hosts file and switch shared or environment-specific mappings with explicit write permission.",
      introduction: "Hosts Manager keeps environment-specific hostname mappings visible in one place. Review the active hosts file, compare shared profiles, and apply a switch only after macOS grants write permission—so local development and staging setups stay intentional instead of buried in Terminal edits.",
      highlights: [
        "View the active system hosts file",
        "Switch shared or environment-specific mappings",
        "Require explicit permission before writing",
      ],
    },
    "zh-CN": {
      title: "Hosts 管理",
      summary: "查看当前 hosts 文件，并在明确授权后切换公共或指定环境的映射。",
      introduction: "Hosts 管理把不同环境的主机名映射集中展示。你可以查看当前 hosts 文件、对比共享配置，并在 macOS 明确授权后再切换映射，让本机开发与联调环境的切换更清楚，而不是散落在终端里反复编辑。",
      highlights: [
        "查看当前系统 hosts 文件",
        "切换公共或指定环境映射",
        "写入前需要明确授权",
      ],
    },
  }),
  tool({
    id: "timestamp-converter",
    category: "text-data",
    en: {
      title: "Timestamp Converter",
      summary: "Convert Unix timestamps and standard date formats across units, time zones, and common interchange formats.",
      introduction: "Timestamp Converter turns Unix epochs, ISO strings, and everyday date formats into each other without leaving the Mac. Switch units and time zones, copy the result you need, and keep debugging logs or API payloads free of mental math and timezone mistakes.",
      highlights: [
        "Unix timestamps and standard date formats",
        "Unit and time-zone conversion",
        "Copy-ready interchange values",
      ],
    },
    "zh-CN": {
      title: "时间戳转换",
      summary: "在不同单位、时区、Unix 时间戳和常见标准日期格式之间转换。",
      introduction: "时间戳转换在本机完成 Unix 时间戳、ISO 字符串和常用日期格式之间的互转。可切换单位与时区，并直接复制结果，减少读日志或处理 API 数据时的心算和时区错误。",
      highlights: [
        "Unix 时间戳与标准日期格式",
        "单位与时区转换",
        "可直接复制的结果",
      ],
    },
  }),
  tool({
    id: "json-formatter",
    category: "text-data",
    en: {
      title: "JSON Formatter",
      summary: "Format, minify, sort keys, inspect structure, and query JSON with path expressions.",
      introduction: "JSON Formatter is a local workspace for messy payloads. Beautify or minify JSON, sort keys for comparison, inspect structure at a glance, and query values with path expressions—useful when an API response or config file needs to be readable without uploading it anywhere.",
      highlights: [
        "Format, minify, and sort keys",
        "Inspect nested structure",
        "Query values with path expressions",
      ],
    },
    "zh-CN": {
      title: "JSON 格式化",
      summary: "格式化、压缩、键排序、查看结构，并通过路径表达式查询 JSON。",
      introduction: "JSON 格式化是处理杂乱 JSON 的本地工作区。可以美化或压缩、按键排序方便对比、快速查看结构，并用路径表达式查询取值。适合阅读 API 响应或配置文件，且无需把内容上传到任何地方。",
      highlights: [
        "格式化、压缩与键排序",
        "查看嵌套结构",
        "用路径表达式查询取值",
      ],
    },
  }),
  tool({
    id: "codec",
    category: "text-data",
    en: {
      title: "Codec",
      summary: "Encode, decode, escape, and hash text with Base64, Base32, Base62, Hex, URL, HTML, Unicode, and more.",
      introduction: "Codec covers the encoding and escaping chores that show up in debugging, packaging, and content hand-offs. Encode or decode Base64, Hex, URL, HTML, Unicode, and related formats, or generate hashes locally when you need a quick transform without an online converter.",
      highlights: [
        "Base64, Base32, Base62, Hex, and more",
        "URL, HTML, and Unicode escaping",
        "Local hashing for quick checks",
      ],
    },
    "zh-CN": {
      title: "编解码",
      summary: "使用 Base64、Base32、Base62、Hex、URL、HTML、Unicode 等方式编码、解码、转义与 Hash。",
      introduction: "编解码覆盖调试、打包和内容交接中常见的编码与转义操作。可在本机处理 Base64、Hex、URL、HTML、Unicode 等格式的编解码，或生成 Hash，不必再依赖在线转换网站。",
      highlights: [
        "Base64、Base32、Base62、Hex 等",
        "URL、HTML 与 Unicode 转义",
        "本地 Hash 快速校验",
      ],
    },
  }),
  tool({
    id: "string-generator",
    category: "text-data",
    en: {
      title: "String Generator",
      summary: "Generate UUID v1–v7, ULIDs, Nano IDs, Object IDs, hex strings, and configurable passwords locally.",
      introduction: "String Generator creates identifiers and passwords on the Mac instead of in a browser tab. Choose UUID versions, ULID, Nano ID, Object ID, hex strings, or configurable passwords when scaffolding data, filling forms, or preparing test fixtures.",
      highlights: [
        "UUID v1–v7, ULID, Nano ID, and Object ID",
        "Hex strings and configurable passwords",
        "Everything generated locally",
      ],
    },
    "zh-CN": {
      title: "字符串生成",
      summary: "在本地生成 UUID v1–v7、ULID、Nano ID、Object ID、十六进制字符串和可配置密码。",
      introduction: "字符串生成在 Mac 本机创建标识符和密码，不必打开浏览器标签。可选择 UUID 版本、ULID、Nano ID、Object ID、十六进制字符串或可配置密码，方便搭数据、填表单或准备测试样例。",
      highlights: [
        "UUID v1–v7、ULID、Nano ID、Object ID",
        "十六进制字符串与可配置密码",
        "全部在本地生成",
      ],
    },
  }),
  tool({
    id: "regex-lab",
    category: "text-data",
    en: {
      title: "Regex Lab",
      summary: "Test expressions, highlight matches, inspect capture groups, and try common replacements.",
      introduction: "Regex Lab makes pattern testing immediate and visual. Paste sample text, refine an expression, highlight matches, inspect capture groups, and try replacements before the pattern ever lands in production code or a search-and-replace workflow.",
      highlights: [
        "Live match highlighting",
        "Capture-group inspection",
        "Common replacement experiments",
      ],
    },
    "zh-CN": {
      title: "正则实验室",
      summary: "测试表达式、高亮匹配、查看捕获分组，并尝试常用替换。",
      introduction: "正则实验室让模式测试即时可见。粘贴样例文本、调整表达式、高亮匹配、查看捕获分组，并在正式写进代码或批量替换前先试常用替换效果。",
      highlights: [
        "实时匹配高亮",
        "查看捕获分组",
        "尝试常用替换",
      ],
    },
  }),
  tool({
    id: "text-diff",
    category: "text-data",
    en: {
      title: "Text Diff",
      summary: "Compare two texts side by side, ignore whitespace when needed, and copy a line-level patch.",
      introduction: "Text Diff compares two snippets side by side so changes are easy to spot. Ignore whitespace when the noise gets in the way, review line-level differences, and copy a patch-style result for notes, reviews, or hand-offs.",
      highlights: [
        "Side-by-side comparison",
        "Optional whitespace ignoring",
        "Copy a line-level patch",
      ],
    },
    "zh-CN": {
      title: "文本 Diff",
      summary: "左右对比两段文本、按需忽略空白，并复制行级差异结果。",
      introduction: "文本 Diff 左右对比两段内容，让改动一目了然。需要时可以忽略空白差异，查看行级变化，并复制 patch 风格结果，方便记录、评审或交接。",
      highlights: [
        "左右对照比较",
        "可按需忽略空白",
        "复制行级差异结果",
      ],
    },
  }),
  tool({
    id: "url-lab",
    category: "text-data",
    en: {
      title: "URL Lab",
      summary: "Parse and rebuild URLs while editing query parameters, paths, and fragments.",
      introduction: "URL Lab breaks a URL into editable parts and rebuilds it cleanly. Adjust query parameters, paths, and fragments without fighting escaped strings by hand—handy for API debugging, campaign links, and deep-link construction.",
      highlights: [
        "Parse and rebuild URLs",
        "Edit query, path, and fragment",
        "Avoid hand-escaped string mistakes",
      ],
    },
    "zh-CN": {
      title: "URL 实验室",
      summary: "解析并重新构建 URL，可编辑查询参数、路径和片段。",
      introduction: "URL 实验室把地址拆成可编辑部分再干净地拼回去。调整查询参数、路径和片段时不必手搓转义字符串，适合 API 调试、投放链接和深度链接拼装。",
      highlights: [
        "解析并重建 URL",
        "编辑查询、路径与片段",
        "减少手写转义错误",
      ],
    },
  }),
  tool({
    id: "data-format",
    category: "text-data",
    en: {
      title: "Data Format",
      summary: "Convert structured data between JSON, YAML, and TOML locally.",
      introduction: "Data Format converts structured content between JSON, YAML, and TOML on the Mac. Keep configuration experiments and data hand-offs local when you need a quick format change without installing another CLI or opening an upload form.",
      highlights: [
        "JSON, YAML, and TOML conversion",
        "Local structured-data transforms",
        "No upload or extra CLI required",
      ],
    },
    "zh-CN": {
      title: "数据格式",
      summary: "在本地转换 JSON、YAML 和 TOML 结构化数据。",
      introduction: "数据格式在本机完成 JSON、YAML、TOML 之间的转换。做配置试验或数据交接时，不必再装额外 CLI，也不必把内容上传到网页表单。",
      highlights: [
        "JSON、YAML、TOML 互转",
        "本地结构化数据转换",
        "无需上传或额外命令行工具",
      ],
    },
  }),
  tool({
    id: "number-base",
    category: "text-data",
    en: {
      title: "Unit Converter",
      summary: "Convert integers across bases and translate common byte, time, length, mass, and temperature units.",
      introduction: "Unit Converter handles the unit math that appears in logs, specs, and everyday calculations. Switch integer bases, convert byte sizes, and move between common time, length, mass, and temperature units without reaching for a separate calculator.",
      highlights: [
        "Integer base conversion",
        "Byte and everyday physical units",
        "Local, copy-friendly results",
      ],
    },
    "zh-CN": {
      title: "单位换算",
      summary: "转换整数进制，以及常用字节、时间、长度、质量和温度单位。",
      introduction: "单位换算处理日志、规格和日常计算里常见的单位换算。可切换整数进制、换算字节大小，并在常见时间、长度、质量、温度单位之间转换，不必再另开计算器。",
      highlights: [
        "整数进制转换",
        "字节与常用物理单位",
        "本地生成、方便复制的结果",
      ],
    },
  }),
  tool({
    id: "cron-expression",
    category: "system",
    en: {
      title: "Cron Expression",
      summary: "Build five-field cron schedules and preview upcoming run times.",
      introduction: "Cron Expression helps you write a five-field schedule and immediately see when it would run next. Use it to validate jobs, explain schedules to teammates, or catch off-by-one mistakes before a timer is deployed.",
      highlights: [
        "Five-field cron editing",
        "Upcoming run-time previews",
        "Catch schedule mistakes early",
      ],
    },
    "zh-CN": {
      title: "Cron 表达式",
      summary: "编写五段 cron 计划并预览接下来的执行时间。",
      introduction: "Cron 表达式帮助你编写五段计划，并立刻看到接下来的执行时间。适合校验定时任务、向同事解释计划，或在部署前发现常见的 off-by-one 错误。",
      highlights: [
        "编辑五段 cron",
        "预览接下来的执行时间",
        "尽早发现计划错误",
      ],
    },
  }),
  tool({
    id: "ip-cidr",
    category: "network",
    en: {
      title: "IP / CIDR",
      summary: "Inspect IPv4 and IPv6 addresses or calculate IPv4 CIDR ranges.",
      introduction: "IP / CIDR explains a single IPv4 or IPv6 address and calculates IPv4 network ranges in one place. Identify address kinds, integer and reverse DNS forms, or inspect masks, ranges, and membership when reviewing logs, firewall rules, and network plans.",
      highlights: [
        "IPv4 and IPv6 address inspection",
        "Integer and reverse DNS forms",
        "IPv4 CIDR ranges and membership",
      ],
    },
    "zh-CN": {
      title: "IP / CIDR",
      summary: "查看 IPv4 / IPv6 地址，或计算 IPv4 CIDR 范围。",
      introduction: "IP / CIDR 在一个入口里解释单个 IPv4 / IPv6 地址，并计算 IPv4 网段范围。可识别地址类型、整数与反向 DNS 形式，也可查看掩码、范围和归属关系，适合检查日志、防火墙规则和网络规划。",
      highlights: [
        "IPv4 与 IPv6 地址查看",
        "整数与反向 DNS 形式",
        "IPv4 CIDR 范围与归属",
      ],
    },
  }),
  tool({
    id: "color-lab",
    category: "media",
    en: {
      title: "Color Lab",
      summary: "Convert HEX, RGB, HSL, and HSV colors and check contrast locally.",
      introduction: "Color Lab converts between HEX, RGB, HSL, and HSV while keeping contrast checks nearby. Use it when adjusting themes, validating accessibility contrast, or translating a color across design and code formats.",
      highlights: [
        "HEX, RGB, HSL, and HSV conversion",
        "Local contrast checks",
        "Design-to-code color hand-offs",
      ],
    },
    "zh-CN": {
      title: "颜色实验室",
      summary: "在本地转换 HEX、RGB、HSL、HSV 并检查对比度。",
      introduction: "颜色实验室在 HEX、RGB、HSL、HSV 之间转换，并把对比度检查放在旁边。适合调整主题、校验无障碍对比度，或在设计和代码格式之间交接颜色。",
      highlights: [
        "HEX、RGB、HSL、HSV 互转",
        "本地对比度检查",
        "设计与代码之间的颜色交接",
      ],
    },
  }),
  tool({
    id: "image-process",
    category: "media",
    en: {
      title: "Image Tools",
      summary: "Convert image formats and control output by quality, size, or dimensions.",
      introduction: "Image Tools handles common local image prep without an upload service. Convert formats and control output by quality, target size, or dimensions when you need a smaller asset, a different container, or a quick resize before sharing.",
      highlights: [
        "Local format conversion",
        "Quality, size, and dimension controls",
        "No cloud upload required",
      ],
    },
    "zh-CN": {
      title: "图片处理",
      summary: "转换图片格式，并按质量、目标大小或尺寸控制输出。",
      introduction: "图片处理在本地完成常见的图片准备，不必上传到云端服务。可转换格式，并按质量、目标大小或尺寸控制输出，适合压缩资源、更换格式或分享前快速缩放。",
      highlights: [
        "本地格式转换",
        "质量、大小与尺寸控制",
        "无需上传云端",
      ],
    },
  }),
  tool({
    id: "qr-code",
    category: "media",
    en: {
      title: "QR Code",
      summary: "Generate customizable QR codes from text or URLs entirely locally.",
      introduction: "QR Code turns text or URLs into a customizable code without sending the content to a generator website. Keep Wi-Fi notes, deep links, and temporary sharing payloads local while you adjust size and appearance.",
      highlights: [
        "Generate from text or URLs",
        "Local customization controls",
        "No generator-site upload",
      ],
    },
    "zh-CN": {
      title: "二维码",
      summary: "完全在本地从文本或 URL 生成可定制二维码。",
      introduction: "二维码把文本或 URL 生成为可定制代码，不会把内容发到在线生成网站。调整尺寸与外观时，Wi-Fi 备注、深度链接和临时分享内容都留在本机。",
      highlights: [
        "从文本或 URL 生成",
        "本地自定义控制",
        "无需上传到生成网站",
      ],
    },
  }),
  tool({
    id: "jwt-lab",
    category: "network",
    en: {
      title: "JWT Lab",
      summary: "Decode, inspect, validate, and create JSON Web Tokens locally.",
      introduction: "JWT Lab keeps token work on the Mac. Decode headers and payloads, inspect claims, validate structure, and create tokens locally when debugging auth flows—without pasting secrets into an unknown website.",
      highlights: [
        "Decode headers and payloads",
        "Inspect and validate claims",
        "Create tokens locally",
      ],
    },
    "zh-CN": {
      title: "JWT 实验室",
      summary: "在本地解码、检查、验证和创建 JSON Web Token。",
      introduction: "JWT 实验室把令牌相关操作留在 Mac 本机。可解码 header 与 payload、检查声明、验证结构，并在调试鉴权流程时本地创建令牌，不必把密钥粘贴到未知网站。",
      highlights: [
        "解码 header 与 payload",
        "检查并验证声明",
        "在本地创建令牌",
      ],
    },
  }),
  tool({
    id: "chmod-lab",
    category: "system",
    en: {
      title: "chmod Lab",
      summary: "Convert Unix permission modes and preview symbolic permission changes.",
      introduction: "chmod Lab translates between octal, symbolic, and permission-bit views of Unix modes. Preview what a change would mean before applying it, which is useful when scripts, shared folders, or SSH keys need the right access without guesswork.",
      highlights: [
        "Octal, symbolic, and bit views",
        "Preview permission changes",
        "Reduce chmod guesswork",
      ],
    },
    "zh-CN": {
      title: "chmod 实验室",
      summary: "转换 Unix 权限模式并预览符号权限变化。",
      introduction: "chmod 实验室在八进制、符号和权限位视图之间转换 Unix 模式。应用前先预览变更含义，适合处理脚本、共享目录或 SSH 密钥的权限，减少猜测。",
      highlights: [
        "八进制、符号与权限位视图",
        "预览权限变化",
        "减少 chmod 猜测",
      ],
    },
  }),
  tool({
    id: "cert-lab",
    category: "network",
    en: {
      title: "Certificate Lab",
      summary: "Inspect certificates, CSRs, and certificate chains without uploading them.",
      introduction: "Certificate Lab inspects PEM certificates, CSRs, fingerprints, SANs, and chains on the Mac. Use it when diagnosing TLS trust issues or reviewing a certificate before it is installed—without uploading private material.",
      highlights: [
        "Inspect PEM certificates and CSRs",
        "Fingerprints, SANs, and chains",
        "No certificate upload",
      ],
    },
    "zh-CN": {
      title: "证书实验室",
      summary: "无需上传即可检查证书、CSR 和证书链。",
      introduction: "证书实验室在本机检查 PEM 证书、CSR、指纹、SAN 和证书链。适合诊断 TLS 信任问题，或在安装前核对证书，且不会上传私钥材料。",
      highlights: [
        "检查 PEM 证书与 CSR",
        "指纹、SAN 与证书链",
        "无需上传证书",
      ],
    },
  }),
  tool({
    id: "text-lab",
    category: "text-data",
    en: {
      title: "Text Lab",
      summary: "Clean, transform, sort, count, and reshape text in one workspace.",
      introduction: "Text Lab gathers everyday text cleanup into one workspace. Trim, dedupe, sort, count, and reshape lines when a pasted list, CSV fragment, or notes dump needs to become usable without opening a spreadsheet.",
      highlights: [
        "Trim, dedupe, sort, and count",
        "Reshape lines in one place",
        "Local text cleanup",
      ],
    },
    "zh-CN": {
      title: "文本实验室",
      summary: "在一个工作区中清理、转换、排序、统计和重组文本。",
      introduction: "文本实验室把日常文本清理集中到一个工作区。修剪、去重、排序、统计和重组行内容，让粘贴列表、CSV 片段或笔记草稿更快变成可用文本，不必打开表格软件。",
      highlights: [
        "修剪、去重、排序与统计",
        "在一处重组文本行",
        "本地文本清理",
      ],
    },
  }),
  tool({
    id: "curl-lab",
    category: "network",
    en: {
      title: "cURL Lab",
      summary: "Build, parse, edit, and run HTTP requests visually, then convert to or from cURL.",
      introduction: "cURL Lab turns HTTP request work into a readable workspace. Build or paste a request, edit headers and body visually, convert to or from cURL, and run it when you need a quick local check—without reconstructing long command lines by hand.",
      highlights: [
        "Visual request editing",
        "Convert to and from cURL",
        "Run requests locally when needed",
      ],
    },
    "zh-CN": {
      title: "cURL 实验室",
      summary: "可视化构建、解析、编辑并运行 HTTP 请求，同时与 cURL 互相转换。",
      introduction: "cURL 实验室把 HTTP 请求工作变成可读的工作区。可构建或粘贴请求、可视化编辑请求头与正文、与 cURL 互相转换，并在需要时本机运行，不必手搓冗长命令行。",
      highlights: [
        "可视化编辑请求",
        "与 cURL 互相转换",
        "需要时可在本地运行请求",
      ],
    },
  }),
  tool({
    id: "connection-trace",
    category: "network",
    en: {
      title: "Connection Trace",
      summary: "Trace DNS resolution, routes, proxies, and connection timing for a host.",
      introduction: "Connection Trace follows what happens when your Mac reaches a host. Review DNS resolution, routing, proxy influence, and connection timing so intermittent network issues become a sequence of facts instead of a vague timeout.",
      highlights: [
        "DNS resolution and route context",
        "Proxy visibility",
        "Connection timing diagnostics",
      ],
    },
    "zh-CN": {
      title: "连接追踪",
      summary: "追踪目标主机的 DNS 解析、路由、代理和连接耗时。",
      introduction: "连接追踪跟进 Mac 访问某个主机时发生了什么。查看 DNS 解析、路由、代理影响和连接耗时，让间歇性网络问题变成一串可核对的事实，而不是模糊的超时。",
      highlights: [
        "DNS 解析与路由上下文",
        "代理状态可见",
        "连接耗时诊断",
      ],
    },
  }),
  tool({
    id: "port-scan",
    category: "network",
    en: {
      title: "Port Scanner",
      summary: "Scan any TCP port or range with live progress and open-port results.",
      introduction: "Port Scanner checks TCP ports or ranges with live progress and a clear open-port list. Use it to verify local services, confirm a listener after deploy, or quickly see what is accepting connections on a host you manage.",
      highlights: [
        "Single ports or ranges",
        "Live scan progress",
        "Clear open-port results",
      ],
    },
    "zh-CN": {
      title: "端口扫描",
      summary: "扫描任意 TCP 端口或范围，实时显示进度和开放端口。",
      introduction: "端口扫描检查 TCP 端口或范围，并实时显示进度与开放端口列表。适合核对本机服务、部署后确认监听，或快速查看你管理的主机上哪些端口在接受连接。",
      highlights: [
        "单端口或端口范围",
        "实时扫描进度",
        "清晰的开放端口结果",
      ],
    },
  }),
]);

export function localizedTool(tool, locale) {
  const copy = tool[locale] || tool.en;
  return Object.freeze({
    id: tool.id,
    categoryId: tool.category,
    category: toolCategories[tool.category][locale] || toolCategories[tool.category].en,
    title: copy.title,
    summary: copy.summary,
    introduction: copy.introduction,
    highlights: Object.freeze([...copy.highlights]),
  });
}

export function localizedWebsiteTools(locale) {
  return Object.freeze(websiteToolCatalog.map((tool) => localizedTool(tool, locale)));
}

export function groupedWebsiteTools(locale) {
  const tools = localizedWebsiteTools(locale);
  return Object.freeze(
    toolCategoryOrder
      .map((categoryId) => {
        const items = tools.filter((tool) => tool.categoryId === categoryId);
        if (!items.length) return null;
        return Object.freeze({
          id: categoryId,
          category: toolCategories[categoryId][locale] || toolCategories[categoryId].en,
          tools: Object.freeze(items),
        });
      })
      .filter(Boolean),
  );
}

/** @deprecated Prefer localizedWebsiteTools(locale); kept for transitional summaries. */
export const localizedWebsiteToolSummaries = Object.freeze({
  en: Object.freeze(localizedWebsiteTools("en").map((tool) => Object.freeze([tool.title, tool.summary]))),
  "zh-CN": Object.freeze(localizedWebsiteTools("zh-CN").map((tool) => Object.freeze([tool.title, tool.summary]))),
});
