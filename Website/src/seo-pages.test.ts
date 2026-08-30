import test from "node:test";
import assert from "node:assert/strict";
import {
  featurePages,
  localizedPath,
  supportedLocales,
} from "./seo-pages.js";
import type { FeaturePage, SiteLocale } from "./seo-pages.js";
import { renderFeatureDocument, renderSitemap } from "../scripts/site-renderer.js";
import {
  groupedWebsiteTools,
  localizedWebsiteTools,
  websiteToolCatalog,
} from "./tool-catalog.js";

test("website tool catalog keeps unique localized entries with introductions", () => {
  assert.equal(new Set(websiteToolCatalog.map((tool) => tool.id)).size, websiteToolCatalog.length);
  assert.equal(localizedWebsiteTools("en").length, websiteToolCatalog.length);
  assert.equal(localizedWebsiteTools("zh-CN").length, websiteToolCatalog.length);
  for (const tool of websiteToolCatalog) {
    assert.ok(tool.category);
    assert.ok(tool.en.title);
    assert.ok(tool.en.summary);
    assert.ok(tool.en.introduction.length > tool.en.summary.length);
    assert.ok(tool.en.highlights.length >= 3);
    assert.ok(tool["zh-CN"].title);
    assert.ok(tool["zh-CN"].summary);
    assert.ok(tool["zh-CN"].introduction.length > tool["zh-CN"].summary.length);
    assert.ok(tool["zh-CN"].highlights.length >= 3);
  }
  assert.equal(groupedWebsiteTools("en").length, 4);
  assert.equal(
    groupedWebsiteTools("en").reduce((sum, group) => sum + group.tools.length, 0),
    websiteToolCatalog.length,
  );
});

test("feature pages provide complete localized content and unique paths", () => {
  const paths = new Set<string>();
  for (const page of featurePages as readonly FeaturePage[]) {
    for (const locale of supportedLocales as readonly SiteLocale[]) {
      const content = page.locales[locale];
      assert.ok(content?.title);
      assert.ok(content?.description);
      assert.ok(content?.heading);
      assert.equal(content.highlights.length, 3);
      assert.equal(content.sections.length, 3);
      const pathname = localizedPath(page, locale);
      assert.equal(paths.has(pathname), false);
      paths.add(pathname);
    }
  }
});

test("utilities page represents the current growing catalog with introductions", () => {
  const page = (featurePages as readonly FeaturePage[]).find((candidate) => candidate.id === "utilities");
  assert.ok(page);
  assert.ok(page.locales.en.catalog);
  assert.ok(page.locales["zh-CN"].catalog);
  assert.ok(page.locales.en.catalogGroups);
  assert.equal(page.locales.en.catalog.length, websiteToolCatalog.length);
  assert.equal(page.locales["zh-CN"].catalog!.length, websiteToolCatalog.length);
  assert.equal(page.locales.en.catalogGroups.length, 4);
  assert.match(page.locales.en.lead, /catalog/i);
  assert.match(page.locales.en.lead, /screenshot/i);
  assert.match(page.locales["zh-CN"].lead, /目录|工具/);
  assert.match(page.locales["zh-CN"].lead, /截图/);
  assert.ok(page.locales.en.catalogTitle);
  assert.ok(page.locales["zh-CN"].catalogTitle);
  assert.match(page.locales.en.catalogTitle, /introduction/i);
  assert.match(page.locales["zh-CN"].catalogTitle, /介绍/);

  const html = renderFeatureDocument({ page, locale: "en", stylesheetHref: "/assets/site.css" });
  assert.match(html, /id="curl-lab"/);
  assert.match(html, /cURL Lab/);
  assert.match(html, /Run requests locally when needed/);
  assert.match(html, /Text &amp; Data/);
  assert.match(html, /tool-introduction/);
  assert.match(html, /Native screenshot/);
  assert.match(html, /Global shortcut region capture/);
  assert.match(html, /aria-label="Primary navigation"/);
  assert.match(html, /href="\/#capabilities"/);
  assert.match(html, /href="\/#product"/);
  assert.match(html, /href="\/#safety"/);
  assert.match(html, /href="\/utilities\/"/);
});

test("feature documents expose canonical, alternate, and structured data", () => {
  const page = (featurePages as readonly FeaturePage[])[0];
  assert.ok(page);
  const html = renderFeatureDocument({ page, locale: "en", stylesheetHref: "/assets/site.css" });
  const chineseHTML = renderFeatureDocument({ page, locale: "zh-CN", stylesheetHref: "/assets/site.css" });
  assert.match(html, /<link rel="canonical" href="https:\/\/machkit\.app\/features\/storage-cleanup\/"/);
  assert.match(html, /hreflang="zh-CN"/);
  assert.match(html, /"@type": "WebPage"/);
  assert.match(html, /\/assets\/site\.css/);
  assert.match(html, /\/assets\/cleanup\.webp/);
  assert.doesNotMatch(html, /-zh-CN\.webp/);
  assert.match(chineseHTML, /\/assets\/cleanup-zh-CN\.webp/);
});

test("screenshot page has localized capture and annotation content", () => {
  const page = (featurePages as readonly FeaturePage[]).find((candidate) => candidate.id === "screenshot");
  assert.ok(page);
  assert.match(page.locales.en.title, /Mac Screenshot Tool/);
  assert.match(page.locales.en.lead, /global shortcut/i);
  assert.match(page.locales["zh-CN"].lead, /全局快捷键/);
  assert.ok(page.locales.en.sections[1]);
  assert.match(page.locales.en.sections[1].body, /mosaic/i);
});

test("sitemap includes every localized homepage and feature page", () => {
  const sitemap = renderSitemap("2026-08-15");
  assert.equal((sitemap.match(/<url>/g) || []).length, 12);
  assert.match(sitemap, /https:\/\/machkit\.app\/utilities\//);
  assert.match(sitemap, /https:\/\/machkit\.app\/zh-CN\/utilities\//);
  assert.match(sitemap, /https:\/\/machkit\.app\/features\/screenshot\//);
  assert.match(sitemap, /xmlns:image="http:\/\/www\.google\.com\/schemas\/sitemap-image\/1\.1"/);
  assert.equal((sitemap.match(/<image:image>/g) || []).length, 12);
  assert.match(sitemap, /https:\/\/machkit\.app\/assets\/cleanup\.webp/);
  assert.match(sitemap, /https:\/\/machkit\.app\/assets\/cleanup-zh-CN\.webp/);
  assert.match(sitemap, /https:\/\/machkit\.app\/assets\/tools-zh-CN\.webp/);
  assert.equal((sitemap.match(/<lastmod>2026-08-15<\/lastmod>/g) || []).length, 12);
});

test("sitemap omits lastmod when no reliable content date is available", () => {
  assert.doesNotMatch(renderSitemap({}), /<lastmod>/);
});
