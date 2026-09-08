import {
  convertRadix,
  decodeBinary,
  decodeDataURI,
  decodeDecimal,
  decodeGbk,
  decodeJsonString,
  decodePunycode,
  decodeQuotedPrintable,
  decodeRot13,
  encodeBinary,
  encodeDataURI,
  encodeDecimal,
  encodeGbk,
  encodeJsonString,
  encodePunycode,
  encodeQuotedPrintable,
  encodeRot13,
} from "./codec-extra.js";

export {
  convertRadix,
  decodeBinary,
  decodeDataURI,
  decodeDecimal,
  decodeGbk,
  decodeJsonString,
  decodePunycode,
  decodeQuotedPrintable,
  decodeRot13,
  encodeBinary,
  encodeDataURI,
  encodeDecimal,
  encodeGbk,
  encodeJsonString,
  encodePunycode,
  encodeQuotedPrintable,
  encodeRot13,
  inspectDataURI,
} from "./codec-extra.js";

export type { DataURIInfo, DataURIInspectResult } from "./codec-extra.js";

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder("utf-8", { fatal: true });

const BASE62_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const BASE36_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

export type CodecOk = { ok: true; value: string; error?: null };
export type CodecErr = { ok: false; value: string; error: string };
export type CodecResult = CodecOk | CodecErr;

export type UrlMode = "component" | "uri" | string;
export type CodecDirection = "encode" | "decode" | string;
export type CodecTab =
  | "hash"
  | "base64"
  | "base16"
  | "base32"
  | "base36"
  | "base58"
  | "base62"
  | "base85"
  | "url"
  | "hex"
  | "html"
  | "unicode"
  | "utf-8"
  | "ascii"
  | "native"
  | "escape"
  | "binary"
  | "decimal"
  | "punycode"
  | "json"
  | "quoted-printable"
  | "rot13"
  | "data-uri"
  | "gbk"
  | "radix"
  | string;

export type ConvertCodecParams = {
  tab: CodecTab;
  direction?: CodecDirection;
  input: unknown;
  urlMode?: UrlMode;
  base64URL?: boolean;
  algorithm?: string;
  hmacKey?: string;
  fromRadix?: number;
  toRadix?: number;
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

function encodeWithAlphabet(
  text: unknown,
  alphabet: string,
  zeroChar: string,
): string {
  const bytes = bytesFromText(text);
  if (!bytes.length) return "";
  const base = BigInt(alphabet.length);
  let leadingZeroCount = 0;
  while (leadingZeroCount < bytes.length && bytes[leadingZeroCount] === 0) leadingZeroCount += 1;
  const prefix = zeroChar.repeat(leadingZeroCount);
  if (leadingZeroCount === bytes.length) return prefix;

  let value = 0n;
  for (const byte of bytes.slice(leadingZeroCount)) value = (value << 8n) + BigInt(byte);
  let result = "";
  while (value > 0n) {
    const remainder = Number(value % base);
    result = alphabet[remainder] + result;
    value /= base;
  }
  return prefix + result;
}

function decodeWithAlphabet(
  raw: unknown,
  alphabet: string,
  zeroChar: string,
  error: string,
  normalize?: (value: string) => string,
): CodecResult {
  const value = (normalize ? normalize(String(raw ?? "").trim()) : String(raw ?? "").trim());
  if (!value) return { ok: true, value: "" };

  const base = BigInt(alphabet.length);
  let leadingZeroCount = 0;
  while (leadingZeroCount < value.length && value[leadingZeroCount] === zeroChar) leadingZeroCount += 1;
  let number = 0n;
  for (const char of value.slice(leadingZeroCount)) {
    const index = alphabet.indexOf(char);
    if (index < 0) return { ok: false, error, value: "" };
    number = number * base + BigInt(index);
  }

  const significantBytes: number[] = [];
  while (number > 0n) {
    significantBytes.unshift(Number(number & 0xffn));
    number >>= 8n;
  }
  const bytes = [...Array(leadingZeroCount).fill(0), ...significantBytes];
  return decodedTextResult(Uint8Array.from(bytes), error);
}

export function encodeBase16(text: unknown): string {
  return encodeHex(text);
}

export function decodeBase16(raw: unknown): CodecResult {
  return decodeHex(raw);
}

export function encodeBase36(text: unknown): string {
  return encodeWithAlphabet(text, BASE36_ALPHABET, "0");
}

export function decodeBase36(raw: unknown): CodecResult {
  return decodeWithAlphabet(raw, BASE36_ALPHABET, "0", "invalid-base36", (value) => value.toUpperCase());
}

export function encodeBase58(text: unknown): string {
  return encodeWithAlphabet(text, BASE58_ALPHABET, "1");
}

export function decodeBase58(raw: unknown): CodecResult {
  return decodeWithAlphabet(raw, BASE58_ALPHABET, "1", "invalid-base58");
}

export function encodeBase62(text: unknown): string {
  return encodeWithAlphabet(text, BASE62_ALPHABET, "0");
}

export function decodeBase62(raw: unknown): CodecResult {
  return decodeWithAlphabet(raw, BASE62_ALPHABET, "0", "invalid-base62");
}

/** Adobe Ascii85 / Base85. */
export function encodeBase85(text: unknown): string {
  const bytes = bytesFromText(text);
  if (!bytes.length) return "";
  let output = "";
  for (let index = 0; index < bytes.length; index += 4) {
    const chunk = bytes.subarray(index, Math.min(index + 4, bytes.length));
    const padding = 4 - chunk.length;
    let value = 0;
    for (let offset = 0; offset < 4; offset += 1) {
      value = ((value << 8) + (offset < chunk.length ? chunk[offset]! : 0)) >>> 0;
    }
    if (chunk.length === 4 && value === 0) {
      output += "z";
      continue;
    }
    const digits = Array<string>(5);
    for (let digit = 4; digit >= 0; digit -= 1) {
      digits[digit] = String.fromCharCode((value % 85) + 33);
      value = Math.floor(value / 85);
    }
    output += digits.slice(0, 5 - padding).join("");
  }
  return output;
}

export function decodeBase85(raw: unknown): CodecResult {
  const source = String(raw ?? "").replace(/\s+/g, "");
  if (!source) return { ok: true, value: "" };
  const bytes: number[] = [];
  let index = 0;
  while (index < source.length) {
    if (source[index] === "z") {
      bytes.push(0, 0, 0, 0);
      index += 1;
      continue;
    }
    const chunk = source.slice(index, index + 5);
    if (!chunk.length) break;
    if (chunk.length < 2) return { ok: false, error: "invalid-base85", value: "" };
    const padding = 5 - chunk.length;
    let value = 0;
    for (let offset = 0; offset < 5; offset += 1) {
      const char = offset < chunk.length ? chunk[offset]! : "u";
      const code = char.charCodeAt(0) - 33;
      if (code < 0 || code > 84) return { ok: false, error: "invalid-base85", value: "" };
      value = value * 85 + code;
    }
    if (value > 0xffffffff) return { ok: false, error: "invalid-base85", value: "" };
    const decoded = [
      (value >>> 24) & 0xff,
      (value >>> 16) & 0xff,
      (value >>> 8) & 0xff,
      value & 0xff,
    ];
    bytes.push(...decoded.slice(0, 4 - padding));
    index += chunk.length;
  }
  return decodedTextResult(Uint8Array.from(bytes), "invalid-base85");
}

/** UTF-8 bytes as spaced hex, e.g. `E4 BD A0`. */
export function encodeUTF8Bytes(text: unknown): string {
  return Array.from(bytesFromText(text), (byte) => byte.toString(16).padStart(2, "0").toUpperCase()).join(
    " ",
  );
}

export function decodeUTF8Bytes(raw: unknown): CodecResult {
  return decodeHex(String(raw ?? "").replace(/\\x/gi, ""));
}

/** Code points as decimals, e.g. `72 105`. */
export function encodeASCII(text: unknown): string {
  return Array.from(String(text ?? ""), (char) => String(char.codePointAt(0) ?? 0)).join(" ");
}

export function decodeASCII(raw: unknown): CodecResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: true, value: "" };
  const parts = value.split(/[\s,;]+/).filter(Boolean);
  try {
    return {
      ok: true,
      value: parts
        .map((part) => {
          if (!/^\d+$/.test(part)) throw new Error("invalid-ascii");
          const code = Number.parseInt(part, 10);
          if (!Number.isFinite(code) || code < 0 || code > 0x10ffff) throw new Error("invalid-ascii");
          return String.fromCodePoint(code);
        })
        .join(""),
    };
  } catch {
    return { ok: false, error: "invalid-ascii", value: "" };
  }
}

/** Java-style Native2Ascii: non-ASCII → `\uXXXX`, ASCII left as-is. */
export function encodeNative(text: unknown): string {
  return Array.from(String(text ?? ""), (char) => {
    const code = char.codePointAt(0);
    if (code === undefined) return char;
    if (code >= 0x20 && code <= 0x7e) return char;
    if (code <= 0xffff) return `\\u${code.toString(16).padStart(4, "0")}`;
    const high = Math.floor((code - 0x10000) / 0x400) + 0xd800;
    const low = ((code - 0x10000) % 0x400) + 0xdc00;
    return `\\u${high.toString(16).padStart(4, "0")}\\u${low.toString(16).padStart(4, "0")}`;
  }).join("");
}

export function decodeNative(raw: unknown): CodecResult {
  return decodeUnicode(raw);
}

function rotateLeft(value: number, bits: number): number {
  return (value << bits) | (value >>> (32 - bits));
}

function md5Digest(bytes: Uint8Array): Uint8Array {
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
  return digest;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function md5ToHex(bytes: Uint8Array): string {
  return bytesToHex(md5Digest(bytes));
}

function hmacMD5(keyBytes: Uint8Array, messageBytes: Uint8Array): string {
  const blockSize = 64;
  let key = keyBytes;
  if (key.length > blockSize) key = md5Digest(key);
  if (key.length < blockSize) {
    const padded = new Uint8Array(blockSize);
    padded.set(key);
    key = padded;
  }

  const inner = new Uint8Array(blockSize + messageBytes.length);
  const outerPrefix = new Uint8Array(blockSize);
  for (let index = 0; index < blockSize; index += 1) {
    const value = key[index] ?? 0;
    inner[index] = value ^ 0x36;
    outerPrefix[index] = value ^ 0x5c;
  }
  inner.set(messageBytes, blockSize);

  const outer = new Uint8Array(blockSize + 16);
  outer.set(outerPrefix);
  outer.set(md5Digest(inner), blockSize);
  return bytesToHex(md5Digest(outer));
}

function subtleHashName(algorithm: string): string | null {
  switch (algorithm) {
    case "SHA-1":
    case "SHA-256":
    case "SHA-384":
    case "SHA-512":
      return algorithm;
    default:
      return null;
  }
}

export function isHMACAlgorithm(algorithm: string): boolean {
  return algorithm.startsWith("HMAC-");
}

export function hmacHashName(algorithm: string): string | null {
  if (!isHMACAlgorithm(algorithm)) return null;
  return algorithm.slice("HMAC-".length);
}

export async function hashText(
  text: unknown,
  algorithm = "SHA-256",
  hmacKey: unknown = "",
): Promise<string> {
  const message = bytesFromText(text);
  if (algorithm === "MD5") return md5ToHex(message);

  if (isHMACAlgorithm(algorithm)) {
    const hashName = hmacHashName(algorithm);
    const key = bytesFromText(hmacKey);
    if (hashName === "MD5") return hmacMD5(key, message);
    const subtleHash = hashName ? subtleHashName(hashName) : null;
    if (!subtleHash) throw new Error("unsupported");
    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      key as BufferSource,
      { name: "HMAC", hash: subtleHash },
      false,
      ["sign"],
    );
    const signature = await crypto.subtle.sign("HMAC", cryptoKey, message as BufferSource);
    return bytesToHex(new Uint8Array(signature));
  }

  const subtleHash = subtleHashName(algorithm);
  if (!subtleHash) throw new Error("unsupported");
  const digest = await crypto.subtle.digest(subtleHash, message as BufferSource);
  return bytesToHex(new Uint8Array(digest));
}

/** MD5 hex forms commonly shown by Chinese hash utilities. */
export type MD5Variants = {
  lower32: string;
  upper32: string;
  lower16: string;
  upper16: string;
};

export function md5VariantsFromHex(hex: string): MD5Variants {
  const lower32 = String(hex || "").toLowerCase();
  const upper32 = lower32.toUpperCase();
  return {
    lower32,
    upper32,
    lower16: lower32.slice(0, 16),
    upper16: upper32.slice(0, 16),
  };
}

export type HexCaseVariants = {
  lower: string;
  upper: string;
};

export function hexCaseVariants(hex: string): HexCaseVariants {
  const lower = String(hex || "").toLowerCase();
  return { lower, upper: lower.toUpperCase() };
}

export async function hashMD5Variants(text: unknown): Promise<MD5Variants> {
  return md5VariantsFromHex(await hashText(text, "MD5"));
}

export const hashAlgorithmGroups = Object.freeze([
  { id: "digest" as const, items: Object.freeze(["MD5"] as const) },
  {
    id: "sha" as const,
    items: Object.freeze(["SHA-1", "SHA-256", "SHA-384", "SHA-512"] as const),
  },
  {
    id: "hmac" as const,
    items: Object.freeze([
      "HMAC-MD5",
      "HMAC-SHA-1",
      "HMAC-SHA-256",
      "HMAC-SHA-384",
      "HMAC-SHA-512",
    ] as const),
  },
]);

export const hashAlgorithms = Object.freeze(
  hashAlgorithmGroups.flatMap((group) => [...group.items]),
);

export function convertCodec({
  tab,
  direction,
  input,
  urlMode = "component",
  base64URL = false,
  algorithm = "MD5",
  hmacKey = "",
  fromRadix = 10,
  toRadix = 16,
}: ConvertCodecParams): Promise<ConvertCodecResult> {
  const value = String(input ?? "");

  if (tab === "hash") {
    return hashText(value, algorithm, hmacKey)
      .then((hash) => ({ ok: true, value: hash, error: null }))
      .catch(() => ({ ok: false, value: "", error: "unsupported" }));
  }

  if (tab === "radix") {
    const result = convertRadix(value, fromRadix, toRadix);
    return Promise.resolve({
      ok: result.ok,
      value: result.value,
      error: result.ok ? null : result.error,
    });
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

  if (tab === "base16" || tab === "hex") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase16(value), error: null });
    }
    const result = decodeBase16(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base36") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase36(value), error: null });
    }
    const result = decodeBase36(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base58") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase58(value), error: null });
    }
    const result = decodeBase58(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base62") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase62(value), error: null });
    }
    const result = decodeBase62(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "base85") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBase85(value), error: null });
    }
    const result = decodeBase85(value);
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

  if (tab === "utf-8") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeUTF8Bytes(value), error: null });
    }
    const result = decodeUTF8Bytes(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "ascii") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeASCII(value), error: null });
    }
    const result = decodeASCII(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "native") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeNative(value), error: null });
    }
    const result = decodeNative(value);
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

  if (tab === "binary") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeBinary(value), error: null });
    }
    const result = decodeBinary(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "decimal") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeDecimal(value), error: null });
    }
    const result = decodeDecimal(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "punycode") {
    if (direction === "encode") {
      try {
        return Promise.resolve({ ok: true, value: encodePunycode(value), error: null });
      } catch {
        return Promise.resolve({ ok: false, value: "", error: "invalid-punycode" });
      }
    }
    const result = decodePunycode(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "json") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeJsonString(value), error: null });
    }
    const result = decodeJsonString(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "quoted-printable") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeQuotedPrintable(value), error: null });
    }
    const result = decodeQuotedPrintable(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "rot13") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeRot13(value), error: null });
    }
    const result = decodeRot13(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: null });
  }

  if (tab === "data-uri") {
    if (direction === "encode") {
      return Promise.resolve({ ok: true, value: encodeDataURI(value), error: null });
    }
    const result = decodeDataURI(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  if (tab === "gbk") {
    if (direction === "encode") {
      try {
        return Promise.resolve({ ok: true, value: encodeGbk(value), error: null });
      } catch {
        return Promise.resolve({ ok: false, value: "", error: "invalid-gbk" });
      }
    }
    const result = decodeGbk(value);
    return Promise.resolve({ ok: result.ok, value: result.value, error: result.ok ? null : result.error });
  }

  return Promise.resolve({ ok: false, value: "", error: "unsupported" });
}
