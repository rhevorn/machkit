export const maxXMLInput = 1_000_000;

function tooLarge(input) {
  return String(input ?? "").length > maxXMLInput;
}

/** Minify XML-ish markup by removing comments and collapsing whitespace between tags. */
export function minifyXML(input) {
  const text = String(input ?? "");
  if (!text.trim()) return { ok: false, error: "empty", text: "" };
  if (tooLarge(text)) return { ok: false, error: "too-large", text: "" };
  const minified = text
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/>\s+</g, "><")
    .trim();
  return { ok: true, error: null, text: minified };
}

/** Pretty-print XML with 2-space indent. Best-effort for well-formed markup. */
export function formatXML(input, indentSize = 2) {
  const minified = minifyXML(input);
  if (!minified.ok) return minified;

  const pad = " ".repeat(Math.max(1, indentSize));
  const tokens = minified.text.replace(/(>)(<)(\/*)/g, "$1\n$2$3").split("\n");
  let depth = 0;
  const lines = [];

  for (const raw of tokens) {
    const line = raw.trim();
    if (!line) continue;
    if (/^<\/\w/.test(line)) depth = Math.max(depth - 1, 0);
    lines.push(`${pad.repeat(depth)}${line}`);
    if (
      /^<\w[^>]*[^/]>$/.test(line) &&
      !/^<\?/.test(line) &&
      !/^<!/.test(line) &&
      !/^<.*<\/\w/.test(line)
    ) {
      depth += 1;
    }
  }

  return { ok: true, error: null, text: `${lines.join("\n")}\n` };
}

function decodeEntities(text) {
  return String(text)
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

function readTag(source, index) {
  if (source[index] !== "<") return null;
  const end = source.indexOf(">", index);
  if (end === -1) return null;
  return { raw: source.slice(index, end + 1), end: end + 1 };
}

function parseNode(source, index) {
  while (index < source.length && /\s/.test(source[index])) index += 1;
  if (index >= source.length) return { value: null, index };

  const tag = readTag(source, index);
  if (!tag) {
    const next = source.indexOf("<", index);
    const text = decodeEntities(source.slice(index, next === -1 ? source.length : next).trim());
    return { value: text || null, index: next === -1 ? source.length : next };
  }

  const { raw, end } = tag;
  if (raw.startsWith("<?") || raw.startsWith("<!")) {
    return parseNode(source, end);
  }
  if (raw.startsWith("</")) {
    return { value: null, index, closed: raw };
  }

  const selfClosing = /\/>$/.test(raw);
  const nameMatch = raw.match(/^<\/?([A-Za-z_][\w:.-]*)/);
  if (!nameMatch) throw new Error("invalid-tag");
  const name = nameMatch[1];
  index = end;

  if (name === "true") {
    if (!selfClosing) index = skipClose(source, index, name);
    return { value: true, index };
  }
  if (name === "false") {
    if (!selfClosing) index = skipClose(source, index, name);
    return { value: false, index };
  }

  if (selfClosing) {
    return { value: name === "array" ? [] : name === "dict" ? {} : null, index };
  }

  if (["string", "integer", "real", "date", "data", "key"].includes(name)) {
    const close = `</${name}>`;
    const closeAt = source.indexOf(close, index);
    if (closeAt === -1) throw new Error("unclosed");
    const body = decodeEntities(source.slice(index, closeAt));
    index = closeAt + close.length;
    if (name === "integer") return { value: Number.parseInt(body, 10), index };
    if (name === "real") return { value: Number.parseFloat(body), index };
    if (name === "key") return { value: { type: "key", value: body }, index };
    return { value: body, index };
  }

  if (name === "array") {
    const items = [];
    while (true) {
      while (index < source.length && /\s/.test(source[index])) index += 1;
      if (source.startsWith(`</${name}>`, index)) {
        index += `</${name}>`.length;
        break;
      }
      const child = parseNode(source, index);
      if (child.closed) throw new Error("unexpected-close");
      if (child.value === null && child.index === index) throw new Error("invalid-array");
      items.push(child.value);
      index = child.index;
    }
    return { value: items, index };
  }

  if (name === "dict") {
    const object = {};
    while (true) {
      while (index < source.length && /\s/.test(source[index])) index += 1;
      if (source.startsWith(`</${name}>`, index)) {
        index += `</${name}>`.length;
        break;
      }
      const keyNode = parseNode(source, index);
      if (!keyNode.value || keyNode.value.type !== "key") throw new Error("dict-key");
      index = keyNode.index;
      const valueNode = parseNode(source, index);
      object[keyNode.value.value] = valueNode.value;
      index = valueNode.index;
    }
    return { value: object, index };
  }

  if (name === "plist") {
    const child = parseNode(source, index);
    index = skipClose(source, child.index, name);
    return { value: child.value, index };
  }

  // Unknown wrapper: parse single child or raw text.
  const close = `</${name}>`;
  const closeAt = source.indexOf(close, index);
  if (closeAt === -1) throw new Error("unclosed");
  const inner = source.slice(index, closeAt).trim();
  index = closeAt + close.length;
  if (!inner) return { value: null, index };
  if (inner.startsWith("<")) {
    const child = parseNode(inner, 0);
    return { value: child.value, index };
  }
  return { value: decodeEntities(inner), index };
}

function skipClose(source, index, name) {
  while (index < source.length && /\s/.test(source[index])) index += 1;
  const close = `</${name}>`;
  if (!source.startsWith(close, index)) throw new Error("unclosed");
  return index + close.length;
}

export function parsePlistXML(input) {
  const text = String(input ?? "").trim();
  if (!text) return { ok: false, error: "empty", value: null };
  if (tooLarge(text)) return { ok: false, error: "too-large", value: null };
  try {
    const cleaned = text.replace(/<!--[\s\S]*?-->/g, "");
    const start = cleaned.search(/<plist[\s>]/i);
    if (start === -1) return { ok: false, error: "not-plist", value: null };
    const parsed = parseNode(cleaned, start);
    return { ok: true, error: null, value: parsed.value };
  } catch (error) {
    return { ok: false, error: error?.message || "parse-failed", value: null };
  }
}

export function plistToJSON(input, indent = 2) {
  const parsed = parsePlistXML(input);
  if (!parsed.ok) return { ok: false, error: parsed.error, text: "" };
  return {
    ok: true,
    error: null,
    text: `${JSON.stringify(parsed.value, null, indent)}\n`,
  };
}
