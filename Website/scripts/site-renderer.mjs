import {
  featurePages,
  localizedPath,
  localizedURL,
  site,
  supportedLocales,
} from "../src/seo-pages.js";

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function jsonLD(value) {
  return JSON.stringify(value, null, 2).replaceAll("<", "\\u003c");
}

function localeText(locale) {
  return locale === "zh-CN"
    ? {
        home: "首页",
        capabilities: "功能",
        product: "产品",
        safety: "安全",
        tools: "工具",
        download: "下载",
        language: "English",
        languageLabel: "View in English",
        theme: "切换颜色主题",
        overview: "概览",
        details: "详细能力",
        detailsHeading: "看清提供的能力，也看清安全边界。",
        explore: "继续了解 MachKit",
        exploreBody: "从一个清晰的原生工作区查看、理解并维护你的 Mac。",
        source: "查看源码",
        releases: "版本发布",
        issues: "问题反馈",
        license: "MIT 许可证",
        local: "所有处理都在你的 Mac 上完成",
        platform: "macOS 14+",
        primaryNav: "主导航",
      }
    : {
        home: "Home",
        capabilities: "Capabilities",
        product: "Product",
        safety: "Safety",
        tools: "Tools",
        download: "Download",
        language: "中文",
        languageLabel: "View in Chinese",
        theme: "Switch color theme",
        overview: "Overview",
        details: "What it covers",
        detailsHeading: "See the capability and the boundary together.",
        explore: "Explore MachKit",
        exploreBody: "See, understand, and maintain your Mac from one clear native workspace.",
        source: "View source",
        releases: "Releases",
        issues: "Issues",
        license: "MIT License",
        local: "Everything runs on your Mac",
        platform: "macOS 14+",
        primaryNav: "Primary navigation",
      };
}

function renderBrand(locale) {
  const homeURL = locale === "zh-CN" ? "/zh-CN/" : "/";
  return `<a class="brand" href="${homeURL}" aria-label="MachKit home">
    <img src="/assets/logo.png" alt="" width="28" height="28" />
    <span>MachKit</span>
  </a>`;
}

function renderHeader(locale, activePage) {
  const text = localeText(locale);
  const homeURL = locale === "zh-CN" ? "/zh-CN/" : "/";
  const otherLocale = locale === "zh-CN" ? "en" : "zh-CN";
  const languageURL = localizedPath(activePage, otherLocale);
  const toolsPage = featurePages.find((page) => page.id === "utilities");
  return `<header class="site-header">
    <nav class="nav-shell" aria-label="${escapeHTML(text.primaryNav)}">
      ${renderBrand(locale)}
      <div class="nav-links">
        <a href="${homeURL}#capabilities">${escapeHTML(text.capabilities)}</a>
        <a href="${homeURL}#product">${escapeHTML(text.product)}</a>
        <a href="${homeURL}#safety">${escapeHTML(text.safety)}</a>
        <a href="${localizedPath(toolsPage, locale)}">${escapeHTML(text.tools)}</a>
      </div>
      <div class="nav-actions">
        <a class="language-link" href="${languageURL}" aria-label="${escapeHTML(text.languageLabel)}">
          <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" fill="currentColor" viewBox="0 0 256 256" aria-hidden="true">
            <path d="M128,24A104,104,0,1,0,232,128,104.12,104.12,0,0,0,128,24Zm86.47,96H174.83a156.89,156.89,0,0,0-12.34-61.74A88.35,88.35,0,0,1,214.47,120ZM128,40c10.13,0,25.52,27,30.64,80H97.36C102.48,67,117.87,40,128,40ZM93.51,58.26A156.89,156.89,0,0,0,81.17,120H41.53A88.35,88.35,0,0,1,93.51,58.26ZM41.53,136H81.17a156.89,156.89,0,0,0,12.34,61.74A88.35,88.35,0,0,1,41.53,136ZM128,216c-10.13,0-25.52-27-30.64-80h61.28C153.52,189,138.13,216,128,216Zm34.49-18.26A156.89,156.89,0,0,0,174.83,136h39.64A88.35,88.35,0,0,1,162.49,197.74Z" />
          </svg>
          <span>${escapeHTML(text.language)}</span>
        </a>
        <button class="theme-button" type="button" data-theme-toggle aria-label="${escapeHTML(text.theme)}" title="${escapeHTML(text.theme)}">
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 256 256" aria-hidden="true">
            <path d="M233.54,142.23a8,8,0,0,0-8-2,88.08,88.08,0,0,1-109.8-109.8,8,8,0,0,0-10-10,104.84,104.84,0,0,0-52.91,37A104,104,0,0,0,136,224a103.09,103.09,0,0,0,62.52-20.88,104.84,104.84,0,0,0,37-52.91A8,8,0,0,0,233.54,142.23ZM188.9,190.34A88,88,0,0,1,65.66,67.11a89,89,0,0,1,31.4-26A106,106,0,0,0,96,56,104.11,104.11,0,0,0,200,160a106,106,0,0,0,14.92-1.06A89,89,0,0,1,188.9,190.34Z" />
          </svg>
        </button>
        <a class="nav-download" href="${site.downloadURL}" data-release-download>
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 256 256" aria-hidden="true">
            <path d="M228,144v64a12,12,0,0,1-12,12H40a12,12,0,0,1-12-12V144a12,12,0,0,1,24,0v52H204V144a12,12,0,0,1,24,0Zm-108.49,8.49a12,12,0,0,0,17,0l40-40a12,12,0,0,0-17-17L140,115V32a12,12,0,0,0-24,0v83L96.49,95.51a12,12,0,0,0-17,17Z" />
          </svg>
          <span>${escapeHTML(text.download)}</span>
        </a>
      </div>
    </nav>
  </header>`;
}

function renderFooter(locale) {
  const text = localeText(locale);
  return `<footer class="site-footer">
    <div class="footer-main section-shell">
      <div class="footer-brand">
        ${renderBrand(locale)}
        <p>${escapeHTML(text.exploreBody)}</p>
      </div>
      <div class="footer-links">
        <a href="${localizedPath(featurePages.find((page) => page.id === "utilities"), locale)}">${escapeHTML(text.tools)}</a>
        <a href="${site.repositoryURL}/releases">${escapeHTML(text.releases)}</a>
        <a href="${site.repositoryURL}/issues">${escapeHTML(text.issues)}</a>
        <a href="${site.repositoryURL}/blob/main/LICENSE">${escapeHTML(text.license)}</a>
      </div>
    </div>
    <div class="footer-bottom section-shell">
      <span>© 2026 MachKit</span>
      <span>${escapeHTML(text.local)}</span>
      <span>${escapeHTML(text.platform)}</span>
    </div>
  </footer>`;
}

function renderCatalog(content) {
  const groups = content.catalogGroups?.length
    ? content.catalogGroups
    : content.catalog?.length
      ? [{ id: "all", category: content.catalogTitle, tools: content.catalog }]
      : [];
  if (!groups.length) return "";

  let toolIndex = 0;
  return `<section class="feature-catalog section-shell" aria-labelledby="catalog-title">
    <header class="section-heading">
      <p class="kicker">${escapeHTML(content.eyebrow)}</p>
      <h2 id="catalog-title">${escapeHTML(content.catalogTitle)}</h2>
      <p>${escapeHTML(content.catalogIntro)}</p>
    </header>
    <div class="tool-catalog">
      ${groups.map((group) => `<section class="tool-category" aria-labelledby="category-${escapeHTML(group.id)}">
        <h3 id="category-${escapeHTML(group.id)}">${escapeHTML(group.category)}</h3>
        <div class="tool-category-list">
          ${group.tools.map((entry) => {
            toolIndex += 1;
            const tool = Array.isArray(entry)
              ? { id: `tool-${toolIndex}`, title: entry[0], summary: entry[1], introduction: entry[1], highlights: [] }
              : entry;
            return `<article id="${escapeHTML(tool.id)}">
              <span>${String(toolIndex).padStart(2, "0")}</span>
              <div>
                <h4>${escapeHTML(tool.title)}</h4>
                <p class="tool-summary">${escapeHTML(tool.summary)}</p>
                <p class="tool-introduction">${escapeHTML(tool.introduction)}</p>
                ${tool.highlights?.length ? `<ul>${tool.highlights.map((item) => `<li>${escapeHTML(item)}</li>`).join("")}</ul>` : ""}
              </div>
            </article>`;
          }).join("")}
        </div>
      </section>`).join("")}
    </div>
  </section>`;
}

export function renderFeatureDocument({
  page,
  locale,
  stylesheetHref = "/src/styles.css",
  scriptHref = "/src/static-page.js",
}) {
  const content = page.locales[locale];
  const text = localeText(locale);
  const canonical = localizedURL(page, locale);
  const homeURL = locale === "zh-CN" ? `${site.origin}/zh-CN/` : `${site.origin}/`;
  const imageURL = `${site.origin}/assets/${page.image}`;
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${canonical}#webpage`,
        url: canonical,
        name: content.title,
        description: content.description,
        inLanguage: locale,
        image: imageURL,
        isPartOf: { "@id": `${site.origin}/#website` },
        about: { "@id": `${site.origin}/#software` },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: text.home, item: homeURL },
          { "@type": "ListItem", position: 2, name: content.eyebrow, item: canonical },
        ],
      },
    ],
  };

  return `<!doctype html>
<html lang="${locale}" data-theme="light">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#f4f5f7" />
    <meta name="robots" content="index,follow,max-image-preview:large" />
    <meta name="description" content="${escapeHTML(content.description)}" />
    <link rel="canonical" href="${canonical}" />
    <link rel="alternate" hreflang="en" href="${localizedURL(page, "en")}" />
    <link rel="alternate" hreflang="zh-CN" href="${localizedURL(page, "zh-CN")}" />
    <link rel="alternate" hreflang="x-default" href="${localizedURL(page, "en")}" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="MachKit" />
    <meta property="og:title" content="${escapeHTML(content.title)}" />
    <meta property="og:description" content="${escapeHTML(content.description)}" />
    <meta property="og:url" content="${canonical}" />
    <meta property="og:image" content="${imageURL}" />
    <meta property="og:image:alt" content="${escapeHTML(content.heading)}" />
    <meta property="og:locale" content="${locale === "zh-CN" ? "zh_CN" : "en_US"}" />
    <meta property="og:locale:alternate" content="${locale === "zh-CN" ? "en_US" : "zh_CN"}" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${escapeHTML(content.title)}" />
    <meta name="twitter:description" content="${escapeHTML(content.description)}" />
    <meta name="twitter:image" content="${imageURL}" />
    <link rel="icon" type="image/png" href="/assets/favicon.png" />
    <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png" />
    <link rel="stylesheet" href="${stylesheetHref}" />
    <title>${escapeHTML(content.title)}</title>
    <script type="application/ld+json">${jsonLD(structuredData)}</script>
    <script>try{const t=localStorage.getItem("machkit-website-theme");if(t==="light"||t==="dark"){document.documentElement.dataset.theme=t;document.documentElement.style.colorScheme=t}}catch{}</script>
  </head>
  <body>
    <div class="site-shell feature-page">
      ${renderHeader(locale, page)}
      <main>
        <section class="feature-hero section-shell">
          <div class="feature-hero-copy">
            <nav class="breadcrumbs" aria-label="Breadcrumb">
              <a href="${locale === "zh-CN" ? "/zh-CN/" : "/"}">${escapeHTML(text.home)}</a>
              <span aria-hidden="true">/</span>
              <span>${escapeHTML(content.eyebrow)}</span>
            </nav>
            <p class="kicker">${escapeHTML(content.eyebrow)}</p>
            <h1>${escapeHTML(content.heading)}</h1>
            <p class="feature-lead">${escapeHTML(content.lead)}</p>
            <div class="hero-actions">
              <a class="button button-primary" href="${site.downloadURL}" data-release-download>${escapeHTML(text.download)}</a>
              <a class="text-link" href="${site.repositoryURL}">${escapeHTML(text.source)} <span aria-hidden="true">→</span></a>
            </div>
          </div>
          <div class="feature-visual">
            <img src="/assets/${page.image}" alt="${escapeHTML(content.heading)}" width="1600" height="1329" />
          </div>
        </section>

        <section class="feature-highlights section-shell" aria-label="${escapeHTML(text.overview)}">
          ${content.highlights.map(([title, detail], index) => `<article>
            <span>${String(index + 1).padStart(2, "0")}</span>
            <h2>${escapeHTML(title)}</h2>
            <p>${escapeHTML(detail)}</p>
          </article>`).join("")}
        </section>

        ${renderCatalog(content)}

        <section class="feature-details section-shell" aria-labelledby="details-title">
          <header class="section-heading">
            <p class="kicker">${escapeHTML(text.details)}</p>
            <h2 id="details-title">${escapeHTML(text.detailsHeading)}</h2>
          </header>
          <div class="feature-detail-list">
            ${content.sections.map((section, index) => `<article>
              <span>${String(index + 1).padStart(2, "0")}</span>
              <div>
                <h3>${escapeHTML(section.title)}</h3>
                <p>${escapeHTML(section.body)}</p>
                <ul>${section.items.map((item) => `<li>${escapeHTML(item)}</li>`).join("")}</ul>
              </div>
            </article>`).join("")}
          </div>
        </section>

        <section class="feature-related">
          <div class="section-shell">
            <header class="section-heading">
              <p class="kicker">MachKit</p>
              <h2>${escapeHTML(text.explore)}</h2>
              <p>${escapeHTML(text.exploreBody)}</p>
            </header>
            <div class="related-links">
              ${featurePages.filter((candidate) => candidate.id !== page.id).map((candidate) => `<a href="${localizedPath(candidate, locale)}">
                <span>${escapeHTML(candidate.locales[locale].eyebrow)}</span>
                <strong>${escapeHTML(candidate.locales[locale].heading)}</strong>
              </a>`).join("")}
            </div>
          </div>
        </section>
      </main>
      ${renderFooter(locale)}
    </div>
    <script type="module" src="${scriptHref}"></script>
  </body>
</html>`;
}

export function renderSitemap(lastModified) {
  const entries = [
    ...supportedLocales.map((locale) => ({
      url: locale === "zh-CN" ? `${site.origin}/zh-CN/` : `${site.origin}/`,
      alternates: {
        en: `${site.origin}/`,
        "zh-CN": `${site.origin}/zh-CN/`,
        "x-default": `${site.origin}/`,
      },
    })),
    ...featurePages.flatMap((page) => supportedLocales.map((locale) => ({
      url: localizedURL(page, locale),
      alternates: {
        en: localizedURL(page, "en"),
        "zh-CN": localizedURL(page, "zh-CN"),
        "x-default": localizedURL(page, "en"),
      },
    }))),
  ];

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset
  xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
>
${entries.map((entry) => `  <url>
    <loc>${entry.url}</loc>
    <lastmod>${lastModified}</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${entry.alternates.en}" />
    <xhtml:link rel="alternate" hreflang="zh-CN" href="${entry.alternates["zh-CN"]}" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${entry.alternates["x-default"]}" />
  </url>`).join("\n")}
</urlset>
`;
}
