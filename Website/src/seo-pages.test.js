import test from "node:test";
import assert from "node:assert/strict";
import {
  featurePages,
  localizedPath,
  supportedLocales,
} from "./seo-pages.js";
import { renderFeatureDocument, renderSitemap } from "../scripts/site-renderer.mjs";
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
  const paths = new Set();
  for (const page of featurePages) {
    for (const locale of supportedLocales) {
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
  const page = featurePages.find((candidate) => candidate.id === "utilities");
  assert.equal(page.locales.en.catalog.length, 24);
  assert.equal(page.locales["zh-CN"].catalog.length, 24);
  assert.equal(page.locales.en.catalogGroups.length, 4);
  assert.match(page.locales.en.lead, /growing catalog/i);
  assert.match(page.locales["zh-CN"].lead, /持续增长/);
  assert.match(page.locales.en.catalogTitle, /introduction/i);
  assert.match(page.locales["zh-CN"].catalogTitle, /介绍/);

  const html = renderFeatureDocument({ page, locale: "en", stylesheetHref: "/assets/site.css" });
  assert.match(html, /id="curl-lab"/);
  assert.match(html, /cURL Lab/);
  assert.match(html, /Run requests locally when needed/);
  assert.match(html, /Text &amp; Data/);
  assert.match(html, /tool-introduction/);
});

test("feature documents expose canonical, alternate, and structured data", () => {
  const page = featurePages[0];
  const html = renderFeatureDocument({ page, locale: "en", stylesheetHref: "/assets/site.css" });
  assert.match(html, /<link rel="canonical" href="https:\/\/machkit\.app\/features\/storage-cleanup\/"/);
  assert.match(html, /hreflang="zh-CN"/);
  assert.match(html, /"@type": "WebPage"/);
  assert.match(html, /\/assets\/site\.css/);
});

test("sitemap includes every localized homepage and feature page", () => {
  const sitemap = renderSitemap("2026-08-15");
  assert.equal((sitemap.match(/<url>/g) || []).length, 10);
  assert.match(sitemap, /https:\/\/machkit\.app\/utilities\//);
  assert.match(sitemap, /https:\/\/machkit\.app\/zh-CN\/utilities\//);
  assert.equal((sitemap.match(/<lastmod>2026-08-15<\/lastmod>/g) || []).length, 10);
});
