import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { fileURLToPath } from "node:url";
import {
  featurePages,
  localizedPath,
  supportedLocales,
} from "../src/seo-pages.js";
import { renderFeatureDocument, renderSitemap } from "./site-renderer.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const clientDirectory = path.join(root, "dist/client");
const serverEntry = path.join(root, "dist/server/entry-server.js");
const { renderHome } = await import(pathToFileURL(serverEntry));

function pageFile(pathname) {
  return path.join(clientDirectory, pathname.replace(/^\//, ""), "index.html");
}

function stylesheetFrom(html) {
  const match = html.match(/<link rel="stylesheet"[^>]*href="([^"]+)"/);
  if (!match) throw new Error("Unable to find the built website stylesheet.");
  return match[1];
}

function replaceFallback(html, markup) {
  const pattern = /<main class="seo-fallback">[\s\S]*?<\/main>/;
  if (!pattern.test(html)) throw new Error("Unable to find the homepage SEO fallback.");
  return html.replace(pattern, markup);
}

const englishFile = path.join(clientDirectory, "index.html");
const chineseFile = path.join(clientDirectory, "zh-CN/index.html");
const englishHTML = await fs.readFile(englishFile, "utf8");
const chineseHTML = await fs.readFile(chineseFile, "utf8");
const stylesheetHref = stylesheetFrom(englishHTML);
const manifest = JSON.parse(await fs.readFile(path.join(clientDirectory, ".vite/manifest.json"), "utf8"));
const staticPageEntry = manifest["src/static-page.js"];
if (!staticPageEntry?.file) throw new Error("Unable to find the built static page script.");
const scriptHref = `/${staticPageEntry.file}`;

await fs.writeFile(
  englishFile,
  replaceFallback(englishHTML, renderHome({ locale: "en", assetBase: "." })),
);
await fs.writeFile(
  chineseFile,
  replaceFallback(chineseHTML, renderHome({ locale: "zh-CN", assetBase: ".." })),
);

for (const page of featurePages) {
  for (const locale of supportedLocales) {
    const outputFile = pageFile(localizedPath(page, locale));
    await fs.mkdir(path.dirname(outputFile), { recursive: true });
    await fs.writeFile(
      outputFile,
      renderFeatureDocument({ page, locale, stylesheetHref, scriptHref }),
    );
  }
}

const requestedDate = process.env.SITE_LAST_MODIFIED;
const lastModified = /^\d{4}-\d{2}-\d{2}$/.test(requestedDate || "")
  ? requestedDate
  : new Date().toISOString().slice(0, 10);
await fs.writeFile(
  path.join(clientDirectory, "sitemap.xml"),
  renderSitemap(lastModified),
);

console.log(`Prerendered 2 homepages and ${featurePages.length * supportedLocales.length} feature pages.`);
