import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { featurePages, supportedLocales } from "../src/seo-pages.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const clientDirectory = path.join(root, "dist/client");

async function collectHTML(directory: string): Promise<string[]> {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectHTML(target));
    else if (entry.isFile() && entry.name.endsWith(".html")) files.push(target);
  }
  return files;
}

function localTarget(href: string): string | null {
  if (!href.startsWith("/") || href.startsWith("//")) return null;
  const pathname = href.split(/[?#]/, 1)[0]!;
  if (pathname === "/") return path.join(clientDirectory, "index.html");
  if (pathname.endsWith("/")) return path.join(clientDirectory, pathname, "index.html");
  return path.join(clientDirectory, pathname);
}

const htmlFiles = await collectHTML(clientDirectory);
const expectedIndexablePages = 2 + featurePages.length * supportedLocales.length;
assert.equal(
  htmlFiles.length,
  expectedIndexablePages + 2,
  `expected ${expectedIndexablePages} indexable pages plus two verification HTML files`,
);

const indexableFiles: string[] = [];
for (const file of htmlFiles) {
  const html = await fs.readFile(file, "utf8");
  if (!html.includes('<meta name="robots"')) continue;
  indexableFiles.push(file);
  assert.doesNotMatch(html, /class="seo-fallback"/, `${file} was not prerendered`);
  assert.doesNotMatch(html, /(?:src|href)="\/src\//, `${file} references source assets`);
  assert.match(html, /<meta name="description" content="[^"]+"/);
  assert.match(html, /<link rel="canonical" href="https:\/\/machkit\.app\//);
  assert.match(html, /<h1[^>]*>[^<]+/);

  const structuredBlocks = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
  assert.ok(structuredBlocks.length > 0, `${file} has no structured data`);
  for (const block of structuredBlocks) {
    assert.ok(block[1], `${file} has empty structured data`);
    JSON.parse(block[1]);
  }

  for (const match of html.matchAll(/href="([^"]+)"/g)) {
    const href = match[1];
    if (!href) continue;
    const target = localTarget(href);
    if (!target) continue;
    await fs.access(target).catch(() => {
      throw new Error(`${file} links to missing local target ${href}`);
    });
  }
}

assert.equal(
  indexableFiles.length,
  expectedIndexablePages,
  `expected ${expectedIndexablePages} indexable localized pages`,
);

const homepage = await fs.readFile(path.join(clientDirectory, "index.html"), "utf8");
const chineseHomepage = await fs.readFile(path.join(clientDirectory, "zh-CN/index.html"), "utf8");
assert.match(homepage, /"@type": "WebSite"/);
assert.match(homepage, /"@type": "Offer"/);
assert.match(homepage, /"price": "0"/);
assert.match(homepage, /Open the tools page|打开工具页面/);
assert.match(homepage, /href="\.\/utilities\/"/);
assert.match(homepage, /Mackit/);
assert.match(homepage, /Mac cleaner/);
assert.match(homepage, /href="\.\/features\/screenshot\/"/);
assert.match(homepage, /width="2040" height="1648"/);
assert.match(homepage, /data-screen-tab="cleanup"/);
assert.match(homepage, /data-screen-panel="performance"/);
assert.doesNotMatch(homepage, /src\/main\.tsx|24 practical local tools/);
assert.match(homepage, /assets\/cleanup\.webp/);
assert.doesNotMatch(homepage, /assets\/cleanup-zh-CN\.webp/);
assert.match(chineseHomepage, /assets\/cleanup-zh-CN\.webp/);

const utilities = await fs.readFile(path.join(clientDirectory, "utilities/index.html"), "utf8");
assert.match(utilities, /Regex Lab/);
assert.match(utilities, /Text Diff/);
assert.match(utilities, /cURL Lab/);
assert.match(utilities, /tool-introduction/);
assert.match(utilities, /id="port-scan"/);
assert.match(utilities, /href="\/tools\/port-scan\/"/);

const toolPage = await fs.readFile(path.join(clientDirectory, "tools/json-formatter/index.html"), "utf8");
assert.match(toolPage, /JSON Formatter for Mac/);
assert.match(toolPage, /<h1>JSON Formatter, available locally on your Mac\.<\/h1>/);

const sitemap = await fs.readFile(path.join(clientDirectory, "sitemap.xml"), "utf8");
assert.equal((sitemap.match(/<url>/g) || []).length, expectedIndexablePages);
assert.equal((sitemap.match(/<image:image>/g) || []).length, expectedIndexablePages);
assert.match(sitemap, /xmlns:image="http:\/\/www\.google\.com\/schemas\/sitemap-image\/1\.1"/);
assert.match(sitemap, /https:\/\/machkit\.app\/utilities\//);
assert.match(sitemap, /https:\/\/machkit\.app\/zh-CN\/utilities\//);
assert.match(sitemap, /https:\/\/machkit\.app\/features\/screenshot\//);
assert.match(sitemap, /https:\/\/machkit\.app\/zh-CN\/features\/screenshot\//);
assert.match(sitemap, /https:\/\/machkit\.app\/tools\/json-formatter\//);

const manifest = JSON.parse(
  await fs.readFile(path.join(clientDirectory, ".vite/manifest.json"), "utf8"),
) as Record<string, unknown>;
assert.equal(Object.hasOwn(manifest, "src/main.tsx"), false, "client React entry must not be shipped");

console.log(`Verified ${indexableFiles.length} prerendered pages and their local links.`);
