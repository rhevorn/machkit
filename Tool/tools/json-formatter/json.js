function looksLikeJSON(text) {
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
    (first >= "0" && first <= "9")
  );
}

function tryParse(text) {
  try {
    return { ok: true, error: null, data: JSON.parse(text) };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Invalid JSON",
      data: null,
    };
  }
}

function unwrapJSONLayers(data) {
  let current = data;
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

export function parseJSON(raw) {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: false, error: "empty", data: null, unwrapped: false };

  let parsed = tryParse(value);
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

export function formatJSON(data, space = 2) {
  return `${JSON.stringify(data, null, space)}\n`;
}

export function minifyJSON(data) {
  return JSON.stringify(data);
}

export function sortKeysDeep(value) {
  if (!value || typeof value !== "object") return value;
  const root = Array.isArray(value) ? [] : {};
  const stack = [{ source: value, target: root }];
  let visited = 0;

  while (stack.length) {
    const { source, target } = stack.pop();
    visited += 1;
    if (visited > 100_000) throw new Error("JSON is too complex to sort safely");
    const keys = Array.isArray(source)
      ? source.map((_, index) => index)
      : Object.keys(source).sort((left, right) => left.localeCompare(right));
    for (const key of keys) {
      const child = source[key];
      if (child && typeof child === "object") {
        const clone = Array.isArray(child) ? [] : {};
        target[key] = clone;
        stack.push({ source: child, target: clone });
      } else {
        target[key] = child;
      }
    }
  }
  return root;
}

export function stringifyValue(value, space = 2) {
  if (typeof value === "string") return value;
  return JSON.stringify(value, null, space);
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function quoteKey(key) {
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? `.${key}` : `['${String(key).replaceAll("'", "\\'")}']`;
}

function tokenizePath(rawPath) {
  const path = String(rawPath ?? "").trim();
  if (!path || path === "$") return [];

  let source = path.startsWith("$") ? path.slice(1) : path;
  if (source.startsWith(".") && !source.startsWith("..")) source = source.slice(1);

  const tokens = [];
  let index = 0;

  while (index < source.length) {
    const char = source[index];

    if (char === "." && source[index + 1] === ".") {
      let cursor = index + 2;
      while (source[cursor] === ".") cursor += 1;
      let name = "";
      while (cursor < source.length && /[A-Za-z0-9_$]/.test(source[cursor])) {
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
      while (index < source.length && /[A-Za-z0-9_$]/.test(source[index])) {
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

function collectDescendants(value, name, path, results) {
  const stack = [{ value, path }];
  let visited = 0;
  while (stack.length) {
    const current = stack.pop();
    visited += 1;
    if (visited > 100_000) throw new Error("JSON path visited too many values");
    if (Array.isArray(current.value)) {
      for (let index = current.value.length - 1; index >= 0; index -= 1) {
        stack.push({ value: current.value[index], path: `${current.path}[${index}]` });
      }
      continue;
    }
    if (!isObject(current.value)) continue;
    const entries = Object.entries(current.value);
    for (let index = entries.length - 1; index >= 0; index -= 1) {
      const [key, child] = entries[index];
      const nextPath = `${current.path}${quoteKey(key)}`;
      if (key === name) {
        results.push({ path: nextPath, value: child });
        if (results.length > 1_000) throw new Error("JSON path returned too many matches");
      }
      stack.push({ value: child, path: nextPath });
    }
  }
}

function applyToken(matches, token) {
  const next = [];

  for (const match of matches) {
    const { value, path } = match;

    if (token.type === "key") {
      if (isObject(value) && Object.prototype.hasOwnProperty.call(value, token.name)) {
        next.push({ path: `${path}${quoteKey(token.name)}`, value: value[token.name] });
      }
      continue;
    }

    if (token.type === "index") {
      if (!Array.isArray(value)) continue;
      const index = token.index < 0 ? value.length + token.index : token.index;
      if (index < 0 || index >= value.length) continue;
      next.push({ path: `${path}[${index}]`, value: value[index] });
      continue;
    }

    if (token.type === "wildcard") {
      if (Array.isArray(value)) {
        value.forEach((item, index) => next.push({ path: `${path}[${index}]`, value: item }));
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

export function queryPath(data, rawPath) {
  const path = String(rawPath ?? "").trim();
  if (!path) return { ok: true, error: null, matches: [] };

  try {
    const tokens = tokenizePath(path);
    let matches = [{ path: "$", value: data }];
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

export function byteSize(text) {
  return new TextEncoder().encode(String(text ?? "")).length;
}
