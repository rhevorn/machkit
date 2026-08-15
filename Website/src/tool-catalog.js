export const websiteToolCatalog = Object.freeze([
  {
    id: "hosts-manager",
    en: ["Hosts Manager", "Inspect the current hosts file and switch shared or environment-specific mappings with explicit write permission."],
    "zh-CN": ["Hosts 管理", "查看当前 hosts 文件，并在明确授权后切换公共或指定环境的映射。"],
  },
  {
    id: "timestamp-converter",
    en: ["Timestamp Converter", "Convert Unix timestamps and standard date formats across units, time zones, and common interchange formats."],
    "zh-CN": ["时间戳转换", "在不同单位、时区、Unix 时间戳和常见标准日期格式之间转换。"],
  },
  {
    id: "json-formatter",
    en: ["JSON Formatter", "Format, minify, sort keys, inspect structure, and query JSON with path expressions."],
    "zh-CN": ["JSON 格式化", "格式化、压缩、键排序、查看结构，并通过路径表达式查询 JSON。"],
  },
  {
    id: "codec",
    en: ["Codec", "Encode, decode, escape, and hash text with Base64, Base32, Base62, Hex, URL, HTML, Unicode, and more."],
    "zh-CN": ["编解码", "使用 Base64、Base32、Base62、Hex、URL、HTML、Unicode 等方式编码、解码、转义与 Hash。"],
  },
  {
    id: "string-generator",
    en: ["String Generator", "Generate UUID v1–v7, ULIDs, Nano IDs, Object IDs, hex strings, and configurable passwords locally."],
    "zh-CN": ["字符串生成", "在本地生成 UUID v1–v7、ULID、Nano ID、Object ID、十六进制字符串和可配置密码。"],
  },
  {
    id: "regex-lab",
    en: ["Regex Lab", "Test expressions, highlight matches, inspect capture groups, and try common replacements."],
    "zh-CN": ["正则实验室", "测试表达式、高亮匹配、查看捕获分组，并尝试常用替换。"],
  },
  {
    id: "text-diff",
    en: ["Text Diff", "Compare two texts side by side, ignore whitespace when needed, and copy a line-level patch."],
    "zh-CN": ["文本 Diff", "左右对比两段文本、按需忽略空白，并复制行级差异结果。"],
  },
  {
    id: "url-lab",
    en: ["URL Lab", "Parse and rebuild URLs while editing query parameters, paths, and fragments."],
    "zh-CN": ["URL 实验室", "解析并重新构建 URL，可编辑查询参数、路径和片段。"],
  },
  {
    id: "data-format",
    en: ["Data Format", "Convert structured data between JSON, YAML, and TOML locally."],
    "zh-CN": ["数据格式", "在本地转换 JSON、YAML 和 TOML 结构化数据。"],
  },
  {
    id: "number-base",
    en: ["Number Base", "Convert integers across bases and translate common byte units."],
    "zh-CN": ["进制换算", "转换整数进制和常用字节单位。"],
  },
  {
    id: "cron-expression",
    en: ["Cron Expression", "Build five-field cron schedules and preview upcoming run times."],
    "zh-CN": ["Cron 表达式", "编写五段 cron 计划并预览接下来的执行时间。"],
  },
  {
    id: "ip-cidr",
    en: ["IP / CIDR Calculator", "Calculate IPv4 network details, address ranges, and membership."],
    "zh-CN": ["IP / CIDR 计算器", "计算 IPv4 网段详情、地址范围和归属关系。"],
  },
  {
    id: "ip-inspector",
    en: ["IP Inspector", "Inspect IPv4 and IPv6 types, integer forms, and reverse DNS labels."],
    "zh-CN": ["IP 解析", "检查 IPv4 和 IPv6 类型、整数形式与反向 DNS 标签。"],
  },
  {
    id: "color-lab",
    en: ["Color Lab", "Convert HEX, RGB, HSL, and HSV colors and check contrast locally."],
    "zh-CN": ["颜色实验室", "在本地转换 HEX、RGB、HSL、HSV 并检查对比度。"],
  },
  {
    id: "image-process",
    en: ["Image Tools", "Convert image formats and control output by quality, size, or dimensions."],
    "zh-CN": ["图片处理", "转换图片格式，并按质量、目标大小或尺寸控制输出。"],
  },
  {
    id: "xml-plist",
    en: ["XML / Plist", "Format XML and convert Apple XML property lists to JSON."],
    "zh-CN": ["XML / Plist", "格式化 XML，并将 Apple XML 属性列表转换为 JSON。"],
  },
  {
    id: "qr-code",
    en: ["QR Code", "Generate customizable QR codes from text or URLs entirely locally."],
    "zh-CN": ["二维码", "完全在本地从文本或 URL 生成可定制二维码。"],
  },
  {
    id: "jwt-lab",
    en: ["JWT Lab", "Decode, inspect, validate, and create JSON Web Tokens locally."],
    "zh-CN": ["JWT 实验室", "在本地解码、检查、验证和创建 JSON Web Token。"],
  },
  {
    id: "chmod-lab",
    en: ["chmod Lab", "Convert Unix permission modes and preview symbolic permission changes."],
    "zh-CN": ["chmod 实验室", "转换 Unix 权限模式并预览符号权限变化。"],
  },
  {
    id: "cert-lab",
    en: ["Certificate Lab", "Inspect certificates, CSRs, and certificate chains without uploading them."],
    "zh-CN": ["证书实验室", "无需上传即可检查证书、CSR 和证书链。"],
  },
  {
    id: "text-lab",
    en: ["Text Lab", "Clean, transform, sort, count, and reshape text in one workspace."],
    "zh-CN": ["文本实验室", "在一个工作区中清理、转换、排序、统计和重组文本。"],
  },
  {
    id: "curl-lab",
    en: ["cURL Lab", "Build, parse, and edit cURL requests without sending them."],
    "zh-CN": ["cURL 实验室", "构建、解析和编辑 cURL 请求，不会实际发送。"],
  },
  {
    id: "connection-trace",
    en: ["Connection Trace", "Trace DNS resolution, routes, proxies, and connection diagnostics."],
    "zh-CN": ["连接追踪", "追踪 DNS 解析、路由、代理和连接诊断信息。"],
  },
  {
    id: "port-scan",
    en: ["Port Scanner", "Scan any TCP port or range with live progress and open-port results."],
    "zh-CN": ["端口扫描", "扫描任意 TCP 端口或范围，实时显示进度和开放端口。"],
  },
]);

export const localizedWebsiteTools = Object.freeze({
  en: Object.freeze(websiteToolCatalog.map((tool) => Object.freeze([...tool.en]))),
  "zh-CN": Object.freeze(websiteToolCatalog.map((tool) => Object.freeze([...tool["zh-CN"]]))),
});
