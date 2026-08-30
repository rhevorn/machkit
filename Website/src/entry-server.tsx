import { renderToStaticMarkup } from "react-dom/server";
import { App } from "./App.js";

export { renderFeatureDocument, renderSitemap } from "../scripts/site-renderer.js";
export { findFeaturePage } from "./seo-pages.js";

export type RenderHomeOptions = {
  locale?: string;
  assetBase?: string;
};

export function renderHome({ locale = "en", assetBase = "." }: RenderHomeOptions = {}): string {
  return renderToStaticMarkup(
    <App locale={locale} assetBase={assetBase} />,
  );
}
