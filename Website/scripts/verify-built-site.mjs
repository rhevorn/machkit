import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const clientDirectory = path.join(root, "dist/client");

async function collectHTML(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectHTML(target));
    else if (entry.isFile() && entry.name.endsWith(".html")) files.push(target);
  }
  return files;
}

function localTarget(href) {
  if (!href.startsWith("/") || href.startsWith("//")) return null;
  const pathname = href.split(/[?#]/, 1)[0];
  if (pathname === "/") return path.join(clientDirectory, "index.html");
  if (pathname.endsWith("/")) return path.join(clientDirectory, pathname, "index.html");
  return path.join(clientDirectory, pathname);
}

const htmlFiles = await collectHTML(clientDirectory);
assert.equal(htmlFiles.length, 12, "expected 10 indexable pages plus two verification HTML files");

const indexableFiles = [];
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
  for (const block of structuredBlocks) JSON.parse(block[1]);

  for (const match of html.matchAll(/href="([^"]+)"/g)) {
    const target = localTarget(match[1]);
    if (!target) continue;
    await fs.access(target).catch(() => {
      throw new Error(`${file} links to missing local target ${match[1]}`);
    });
  }
}

assert.equal(indexableFiles.length, 10, "expected 10 indexable localized pages");

const homepage = await fs.readFile(path.join(clientDirectory, "index.html"), "utf8");
assert.match(homepage, /"@type": "WebSite"/);
assert.match(homepage, /"@type": "Offer"/);
assert.match(homepage, /"price": "0"/);
assert.match(homepage, /Regex Lab/);
assert.match(homepage, /Text Diff/);

const sitemap = await fs.readFile(path.join(clientDirectory, "sitemap.xml"), "utf8");
assert.equal((sitemap.match(/<url>/g) || []).length, 10);
assert.match(sitemap, /https:\/\/machkit\.app\/developer-tools\//);
assert.match(sitemap, /https:\/\/machkit\.app\/zh-CN\/developer-tools\//);

console.log(`Verified ${indexableFiles.length} prerendered pages and their local links.`);
