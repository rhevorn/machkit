import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { pathToFileURL } from "node:url";
import { fileURLToPath } from "node:url";
import {
  featurePages,
  localizedPath,
  site,
  supportedLocales,
} from "../src/seo-pages.js";
import type { FeaturePage, SiteLocale } from "../src/seo-pages.js";
import type { RenderHomeOptions } from "../src/entry-server.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = path.resolve(root, "..");
const clientDirectory = path.join(root, "dist/client");
const serverEntry = path.join(root, "dist/server/entry-server.js");
const { renderFeatureDocument, renderHome, renderSitemap } = await import(pathToFileURL(serverEntry).href) as {
  renderFeatureDocument: (options: {
    page: FeaturePage;
    locale: SiteLocale;
    stylesheetHref: string;
    scriptHref: string;
  }) => string;
  renderHome: (options?: RenderHomeOptions) => string;
  renderSitemap: (lastModified?: Record<string, string | undefined>) => string;
};
const execFileAsync = promisify(execFile);

function bakeDownloadURL(html: string): string {
  const next = html.replace(
    /"downloadUrl"\s*:\s*"[^"]*"/g,
    `"downloadUrl": ${JSON.stringify(site.downloadURL)}`,
  );
  if (!next.includes(site.downloadURL)) {
    throw new Error("Unable to bake the release download URL into homepage structured data.");
  }
  return next;
}

async function gitLastModified(paths: string[]): Promise<string | undefined> {
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

function pageFile(pathname: string): string {
  return path.join(clientDirectory, pathname.replace(/^\//, ""), "index.html");
}

function stylesheetFrom(html: string): string {
  const match = html.match(/<link rel="stylesheet"[^>]*href="([^"]+)"/);
  if (!match?.[1]) throw new Error("Unable to find the built website stylesheet.");
  return match[1];
}

function replaceFallback(html: string, markup: string): string {
  const pattern = /<main class="seo-fallback">[\s\S]*?<\/main>/;
  if (!pattern.test(html)) throw new Error("Unable to find the homepage SEO fallback.");
  return html.replace(pattern, markup);
}

type ViteManifestEntry = {
  file?: string;
  [key: string]: unknown;
};

const englishFile = path.join(clientDirectory, "index.html");
const chineseFile = path.join(clientDirectory, "zh-CN/index.html");
const englishHTML = await fs.readFile(englishFile, "utf8");
const chineseHTML = await fs.readFile(chineseFile, "utf8");
const stylesheetHref = stylesheetFrom(englishHTML);
const manifest = JSON.parse(
  await fs.readFile(path.join(clientDirectory, ".vite/manifest.json"), "utf8"),
) as Record<string, ViteManifestEntry>;
const staticPageEntry = manifest["src/static-page.ts"];
if (!staticPageEntry?.file) throw new Error("Unable to find the built static page script.");
const scriptHref = `/${staticPageEntry.file}`;

await fs.writeFile(
  englishFile,
  bakeDownloadURL(replaceFallback(englishHTML, renderHome({ locale: "en", assetBase: "." }))),
);
await fs.writeFile(
  chineseFile,
  bakeDownloadURL(replaceFallback(chineseHTML, renderHome({ locale: "zh-CN", assetBase: ".." }))),
);

const pages = featurePages as readonly FeaturePage[];
for (const page of pages) {
  for (const locale of supportedLocales as readonly SiteLocale[]) {
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
        "Website/src/App.tsx",
        "Website/src/i18n.ts",
      ]),
      features: await gitLastModified([
        "Website/src/seo-pages.ts",
        "Website/scripts/site-renderer.ts",
      ]),
      utilities: await gitLastModified([
        "Website/src/seo-pages.ts",
        "Website/src/tool-catalog.ts",
        "Website/scripts/site-renderer.ts",
      ]),
    };
await fs.writeFile(
  path.join(clientDirectory, "sitemap.xml"),
  renderSitemap(lastModified),
);

console.log(`Prerendered 2 homepages and ${pages.length * supportedLocales.length} feature pages.`);
