import {
  ArrowRightIcon,
  ChartDonutIcon,
  CodeIcon,
  DownloadSimpleIcon,
  GithubLogoIcon,
  GlobeIcon,
  HouseIcon,
  MoonIcon,
  PulseIcon,
  ShieldCheckIcon,
  SunIcon,
  WrenchIcon,
} from "@phosphor-icons/react";
import { messages } from "./i18n.js";
import { site } from "./seo-pages.js";

const SCREEN_SPECS = [
  ["overview", 1600, 1329],
  ["cleanup", 2040, 1648],
  ["apps", 2040, 1648],
  ["storage", 1600, 1329],
  ["performance", 2040, 1648],
  ["network", 1600, 1329],
  ["tools", 2040, 1648],
  ["system", 1600, 1329],
  ["settings", 2040, 1648],
] as const;
type ScreenKey = (typeof SCREEN_SPECS)[number][0];
const SCREEN_KEYS: readonly ScreenKey[] = SCREEN_SPECS.map(([key]) => key);
const SCREEN_DIMENSIONS: Record<ScreenKey, { width: number; height: number }> = Object.fromEntries(
  SCREEN_SPECS.map(([key, width, height]) => [key, { width, height }]),
) as Record<ScreenKey, { width: number; height: number }>;

const GROUP_ICONS = [ChartDonutIcon, WrenchIcon, PulseIcon, CodeIcon];

export type AppProps = {
  locale?: string;
  assetBase?: string;
};

function Brand({ assetBase }: { assetBase: string }) {
  return (
    <a className="brand" href="#top" aria-label="MachKit home">
      <img src={`${assetBase}/assets/logo.png`} alt="" width="28" height="28" />
      <span>MachKit</span>
    </a>
  );
}

type CapabilityGroupData = {
  tone: string;
  title: string;
  body: string;
  items: readonly (readonly string[])[];
};

function CapabilityGroup({ group, index }: { group: CapabilityGroupData; index: number }) {
  const Icon = GROUP_ICONS[index] ?? ChartDonutIcon;
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
        {group.items.map((item) => {
          const [title, detail, href] = item;
          return (
            <div key={title}>
              <dt>{href ? <a href={href}>{title}</a> : title}</dt>
              <dd>{detail}</dd>
            </div>
          );
        })}
      </dl>
    </article>
  );
}

function resolveLocale(locale: string): keyof typeof messages {
  return locale === "zh-CN" ? "zh-CN" : "en";
}

export function App({
  locale: localeOverride = "en",
  assetBase = ".",
}: AppProps = {}) {
  const locale = resolveLocale(localeOverride);
  const copy = messages[locale];

  const languageURL = locale === "en" ? "./zh-CN/" : "../";
  const languageLabel = locale === "en" ? "中文" : "English";
  const utilitiesURL = "./utilities/";
  const localeSuffix = locale === "zh-CN" ? "-zh-CN" : "";
  const screenImages = Object.fromEntries(
    SCREEN_KEYS.map((key) => [key, `${assetBase}/assets/${key}${localeSuffix}.webp`]),
  ) as Record<ScreenKey, string>;

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
              <GlobeIcon size={15} aria-hidden="true" />
              <span>{languageLabel}</span>
            </a>
            <button
              className="theme-button"
              type="button"
              data-theme-toggle
              aria-label={copy.controls.theme}
              title={copy.controls.theme}
            >
              <span className="theme-icon theme-icon-light" aria-hidden="true">
                <MoonIcon size={18} />
              </span>
              <span className="theme-icon theme-icon-dark" aria-hidden="true">
                <SunIcon size={18} />
              </span>
            </button>
            <a className="nav-download" href={site.downloadURL}>
              <DownloadSimpleIcon size={16} weight="bold" />
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
              <a className="button button-primary" href={site.downloadURL}>
                <DownloadSimpleIcon size={18} weight="bold" />
                {copy.hero.primary}
              </a>
              <a className="text-link" href={site.repositoryURL} target="_blank" rel="noreferrer">
                <GithubLogoIcon size={19} weight="fill" />
                {copy.hero.secondary}
                <ArrowRightIcon size={15} />
              </a>
            </div>
            <p className="compatibility">{copy.hero.compatibility}</p>
          </div>

          <div className="hero-product" aria-label={copy.hero.previewAlt}>
            <div className="product-window">
              <img
                src={screenImages.cleanup}
                alt={copy.hero.previewAlt}
                width="2040"
                height="1648"
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
            {copy.introduction.paragraphs.map((paragraph: string) => <p key={paragraph}>{paragraph}</p>)}
          </div>
        </section>

        <section className="capabilities section-shell" id="capabilities" aria-labelledby="capabilities-title">
          <header className="section-heading">
            <p className="kicker">{copy.capabilities.kicker}</p>
            <h2 id="capabilities-title">{copy.capabilities.title}</h2>
            <p>{copy.capabilities.description}</p>
          </header>
          <div className="capability-grid">
            {copy.capabilities.groups.map((group: CapabilityGroupData, index: number) => (
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
                  id={`screen-tab-${key}`}
                  type="button"
                  role="tab"
                  aria-controls={`screen-panel-${key}`}
                  aria-selected={key === "cleanup"}
                  className={key === "cleanup" ? "is-active" : ""}
                  tabIndex={key === "cleanup" ? 0 : -1}
                  data-screen-tab={key}
                >
                  {copy.screens.tabs[key].label}
                </button>
              ))}
            </div>

            <div className="screen-panels">
              {SCREEN_KEYS.map((key) => {
                const screen = copy.screens.tabs[key];
                return (
                  <div
                    key={key}
                    id={`screen-panel-${key}`}
                    className="screen-layout"
                    role="tabpanel"
                    aria-labelledby={`screen-tab-${key}`}
                    data-screen-panel={key}
                    hidden={key !== "cleanup"}
                  >
                    <div className="screen-copy">
                      <span className="screen-index">0{SCREEN_KEYS.indexOf(key) + 1}</span>
                      <h3>{screen.title}</h3>
                      <ul className="screen-feature-list">
                        {screen.features.map((feature: string) => <li key={feature}>{feature}</li>)}
                      </ul>
                    </div>
                    <div className="screen-frame">
                      <img
                        src={screenImages[key]}
                        alt={screen.alt}
                        width={SCREEN_DIMENSIONS[key].width}
                        height={SCREEN_DIMENSIONS[key].height}
                        loading={key === "cleanup" ? "eager" : "lazy"}
                      />
                    </div>
                  </div>
                );
              })}
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
            {copy.safety.principles.map((principle, index) => {
              const [title, detail] = principle;
              return (
                <article key={title}>
                  <span>0{index + 1}</span>
                  <h3>{title}</h3>
                  <p>{detail}</p>
                </article>
              );
            })}
          </div>
        </section>

        <section className="tools-section" id="tools" aria-labelledby="tools-title">
          <div className="section-shell tools-layout">
            <header className="section-heading">
              <p className="kicker">{copy.tools.kicker}</p>
              <h2 id="tools-title">{copy.tools.title}</h2>
              <p>{copy.tools.description}</p>
              <dl className="tool-principles">
                {copy.tools.principles.map((principle) => {
                  const [title, detail] = principle;
                  return (
                    <div key={title}>
                      <dt>{title}</dt>
                      <dd>{detail}</dd>
                    </div>
                  );
                })}
              </dl>
            </header>
            <div className="tools-teaser-aside">
              <p className="tools-count">{copy.tools.count}</p>
              <dl className="tools-preview">
                {copy.tools.preview.map((item) => {
                  const [title, detail] = item;
                  return (
                    <div key={title}>
                      <dt>{title}</dt>
                      <dd>{detail}</dd>
                    </div>
                  );
                })}
              </dl>
              <a className="tools-explore-link" href={utilitiesURL}>
                {copy.tools.explore}<ArrowRightIcon size={15} />
              </a>
            </div>
          </div>
        </section>

        <section className="open-source section-shell" aria-labelledby="open-source-title">
          <ShieldCheckIcon size={30} weight="duotone" aria-hidden="true" />
          <div>
            <p className="kicker">{copy.openSource.kicker}</p>
            <h2 id="open-source-title">{copy.openSource.title}</h2>
            <p>{copy.openSource.description}</p>
          </div>
          <div className="open-source-actions">
            <a className="button button-primary" href={site.repositoryURL} target="_blank" rel="noreferrer">
              <GithubLogoIcon size={18} weight="fill" />
              {copy.openSource.primary}
            </a>
            <a className="text-link" href={site.downloadURL} target="_blank" rel="noreferrer">
              {copy.openSource.secondary}<ArrowRightIcon size={15} />
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
            <a href={`${site.repositoryURL}/releases`} target="_blank" rel="noreferrer">{copy.footer.releases}</a>
            <a href={`${site.repositoryURL}/issues`} target="_blank" rel="noreferrer">{copy.footer.issues}</a>
            <a href={`${site.repositoryURL}/blob/main/LICENSE`} target="_blank" rel="noreferrer">{copy.footer.license}</a>
          </div>
        </div>
        <div className="footer-bottom section-shell">
          <span>© 2026 MachKit</span>
          <span><HouseIcon size={14} weight="duotone" />{copy.footer.local}</span>
          <span>{copy.footer.platform}</span>
        </div>
      </footer>
    </div>
  );
}
