import { useSyncExternalStore } from "react";
import { machkit } from "./runtime/machkit.js";
import { supportedLocales, type SupportedLocale } from "./i18n-catalog.js";
export { catalogIssues, supportedLocales } from "./i18n-catalog.js";

export type MessageTable = Record<string, string>;
export type MessageCatalog = Record<string, MessageTable> & { en: MessageTable };

const supportedLocaleCatalog: MessageCatalog = Object.fromEntries(
  supportedLocales.map((locale) => [locale, {}]),
) as MessageCatalog;

export function resolveLocale(requested: unknown, catalog: MessageCatalog = supportedLocaleCatalog): string {
  const normalized = String(requested || "en").replaceAll("_", "-");
  if (catalog[normalized]) return normalized;

  const lowered = normalized.toLowerCase();
  if (lowered.startsWith("zh-hant") || lowered === "zh-tw" || lowered === "zh-hk" || lowered === "zh-mo") {
    return catalog["zh-Hant"] ? "zh-Hant" : "en";
  }
  if (lowered.startsWith("zh")) return catalog["zh-Hans"] ? "zh-Hans" : "en";
  if (lowered === "pt-br" || lowered.startsWith("pt-br")) return catalog["pt-BR"] ? "pt-BR" : "en";

  const base = normalized.split("-")[0] ?? "en";
  return catalog[base] ? base : "en";
}

export function currentLocale(): string {
  return resolveLocale(machkit.getPreferences().locale || window.__MACHKIT__?.locale || navigator.language || "en");
}

export function useLocale(): string {
  useSyncExternalStore(machkit.subscribePreferences, machkit.getPreferences, machkit.getPreferences);
  return currentLocale();
}

/** Prefer catalogs typed as `satisfies Record<SupportedLocale, typeof messages.en>`. */
export function useToolMessages<T extends MessageCatalog>(catalog: T): T["en"] {
  useSyncExternalStore(machkit.subscribePreferences, machkit.getPreferences, machkit.getPreferences);
  const locale = resolveLocale(
    machkit.getPreferences().locale || window.__MACHKIT__?.locale || navigator.language || "en",
    catalog,
  ) as SupportedLocale | string;
  return (catalog[locale] || catalog.en) as T["en"];
}
