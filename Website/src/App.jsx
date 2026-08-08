import { useEffect, useState } from "react";
import {
  AppleLogo,
  ArrowRight,
  ChartDonut,
  CheckCircle,
  Cpu,
  DownloadSimple,
  GithubLogo,
  Globe,
  HardDrives,
  LockKey,
  Moon,
  Package,
  Plugs,
  ShieldCheck,
  Sparkle,
  Sun,
  Trash,
} from "@phosphor-icons/react";
import { messages } from "./i18n.js";

const THEME_KEY = "sift-website-theme";
const LOCALE_KEY = "sift-website-locale";
const REPOSITORY_URL = "https://github.com/rhevorn/sift";
const DOWNLOAD_URL = `${REPOSITORY_URL}/releases/latest`;

const HERO_IMAGES = {
  light: ["./assets/img10.png", "./assets/img11.png"],
  dark: ["./assets/img20.png", "./assets/img21.png"],
};

function preferredTheme() {
  const savedTheme = window.localStorage.getItem(THEME_KEY);
  if (savedTheme === "light" || savedTheme === "dark") return savedTheme;
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function preferredLocale() {
  const savedLocale = window.localStorage.getItem(LOCALE_KEY);
  if (savedLocale === "en" || savedLocale === "zh-CN") return savedLocale;
  return navigator.language?.toLowerCase().startsWith("zh") ? "zh-CN" : "en";
}

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Sift home">
      <img src="./assets/logo.png" alt="" />
      <span>Sift</span>
    </a>
  );
}

function Feature({ icon: Icon, title, children, tone }) {
  return (
    <article className={`feature-card feature-card-${tone}`}>
      <div className="feature-icon" aria-hidden="true"><Icon size={22} weight="duotone" /></div>
      <h3>{title}</h3>
      <p>{children}</p>
    </article>
  );
}

export function App() {
  const [theme, setTheme] = useState(preferredTheme);
  const [locale, setLocale] = useState(preferredLocale);
  const [slide, setSlide] = useState(0);
  const copy = messages[locale] ?? messages.en;

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute(
      "content",
      theme === "dark" ? "#080b12" : "#f7f9fc",
    );
  }, [theme]);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: light)");
    const followSystem = () => {
      if (window.localStorage.getItem(THEME_KEY) == null) {
        setTheme(media.matches ? "light" : "dark");
      }
    };
    media.addEventListener("change", followSystem);
    return () => media.removeEventListener("change", followSystem);
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return undefined;
    const timer = window.setInterval(() => setSlide((current) => (current + 1) % 2), 6000);
    return () => window.clearInterval(timer);
  }, []);

  const toggleTheme = () =>
    setTheme((current) => {
      const next = current === "dark" ? "light" : "dark";
      window.localStorage.setItem(THEME_KEY, next);
      return next;
    });

  const toggleLocale = () =>
    setLocale((current) => {
      const next = current === "en" ? "zh-CN" : "en";
      window.localStorage.setItem(LOCALE_KEY, next);
      return next;
    });

  return (
    <div className="site-shell" id="top">
      <header className="site-header">
        <nav className="nav-shell" aria-label="Primary navigation">
          <Brand />
          <div className="nav-links">
            <a href="#features">{copy.nav.features}</a>
            <a href="#safety">{copy.nav.safety}</a>
            <a href={REPOSITORY_URL} target="_blank" rel="noreferrer">{copy.nav.github}</a>
          </div>
          <div className="nav-actions">
            <button
              className="nav-control language-button"
              type="button"
              onClick={toggleLocale}
              aria-label={copy.controls.language}
              title={copy.controls.language}
            >
              <Globe size={16} aria-hidden="true" />
              <span>{locale === "en" ? "EN" : "中"}</span>
            </button>
            <button
              className="nav-control theme-button"
              type="button"
              onClick={toggleTheme}
              aria-label={copy.controls.theme}
              title={copy.controls.theme}
            >
              {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
            </button>
            <a className="nav-download" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">
              <DownloadSimple size={17} weight="bold" />
              <span>{copy.nav.download}</span>
            </a>
          </div>
        </nav>
      </header>

      <main>
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy-block">
            <div className="eyebrow">
              <Sparkle size={15} weight="fill" />
              {copy.hero.eyebrow}
            </div>
            <h1 id="hero-title">{copy.hero.title}</h1>
            <p className="hero-copy">{copy.hero.description}</p>
            <div className="hero-actions">
              <a className="button" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">
                <DownloadSimple size={19} weight="bold" />
                {copy.hero.primary}
              </a>
              <a className="button button-quiet" href={REPOSITORY_URL} target="_blank" rel="noreferrer">
                <GithubLogo size={20} weight="fill" />
                {copy.hero.secondary}
              </a>
            </div>
            <p className="compatibility">{copy.hero.compatibility}</p>
          </div>

          <div className="app-stage" aria-label={copy.productPreviewLabel}>
            {HERO_IMAGES[theme].map((src, index) => (
              <img
                key={src}
                src={src}
                alt={index === slide ? copy.productPreviewAlt : ""}
                aria-hidden={index !== slide}
                className={index === slide ? "is-active" : ""}
                fetchPriority={index === 0 ? "high" : undefined}
              />
            ))}
            <div className="stage-dots" aria-hidden="true">
              {HERO_IMAGES[theme].map((src, index) => (
                <button
                  key={src}
                  type="button"
                  tabIndex={-1}
                  className={index === slide ? "is-active" : ""}
                  onClick={() => setSlide(index)}
                />
              ))}
            </div>
          </div>
        </section>

        <section className="trust-band" id="safety" aria-label={copy.trust.label}>
          <div className="trust-strip">
            <div>
              <ShieldCheck size={21} weight="duotone" />
              <span><strong>{copy.trust.localTitle}</strong>{copy.trust.localBody}</span>
            </div>
            <div>
              <LockKey size={21} weight="duotone" />
              <span><strong>{copy.trust.controlTitle}</strong>{copy.trust.controlBody}</span>
            </div>
            <div>
              <CheckCircle size={21} weight="duotone" />
              <span><strong>{copy.trust.previewTitle}</strong>{copy.trust.previewBody}</span>
            </div>
          </div>
        </section>

        <section className="features section-shell" id="features">
          <div className="section-intro">
            <span className="section-kicker">{copy.features.kicker}</span>
            <h2>{copy.features.title}</h2>
            <p>{copy.features.description}</p>
          </div>
          <div className="feature-grid">
            <Feature icon={Trash} tone="blue" title={copy.features.cleanup.title}>{copy.features.cleanup.body}</Feature>
            <Feature icon={Package} tone="purple" title={copy.features.apps.title}>{copy.features.apps.body}</Feature>
            <Feature icon={ChartDonut} tone="indigo" title={copy.features.storage.title}>{copy.features.storage.body}</Feature>
            <Feature icon={Cpu} tone="green" title={copy.features.performance.title}>{copy.features.performance.body}</Feature>
            <Feature icon={Plugs} tone="orange" title={copy.features.ports.title}>{copy.features.ports.body}</Feature>
            <Feature icon={HardDrives} tone="cyan" title={copy.features.system.title}>{copy.features.system.body}</Feature>
          </div>
        </section>

        <section className="closing section-shell" id="download">
          <div>
            <span className="section-kicker">{copy.closing.kicker}</span>
            <h2>{copy.closing.title}</h2>
            <p>{copy.closing.description}</p>
          </div>
          <a className="button" href={DOWNLOAD_URL} target="_blank" rel="noreferrer">
            {copy.closing.action}<ArrowRight size={18} weight="bold" />
          </a>
        </section>
      </main>

      <footer className="site-footer">
        <div className="footer-main section-shell">
          <div className="footer-brand">
            <Brand />
            <p>{copy.footer.description}</p>
            <span className="platform-badge">
              <AppleLogo size={15} weight="fill" />
              {copy.footer.platform}
            </span>
          </div>
          <div className="footer-links">
            <div>
              <strong>{copy.footer.product}</strong>
              <a href="#features">{copy.nav.features}</a>
              <a href="#safety">{copy.nav.safety}</a>
              <a href={DOWNLOAD_URL} target="_blank" rel="noreferrer">{copy.nav.download}</a>
            </div>
            <div>
              <strong>{copy.footer.project}</strong>
              <a href={REPOSITORY_URL} target="_blank" rel="noreferrer">GitHub</a>
              <a href={`${REPOSITORY_URL}/releases`} target="_blank" rel="noreferrer">{copy.footer.releases}</a>
              <a href={`${REPOSITORY_URL}/issues`} target="_blank" rel="noreferrer">{copy.footer.issues}</a>
            </div>
          </div>
        </div>
        <div className="footer-bottom section-shell">
          <span>© 2026 Sift</span>
          <span className="footer-local">
            <ShieldCheck size={15} weight="duotone" />
            {copy.footer.local}
          </span>
          <a href={REPOSITORY_URL} target="_blank" rel="noreferrer" aria-label="Sift on GitHub">
            <GithubLogo size={19} />
          </a>
        </div>
      </footer>
    </div>
  );
}
