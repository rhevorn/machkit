import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { pathToFileURL } from "node:url";
import { fileURLToPath } from "node:url";
import {
  featurePages,
  localizedPath,
  supportedLocales,
} from "../src/seo-pages.js";
import { renderFeatureDocument, renderSitemap } from "./site-renderer.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = path.resolve(root, "..");
const clientDirectory = path.join(root, "dist/client");
const serverEntry = path.join(root, "dist/server/entry-server.js");
const { renderHome } = await import(pathToFileURL(serverEntry));
const execFileAsync = promisify(execFile);

async function gitLastModified(paths) {
  try {
    const { stdout } = await execFileAsync(
      "git",
      ["log", "-1", "--format=%cs", "--", ...paths],
      { cwd: repositoryRoot },
    );
    const value = stdout.trim();
    return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : undefined;
  } catch {
    return undefined;
  }
}

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
const explicitDate = /^\d{4}-\d{2}-\d{2}$/.test(requestedDate || "")
  ? requestedDate
  : undefined;
const lastModified = explicitDate
  ? { home: explicitDate, features: explicitDate, utilities: explicitDate }
  : {
      home: await gitLastModified([
        "Website/index.html",
        "Website/zh-CN/index.html",
        "Website/src/App.jsx",
        "Website/src/i18n.js",
      ]),
      features: await gitLastModified([
        "Website/src/seo-pages.js",
        "Website/scripts/site-renderer.mjs",
      ]),
      utilities: await gitLastModified([
        "Website/src/seo-pages.js",
        "Website/src/tool-catalog.js",
        "Website/scripts/site-renderer.mjs",
      ]),
    };
await fs.writeFile(
  path.join(clientDirectory, "sitemap.xml"),
  renderSitemap(lastModified),
);

console.log(`Prerendered 2 homepages and ${featurePages.length * supportedLocales.length} feature pages.`);
