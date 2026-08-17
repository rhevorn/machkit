import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  ChartDonut,
  Code,
  DownloadSimple,
  GithubLogo,
  Globe,
  House,
  Moon,
  Pulse,
  ShieldCheck,
  Sun,
  Wrench,
} from "@phosphor-icons/react";
import { messages } from "./i18n.js";
import {
  fallbackRelease,
  REPOSITORY_URL,
} from "./release.js";

const THEME_KEY = "machkit-website-theme";
const SCREEN_KEYS = [
  "overview",
  "cleanup",
  "apps",
  "storage",
  "performance",
  "network",
  "tools",
  "system",
];

const GROUP_ICONS = [ChartDonut, Wrench, Pulse, Code];

function preferredTheme() {
  if (typeof window === "undefined") return "light";
  const savedTheme = window.localStorage.getItem(THEME_KEY);
  if (savedTheme === "light" || savedTheme === "dark") return savedTheme;
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function Brand({ assetBase }) {
  return (
    <a className="brand" href="#top" aria-label="MachKit home">
      <img src={`${assetBase}/assets/logo.png`} alt="" />
      <span>MachKit</span>
    </a>
  );
}

function CapabilityGroup({ group, index }) {
  const Icon = GROUP_ICONS[index];
  return (
    <article className="capability-group" data-tone={group.tone}>
      <header>
        <Icon size={23} weight="duotone" aria-hidden="true" />
        <div>
          <h3>{group.title}</h3>
          <p>{group.body}</p>
        </div>
      </header>
      <dl>
        {group.items.map(([title, detail, href]) => (
          <div key={title}>
            <dt>{href ? <a href={href}>{title}</a> : title}</dt>
            <dd>{detail}</dd>
          </div>
        ))}
      </dl>
    </article>
  );
}

export function App({
  locale: localeOverride,
  assetBase: assetBaseOverride,
  initialTheme,
} = {}) {
  const documentLocale = typeof document !== "undefined" && document.documentElement.dataset.locale === "zh-CN"
    ? "zh-CN"
    : "en";
  const locale = localeOverride || documentLocale;
  const assetBase = assetBaseOverride
    || (typeof document !== "undefined" ? document.documentElement.dataset.assetBase : ".")
    || ".";
  const copy = messages[locale];
  const [theme, setTheme] = useState(() => initialTheme || preferredTheme());
  const [selectedScreen, setSelectedScreen] = useState("overview");
  const release = fallbackRelease;

  const languageURL = locale === "en" ? "./zh-CN/" : "../";
  const languageLabel = locale === "en" ? "中文" : "English";
  const utilitiesURL = "./utilities/";

  const screenImages = useMemo(() => {
    const localeSuffix = locale === "zh-CN" ? "-zh-CN" : "";
    return Object.fromEntries(
      SCREEN_KEYS.map((key) => [key, `${assetBase}/assets/${key}${localeSuffix}.webp`]),
    );
  }, [assetBase, locale]);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute(
      "content",
      theme === "dark" ? "#101214" : "#f4f5f7",
    );
  }, [theme]);

  const toggleTheme = () => {
    setTheme((current) => {
      const next = current === "dark" ? "light" : "dark";
      window.localStorage.setItem(THEME_KEY, next);
      return next;
    });
  };

  const activeScreen = copy.screens.tabs[selectedScreen];

  return (
    <div className="site-shell" id="top">
      <header className="site-header">
        <nav className="nav-shell" aria-label="Primary navigation">
          <Brand assetBase={assetBase} />
          <div className="nav-links">
            <a href="#capabilities">{copy.nav.capabilities}</a>
            <a href="#product">{copy.nav.screens}</a>
            <a href="#safety">{copy.nav.safety}</a>
            <a href={utilitiesURL}>{copy.nav.tools}</a>
          </div>
          <div className="nav-actions">
            <a className="language-link" href={languageURL} aria-label={copy.controls.language}>
              <Globe size={15} aria-hidden="true" />
              <span>{languageLabel}</span>
            </a>
            <button
              className="theme-button"
              type="button"
              onClick={toggleTheme}
              aria-label={copy.controls.theme}
              title={copy.controls.theme}
            >
              <span className="theme-icon theme-icon-light" aria-hidden="true">
                <Moon size={18} />
              </span>
              <span className="theme-icon theme-icon-dark" aria-hidden="true">
                <Sun size={18} />
              </span>
            </button>
            <a className="nav-download" href={release.downloadURL}>
              <DownloadSimple size={16} weight="bold" />
              <span>{copy.nav.download}</span>
            </a>
          </div>
        </nav>
      </header>

      <main>
        <section className="hero section-shell" aria-labelledby="hero-title">
          <div className="hero-copy-block">
            <p className="kicker">{copy.hero.eyebrow}</p>
            <h1 id="hero-title">{copy.hero.title}</h1>
            <p className="hero-description">{copy.hero.description}</p>
            <div className="hero-actions">
              <a className="button button-primary" href={release.downloadURL}>
                <DownloadSimple size={18} weight="bold" />
                {copy.hero.primary} · {release.tag}
              </a>
              <a className="text-link" href={REPOSITORY_URL} target="_blank" rel="noreferrer">
                <GithubLogo size={19} weight="fill" />
                {copy.hero.secondary}
                <ArrowRight size={15} />
              </a>
            </div>
            <p className="compatibility">{copy.hero.compatibility}</p>
          </div>

          <div className="hero-product" aria-label={copy.hero.previewAlt}>
            <div className="product-window">
              <img
                src={screenImages.overview}
                alt={copy.hero.previewAlt}
                width="1600"
                height="1329"
                fetchPriority="high"
              />
            </div>
          </div>
        </section>

        <section className="introduction section-shell" aria-labelledby="introduction-title">
          <div>
            <p className="kicker">{copy.introduction.kicker}</p>
            <h2 id="introduction-title">{copy.introduction.title}</h2>
          </div>
          <div className="introduction-copy">
            {copy.introduction.paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
          </div>
        </section>

        <section className="capabilities section-shell" id="capabilities" aria-labelledby="capabilities-title">
          <header className="section-heading">
            <p className="kicker">{copy.capabilities.kicker}</p>
            <h2 id="capabilities-title">{copy.capabilities.title}</h2>
            <p>{copy.capabilities.description}</p>
          </header>
          <div className="capability-grid">
            {copy.capabilities.groups.map((group, index) => (
              <CapabilityGroup key={group.title} group={group} index={index} />
            ))}
          </div>
        </section>

        <section className="product-section" id="product" aria-labelledby="product-title">
          <div className="section-shell">
            <header className="section-heading product-heading">
              <p className="kicker">{copy.screens.kicker}</p>
              <h2 id="product-title">{copy.screens.title}</h2>
              <p>{copy.screens.description}</p>
            </header>

            <div className="screen-tabs" role="tablist" aria-label={copy.screens.title}>
              {SCREEN_KEYS.map((key) => (
                <button
                  key={key}
                  type="button"
                  role="tab"
                  aria-selected={selectedScreen === key}
                  className={selectedScreen === key ? "is-active" : ""}
                  onClick={() => setSelectedScreen(key)}
                >
                  {copy.screens.tabs[key].label}
                </button>
              ))}
            </div>

            <div className="screen-layout">
              <div className="screen-copy" aria-live="polite">
                <span className="screen-index">0{SCREEN_KEYS.indexOf(selectedScreen) + 1}</span>
                <h3>{activeScreen.title}</h3>
                <ul className="screen-feature-list">
                  {activeScreen.features.map((feature) => <li key={feature}>{feature}</li>)}
                </ul>
              </div>
              <div className="screen-frame">
                <img
                  src={screenImages[selectedScreen]}
                  alt={activeScreen.alt}
                  width="1600"
                  height="1329"
                />
              </div>
            </div>
          </div>
        </section>

        <section className="safety section-shell" id="safety" aria-labelledby="safety-title">
          <header className="section-heading safety-heading">
            <p className="kicker">{copy.safety.kicker}</p>
            <h2 id="safety-title">{copy.safety.title}</h2>
            <p>{copy.safety.description}</p>
          </header>
          <div className="principle-list">
            {copy.safety.principles.map(([title, detail], index) => (
              <article key={title}>
                <span>0{index + 1}</span>
                <h3>{title}</h3>
                <p>{detail}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="tools-section" id="tools" aria-labelledby="tools-title">
          <div className="section-shell tools-layout">
            <header className="section-heading">
              <p className="kicker">{copy.tools.kicker}</p>
              <h2 id="tools-title">{copy.tools.title}</h2>
              <p>{copy.tools.description}</p>
              <dl className="tool-principles">
                {copy.tools.principles.map(([title, detail]) => (
                  <div key={title}>
                    <dt>{title}</dt>
                    <dd>{detail}</dd>
                  </div>
                ))}
              </dl>
            </header>
            <div className="tools-teaser-aside">
              <p className="tools-count">{copy.tools.count}</p>
              <dl className="tools-preview">
                {copy.tools.preview.map(([title, detail]) => (
                  <div key={title}>
                    <dt>{title}</dt>
                    <dd>{detail}</dd>
                  </div>
                ))}
              </dl>
              <a className="tools-explore-link" href={utilitiesURL}>
                {copy.tools.explore}<ArrowRight size={15} />
              </a>
            </div>
          </div>
        </section>

        <section className="open-source section-shell" aria-labelledby="open-source-title">
          <ShieldCheck size={30} weight="duotone" aria-hidden="true" />
          <div>
            <p className="kicker">{copy.openSource.kicker}</p>
            <h2 id="open-source-title">{copy.openSource.title}</h2>
            <p>{copy.openSource.description}</p>
          </div>
          <div className="open-source-actions">
            <a className="button button-primary" href={REPOSITORY_URL} target="_blank" rel="noreferrer">
              <GithubLogo size={18} weight="fill" />
              {copy.openSource.primary}
            </a>
            <a className="text-link" href={release.downloadURL} target="_blank" rel="noreferrer">
              {copy.openSource.secondary}<ArrowRight size={15} />
            </a>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="footer-main section-shell">
          <div className="footer-brand">
            <Brand assetBase={assetBase} />
            <p>{copy.footer.description}</p>
          </div>
          <div className="footer-links">
            <a href={utilitiesURL}>{copy.footer.tools}</a>
            <a href={`${REPOSITORY_URL}/releases`} target="_blank" rel="noreferrer">{copy.footer.releases}</a>
            <a href={`${REPOSITORY_URL}/issues`} target="_blank" rel="noreferrer">{copy.footer.issues}</a>
            <a href={`${REPOSITORY_URL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">{copy.footer.license}</a>
          </div>
        </div>
        <div className="footer-bottom section-shell">
          <span>© 2026 MachKit</span>
          <span><House size={14} weight="duotone" />{copy.footer.local}</span>
          <span>{copy.footer.platform}</span>
        </div>
      </footer>
    </div>
  );
}
