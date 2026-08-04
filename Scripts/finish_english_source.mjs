import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const catalogPath = path.join(root, "Resources/Localizable.xcstrings");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const interpolationMarker = "918273645000";

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
      staticText += interpolationMarker;
    } else {
      staticText += raw[i++];
    }
  }
  return { staticText: decodeSwiftStatic(staticText), expressions };
}

function swiftEscape(value) {
  return value.replaceAll("\\", "\\\\").replaceAll('"', '\\"').replaceAll("\n", "\\n").replaceAll("\t", "\\t");
}

function rebuildSwiftLiteral(translated, expressions) {
  const pieces = translated.split(interpolationMarker);
  let result = swiftEscape(pieces[0] ?? "");
  for (let i = 0; i < expressions.length; i += 1) result += expressions[i] + swiftEscape(pieces[i + 1] ?? "");
  return result;
}

function swiftFiles(directory) {
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...swiftFiles(fullPath));
    else if (entry.name.endsWith(".swift")) result.push(fullPath);
  }
  return result;
}

const files = [...swiftFiles(path.join(root, "App/Sources")), ...swiftFiles(path.join(root, "Sources"))];
const records = new Map();
for (const file of files) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(/"(?:\\.|[^"\\])*"/g)) {
    if (!/\p{Script=Han}/u.test(match[0])) continue;
    const raw = match[0].slice(1, -1);
    if (!records.has(raw)) records.set(raw, splitInterpolations(raw));
  }
}

async function translateBatch(values) {
  const translated = [];
  for (let offset = 0; offset < values.length; offset += 16) {
    const chunk = values.slice(offset, offset + 16);
    const markers = chunk.map((_, index) => `7823649${String(offset + index).padStart(5, "0")}`);
    const query = chunk.map((value, index) => `${markers[index]}\n${value}`).join("\n");
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=zh-CN&tl=en&dt=t&q=${encodeURIComponent(query)}`;
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Translation request failed: ${response.status}`);
    const json = await response.json();
    const output = json[0].map(part => part[0]).join("");
    for (let index = 0; index < chunk.length; index += 1) {
      const start = output.indexOf(markers[index]);
      const next = index + 1 < chunk.length ? output.indexOf(markers[index + 1]) : output.length;
      if (start < 0 || next < 0) throw new Error("Translation boundary was not preserved");
      translated.push(output.slice(start + markers[index].length, next).trim());
    }
  }
  return translated;
}

const raws = [...records.keys()];
const english = await translateBatch(raws.map(raw => records.get(raw).staticText));
const replacements = new Map();
for (let index = 0; index < raws.length; index += 1) {
  const record = records.get(raws[index]);
  const englishValue = english[index];
  replacements.set(raws[index], rebuildSwiftLiteral(englishValue, record.expressions));
  const catalogKey = englishValue.replaceAll(interpolationMarker, "%@");
  const chineseValue = record.staticText.replaceAll(interpolationMarker, "%@");
  catalog.strings[catalogKey] ??= {};
  catalog.strings[catalogKey].localizations ??= {};
  catalog.strings[catalogKey].localizations["zh-Hans"] = {
    stringUnit: { state: "translated", value: chineseValue }
  };
}

for (const file of files) {
  const original = fs.readFileSync(file, "utf8");
  const migrated = original.replace(/"(?:\\.|[^"\\])*"/g, token => {
    const raw = token.slice(1, -1);
    const replacement = replacements.get(raw);
    return replacement === undefined ? token : `"${replacement}"`;
  });
  if (migrated !== original) fs.writeFileSync(file, migrated);
}

catalog.strings = Object.fromEntries(Object.entries(catalog.strings).sort(([a], [b]) => a.localeCompare(b, "en")));
fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
console.log(`Migrated ${raws.length} remaining Chinese source strings.`);
