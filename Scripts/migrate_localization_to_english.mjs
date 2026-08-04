import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const catalogPath = path.join(root, "Resources/Localizable.xcstrings");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));

const missingEnglish = new Map([
  ["· %@", "· %@"],
  ["使用 macOS 本地文件系统快速汇总，不建立深层文件索引", "Quickly summarizes the macOS file system without building a deep index"],
  ["分析中", "Analyzing"],
  ["只展示第一层文件夹，说明用途并统计实际占用", "Shows only top-level folders, explains their purpose, and calculates actual usage"],
  ["只读取路径与占用空间，不读取文件内容", "Reads only paths and disk usage, not file contents"],
  ["存储分析正在后台进行", "Storage analysis is running in the background"],
  ["完成", "Done"],
  ["快速看看用户目录", "Quick overview of your home folder"],
  ["正在后台更新目录大小", "Updating folder sizes in the background"],
  ["正在更新", "Updating"],
  ["正在统计%@下的目录", "Calculating folders in %@"],
  ["用户目录", "Home Folder"],
  ["目录大小为当前可读取内容的汇总。受权限保护的内容可能未完全计入；点击任意目录可在 Finder 中查看。", "Folder sizes summarize currently readable content. Protected items may not be fully counted; click any folder to view it in Finder."],
  ["立即更新", "Update Now"],
  ["第一层 · 按大小排序", "Top Level · Sorted by Size"],
  ["自动更新已暂停", "Automatic updates paused"],
  ["", ""]
]);

const placeholder = /%(?:\d+\$)?(?:lld|llu|ld|lu|zd|zu|d|u|f|g|s|c|@)/g;
const marker = "\u{F0000}";

function englishFor(key, entry) {
  return entry?.localizations?.en?.stringUnit?.value ?? missingEnglish.get(key) ?? key;
}

function catalogSkeleton(value) {
  return value.replace(placeholder, marker).replaceAll("%%", "%");
}

function decodeSwiftStatic(value) {
  return value.replaceAll('\\"', '"').replaceAll("\\n", "\n").replaceAll("\\t", "\t").replaceAll("\\\\", "\\");
}

function splitInterpolations(raw) {
  let staticText = "";
  const expressions = [];
  for (let i = 0; i < raw.length;) {
    if (raw[i] === "\\" && raw[i + 1] === "(") {
      const start = i;
      i += 2;
      let depth = 1;
      let quote = false;
      while (i < raw.length && depth > 0) {
        const ch = raw[i];
        if (ch === '"' && raw[i - 1] !== "\\") quote = !quote;
        if (!quote && ch === "(") depth += 1;
        if (!quote && ch === ")") depth -= 1;
        i += 1;
      }
      expressions.push(raw.slice(start, i));
      staticText += marker;
    } else {
      staticText += raw[i];
      i += 1;
    }
  }
  return { staticText: decodeSwiftStatic(staticText), expressions };
}

function swiftEscape(value) {
  return value.replaceAll("\\", "\\\\").replaceAll('"', '\\"').replaceAll("\n", "\\n").replaceAll("\t", "\\t");
}

function englishSwiftLiteral(english, expressions) {
  const pieces = english.replaceAll("%%", "%").split(placeholder);
  let result = swiftEscape(pieces[0] ?? "");
  for (let i = 0; i < expressions.length; i += 1) {
    result += expressions[i] + swiftEscape(pieces[i + 1] ?? "");
  }
  return result;
}

const mapping = [];
for (const [key, entry] of Object.entries(catalog.strings)) {
  if (catalog.sourceLanguage === "en") {
    const chinese = entry?.localizations?.["zh-Hans"]?.stringUnit?.value;
    if (chinese) mapping.push({ key: chinese, english: key, skeleton: catalogSkeleton(chinese) });
  } else {
    const english = englishFor(key, entry);
    mapping.push({ key, english, skeleton: catalogSkeleton(key) });
  }
}

const bySkeleton = new Map();
for (const item of mapping) {
  const list = bySkeleton.get(item.skeleton) ?? [];
  list.push(item);
  bySkeleton.set(item.skeleton, list);
}

function migrateSwiftFile(file) {
  const original = fs.readFileSync(file, "utf8");
  const migrated = original.replace(/"(?:\\.|[^"\\])*"/g, token => {
    const raw = token.slice(1, -1);
    const { staticText, expressions } = splitInterpolations(raw);
    const candidates = bySkeleton.get(catalogSkeleton(staticText)) ?? [];
    if (candidates.length !== 1) return token;
    const replacement = englishSwiftLiteral(candidates[0].english, expressions);
    return `"${replacement}"`;
  });
  if (migrated !== original) fs.writeFileSync(file, migrated);
}

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(fullPath);
    else if (entry.name.endsWith(".swift")) migrateSwiftFile(fullPath);
  }
}

walk(path.join(root, "App/Sources"));
walk(path.join(root, "Sources"));

if (catalog.sourceLanguage !== "en") {
  const migratedStrings = {};
  for (const [key, entry] of Object.entries(catalog.strings)) {
    const english = englishFor(key, entry);
    const next = structuredClone(entry);
    const existingEnglish = next.localizations?.en;
    next.localizations ??= {};
    delete next.localizations.en;
    next.localizations["zh-Hans"] = {
      stringUnit: {
        state: "translated",
        value: key
      }
    };
    if (existingEnglish?.variations) next.localizations.en = existingEnglish;
    if (migratedStrings[english]) {
      migratedStrings[english].localizations = {
        ...migratedStrings[english].localizations,
        ...next.localizations
      };
    } else {
      migratedStrings[english] = next;
    }
  }
  catalog.sourceLanguage = "en";
  catalog.strings = Object.fromEntries(Object.entries(migratedStrings).sort(([a], [b]) => a.localeCompare(b, "en")));
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
}
