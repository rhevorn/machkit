const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder("utf-8", { fatal: true });

const BASE62_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

export type CodecOk = { ok: true; value: string; error?: null };
export type CodecErr = { ok: false; value: string; error: string };
export type CodecResult = CodecOk | CodecErr;

export type UrlMode = "component" | "uri" | string;
export type CodecDirection = "encode" | "decode" | string;
export type CodecTab =
  | "hash"
  | "base64"
  | "url"
  | "base62"
  | "hex"
  | "html"
  | "unicode"
  | "escape"
  | "base32"
  | string;

export type ConvertCodecParams = {
  tab: CodecTab;
  direction?: CodecDirection;
  input: unknown;
  urlMode?: UrlMode;
  base64URL?: boolean;
  algorithm?: string;
};

export type ConvertCodecResult = {
  ok: boolean;
  value: string;
  error: string | null;
};

export function bytesFromText(text: unknown): Uint8Array {
  return textEncoder.encode(String(text ?? ""));
}

export function textFromBytes(bytes: BufferSource): string {
  return textDecoder.decode(bytes);
}

function decodedTextResult(bytes: BufferSource, error: string): CodecResult {
  try {
    return { ok: true, value: textFromBytes(bytes) };
  } catch {
    return { ok: false, error, value: "" };
  }
}

export function encodeBase64(text: unknown): string {
  const bytes = bytesFromText(text);
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary);
}

export function decodeBase64(raw: unknown): CodecResult {
  const value = String(raw ?? "").replace(/\s+/g, "");
  if (!value) return { ok: true, value: "" };
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value) || value.length % 4 !== 0) {
    return { ok: false, error: "invalid-base64", value: "" };
  }
  try {
    const binary = atob(value);
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    return decodedTextResult(bytes, "invalid-base64");
  } catch {
    return { ok: false, error: "invalid-base64", value: "" };
  }
}

export function encodeBase64URL(text: unknown): string {
  return encodeBase64(text).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function decodeBase64URL(raw: unknown): CodecResult {
  const value = String(raw ?? "").replace(/\s+/g, "").replace(/-/g, "+").replace(/_/g, "/");
  const padded = value + "=".repeat((4 - (value.length % 4 || 4)) % 4);
  return decodeBase64(padded);
}

export function encodeURL(text: unknown, mode: UrlMode = "component"): string {
  const value = String(text ?? "");
  return mode === "uri" ? encodeURI(value) : encodeURIComponent(value);
}

export function decodeURL(raw: unknown, mode: UrlMode = "component"): CodecResult {
  const value = String(raw ?? "");
  if (!value) return { ok: true, value: "" };
  try {
    return {
      ok: true,
      value: mode === "uri" ? decodeURI(value) : decodeURIComponent(value),
    };
  } catch {
    return { ok: false, error: "invalid-url", value: "" };
  }
}

export function encodeHex(text: unknown): string {
  return Array.from(bytesFromText(text), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function decodeHex(raw: unknown): CodecResult {
  const value = String(raw ?? "").replace(/\s+/g, "").replace(/^0x/i, "");
  if (!value) return { ok: true, value: "" };
  if (!/^[0-9a-fA-F]*$/.test(value) || value.length % 2 !== 0) {
    return { ok: false, error: "invalid-hex", value: "" };
  }
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return decodedTextResult(bytes, "invalid-hex");
}

const HTML_ESCAPE = Object.freeze({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
} as const);

const HTML_NAMED = Object.freeze({
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: "\u00A0",
} as const);

type HtmlEscapeKey = keyof typeof HTML_ESCAPE;
type HtmlNamedKey = keyof typeof HTML_NAMED;

export function encodeHTML(text: unknown): string {
  return String(text ?? "").replace(/[&<>"']/g, (char) => HTML_ESCAPE[char as HtmlEscapeKey]);
}

export function decodeHTML(raw: unknown): CodecOk {
  const value = String(raw ?? "").replace(/&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);/g, (match, entity: string) => {
    if (entity[0] === "#") {
      const code = entity[1] === "x" || entity[1] === "X"
        ? Number.parseInt(entity.slice(2), 16)
        : Number.parseInt(entity.slice(1), 10);
      if (!Number.isFinite(code)) return match;
      try {
        return String.fromCodePoint(code);
      } catch {
        return match;
      }
    }
    return Object.prototype.hasOwnProperty.call(HTML_NAMED, entity)
      ? HTML_NAMED[entity as HtmlNamedKey]
      : match;
  });
  return { ok: true, value };
}

export function encodeUnicode(text: unknown): string {
  return Array.from(String(text ?? ""), (char) => {
    const code = char.codePointAt(0);
    if (code === undefined) return char;
    if (code <= 0xffff) return `\\u${code.toString(16).padStart(4, "0")}`;
    return `\\u{${code.toString(16)}}`;
  }).join("");
}

export function decodeUnicode(raw: unknown): CodecResult {
  const source = String(raw ?? "");
  if (!source) return { ok: true, value: "" };
  try {
    let index = 0;
    let result = "";
    while (index < source.length) {
      if (source[index] !== "\\") {
        result += source[index];
        index += 1;
        continue;
      }
      const next = source[index + 1];
      if (next === "u" && source[index + 2] === "{") {
        const close = source.indexOf("}", index + 3);
        if (close === -1) return { ok: false, error: "invalid-unicode", value: "" };
        const hex = source.slice(index + 3, close);
        if (!/^[0-9a-fA-F]+$/.test(hex)) return { ok: false, error: "invalid-unicode", value: "" };
        result += String.fromCodePoint(Number.parseInt(hex, 16));
        index = close + 1;
        continue;
      }
      if (next === "u" && /^[0-9a-fA-F]{4}/.test(source.slice(index + 2))) {
        result += String.fromCharCode(Number.parseInt(source.slice(index + 2, index + 6), 16));
        index += 6;
        continue;
      }
      if (next === "x" && /^[0-9a-fA-F]{2}/.test(source.slice(index + 2))) {
        result += String.fromCharCode(Number.parseInt(source.slice(index + 2, index + 4), 16));
        index += 4;
        continue;
      }
      if (next === "n") { result += "\n"; index += 2; continue; }
      if (next === "t") { result += "\t"; index += 2; continue; }
      if (next === "r") { result += "\r"; index += 2; continue; }
      if (next === "\\" || next === "'" || next === '"') { result += next; index += 2; continue; }
      return { ok: false, error: "invalid-unicode", value: "" };
    }
    return { ok: true, value: result };
  } catch {
    return { ok: false, error: "invalid-unicode", value: "" };
  }
}

export function encodeEscape(text: unknown): string {
  return Array.from(String(text ?? ""), (char) => {
    switch (char) {
      case "\\": return "\\\\";
      case "\"": return "\\\"";
      case "'": return "\\'";
      case "`": return "\\`";
      case "\n": return "\\n";
      case "\r": return "\\r";
      case "\t": return "\\t";
      case "\b": return "\\b";
      case "\f": return "\\f";
      case "\v": return "\\v";
      case "\0": return "\\0";
      default: return char;
    }
  }).join("");
}

export function decodeEscape(raw: unknown): CodecResult {
  const source = String(raw ?? "");
  if (!source) return { ok: true, value: "" };
  try {
    let index = 0;
    let result = "";
    while (index < source.length) {
      if (source[index] !== "\\") {
        result += source[index];
        index += 1;
        continue;
      }
      const next = source[index + 1];
      if (next === undefined) return { ok: false, error: "invalid-escape", value: "" };
      if (next === "u" && source[index + 2] === "{") {
        const close = source.indexOf("}", index + 3);
        if (close === -1) return { ok: false, error: "invalid-escape", value: "" };
        const hex = source.slice(index + 3, close);
        if (!/^[0-9a-fA-F]+$/.test(hex)) return { ok: false, error: "invalid-escape", value: "" };
        result += String.fromCodePoint(Number.parseInt(hex, 16));
        index = close + 1;
        continue;
      }
      if (next === "u" && /^[0-9a-fA-F]{4}/.test(source.slice(index + 2))) {
        result += String.fromCharCode(Number.parseInt(source.slice(index + 2, index + 6), 16));
        index += 6;
        continue;
      }
      if (next === "x" && /^[0-9a-fA-F]{2}/.test(source.slice(index + 2))) {
        result += String.fromCharCode(Number.parseInt(source.slice(index + 2, index + 4), 16));
        index += 4;
        continue;
      }
      const simple: Record<string, string> = {
        "\\": "\\",
        "'": "'",
        '"': '"',
        "`": "`",
        n: "\n",
        r: "\r",
        t: "\t",
        b: "\b",
        f: "\f",
        v: "\v",
        0: "\0",
      };
      if (Object.prototype.hasOwnProperty.call(simple, next)) {
        result += simple[next]!;
        index += 2;
        continue;
      }
      return { ok: false, error: "invalid-escape", value: "" };
    }
    return { ok: true, value: result };
  } catch {
    return { ok: false, error: "invalid-escape", value: "" };
  }
}

const BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

export function encodeBase32(text: unknown): string {
  const bytes = bytesFromText(text);
  if (!bytes.length) return "";

  let bits = 0;
  let value = 0;
  let output = "";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      output += BASE32_ALPHABET[(value >>> bits) & 31];
    }
    value &= bits === 0 ? 0 : (1 << bits) - 1;
  }
  if (bits > 0) output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  while (output.length % 8 !== 0) output += "=";
  return output;
}

export function decodeBase32(raw: unknown): CodecResult {
  const value = String(raw ?? "").replace(/\s+/g, "").replace(/=+$/g, "").toUpperCase();
  if (!value) return { ok: true, value: "" };
  if (!/^[A-Z2-7]+$/.test(value)) return { ok: false, error: "invalid-base32", value: "" };

  let bits = 0;
  let buffer = 0;
  const bytes: number[] = [];
  for (const char of value) {
    const index = BASE32_ALPHABET.indexOf(char);
    if (index < 0) return { ok: false, error: "invalid-base32", value: "" };
    buffer = (buffer << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((buffer >>> bits) & 255);
      buffer &= bits === 0 ? 0 : (1 << bits) - 1;
    }
  }
  return decodedTextResult(Uint8Array.from(bytes), "invalid-base32");
}

function divideBigIntBase62(bytes: Uint8Array): string {
  let value = 0n;
  for (const byte of bytes) value = (value << 8n) + BigInt(byte);
  if (value === 0n) return "0";

  let result = "";
  while (value > 0n) {
    const remainder = Number(value % 62n);
    result = BASE62_ALPHABET[remainder] + result;
    value /= 62n;
  }
  return result;
}

export function encodeBase62(text: unknown): string {
  const bytes = bytesFromText(text);
  if (!bytes.length) return "";
  let leadingZeroCount = 0;
  while (leadingZeroCount < bytes.length && bytes[leadingZeroCount] === 0) leadingZeroCount += 1;
  const prefix = "0".repeat(leadingZeroCount);
  if (leadingZeroCount === bytes.length) return prefix;
  return prefix + divideBigIntBase62(bytes.slice(leadingZeroCount));
}

export function decodeBase62(raw: unknown): CodecResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: true, value: "" };
  if (!/^[0-9A-Za-z]+$/.test(value)) return { ok: false, error: "invalid-base62", value: "" };

  let leadingZeroCount = 0;
  while (leadingZeroCount < value.length && value[leadingZeroCount] === "0") leadingZeroCount += 1;
  let number = 0n;
  for (const char of value.slice(leadingZeroCount)) {
    const index = BASE62_ALPHABET.indexOf(char);
    if (index < 0) return { ok: false, error: "invalid-base62", value: "" };
    number = number * 62n + BigInt(index);
  }

  const significantBytes: number[] = [];
  while (number > 0n) {
    significantBytes.unshift(Number(number & 0xffn));
    number >>= 8n;
  }
  const bytes = [...Array(leadingZeroCount).fill(0), ...significantBytes];
  return decodedTextResult(Uint8Array.from(bytes), "invalid-base62");
}

function rotateLeft(value: number, bits: number): number {
  return (value << bits) | (value >>> (32 - bits));
}

function md5ToHex(bytes: Uint8Array): string {
  const originalLength = bytes.length;
  const bitLength = BigInt(originalLength) * 8n;
  const withOne = new Uint8Array(((originalLength + 9 + 63) >> 6) << 6);
  withOne.set(bytes);
  withOne[originalLength] = 0x80;
  const view = new DataView(withOne.buffer);
  view.setUint32(withOne.length - 8, Number(bitLength & 0xffffffffn), true);
  view.setUint32(withOne.length - 4, Number((bitLength >> 32n) & 0xffffffffn), true);

  let a0 = 0x67452301;
  let b0 = 0xefcdab89;
  let c0 = 0x98badcfe;
  let d0 = 0x10325476;

  const s = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ];
  const k = Array.from({ length: 64 }, (_, index) => Math.floor(2 ** 32 * Math.abs(Math.sin(index + 1))));

  for (let offset = 0; offset < withOne.length; offset += 64) {
    const m = Array.from({ length: 16 }, (_, index) => view.getUint32(offset + index * 4, true));
    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;

    for (let index = 0; index < 64; index += 1) {
      let f: number;
      let g: number;
      if (index < 16) {
        f = (b & c) | (~b & d);
        g = index;
      } else if (index < 32) {
        f = (d & b) | (~d & c);
        g = (5 * index + 1) % 16;
      } else if (index < 48) {
        f = b ^ c ^ d;
        g = (3 * index + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * index) % 16;
      }
      const temp = d;
      d = c;
      c = b;
      b = (b + rotateLeft((a + f + k[index]! + m[g]!) >>> 0, s[index]!)) >>> 0;
      a = temp;
    }

    a0 = (a0 + a) >>> 0;
    b0 = (b0 + b) >>> 0;
    c0 = (c0 + c) >>> 0;
    d0 = (d0 + d) >>> 0;
  }

  const digest = new Uint8Array(16);
  const digestView = new DataView(digest.buffer);
  digestView.setUint32(0, a0, true);
  digestView.setUint32(4, b0, true);
  digestView.setUint32(8, c0, true);
  digestView.setUint32(12, d0, true);
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function hashText(text: unknown, algorithm = "SHA-256"): Promise<string> {
  const bytes = bytesFromText(text);
  if (algorithm === "MD5") return md5ToHex(bytes);

  const digest = await crypto.subtle.digest(algorithm, bytes as BufferSource);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export const hashAlgorithms = Object.freeze(["MD5", "SHA-1", "SHA-256", "SHA-384", "SHA-512"]);

export function convertCodec({
  tab,
  direction,
  input,
  urlMode = "component",
  base64URL = false,
  algorithm = "SHA-256",
}: ConvertCodecParams): Promise<ConvertCodecResult> {
  const value = String(input ?? "");

  if (tab === "hash") {
    return hashText(value, algorithm).then((hash) => ({ ok: true, value: hash, error: null }));
  }

  if (tab === "base64") {
    if (direction === "encode") {
      return Promise.resolve({
        ok: true,
        value: base64URL ? encodeBase64URL(value) : encodeBase64(value),
        error: null,
      });
    }
    const result = base64URL ? decodeBase64URL(value) : decodeBase64(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "url") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeURL(value, urlMode), error: null });
    }
    const result = decodeURL(value, urlMode);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base62") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase62(value), error: null });
    }
    const result = decodeBase62(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "hex") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeHex(value), error: null });
    }
    const result = decodeHex(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "html") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeHTML(value), error: null });
    }
    const result = decodeHTML(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: null });
  }

  if (tab === "unicode") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeUnicode(value), error: null });
    }
    const result = decodeUnicode(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "escape") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeEscape(value), error: null });
    }
    const result = decodeEscape(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base32") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase32(value), error: null });
    }
    const result = decodeBase32(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  return Promise.resolve({ ok: false, value: "", error: "unsupported" });
}
