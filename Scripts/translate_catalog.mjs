import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const catalogPath = path.join(root, "Resources/Localizable.xcstrings");
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const placeholderPattern = /%(?:\d+\$)?(?:lld|llu|ld|lu|zd|zu|d|u|f|g|s|c|@|%)/g;
const targets = [
  { locale: "zh-Hans", code: "zh-CN", source: "en" },
  { locale: "zh-Hant", code: "zh-TW", source: "zh-CN" },
  { locale: "ja", code: "ja", source: "en" },
  { locale: "ko", code: "ko", source: "en" },
  { locale: "es", code: "es", source: "en" },
  { locale: "fr", code: "fr", source: "en" },
  { locale: "de", code: "de", source: "en" },
  { locale: "pt-BR", code: "pt", source: "en" },
  { locale: "ru", code: "ru", source: "en" }
];

function protectPlaceholders(value) {
  const placeholders = [];
  const protectedText = value.replace(placeholderPattern, token => {
    const marker = `91827364${String(placeholders.length).padStart(3, "0")}`;
    placeholders.push({ marker, token });
    return marker;
  });
  return { protectedText, placeholders };
}

function restorePlaceholders(value, placeholders) {
  let restored = value;
  for (const { marker, token } of placeholders) restored = restored.replaceAll(marker, token);
  return restored;
}

async function translateChunk(values, source, target, offset) {
  const protectedValues = values.map(protectPlaceholders);
  const markers = values.map((_, index) => `736451829${String(offset + index).padStart(5, "0")}`);
  const query = protectedValues.map((item, index) => `${markers[index]}\n${item.protectedText}`).join("\n");
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${source}&tl=${target}&dt=t&q=${encodeURIComponent(query)}`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Translation request failed: ${response.status}`);
  const json = await response.json();
  const output = json[0].map(part => part[0]).join("");
  return values.map((_, index) => {
    const start = output.indexOf(markers[index]);
    const next = index + 1 < values.length ? output.indexOf(markers[index + 1]) : output.length;
    if (start < 0 || next < 0) throw new Error(`Translation boundary lost for ${target} at ${offset + index}`);
    const translated = output.slice(start + markers[index].length, next).trim();
    return restorePlaceholders(translated, protectedValues[index].placeholders);
  });
}

const entries = Object.entries(catalog.strings);
for (const target of targets) {
  const pending = entries.filter(([, entry]) => !entry.localizations?.[target.locale]?.stringUnit?.value);
  for (let offset = 0; offset < pending.length; offset += 30) {
    const chunk = pending.slice(offset, offset + 30);
    const sources = chunk.map(([key, entry]) => target.locale === "zh-Hant"
      ? (entry.localizations?.["zh-Hans"]?.stringUnit?.value ?? key)
      : key
    );
    const translated = await translateChunk(sources, target.source, target.code, offset);
    for (let index = 0; index < chunk.length; index += 1) {
      const [, entry] = chunk[index];
      entry.localizations ??= {};
      entry.localizations[target.locale] = {
        stringUnit: { state: "translated", value: translated[index] }
      };
    }
    fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
  }
  console.log(`${target.locale}: ${pending.length} strings translated`);
}
