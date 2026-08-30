export const maxRegexInput = 500_000;
export const maxRegexMatches = 500;
export const maxRegexBudgetMs = 50;
export const maxRegexSteps = 50_000;

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

export type MatchGroup = {
  index: number;
  value: string;
  start: number | null;
  end: number | null;
};

export type MatchResult = {
  index: number;
  length: number;
  text: string;
  groups: MatchGroup[];
  named: Record<string, string>;
};

export type HighlightSegment =
  | { type: "text"; value: string }
  | { type: "match"; value: string; matchIndex: number };

export type FindMatchesResult =
  | { ok: true; error: null; matches: MatchResult[]; truncated: boolean }
  | { ok: false; error: string; matches: MatchResult[]; truncated: boolean };

export type ReplaceMatchesResult =
  | { ok: true; error: null; value: string }
  | { ok: false; error: string; value: string };

export type RegexBudgetOptions = {
  maxMatches?: number;
  maxBudgetMs?: number;
  maxSteps?: number;
};

type RegExpMatchWithIndices = RegExpExecArray & {
  indices?: Array<[number, number] | undefined>;
};

export function normalizeFlags(flags: string = "") {
  const seen = new Set<string>();
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

function groupEntries(match: RegExpExecArray): { groups: MatchGroup[]; named: Record<string, string> } {
  const withIndices = match as RegExpMatchWithIndices;
  const groups: MatchGroup[] = [];
  for (let index = 1; index < match.length; index += 1) {
    if (match[index] === undefined) continue;
    const indexPair = withIndices.indices?.[index];
    groups.push({
      index,
      value: match[index],
      start: typeof indexPair?.[0] === "number" ? indexPair[0] : null,
      end: typeof indexPair?.[1] === "number" ? indexPair[1] : null,
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

function budgetExceeded(started: number, steps: number, maxBudgetMs: number, maxSteps: number) {
  return steps > maxSteps || Date.now() - started > maxBudgetMs;
}

/** Expand a string replacement template ($1, $&, $<name>, …) for one match. */
export function expandReplacement(template: string, match: RegExpExecArray, input: string): string {
  return String(template ?? "").replace(/\$(\$|&|`|'|<[^>]+>|\d{1,3})/g, (token, key: string) => {
    if (key === "$") return "$";
    if (key === "&") return match[0];
    if (key === "`") return input.slice(0, match.index);
    if (key === "'") return input.slice(match.index + match[0].length);
    if (key.startsWith("<") && key.endsWith(">")) {
      const name = key.slice(1, -1);
      return match.groups?.[name] ?? "";
    }
    const index = Number(key);
    if (!Number.isFinite(index) || index < 1) return token;
    return match[index] ?? "";
  });
}

export function findMatches(
  pattern: unknown,
  flags: unknown,
  input: unknown,
  {
    maxMatches = maxRegexMatches,
    maxBudgetMs = maxRegexBudgetMs,
    maxSteps = maxRegexSteps,
  }: RegexBudgetOptions = {},
): FindMatchesResult {
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
  const matches: MatchResult[] = [];
  let truncated = false;
  const started = Date.now();
  let steps = 0;

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
  let match = regex.exec(text);
  while (match) {
    steps += 1;
    if (budgetExceeded(started, steps, maxBudgetMs, maxSteps)) {
      return { ok: false as const, error: "budget-exceeded", matches, truncated: true };
    }

    if (match[0].length === 0) {
      // Advance past zero-length matches without counting them toward maxMatches.
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
    if (matches.length >= maxMatches) {
      truncated = true;
      break;
    }
    match = regex.exec(text);
  }

  return { ok: true as const, error: null, matches, truncated };
}

export function replaceMatches(
  pattern: string,
  flags: string,
  input: string,
  replacement: string = "",
  {
    maxBudgetMs = maxRegexBudgetMs,
    maxSteps = maxRegexSteps,
  }: Pick<RegexBudgetOptions, "maxBudgetMs" | "maxSteps"> = {},
): ReplaceMatchesResult {
  const text = String(input ?? "");
  if (text.length > maxRegexInput) {
    return { ok: false as const, error: "input-too-large", value: "" };
  }
  const normalized = normalizeFlags(flags);
  const compiled = compileRegex(pattern, normalized);
  if (!compiled.ok) return { ok: false as const, error: compiled.error, value: "" };

  const template = String(replacement ?? "");
  const regex = compiled.regex;
  const started = Date.now();
  let steps = 0;

  try {
    if (!regex.global) {
      const match = regex.exec(text);
      steps += 1;
      if (budgetExceeded(started, steps, maxBudgetMs, maxSteps)) {
        return { ok: false as const, error: "budget-exceeded", value: "" };
      }
      if (!match) return { ok: true as const, error: null, value: text };
      const expanded = expandReplacement(template, match, text);
      return {
        ok: true as const,
        error: null,
        value: text.slice(0, match.index) + expanded + text.slice(match.index + match[0].length),
      };
    }

    let output = "";
    let lastIndex = 0;
    regex.lastIndex = 0;
    let match = regex.exec(text);
    while (match) {
      steps += 1;
      if (budgetExceeded(started, steps, maxBudgetMs, maxSteps)) {
        return { ok: false as const, error: "budget-exceeded", value: "" };
      }

      output += text.slice(lastIndex, match.index);
      if (match[0].length === 0) {
        output += expandReplacement(template, match, text);
        const next = match.index + 1;
        if (next <= text.length) {
          if (match.index < text.length) output += text.charAt(match.index);
          lastIndex = next;
          regex.lastIndex = next;
        } else {
          lastIndex = match.index;
          break;
        }
      } else {
        output += expandReplacement(template, match, text);
        lastIndex = match.index + match[0].length;
      }
      match = regex.exec(text);
    }
    output += text.slice(lastIndex);
    return { ok: true as const, error: null, value: output };
  } catch (error) {
    return { ok: false as const, error: error instanceof Error ? error.message : "replace-failed", value: "" };
  }
}

export function highlightSegments(
  input: string,
  matches: Array<{ index: number; length: number; text?: string }>,
): HighlightSegment[] {
  const text = String(input ?? "");
  if (!matches?.length) return [{ type: "text", value: text }];

  const segments: HighlightSegment[] = [];
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
