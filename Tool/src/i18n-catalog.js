export const supportedLocales = Object.freeze(["en", "zh-Hans", "zh-Hant", "ja", "ko", "es", "fr", "de", "pt-BR", "ru"]);

export function catalogIssues(catalog) {
  if (!catalog?.en || typeof catalog.en !== "object") return ["Missing English catalog"];
  const expected = Object.keys(catalog.en).sort();
  const issues = [];
  for (const [locale, translations] of Object.entries(catalog)) {
    const actual = Object.keys(translations || {}).sort();
    const missing = expected.filter((key) => !actual.includes(key));
    const extra = actual.filter((key) => !expected.includes(key));
    if (missing.length) issues.push(`${locale}: missing ${missing.join(", ")}`);
    if (extra.length) issues.push(`${locale}: unexpected ${extra.join(", ")}`);
    for (const key of expected) {
      if (typeof translations?.[key] !== "string" || !translations[key].trim()) {
        issues.push(`${locale}.${key}: empty translation`);
      }
    }
  }
  return issues;
}
