import { renderToString } from "react-dom/server";
import { App } from "./App.jsx";

export function renderHome({ locale = "en", assetBase = "." } = {}) {
  return renderToString(
    <App locale={locale} assetBase={assetBase} initialTheme="light" />,
  );
}
