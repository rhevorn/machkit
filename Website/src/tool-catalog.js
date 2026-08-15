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
]);

export const localizedWebsiteTools = Object.freeze({
  en: Object.freeze(websiteToolCatalog.map((tool) => Object.freeze([...tool.en]))),
  "zh-CN": Object.freeze(websiteToolCatalog.map((tool) => Object.freeze([...tool["zh-CN"]]))),
});
