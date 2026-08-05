import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  CaretRight,
  CheckCircle,
  DownloadSimple,
  GithubLogo,
  Globe,
  HardDrive,
  Eye,
  LockKey,
  Monitor,
  Moon,
  ShieldCheck,
  Sun,
  Trash,
} from "@phosphor-icons/react";
import { messages, supportedLocales } from "./i18n.js";

const THEME_KEY = "sift-website-theme";
const LOCALE_KEY = "sift-website-locale";

function preferredTheme() {
  const savedTheme = window.localStorage.getItem(THEME_KEY);
  if (savedTheme === "light" || savedTheme === "dark") return savedTheme;
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function repositoryUrl() {
  if (import.meta.env.VITE_REPOSITORY_URL) return import.meta.env.VITE_REPOSITORY_URL;

  const { hostname, pathname } = window.location;
  if (hostname.endsWith(".github.io")) {
    const owner = hostname.slice(0, -".github.io".length);
    const repository = pathname.split("/").filter(Boolean)[0];
    return repository ? `https://github.com/${owner}/${repository}` : `https://github.com/${owner}`;
  }

  return "#download";
}

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Sift home">
      <img src="./assets/sift-mark-tight.png" alt="" />
      <span>Sift</span>
    </a>
  );
}

function Feature({ icon: Icon, title, children }) {
  return (
    <article className="feature">
      <div className="feature-icon" aria-hidden="true"><Icon size={21} weight="regular" /></div>
      <div>
        <h3>{title}</h3>
        <p>{children}</p>
      </div>
      <CaretRight size={18} className="feature-caret" aria-hidden="true" />
    </article>
  );
}

export function App() {
  const [theme, setTheme] = useState(preferredTheme);
  const [locale, setLocale] = useState(() => {
    const savedLocale = window.localStorage.getItem(LOCALE_KEY);
    return supportedLocales.some((item) => item.code === savedLocale) ? savedLocale : "en";
  });
  const copy = messages[locale] ?? messages.en;
  const repoUrl = useMemo(repositoryUrl, []);
  const hasRepository = repoUrl !== "#download";
  const downloadUrl = hasRepository ? `${repoUrl}/releases/latest` : "#download";

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;
    window.localStorage.setItem(THEME_KEY, theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.lang = locale;
    window.localStorage.setItem(LOCALE_KEY, locale);
  }, [locale]);

  const toggleTheme = () => setTheme((current) => (current === "dark" ? "light" : "dark"));

  return (
    <div className="site-shell" id="top">
      <header className="site-header">
        <nav className="nav-shell" aria-label="Primary navigation">
          <Brand />
          <div className="nav-links">
            <a href="#features">{copy.nav.features}</a>
            <a href="#safety">{copy.nav.safety}</a>
            <a href={repoUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer">
              {copy.nav.github}
            </a>
          </div>
          <div className="nav-actions">
            <label className="language-control" aria-label={copy.controls.language}>
              <Globe size={16} aria-hidden="true" />
              <select value={locale} onChange={(event) => setLocale(event.target.value)}>
                {supportedLocales.map((item) => (
                  <option value={item.code} key={item.code}>{item.nativeName}</option>
                ))}
              </select>
            </label>
            <button className="icon-button" type="button" onClick={toggleTheme} aria-label={copy.controls.theme}>
              {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
            </button>
            <a className="button button-small" href={downloadUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer">
              <DownloadSimple size={17} weight="bold" />
              {copy.nav.download}
            </a>
          </div>
        </nav>
      </header>

      <main>
        <section className="hero" aria-labelledby="hero-title">
          <img className="hero-mark" src="./assets/sift-mark-tight.png" alt="" />
          <h1 id="hero-title">{copy.hero.title}</h1>
          <p className="hero-copy">{copy.hero.description}</p>
          <div className="hero-actions">
            <a className="button" href={downloadUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer">
              <DownloadSimple size={19} weight="bold" />
              {copy.hero.primary}
            </a>
            <a className="button button-quiet" href={repoUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer">
              <GithubLogo size={20} weight="fill" />
              {copy.hero.secondary}
            </a>
          </div>
          <p className="compatibility">{copy.hero.compatibility}</p>

          <div className="app-stage" aria-label={copy.productPreviewLabel}>
            <div className="app-window">
              <div className="window-bar" aria-hidden="true">
                <span className="traffic red" />
                <span className="traffic yellow" />
                <span className="traffic green" />
                <span className="window-title">Sift</span>
              </div>
              <picture>
                <source media="(prefers-reduced-motion: reduce)" srcSet={theme === "dark" ? "./assets/sift-overview-dark-crop.png" : "./assets/sift-overview-light-crop.png"} />
                <img
                  src={theme === "dark" ? "./assets/sift-overview-dark-crop.png" : "./assets/sift-overview-light-crop.png"}
                  alt={copy.productPreviewAlt}
                />
              </picture>
            </div>
          </div>
        </section>

        <section className="trust-band" id="safety">
          <div className="trust-strip" aria-label={copy.trust.label}>
          <div>
            <ShieldCheck size={20} weight="duotone" />
            <span><strong>{copy.trust.localTitle}</strong>{copy.trust.localBody}</span>
          </div>
          <div>
            <LockKey size={20} weight="duotone" />
            <span><strong>{copy.trust.controlTitle}</strong>{copy.trust.controlBody}</span>
          </div>
          <div>
            <CheckCircle size={20} weight="duotone" />
            <span><strong>{copy.trust.previewTitle}</strong>{copy.trust.previewBody}</span>
          </div>
          </div>
        </section>

        <section className="features section-shell" id="features">
          <div className="section-intro">
            <h2>{copy.features.title}</h2>
            <p>{copy.features.description}</p>
          </div>
          <div className="feature-list">
            <Feature icon={Eye} title={copy.features.storage.title}>{copy.features.storage.body}</Feature>
            <Feature icon={Trash} title={copy.features.cleanup.title}>{copy.features.cleanup.body}</Feature>
            <Feature icon={ShieldCheck} title={copy.features.control.title}>{copy.features.control.body}</Feature>
            <Feature icon={HardDrive} title={copy.features.native.title}>{copy.features.native.body}</Feature>
          </div>
        </section>

        <section className="appearance section-shell" aria-labelledby="appearance-title">
          <div className="appearance-copy">
            <Monitor size={28} weight="duotone" aria-hidden="true" />
            <h2 id="appearance-title">{copy.appearance.title}</h2>
            <p>{copy.appearance.description}</p>
          </div>
          <div className="appearance-window">
            <img src="./assets/sift-overview-light-crop.png" alt={copy.appearance.alt} />
          </div>
        </section>

        <section className="closing section-shell" id="download">
          <h2>{copy.closing.title}</h2>
          <p>{copy.closing.description}</p>
          <a className="button" href={downloadUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer">
            {copy.closing.action}<ArrowRight size={18} weight="bold" />
          </a>
        </section>
      </main>

      <footer className="site-footer">
        <div className="section-shell footer-inner">
          <Brand />
          <p>{copy.footer}</p>
          <a href={repoUrl} target={hasRepository ? "_blank" : undefined} rel="noreferrer" aria-label="Sift on GitHub">
            <GithubLogo size={21} />
          </a>
        </div>
      </footer>
    </div>
  );
}
