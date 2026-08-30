export const maxJwtLength = 20_000;
export const signAlgorithms = Object.freeze(["HS256", "HS384", "HS512", "none"]);

const HASH_NAMES = {
  HS256: "SHA-256",
  HS384: "SHA-384",
  HS512: "SHA-512",
};

function base64UrlToBytes(segment: any) {
  const normalized = String(segment ?? "").replace(/-/g, "+").replace(/_/g, "/");
  const pad = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const encoded = normalized + pad;
  if (typeof atob === "function") {
    const binary = atob(encoded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }
  return Uint8Array.from(Buffer.from(encoded, "base64"));
}

function bytesToBase64Url(bytes: any) {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
  const base64 =
    typeof btoa === "function"
      ? btoa(binary)
      : Buffer.from(bytes).toString("base64");
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function encodeJsonSegment(value: any) {
  const json = JSON.stringify(value);
  return bytesToBase64Url(new TextEncoder().encode(json));
}

function decodeSegment(segment: any) {
  const text = new TextDecoder().decode(base64UrlToBytes(segment));
  return JSON.parse(text);
}

function asFiniteNumber(value: any) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && /^-?\d+(\.\d+)?$/.test(value)) {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export function formatUnixSeconds(seconds: any, now: number = Date.now()) {
  const n = asFiniteNumber(seconds);
  if (n === null) return null;
  const ms = n > 1e12 ? n : n * 1000;
  const date = new Date(ms);
  if (Number.isNaN(date.getTime())) return null;
  const delta = ms - now;
  return {
    iso: date.toISOString(),
    local: date.toLocaleString(),
    deltaMs: delta,
    expired: delta < 0,
  };
}

export function parseJsonObject(input: any, field: any = "json") {
  const raw = String(input ?? "").trim();
  if (!raw) return { ok: false as const, error: "empty", field, value: null };
  try {
    const value = JSON.parse(raw);
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return { ok: false as const, error: "invalid-object", field, value: null };
    }
    return { ok: true as const, error: null, field, value };
  } catch {
    return { ok: false as const, error: "invalid-json", field, value: null };
  }
}

export function defaultGeneratePayload(now = Date.now()) {
  const iat = Math.floor(now / 1000);
  return {
    sub: "machkit",
    name: "MachKit",
    iat,
    exp: iat + 60 * 60 * 24 * 30,
  };
}

async function hmacSign(algorithm: string, secret: unknown, data: string) {
  const hashName = (HASH_NAMES as Record<string, string>)[algorithm];
  if (!hashName) throw new Error("unsupported-alg");
  const keyBytes = new TextEncoder().encode(String(secret ?? ""));
  const dataBytes = new TextEncoder().encode(data);

  const subtle = globalThis.crypto?.subtle;
  if (!subtle) throw new Error("crypto-unavailable");
  const key = await subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: hashName },
    false,
    ["sign"],
  );
  const signature = await subtle.sign("HMAC", key, dataBytes);
  return bytesToBase64Url(new Uint8Array(signature));
}

export async function createJwt({ headerText, payloadText, secret = "", algorithm = "HS256" }: { headerText?: string; payloadText?: string; secret?: string; algorithm?: string } = {}) {
  const alg = signAlgorithms.includes(algorithm) ? algorithm : "HS256";
  const headerParsed = parseJsonObject(headerText, "header");
  if (!headerParsed.ok) return headerParsed;
  const payloadParsed = parseJsonObject(payloadText, "payload");
  if (!payloadParsed.ok) return payloadParsed;

  const header = { ...headerParsed.value, alg, typ: headerParsed.value.typ || "JWT" };
  const payload = payloadParsed.value;
  const encodedHeader = encodeJsonSegment(header);
  const encodedPayload = encodeJsonSegment(payload);
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  let signature = "";
  if (alg === "none") {
    signature = "";
  } else {
    if (!String(secret ?? "").length) return { ok: false as const, error: "missing-secret" };
    try {
      signature = await hmacSign(alg, secret, signingInput);
    } catch (error) {
      return { ok: false as const, error: error instanceof Error ? error.message : "sign-failed" };
    }
  }

  const token = `${signingInput}.${signature}`;
  if (token.length > maxJwtLength) return { ok: false as const, error: "too-large" };

  return {
    ok: true as const,
    error: null,
    token,
    header,
    payload,
    algorithm: alg,
    headerJson: JSON.stringify(header, null, 2),
    payloadJson: JSON.stringify(payload, null, 2),
  };
}

export function inspectJwt(input: any, now = Date.now()) {
  const token = String(input ?? "").trim();
  if (!token) return { ok: false as const, error: "empty" };
  if (token.length > maxJwtLength) return { ok: false as const, error: "too-large" };

  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part, index) => index < 2 && !part)) {
    return { ok: false as const, error: "invalid-format" };
  }
  // alg=none may have empty signature segment after trailing dot — still 3 parts with last empty
  if (parts.length !== 3) return { ok: false as const, error: "invalid-format" };
  if (!parts[0] || !parts[1]) return { ok: false as const, error: "invalid-format" };

  let header;
  let payload;
  try {
    header = decodeSegment(parts[0]);
    payload = decodeSegment(parts[1]);
  } catch {
    return { ok: false as const, error: "invalid-json" };
  }

  if (!header || typeof header !== "object" || Array.isArray(header)) {
    return { ok: false as const, error: "invalid-header" };
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false as const, error: "invalid-payload" };
  }

  const exp = formatUnixSeconds(payload.exp, now);
  const iat = formatUnixSeconds(payload.iat, now);
  const nbf = formatUnixSeconds(payload.nbf, now);

  let status = "ok";
  if (exp?.expired) status = "expired";
  else if (nbf && nbf.deltaMs > 0) status = "not-before";

  return {
    ok: true as const,
    error: null,
    token,
    parts: {
      header: parts[0],
      payload: parts[1],
      signature: parts[2] || "",
    },
    header,
    payload,
    headerJson: JSON.stringify(header, null, 2),
    payloadJson: JSON.stringify(payload, null, 2),
    algorithm: typeof header.alg === "string" ? header.alg : "",
    typ: typeof header.typ === "string" ? header.typ : "",
    exp,
    iat,
    nbf,
    status,
    verified: false,
  };
}
