const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder("utf-8", { fatal: true });

export type ByteEncoding = "utf8" | "hex" | "base64";
export type CipherPayloadEncoding = "utf8" | "hex" | "base64";

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function decodeHex(raw: string): Uint8Array | null {
  const value = raw.replace(/\s+/g, "");
  if (!value) return new Uint8Array();
  if (value.length % 2 !== 0 || !/^[0-9a-fA-F]+$/.test(value)) return null;
  const out = new Uint8Array(value.length / 2);
  for (let index = 0; index < out.length; index += 1) {
    out[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return out;
}

function decodeBase64(raw: string): Uint8Array | null {
  const value = raw.replace(/\s+/g, "");
  if (!value) return new Uint8Array();
  try {
    const binary = atob(value);
    const out = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) out[index] = binary.charCodeAt(index);
    return out;
  } catch {
    return null;
  }
}

export function decodeBytes(
  raw: string,
  encoding: ByteEncoding,
): { ok: true; bytes: Uint8Array } | { ok: false; error: string } {
  if (encoding === "utf8") return { ok: true, bytes: textEncoder.encode(raw) };
  if (encoding === "hex") {
    const bytes = decodeHex(raw);
    return bytes ? { ok: true, bytes } : { ok: false, error: "invalid-hex" };
  }
  const bytes = decodeBase64(raw);
  return bytes ? { ok: true, bytes } : { ok: false, error: "invalid-base64" };
}

export function encodeBytes(
  bytes: Uint8Array,
  encoding: "hex" | "base64" | "utf8",
): { ok: true; value: string } | { ok: false; error: string } {
  if (encoding === "hex") return { ok: true, value: bytesToHex(bytes) };
  if (encoding === "base64") return { ok: true, value: bytesToBase64(bytes) };
  try {
    return { ok: true, value: textDecoder.decode(bytes) };
  } catch {
    return { ok: false, error: "invalid-utf8" };
  }
}

export function randomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}

export function pkcs7Pad(data: Uint8Array, blockSize: number): Uint8Array {
  const pad = blockSize - (data.length % blockSize || blockSize);
  const out = new Uint8Array(data.length + pad);
  out.set(data);
  out.fill(pad, data.length);
  return out;
}

export function pkcs7Unpad(data: Uint8Array, blockSize: number): Uint8Array | null {
  if (data.length === 0 || data.length % blockSize !== 0) return null;
  const pad = data[data.length - 1]!;
  if (pad < 1 || pad > blockSize) return null;
  for (let index = data.length - pad; index < data.length; index += 1) {
    if (data[index] !== pad) return null;
  }
  return data.slice(0, data.length - pad);
}

export function forgeBytesFromUint8(bytes: Uint8Array): string {
  let out = "";
  for (const byte of bytes) out += String.fromCharCode(byte);
  return out;
}

export function uint8FromForgeBytes(raw: string): Uint8Array {
  const out = new Uint8Array(raw.length);
  for (let index = 0; index < raw.length; index += 1) out[index] = raw.charCodeAt(index) & 0xff;
  return out;
}
