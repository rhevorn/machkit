import { parse as parseYAML, stringify as stringifyYAML } from "yaml";
import { parse as parseTOML, stringify as stringifyTOML } from "smol-toml";

export const maxFormatInput = 1_000_000;
export const formats = Object.freeze(["json", "yaml", "toml"]);

function tooLarge(input) {
  return String(input ?? "").length > maxFormatInput;
}

export function parseFormat(source, format) {
  const text = String(source ?? "");
  if (!text.trim()) return { ok: false, error: "empty", value: null };
  if (tooLarge(text)) return { ok: false, error: "input-too-large", value: null };

  try {
    if (format === "json") return { ok: true, error: null, value: JSON.parse(text) };
    if (format === "yaml") return { ok: true, error: null, value: parseYAML(text) };
    if (format === "toml") return { ok: true, error: null, value: parseTOML(text) };
    return { ok: false, error: "unsupported", value: null };
  } catch (error) {
    return { ok: false, error: error?.message || "parse-failed", value: null };
  }
}

export function stringifyFormat(value, format, { indent = 2 } = {}) {
  try {
    if (format === "json") {
      return { ok: true, error: null, text: `${JSON.stringify(value, null, indent)}\n` };
    }
    if (format === "yaml") {
      return { ok: true, error: null, text: stringifyYAML(value, { indent, lineWidth: 0 }) };
    }
    if (format === "toml") {
      if (value === null || typeof value !== "object" || Array.isArray(value)) {
        return { ok: false, error: "toml-root-object", text: "" };
      }
      return { ok: true, error: null, text: `${stringifyTOML(value)}\n` };
    }
    return { ok: false, error: "unsupported", text: "" };
  } catch (error) {
    return { ok: false, error: error?.message || "stringify-failed", text: "" };
  }
}

export function convertFormat(source, fromFormat, toFormat, options) {
  const parsed = parseFormat(source, fromFormat);
  if (!parsed.ok) return { ok: false, error: parsed.error, text: "" };
  return stringifyFormat(parsed.value, toFormat, options);
}
