import { renderToString } from "react-dom/server";
import { App } from "./App.js";

export type RenderHomeOptions = {
  locale?: string;
  assetBase?: string;
};

export function renderHome({ locale = "en", assetBase = "." }: RenderHomeOptions = {}): string {
  return renderToString(
    <App locale={locale} assetBase={assetBase} initialTheme="light" />,
  );
}
