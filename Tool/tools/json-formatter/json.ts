export type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue };

export type ParseOk = { ok: true; error: null; data: JsonValue; unwrapped?: boolean };
export type ParseErr = { ok: false; error: string; data: null; unwrapped?: boolean };
export type ParseResult = ParseOk | ParseErr;

export type PathMatch = { path: string; value: JsonValue };
export type PathQueryResult =
  | { ok: true; error: null; matches: PathMatch[] }
  | { ok: false; error: string; matches: PathMatch[] };

export type PathAtOffsetResult = { ok: boolean; path: string };

type PathToken =
  | { type: "key"; name: string }
  | { type: "index"; index: number }
  | { type: "wildcard" }
  | { type: "descent"; name: string };

function looksLikeJSON(text: unknown): boolean {
  const value = String(text ?? "").trim();
  if (!value) return false;
  const first = value[0];
  return (
    first === "{" ||
    first === "[" ||
    first === '"' ||
    first === "t" ||
    first === "f" ||
    first === "n" ||
    first === "-" ||
    (first !== undefined && first >= "0" && first <= "9")
  );
}

function tryParse(text: string): { ok: true; error: null; data: JsonValue } | { ok: false; error: string; data: null } {
  try {
    return { ok: true, error: null, data: JSON.parse(text) as JsonValue };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Invalid JSON",
      data: null,
    };
  }
}

function unwrapJSONLayers(data: JsonValue): { data: JsonValue; unwrapped: boolean } {
  let current: JsonValue = data;
  let unwrapped = false;

  for (let depth = 0; depth < 5; depth += 1) {
    if (typeof current !== "string") break;
    const inner = current.trim();
    if (!looksLikeJSON(inner)) break;
    const next = tryParse(inner);
    if (!next.ok) break;
    current = next.data;
    unwrapped = true;
  }

  return { data: current, unwrapped };
}

export function parseJSON(raw: unknown, { unwrap = true }: { unwrap?: boolean } = {}): ParseResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: false, error: "empty", data: null, unwrapped: false };

  let parsed = tryParse(value);

  if (!unwrap) {
    return parsed.ok
      ? { ok: true, error: null, data: parsed.data, unwrapped: false }
      : { ...parsed, unwrapped: false };
  }

  let unwrapped = false;

  // e.g. {\"a\":1} — escaped JSON body without outer quotes
  if (!parsed.ok && /\\["\\/bfnrtu]/.test(value)) {
    const asString = tryParse(`"${value}"`);
    if (asString.ok && typeof asString.data === "string" && looksLikeJSON(asString.data)) {
      parsed = tryParse(asString.data.trim());
      unwrapped = true;
    }
  }

  if (!parsed.ok) {
    return { ...parsed, unwrapped: false };
  }

  const layers = unwrapJSONLayers(parsed.data);
  return {
    ok: true,
    error: null,
    data: layers.data,
    unwrapped: unwrapped || layers.unwrapped,
  };
}

export function formatJSON(data: unknown, space = 2): string {
  return `${JSON.stringify(data, null, space)}\n`;
}

export function minifyJSON(data: unknown): string {
  return JSON.stringify(data);
}

/** Encode the editor text as a JSON string literal (with quotes). */
export function escapeJSONText(text: unknown): string {
  return JSON.stringify(String(text ?? ""));
}

/**
 * Decode a JSON string literal or an escaped JSON body without outer quotes.
 * e.g. "{\"a\":1}" or {\"a\":1} → {"a":1}
 */
export function unescapeJSONText(text: unknown): string {
  const value = String(text ?? "").trim();
  if (!value) throw new Error("empty");

  if (value.startsWith('"')) {
    const parsed = tryParse(value);
    if (!parsed.ok) throw new Error(parsed.error || "Unable to unescape");
    if (typeof parsed.data !== "string") throw new Error("Not a JSON string");
    return parsed.data;
  }

  const wrapped = tryParse(`"${value}"`);
  if (!wrapped.ok || typeof wrapped.data !== "string") {
    throw new Error(wrapped.error || "Unable to unescape");
  }
  return wrapped.data;
}

type MutableJson =
  | JsonValue[]
  | { [key: string]: JsonValue };

export function sortKeysDeep(value: unknown): unknown {
  if (!value || typeof value !== "object") return value;
  const root: MutableJson = Array.isArray(value) ? [] : {};
  const stack: { source: object; target: MutableJson }[] = [{ source: value, target: root }];
  let visited = 0;

  while (stack.length) {
    const frame = stack.pop();
    if (!frame) break;
    const { source, target } = frame;
    visited += 1;
    if (visited > 100_000) throw new Error("JSON is too complex to sort safely");
    const keys = Array.isArray(source)
      ? source.map((_, index) => index)
      : Object.keys(source).sort((left, right) => left.localeCompare(right));
    for (const key of keys) {
      const child = (source as Record<string | number, unknown>)[key as string | number];
      if (child && typeof child === "object") {
        const clone: MutableJson = Array.isArray(child) ? [] : {};
        (target as Record<string | number, unknown>)[key as string | number] = clone;
        stack.push({ source: child, target: clone });
      } else {
        (target as Record<string | number, unknown>)[key as string | number] = child as JsonValue;
      }
    }
  }
  return root;
}

export function stringifyValue(value: unknown, space = 2): string {
  if (typeof value === "string") return value;
  return JSON.stringify(value, null, space);
}

/**
 * If a matched value is a JSON object/array encoded as a string, parse it for preview.
 */
export function resolvePreviewValue(value: unknown): unknown {
  if (typeof value !== "string") return value;
  const trimmed = value.trim();
  if (!trimmed || (trimmed[0] !== "{" && trimmed[0] !== "[")) return value;
  const parsed = tryParse(trimmed);
  if (!parsed.ok || parsed.data === null || typeof parsed.data !== "object") return value;
  return unwrapJSONLayers(parsed.data).data;
}

function isObject(value: unknown): value is Record<string, JsonValue> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function quoteKey(key: string): string {
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? `.${key}` : `['${String(key).replaceAll("'", "\\'")}']`;
}

function tokenizePath(rawPath: unknown): PathToken[] {
  const path = String(rawPath ?? "").trim();
  if (!path || path === "$") return [];

  let source = path.startsWith("$") ? path.slice(1) : path;
  if (source.startsWith(".") && !source.startsWith("..")) source = source.slice(1);

  const tokens: PathToken[] = [];
  let index = 0;

  while (index < source.length) {
    const char = source[index]!;

    if (char === "." && source[index + 1] === ".") {
      let cursor = index + 2;
      while (source[cursor] === ".") cursor += 1;
      let name = "";
      while (cursor < source.length && /[A-Za-z0-9_$]/.test(source[cursor]!)) {
        name += source[cursor];
        cursor += 1;
      }
      if (!name) throw new Error("Invalid recursive descent path");
      tokens.push({ type: "descent", name });
      index = cursor;
      continue;
    }

    if (char === ".") {
      index += 1;
      continue;
    }

    if (char === "[") {
      const close = source.indexOf("]", index);
      if (close === -1) throw new Error("Unclosed bracket in path");
      const inside = source.slice(index + 1, close).trim();
      if (inside === "*") tokens.push({ type: "wildcard" });
      else if (/^-?\d+$/.test(inside)) tokens.push({ type: "index", index: Number(inside) });
      else if (
        (inside.startsWith("'") && inside.endsWith("'")) ||
        (inside.startsWith('"') && inside.endsWith('"'))
      ) {
        tokens.push({ type: "key", name: inside.slice(1, -1) });
      } else {
        throw new Error(`Unsupported path segment: [${inside}]`);
      }
      index = close + 1;
      continue;
    }

    if (/[A-Za-z0-9_$]/.test(char)) {
      let name = "";
      while (index < source.length && /[A-Za-z0-9_$]/.test(source[index]!)) {
        name += source[index];
        index += 1;
      }
      tokens.push({ type: "key", name });
      continue;
    }

    throw new Error(`Unexpected character in path: ${char}`);
  }

  return tokens;
}

function collectDescendants(
  value: JsonValue,
  name: string,
  path: string,
  results: PathMatch[],
): void {
  const stack: { value: JsonValue; path: string }[] = [{ value, path }];
  let visited = 0;
  while (stack.length) {
    const current = stack.pop();
    if (!current) break;
    visited += 1;
    if (visited > 100_000) throw new Error("JSON path visited too many values");
    if (Array.isArray(current.value)) {
      for (let index = current.value.length - 1; index >= 0; index -= 1) {
        stack.push({ value: current.value[index] as JsonValue, path: `${current.path}[${index}]` });
      }
      continue;
    }
    if (!isObject(current.value)) continue;
    const entries = Object.entries(current.value);
    for (let index = entries.length - 1; index >= 0; index -= 1) {
      const entry = entries[index]!;
      const key = entry[0];
      const child = entry[1];
      const nextPath = `${current.path}${quoteKey(key)}`;
      if (key === name) {
        results.push({ path: nextPath, value: child });
        if (results.length > 1_000) throw new Error("JSON path returned too many matches");
      }
      stack.push({ value: child, path: nextPath });
    }
  }
}

function applyToken(matches: PathMatch[], token: PathToken): PathMatch[] {
  const next: PathMatch[] = [];

  for (const match of matches) {
    const { value, path } = match;

    if (token.type === "key") {
      if (isObject(value) && Object.prototype.hasOwnProperty.call(value, token.name)) {
        next.push({ path: `${path}${quoteKey(token.name)}`, value: value[token.name]! });
      }
      continue;
    }

    if (token.type === "index") {
      if (!Array.isArray(value)) continue;
      const index = token.index < 0 ? value.length + token.index : token.index;
      if (index < 0 || index >= value.length) continue;
      next.push({ path: `${path}[${index}]`, value: value[index] as JsonValue });
      continue;
    }

    if (token.type === "wildcard") {
      if (Array.isArray(value)) {
        value.forEach((item, index) => next.push({ path: `${path}[${index}]`, value: item as JsonValue }));
      } else if (isObject(value)) {
        for (const [key, child] of Object.entries(value)) {
          next.push({ path: `${path}${quoteKey(key)}`, value: child });
        }
      }
      continue;
    }

    if (token.type === "descent") {
      collectDescendants(value, token.name, path, next);
    }
  }

  return next;
}

export function queryPath(data: unknown, rawPath: unknown): PathQueryResult {
  const path = String(rawPath ?? "").trim();
  if (!path) return { ok: true, error: null, matches: [] };

  try {
    const tokens = tokenizePath(path);
    let matches: PathMatch[] = [{ path: "$", value: data as JsonValue }];
    for (const token of tokens) matches = applyToken(matches, token);
    if (matches.length > 1_000) throw new Error("JSON path returned too many matches");
    return { ok: true, error: null, matches };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Invalid path",
      matches: [],
    };
  }
}

/**
 * Resolve the JSONPath for the value (or object key) under a document offset.
 */
export function pathAtOffset(source: unknown, offset: unknown): PathAtOffsetResult {
  const text = String(source ?? "");
  if (!text.trim()) return { ok: false, path: "" };

  const target = Math.max(0, Math.min(Number(offset) || 0, text.length));
  let index = 0;
  const bestHolder: { current: { path: string; start: number; span: number } | null } = { current: null };

  function consider(path: string, start: number, end: number): void {
    if (target < start || target > end) return;
    const span = end - start;
    const current = bestHolder.current;
    if (!current || span < current.span || (span === current.span && start >= current.start)) {
      bestHolder.current = { path, start, span };
    }
  }

  function skipWhitespace(): void {
    while (index < text.length && /\s/.test(text[index]!)) index += 1;
  }

  function parseString(): { start: number; end: number; raw: string } {
    const start = index;
    if (text[index] !== '"') throw new Error("Expected string");
    index += 1;
    while (index < text.length) {
      const char = text[index];
      if (char === '"') {
        index += 1;
        return { start, end: index, raw: text.slice(start, index) };
      }
      if (char === "\\") {
        index += index + 1 < text.length ? 2 : 1;
        continue;
      }
      index += 1;
    }
    throw new Error("Unterminated string");
  }

  function parseNumber(): { start: number; end: number } {
    const start = index;
    if (text[index] === "-") index += 1;
    while (index < text.length && /[0-9]/.test(text[index]!)) index += 1;
    if (text[index] === ".") {
      index += 1;
      while (index < text.length && /[0-9]/.test(text[index]!)) index += 1;
    }
    if (text[index] === "e" || text[index] === "E") {
      index += 1;
      if (text[index] === "+" || text[index] === "-") index += 1;
      while (index < text.length && /[0-9]/.test(text[index]!)) index += 1;
    }
    if (index === start || (index === start + 1 && text[start] === "-")) {
      throw new Error("Invalid number");
    }
    return { start, end: index };
  }

  function parseLiteral(word: string): { start: number; end: number } {
    const start = index;
    if (text.slice(index, index + word.length) !== word) throw new Error(`Expected ${word}`);
    index += word.length;
    return { start, end: index };
  }

  function parseValue(path: string): void {
    skipWhitespace();
    const start = index;
    const char = text[index];
    if (char === undefined) throw new Error("Unexpected end of JSON");

    if (char === "{") {
      index += 1;
      skipWhitespace();
      if (text[index] === "}") {
        index += 1;
        consider(path, start, index);
        return;
      }
      while (true) {
        skipWhitespace();
        const keyToken = parseString();
        let key = "";
        try {
          key = JSON.parse(keyToken.raw) as string;
        } catch {
          key = keyToken.raw.slice(1, -1);
        }
        const childPath = `${path}${quoteKey(key)}`;
        consider(childPath, keyToken.start, keyToken.end);
        skipWhitespace();
        if (text[index] !== ":") throw new Error("Expected ':'");
        index += 1;
        parseValue(childPath);
        skipWhitespace();
        if (text[index] === ",") {
          index += 1;
          continue;
        }
        if (text[index] === "}") {
          index += 1;
          break;
        }
        throw new Error("Expected ',' or '}'");
      }
      consider(path, start, index);
      return;
    }

    if (char === "[") {
      index += 1;
      skipWhitespace();
      if (text[index] === "]") {
        index += 1;
        consider(path, start, index);
        return;
      }
      let itemIndex = 0;
      while (true) {
        parseValue(`${path}[${itemIndex}]`);
        skipWhitespace();
        if (text[index] === ",") {
          index += 1;
          itemIndex += 1;
          continue;
        }
        if (text[index] === "]") {
          index += 1;
          break;
        }
        throw new Error("Expected ',' or ']'");
      }
      consider(path, start, index);
      return;
    }

    if (char === '"') {
      const stringToken = parseString();
      consider(path, stringToken.start, stringToken.end);
      return;
    }
    if (char === "-" || /[0-9]/.test(char)) {
      const numberToken = parseNumber();
      consider(path, numberToken.start, numberToken.end);
      return;
    }
    if (char === "t") {
      const literal = parseLiteral("true");
      consider(path, literal.start, literal.end);
      return;
    }
    if (char === "f") {
      const literal = parseLiteral("false");
      consider(path, literal.start, literal.end);
      return;
    }
    if (char === "n") {
      const literal = parseLiteral("null");
      consider(path, literal.start, literal.end);
      return;
    }
    throw new Error(`Unexpected character: ${char}`);
  }

  try {
    parseValue("$");
    skipWhitespace();
    const resolved = bestHolder.current;
    return { ok: Boolean(resolved), path: resolved?.path || "$" };
  } catch {
    return { ok: false, path: "" };
  }
}

export function byteSize(text: unknown): number {
  return new TextEncoder().encode(String(text ?? "")).length;
}
