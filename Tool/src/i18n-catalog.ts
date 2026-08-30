export const supportedLocales = Object.freeze([
  "en",
  "zh-Hans",
  "zh-Hant",
  "ja",
  "ko",
  "es",
  "fr",
  "de",
  "pt-BR",
  "ru",
] as const);

export type SupportedLocale = (typeof supportedLocales)[number];

type Catalog = Record<string, Record<string, string> | undefined>;

export function catalogIssues(catalog: Catalog | null | undefined): string[] {
  if (!catalog?.en || typeof catalog.en !== "object") return ["Missing English catalog"];
  const expected = Object.keys(catalog.en).sort();
  const issues: string[] = [];
  for (const [locale, translations] of Object.entries(catalog)) {
    const actual = Object.keys(translations || {}).sort();
    const missing = expected.filter((key) => !actual.includes(key));
    const extra = actual.filter((key) => !expected.includes(key));
    if (missing.length) issues.push(`${locale}: missing ${missing.join(", ")}`);
    if (extra.length) issues.push(`${locale}: unexpected ${extra.join(", ")}`);
    for (const key of expected) {
      const value = translations?.[key];
      if (typeof value !== "string" || !value.trim()) {
        issues.push(`${locale}.${key}: empty translation`);
      }
    }
  }
  return issues;
}
