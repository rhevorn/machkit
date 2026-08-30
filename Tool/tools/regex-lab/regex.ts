export const maxRegexInput = 500_000;
export const maxRegexMatches = 500;

const FLAG_CHARS = new Set(["d", "g", "i", "m", "s", "u", "v", "y"]);

export const regexPresets = Object.freeze([
  {
    id: "email",
    pattern: String.raw`[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}`,
    flags: "gi",
    replacement: "",
  },
  {
    id: "url",
    pattern: String.raw`https?:\/\/[^\s<>"']+`,
    flags: "gi",
    replacement: "",
  },
  {
    id: "ipv4",
    pattern: String.raw`\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b`,
    flags: "g",
    replacement: "",
  },
  {
    id: "uuid",
    pattern: String.raw`\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b`,
    flags: "g",
    replacement: "",
  },
  {
    id: "hexColor",
    pattern: String.raw`#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b`,
    flags: "g",
    replacement: "",
  },
  {
    id: "whitespace",
    pattern: String.raw`[ \t]+`,
    flags: "g",
    replacement: " ",
  },
  {
    id: "numbers",
    pattern: String.raw`-?\d+(?:\.\d+)?`,
    flags: "g",
    replacement: "",
  },
  {
    id: "quoted",
    pattern: String.raw`(["'])(?:\\.|(?!\1).)*\1`,
    flags: "g",
    replacement: "$1…$1",
  },
]);

export function normalizeFlags(flags: string = "") {
  const seen = new Set();
  let result = "";
  for (const char of String(flags)) {
    if (!FLAG_CHARS.has(char) || seen.has(char)) continue;
    seen.add(char);
    result += char;
  }
  return result;
}

export function compileRegex(pattern: string, flags: string = "g") {
  const source = String(pattern ?? "");
  if (!source) return { ok: false as const, error: "empty-pattern", regex: null };
  const normalized = normalizeFlags(flags);
  try {
    return { ok: true as const, error: null, regex: new RegExp(source, normalized) };
  } catch (error) {
    return { ok: false as const, error: error instanceof Error ? error.message : "invalid-pattern", regex: null };
  }
}

function groupEntries(match: any) {
  const groups: Array<{ index: number; value: string; start: number | null; end: number | null }> = [];
  for (let index = 1; index < match.length; index += 1) {
    if (match[index] === undefined) continue;
    groups.push({
      index,
      value: match[index],
      start: typeof match.indices?.[index]?.[0] === "number" ? match.indices[index][0] : null,
      end: typeof match.indices?.[index]?.[1] === "number" ? match.indices[index][1] : null,
    });
  }
  const named: Record<string, string> = {};
  if (match.groups) {
    for (const [name, value] of Object.entries(match.groups)) {
      if (value === undefined) continue;
      named[name] = String(value);
    }
  }
  return { groups, named };
}

export function findMatches(pattern: unknown, flags: unknown, input: unknown, { maxMatches = maxRegexMatches }: { maxMatches?: number } = {}) {
  const text = String(input ?? "");
  if (text.length > maxRegexInput) {
    return { ok: false as const, error: "input-too-large", matches: [], truncated: false };
  }

  const normalizedFlags = normalizeFlags(String(flags ?? ""));
  const flagsWithIndices = normalizedFlags.includes("d") ? normalizedFlags : `${normalizedFlags}d`;
  let compiled = compileRegex(String(pattern ?? ""), flagsWithIndices);
  if (!compiled.ok && compiled.error !== "empty-pattern") {
    // Some engines reject 'd' with certain flags; retry without indices.
    compiled = compileRegex(String(pattern ?? ""), normalizedFlags);
  }
  if (!compiled.ok) return { ok: false as const, error: compiled.error, matches: [], truncated: false };

  const regex = compiled.regex;
  const matches = [];
  let truncated = false;

  if (!regex.global) {
    const match = regex.exec(text);
    if (match) {
      const { groups, named } = groupEntries(match);
      matches.push({
        index: match.index,
        length: match[0].length,
        text: match[0],
        groups,
        named,
      });
    }
    return { ok: true as const, error: null, matches, truncated: false };
  }

  regex.lastIndex = 0;
  let guard = 0;
  let match = regex.exec(text);
  while (match) {
    guard += 1;
    if (guard > maxMatches) {
      truncated = true;
      break;
    }
    if (match[0].length === 0) {
      regex.lastIndex = match.index + 1;
      match = regex.exec(text);
      continue;
    }
    const { groups, named } = groupEntries(match);
    matches.push({
      index: match.index,
      length: match[0].length,
      text: match[0],
      groups,
      named,
    });
    match = regex.exec(text);
  }

  return { ok: true as const, error: null, matches, truncated };
}

export function replaceMatches(pattern: string, flags: string, input: string, replacement: string = "") {
  const text = String(input ?? "");
  if (text.length > maxRegexInput) {
    return { ok: false as const, error: "input-too-large", value: "" };
  }
  const compiled = compileRegex(pattern, normalizeFlags(flags));
  if (!compiled.ok) return { ok: false as const, error: compiled.error, value: "" };
  try {
    return { ok: true as const, error: null, value: text.replace(compiled.regex, String(replacement ?? "")) };
  } catch (error) {
    return { ok: false as const, error: error instanceof Error ? error.message : "replace-failed", value: "" };
  }
}

export function highlightSegments(input: string, matches: Array<{ index: number; length: number; text?: string }>) {
  const text = String(input ?? "");
  if (!matches?.length) return [{ type: "text", value: text }];

  const segments = [];
  let cursor = 0;
  for (const match of matches) {
    const start = Math.max(0, match.index);
    const end = Math.min(text.length, start + match.length);
    if (start < cursor) continue;
    if (start > cursor) segments.push({ type: "text", value: text.slice(cursor, start) });
    segments.push({ type: "match", value: text.slice(start, end), matchIndex: match.index });
    cursor = end;
  }
  if (cursor < text.length) segments.push({ type: "text", value: text.slice(cursor) });
  return segments;
}
