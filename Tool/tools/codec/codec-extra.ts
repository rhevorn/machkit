import { toASCII, toUnicode } from "punycode/punycode.es6.js";

export type CodecOk = { ok: true; value: string; error?: null };
export type CodecErr = { ok: false; value: string; error: string };
export type CodecResult = CodecOk | CodecErr;

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder("utf-8", { fatal: true });

function bytesFromText(text: unknown): Uint8Array {
  return textEncoder.encode(String(text ?? ""));
}

function textFromBytes(bytes: BufferSource): string {
  return textDecoder.decode(bytes);
}

function encodeBase64(text: unknown): string {
  const bytes = bytesFromText(text);
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary);
}

let gbkEncoderMap: Map<number, number> | null = null;

function getGbkEncoderMap(): Map<number, number> {
  if (gbkEncoderMap) return gbkEncoderMap;
  const decoder = new TextDecoder("gbk");
  const map = new Map<number, number>();
  for (let byte = 0; byte < 0x80; byte += 1) map.set(byte, byte);
  for (let lead = 0x81; lead <= 0xfe; lead += 1) {
    for (let trail = 0x40; trail <= 0xfe; trail += 1) {
      if (trail === 0x7f) continue;
      const text = decoder.decode(Uint8Array.of(lead, trail));
      if (text.length !== 1 || text === "\uFFFD") continue;
      const codePoint = text.codePointAt(0);
      if (codePoint === undefined || map.has(codePoint)) continue;
      map.set(codePoint, (lead << 8) | trail);
    }
  }
  gbkEncoderMap = map;
  return map;
}

function bytesToHexLower(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function hexToBytes(raw: string): { ok: true; bytes: Uint8Array } | { ok: false; error: string } {
  const value = raw.replace(/\s+/g, "").replace(/^0x/i, "");
  if (!value) return { ok: true, bytes: new Uint8Array() };
  if (!/^[0-9a-fA-F]*$/.test(value) || value.length % 2 !== 0) {
    return { ok: false, error: "invalid-hex" };
  }
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return { ok: true, bytes };
}

export function encodeBinary(text: unknown): string {
  return Array.from(bytesFromText(text), (byte) => byte.toString(2).padStart(8, "0")).join(" ");
}

export function decodeBinary(raw: unknown): CodecResult {
  const bits = String(raw ?? "").replace(/[^01]/g, "");
  if (!bits) return { ok: true, value: "" };
  if (bits.length % 8 !== 0) return { ok: false, value: "", error: "invalid-binary" };
  const bytes = new Uint8Array(bits.length / 8);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(bits.slice(index * 8, index * 8 + 8), 2);
  }
  try {
    return { ok: true, value: textFromBytes(bytes) };
  } catch {
    return { ok: false, value: "", error: "invalid-binary" };
  }
}

export function encodeDecimal(text: unknown): string {
  return Array.from(bytesFromText(text), (byte) => String(byte)).join(" ");
}

export function decodeDecimal(raw: unknown): CodecResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: true, value: "" };
  const parts = value.split(/[\s,;|]+/).filter(Boolean);
  const bytes = new Uint8Array(parts.length);
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index]!;
    if (!/^\d+$/.test(part)) return { ok: false, value: "", error: "invalid-decimal" };
    const number = Number.parseInt(part, 10);
    if (number > 255) return { ok: false, value: "", error: "invalid-decimal" };
    bytes[index] = number;
  }
  try {
    return { ok: true, value: textFromBytes(bytes) };
  } catch {
    return { ok: false, value: "", error: "invalid-decimal" };
  }
}

export function encodePunycode(text: unknown): string {
  const value = String(text ?? "").trim();
  if (!value) return "";
  try {
    if (value.includes("://")) {
      const url = new URL(value);
      url.hostname = toASCII(url.hostname);
      return url.toString();
    }
    return toASCII(value);
  } catch {
    return toASCII(value);
  }
}

export function decodePunycode(raw: unknown): CodecResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: true, value: "" };
  try {
    if (value.includes("://")) {
      const url = new URL(value);
      url.hostname = toUnicode(url.hostname);
      return { ok: true, value: url.toString() };
    }
    return { ok: true, value: toUnicode(value) };
  } catch {
    return { ok: false, value: "", error: "invalid-punycode" };
  }
}

export function encodeJsonString(text: unknown): string {
  return JSON.stringify(String(text ?? "")).slice(1, -1);
}

export function decodeJsonString(raw: unknown): CodecResult {
  const value = String(raw ?? "");
  if (!value) return { ok: true, value: "" };
  try {
    const parsed = JSON.parse(`"${value}"`);
    if (typeof parsed !== "string") return { ok: false, value: "", error: "invalid-json-escape" };
    return { ok: true, value: parsed };
  } catch {
    return { ok: false, value: "", error: "invalid-json-escape" };
  }
}

function toQuotedPrintableByte(byte: number): string {
  return `=${byte.toString(16).toUpperCase().padStart(2, "0")}`;
}

export function encodeQuotedPrintable(text: unknown): string {
  const bytes = bytesFromText(text);
  const lines: string[] = [];
  let line = "";

  const pushSoftBreak = () => {
    lines.push(`${line}=`);
    line = "";
  };

  for (let index = 0; index < bytes.length; index += 1) {
    const byte = bytes[index]!;
    const isLiteral =
      byte === 0x09 || (byte >= 0x20 && byte <= 0x7e && byte !== 0x3d);
    let chunk = isLiteral ? String.fromCharCode(byte) : toQuotedPrintableByte(byte);
    if (byte === 0x20 || byte === 0x09) {
      const atEnd = index === bytes.length - 1;
      if (atEnd) chunk = toQuotedPrintableByte(byte);
    }
    if (line.length + chunk.length > 75) pushSoftBreak();
    line += chunk;
  }
  if (line) lines.push(line);
  return lines.join("\r\n");
}

export function decodeQuotedPrintable(raw: unknown): CodecResult {
  const normalized = String(raw ?? "")
    .replace(/=\r?\n/g, "")
    .replace(/\r\n/g, "\n");
  if (!normalized) return { ok: true, value: "" };
  const bytes: number[] = [];
  for (let index = 0; index < normalized.length; ) {
    const char = normalized[index]!;
    if (char === "=") {
      const hex = normalized.slice(index + 1, index + 3);
      if (!/^[0-9a-fA-F]{2}$/.test(hex)) return { ok: false, value: "", error: "invalid-quoted-printable" };
      bytes.push(Number.parseInt(hex, 16));
      index += 3;
      continue;
    }
    bytes.push(char.charCodeAt(0));
    index += 1;
  }
  try {
    return { ok: true, value: textFromBytes(Uint8Array.from(bytes)) };
  } catch {
    return { ok: false, value: "", error: "invalid-quoted-printable" };
  }
}

export function encodeRot13(text: unknown): string {
  return String(text ?? "").replace(/[A-Za-z]/g, (char) => {
    const base = char <= "Z" ? 65 : 97;
    return String.fromCharCode(base + ((char.charCodeAt(0) - base + 13) % 26));
  });
}

export function decodeRot13(raw: unknown): CodecResult {
  return { ok: true, value: encodeRot13(raw) };
}

export function encodeDataURI(text: unknown, mime = "text/plain;charset=utf-8"): string {
  const media = String(mime || "text/plain;charset=utf-8").trim() || "text/plain;charset=utf-8";
  return `data:${media};base64,${encodeBase64(text)}`;
}

const RADIX_DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

function normalizeRadix(value: unknown): number | null {
  const radix = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(radix) || radix < 2 || radix > 36) return null;
  return radix;
}

/** Convert an integer string between radices 2–36 (BigInt; optional 0x/0b/0o prefixes). */
export function convertRadix(input: unknown, fromRadix: unknown, toRadix: unknown): CodecResult {
  const from = normalizeRadix(fromRadix);
  const to = normalizeRadix(toRadix);
  if (from === null || to === null) return { ok: false, value: "", error: "invalid-radix" };

  let text = String(input ?? "").trim().replace(/[\s_]/g, "");
  if (!text) return { ok: true, value: "" };

  if (from === 16 && /^[+-]?0x/i.test(text)) text = text.replace(/0x/i, "");
  else if (from === 2 && /^[+-]?0b/i.test(text)) text = text.replace(/0b/i, "");
  else if (from === 8 && /^[+-]?0o/i.test(text)) text = text.replace(/0o/i, "");

  const negative = text.startsWith("-");
  if (text.startsWith("+") || text.startsWith("-")) text = text.slice(1);
  if (!text) return { ok: false, value: "", error: "invalid-radix" };

  const alphabet = RADIX_DIGITS.slice(0, from);
  const upper = text.toUpperCase();
  for (const char of upper) {
    if (!alphabet.includes(char)) return { ok: false, value: "", error: "invalid-radix" };
  }

  try {
    let value = 0n;
    const base = BigInt(from);
    for (const char of upper) {
      value = value * base + BigInt(RADIX_DIGITS.indexOf(char));
    }
    if (value === 0n) return { ok: true, value: "0" };

    let out = "";
    const toBase = BigInt(to);
    let remaining = value;
    while (remaining > 0n) {
      out = RADIX_DIGITS[Number(remaining % toBase)] + out;
      remaining /= toBase;
    }
    return { ok: true, value: `${negative ? "-" : ""}${out}` };
  } catch {
    return { ok: false, value: "", error: "invalid-radix" };
  }
}

export type DataURIInfo = {
  ok: true;
  mime: string;
  isBase64: boolean;
  isImage: boolean;
  isText: boolean;
  dataURL: string;
  dataBase64: string;
  text: string | null;
  byteLength: number;
  extension: string;
  suggestedName: string;
};

export type DataURIInspectResult = DataURIInfo | { ok: false; error: string };

function extensionForMime(mime: string): string {
  const type = mime.split(";")[0]?.trim().toLowerCase() || "application/octet-stream";
  if (type === "image/png") return "png";
  if (type === "image/jpeg" || type === "image/jpg") return "jpg";
  if (type === "image/gif") return "gif";
  if (type === "image/webp") return "webp";
  if (type === "image/svg+xml") return "svg";
  if (type === "image/bmp") return "bmp";
  if (type === "image/x-icon" || type === "image/vnd.microsoft.icon") return "ico";
  if (type === "text/plain") return "txt";
  if (type === "text/html") return "html";
  if (type === "text/css") return "css";
  if (type === "application/json") return "json";
  if (type === "application/pdf") return "pdf";
  return "bin";
}

function bytesFromBase64(raw: string): Uint8Array | null {
  const value = String(raw ?? "").replace(/\s+/g, "");
  if (!value) return new Uint8Array();
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value) || value.length % 4 !== 0) return null;
  try {
    const binary = atob(value);
    return Uint8Array.from(binary, (char) => char.charCodeAt(0));
  } catch {
    return null;
  }
}

export function inspectDataURI(raw: unknown): DataURIInspectResult {
  const value = String(raw ?? "").trim();
  if (!value) return { ok: false, error: "invalid-data-uri" };
  const match = /^data:([^,]*?),([\s\S]*)$/i.exec(value);
  if (!match) return { ok: false, error: "invalid-data-uri" };
  const meta = match[1] ?? "";
  const data = match[2] ?? "";
  const isBase64 = /;base64/i.test(meta);
  const mime = (meta.replace(/;base64/i, "").trim() || "text/plain").toLowerCase();
  const mediaType = mime.split(";")[0]?.trim() || "text/plain";
  const isImage = mediaType.startsWith("image/");
  const isText =
    mediaType.startsWith("text/") ||
    mediaType === "application/json" ||
    mediaType === "application/xml" ||
    mediaType === "image/svg+xml";

  let bytes: Uint8Array;
  let dataBase64: string;
  let text: string | null = null;

  if (isBase64) {
    const decoded = bytesFromBase64(data);
    if (!decoded) return { ok: false, error: "invalid-data-uri" };
    bytes = decoded;
    dataBase64 = data.replace(/\s+/g, "");
    if (isText) {
      try {
        text = textDecoder.decode(bytes);
      } catch {
        text = null;
      }
    }
  } else {
    try {
      text = decodeURIComponent(data.replace(/\+/g, " "));
      bytes = textEncoder.encode(text);
      dataBase64 = encodeBase64(text);
    } catch {
      return { ok: false, error: "invalid-data-uri" };
    }
  }

  const extension = extensionForMime(mime);
  const dataURL = isBase64
    ? `data:${mime};base64,${dataBase64}`
    : `data:${mime};base64,${dataBase64}`;

  return {
    ok: true,
    mime,
    isBase64,
    isImage,
    isText,
    dataURL,
    dataBase64,
    text,
    byteLength: bytes.length,
    extension,
    suggestedName: `data-uri.${extension}`,
  };
}

export function decodeDataURI(raw: unknown): CodecResult {
  const inspected = inspectDataURI(raw);
  if (!inspected.ok) return { ok: false, value: "", error: inspected.error };
  if (inspected.text !== null) return { ok: true, value: inspected.text };
  // Binary payloads are previewed/saved via inspectDataURI; keep output text empty.
  return { ok: true, value: "" };
}

export function encodeGbk(text: unknown): string {
  const map = getGbkEncoderMap();
  const bytes: number[] = [];
  for (const char of String(text ?? "")) {
    const codePoint = char.codePointAt(0);
    if (codePoint === undefined) continue;
    const encoded = map.get(codePoint);
    if (encoded === undefined) {
      throw new Error("invalid-gbk");
    }
    if (encoded <= 0xff) bytes.push(encoded);
    else {
      bytes.push(encoded >> 8);
      bytes.push(encoded & 0xff);
    }
  }
  return bytesToHexLower(Uint8Array.from(bytes));
}

export function decodeGbk(raw: unknown): CodecResult {
  const parsed = hexToBytes(String(raw ?? ""));
  if (!parsed.ok) return { ok: false, value: "", error: parsed.error };
  if (parsed.bytes.length === 0) return { ok: true, value: "" };
  try {
    const text = new TextDecoder("gbk", { fatal: true }).decode(parsed.bytes);
    return { ok: true, value: text };
  } catch {
    return { ok: false, value: "", error: "invalid-gbk" };
  }
}
