#!/usr/bin/env node
/**
 * Ensures embedded-tool IDs stay synchronized across:
 * - App DeveloperToolRegistry (Swift)
 * - Tool/tools/* folders
 * - Website tool-catalog.ts
 * - Tool/src/tools-catalog.ts preferred order / toolMeta keys when present
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function fail(message) {
  console.error(`verify_tool_catalog: ${message}`);
  process.exit(1);
}

function read(rel) {
  return fs.readFileSync(path.join(repoRoot, rel), "utf8");
}

function sorted(set) {
  return [...set].sort();
}

function extractSwiftRegistryIDs(source) {
  const blockMatch = source.match(/enum DeveloperToolRegistry\s*\{[\s\S]*?static let all:\s*\[DeveloperTool\]\s*=\s*\[([\s\S]*?)\n\s*\]/);
  if (!blockMatch) fail("could not locate DeveloperToolRegistry.all");
  const ids = new Set();
  for (const match of blockMatch[1].matchAll(/\bid:\s*"([^"]+)"/g)) {
    ids.add(match[1]);
  }
  if (ids.size === 0) fail("no tool IDs found in DeveloperToolRegistry.all");
  return ids;
}

function extractToolFolderIDs() {
  const toolsDir = path.join(repoRoot, "Tool/tools");
  const ids = new Set();
  for (const entry of fs.readdirSync(toolsDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith("_")) continue;
    const index = path.join(toolsDir, entry.name, "index.html");
    if (!fs.existsSync(index)) fail(`Tool/tools/${entry.name} is missing index.html`);
    ids.add(entry.name);
  }
  return ids;
}

function extractWebsiteCatalogIDs(source) {
  const match = source.match(/export const websiteToolCatalog\s*=\s*Object\.freeze\(\[([\s\S]*?)\n\]\)/);
  if (!match) fail("could not locate websiteToolCatalog in Website/src/tool-catalog.ts");
  const ids = new Set();
  for (const item of match[1].matchAll(/\bid:\s*"([^"]+)"/g)) {
    ids.add(item[1]);
  }
  if (ids.size === 0) fail("no tool IDs found in websiteToolCatalog");
  return ids;
}

function extractToolsCatalogTS(source) {
  const orderMatch = source.match(/const preferredOrder\s*=\s*\[([\s\S]*?)\];/);
  if (!orderMatch) fail("could not locate preferredOrder in Tool/src/tools-catalog.ts");
  const order = [...orderMatch[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);

  const metaMatch = source.match(/export const toolMeta\s*=\s*\{/);
  if (!metaMatch || metaMatch.index == null) fail("could not locate toolMeta in Tool/src/tools-catalog.ts");
  const start = metaMatch.index + metaMatch[0].length - 1;
  let depth = 0;
  let end = -1;
  for (let i = start; i < source.length; i += 1) {
    const ch = source[i];
    if (ch === "{") depth += 1;
    else if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  if (end < 0) fail("could not parse toolMeta object");
  const body = source.slice(start + 1, end);
  const metaKeys = new Set();
  for (const line of body.split("\n")) {
    const match = line.match(/^\s*"([^"]+)":\s*\{/);
    if (match) metaKeys.add(match[1]);
  }
  return { order, metaKeys };
}

function assertSame(labelA, setA, labelB, setB) {
  const missingInB = sorted(new Set([...setA].filter((id) => !setB.has(id))));
  const missingInA = sorted(new Set([...setB].filter((id) => !setA.has(id))));
  if (missingInB.length || missingInA.length) {
    const parts = [];
    if (missingInB.length) parts.push(`in ${labelA} but not ${labelB}: ${missingInB.join(", ")}`);
    if (missingInA.length) parts.push(`in ${labelB} but not ${labelA}: ${missingInA.join(", ")}`);
    fail(parts.join(" | "));
  }
}

const swiftIDs = extractSwiftRegistryIDs(read("App/Sources/WebView/DeveloperTools.swift"));
const folderIDs = extractToolFolderIDs();
const websiteIDs = extractWebsiteCatalogIDs(read("Website/src/tool-catalog.ts"));
const { order: preferredOrder, metaKeys } = extractToolsCatalogTS(read("Tool/src/tools-catalog.ts"));

assertSame("DeveloperToolRegistry", swiftIDs, "Tool/tools/*", folderIDs);
assertSame("DeveloperToolRegistry", swiftIDs, "Website tool-catalog", websiteIDs);

const preferredSet = new Set(preferredOrder);
assertSame("DeveloperToolRegistry", swiftIDs, "tools-catalog preferredOrder", preferredSet);

for (const id of metaKeys) {
  if (!swiftIDs.has(id)) fail(`Tool/src/tools-catalog.ts toolMeta has unknown key: ${id}`);
}

const keywordPath = path.join(repoRoot, "Resources/ToolSearchKeywords.json");
if (fs.existsSync(keywordPath)) {
  const keywords = JSON.parse(fs.readFileSync(keywordPath, "utf8"));
  for (const id of swiftIDs) {
    if (!(id in keywords)) fail(`Resources/ToolSearchKeywords.json missing key: ${id}`);
  }
}

const entryMismatches = [];
for (const match of read("App/Sources/WebView/DeveloperTools.swift").matchAll(
  /id:\s*"([^"]+)"[\s\S]*?entryFile:\s*"WebTools\/tools\/([^/]+)\/index\.html"/g,
)) {
  if (match[1] !== match[2]) {
    entryMismatches.push(`${match[1]} -> ${match[2]}`);
  }
}
if (entryMismatches.length) {
  fail(`registry id/entryFile folder mismatch: ${entryMismatches.join("; ")}`);
}

console.log(`verify_tool_catalog: ok (${swiftIDs.size} tools)`);
