const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const NANO_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
const LOWER = "abcdefghijklmnopqrstuvwxyz";
const UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const DIGITS = "0123456789";
const SYMBOLS = "!@#$%^&*()-_=+[]{};:,.?/";
const AMBIGUOUS = new Set("0OIl1");
const UUID_PATTERN =
  /^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$/i;
const ULID_PATTERN = /^[0-7][0-9A-HJKMNP-TV-Z]{25}$/i;
const OBJECT_ID_PATTERN = /^[0-9a-f]{24}$/i;
const HEX_PATTERN = /^[0-9a-f]+$/i;

export const formats = Object.freeze([
  "uuid-v1",
  "uuid-v3",
  "uuid-v4",
  "uuid-v5",
  "uuid-v6",
  "uuid-v7",
  "ulid",
  "nanoid",
  "hex",
  "password",
]);
export const uuidNamespaces = Object.freeze({
  dns: "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  url: "6ba7b811-9dad-11d1-80b4-00c04fd430c8",
  oid: "6ba7b812-9dad-11d1-80b4-00c04fd430c8",
  x500: "6ba7b814-9dad-11d1-80b4-00c04fd430c8",
});
export const maxBatchCount = 500;
export const defaultNanoLength = 21;
export const defaultHexBytes = 16;
export const defaultPasswordLength = 16;

const UUID_EPOCH_OFFSET_MS = 12_219_292_800_000;
const textEncoder = new TextEncoder();

function randomBytes(size) {
  const bytes = new Uint8Array(size);
  crypto.getRandomValues(bytes);
  return bytes;
}

function pickIndex(max) {
  if (max <= 0) return 0;
  const limit = Math.floor(256 / max) * max;
  const bytes = randomBytes(1);
  if (bytes[0] >= limit) return pickIndex(max);
  return bytes[0] % max;
}

function uuidTimestamp(now = Date.now()) {
  return BigInt(Math.max(0, Math.floor(Number(now))) + UUID_EPOCH_OFFSET_MS) * 10_000n;
}

function setVersionAndVariant(bytes, version) {
  bytes[6] = (bytes[6] & 0x0f) | (version << 4);
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return bytes;
}

function parseUuidBytes(value) {
  const compact = String(value).replace(/-/g, "").toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(compact)) throw new Error("invalid-namespace");
  const bytes = new Uint8Array(16);
  for (let index = 0; index < 16; index += 1) {
    bytes[index] = Number.parseInt(compact.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

function encodeCrockford(bytes) {
  let bits = 0;
  let value = 0;
  let output = "";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += CROCKFORD[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += CROCKFORD[(value << (5 - bits)) & 31];
  return output;
}

function bytesToUuid(bytes) {
  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function md5Bytes(bytes) {
  const rotate = (value, bits) => (value << bits) | (value >>> (32 - bits));
  const add = (left, right) => (left + right) >>> 0;
  const shared = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
  ];
  const shifts = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ];

  const bitLength = BigInt(bytes.length) * 8n;
  const paddedLength = ((bytes.length + 8) >> 6 << 6) + 64;
  const buffer = new Uint8Array(paddedLength);
  buffer.set(bytes);
  buffer[bytes.length] = 0x80;
  const view = new DataView(buffer.buffer);
  view.setUint32(paddedLength - 8, Number(bitLength & 0xffffffffn), true);
  view.setUint32(paddedLength - 4, Number(bitLength >> 32n), true);

  let a0 = 0x67452301;
  let b0 = 0xefcdab89;
  let c0 = 0x98badcfe;
  let d0 = 0x10325476;

  for (let offset = 0; offset < paddedLength; offset += 64) {
    const words = new Uint32Array(16);
    for (let index = 0; index < 16; index += 1) words[index] = view.getUint32(offset + index * 4, true);
    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;
    for (let index = 0; index < 64; index += 1) {
      let f;
      let g;
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
      const next = d;
      d = c;
      c = b;
      b = add(b, rotate(add(add(a, f >>> 0), add(shared[index], words[g])), shifts[index]));
      a = next;
    }
    a0 = add(a0, a);
    b0 = add(b0, b);
    c0 = add(c0, c);
    d0 = add(d0, d);
  }

  const digest = new Uint8Array(16);
  const digestView = new DataView(digest.buffer);
  digestView.setUint32(0, a0, true);
  digestView.setUint32(4, b0, true);
  digestView.setUint32(8, c0, true);
  digestView.setUint32(12, d0, true);
  return digest;
}

async function sha1Bytes(bytes) {
  const digest = await crypto.subtle.digest("SHA-1", bytes);
  return new Uint8Array(digest);
}

export function formatUuid(value, { uppercase = false, hyphens = true } = {}) {
  const compact = String(value).replace(/-/g, "").toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(compact)) return String(value);
  const dashed = `${compact.slice(0, 8)}-${compact.slice(8, 12)}-${compact.slice(12, 16)}-${compact.slice(16, 20)}-${compact.slice(20)}`;
  const formatted = hyphens ? dashed : compact;
  return uppercase ? formatted.toUpperCase() : formatted;
}

export function generateUuidV1(now = Date.now()) {
  const timestamp = uuidTimestamp(now);
  const bytes = randomBytes(16);
  const timeLow = Number(timestamp & 0xffffffffn);
  const timeMid = Number((timestamp >> 32n) & 0xffffn);
  const timeHi = Number((timestamp >> 48n) & 0x0fffn);
  bytes[0] = (timeLow >>> 24) & 0xff;
  bytes[1] = (timeLow >>> 16) & 0xff;
  bytes[2] = (timeLow >>> 8) & 0xff;
  bytes[3] = timeLow & 0xff;
  bytes[4] = (timeMid >>> 8) & 0xff;
  bytes[5] = timeMid & 0xff;
  bytes[6] = ((timeHi >>> 8) & 0x0f) | 0x10;
  bytes[7] = timeHi & 0xff;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  bytes[10] |= 0x01;
  return bytesToUuid(bytes);
}

export function generateUuidV4() {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
  const bytes = randomBytes(16);
  setVersionAndVariant(bytes, 4);
  return bytesToUuid(bytes);
}

export function generateUuidV6(now = Date.now()) {
  const timestamp = uuidTimestamp(now);
  const bytes = randomBytes(16);
  const timeHigh = Number((timestamp >> 28n) & 0xffffffffn);
  const timeMid = Number((timestamp >> 12n) & 0xffffn);
  const timeLow = Number(timestamp & 0x0fffn);
  bytes[0] = (timeHigh >>> 24) & 0xff;
  bytes[1] = (timeHigh >>> 16) & 0xff;
  bytes[2] = (timeHigh >>> 8) & 0xff;
  bytes[3] = timeHigh & 0xff;
  bytes[4] = (timeMid >>> 8) & 0xff;
  bytes[5] = timeMid & 0xff;
  bytes[6] = ((timeLow >>> 8) & 0x0f) | 0x60;
  bytes[7] = timeLow & 0xff;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  bytes[10] |= 0x01;
  return bytesToUuid(bytes);
}

export function generateUuidV7(now = Date.now()) {
  const bytes = randomBytes(16);
  const timestamp = BigInt(Math.max(0, Math.floor(Number(now))));
  bytes[0] = Number((timestamp >> 40n) & 0xffn);
  bytes[1] = Number((timestamp >> 32n) & 0xffn);
  bytes[2] = Number((timestamp >> 24n) & 0xffn);
  bytes[3] = Number((timestamp >> 16n) & 0xffn);
  bytes[4] = Number((timestamp >> 8n) & 0xffn);
  bytes[5] = Number(timestamp & 0xffn);
  setVersionAndVariant(bytes, 7);
  return bytesToUuid(bytes);
}

async function generateNameBasedUuid(version, namespace, name) {
  const namespaceBytes = parseUuidBytes(namespace || uuidNamespaces.dns);
  const nameBytes = textEncoder.encode(String(name ?? ""));
  const payload = new Uint8Array(namespaceBytes.length + nameBytes.length);
  payload.set(namespaceBytes);
  payload.set(nameBytes, namespaceBytes.length);
  const digest = version === 3 ? md5Bytes(payload) : await sha1Bytes(payload);
  const bytes = digest.slice(0, 16);
  setVersionAndVariant(bytes, version);
  return bytesToUuid(bytes);
}

export function generateUuidV3(namespace, name) {
  return generateNameBasedUuid(3, namespace, name);
}

export function generateUuidV5(namespace, name) {
  return generateNameBasedUuid(5, namespace, name);
}

export function generateUlid(now = Date.now()) {
  const timestamp = Math.max(0, Math.floor(Number(now)));
  const timeChars = [];
  let remaining = timestamp;
  for (let index = 0; index < 10; index += 1) {
    timeChars.push(CROCKFORD[remaining % 32]);
    remaining = Math.floor(remaining / 32);
  }
  const randomness = encodeCrockford(randomBytes(10)).slice(0, 16);
  return timeChars.reverse().join("") + randomness;
}

export function generateNanoId(length = defaultNanoLength) {
  const size = Math.min(128, Math.max(1, Math.floor(Number(length)) || defaultNanoLength));
  const bytes = randomBytes(size);
  let output = "";
  for (let index = 0; index < size; index += 1) {
    output += NANO_ALPHABET[bytes[index] % NANO_ALPHABET.length];
  }
  return output;
}

export function generateHex(byteLength = defaultHexBytes, { uppercase = false } = {}) {
  const size = Math.min(64, Math.max(1, Math.floor(Number(byteLength)) || defaultHexBytes));
  const hex = [...randomBytes(size)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return uppercase ? hex.toUpperCase() : hex;
}

function filterAmbiguous(alphabet) {
  return [...alphabet].filter((char) => !AMBIGUOUS.has(char)).join("");
}

export function passwordAlphabet({
  upper = true,
  lower = true,
  digits = true,
  symbols = true,
  excludeAmbiguous = false,
} = {}) {
  const groups = [];
  if (lower) groups.push(excludeAmbiguous ? filterAmbiguous(LOWER) : LOWER);
  if (upper) groups.push(excludeAmbiguous ? filterAmbiguous(UPPER) : UPPER);
  if (digits) groups.push(excludeAmbiguous ? filterAmbiguous(DIGITS) : DIGITS);
  if (symbols) groups.push(SYMBOLS);
  return groups.filter(Boolean);
}

export function generatePassword({
  length = defaultPasswordLength,
  upper = true,
  lower = true,
  digits = true,
  symbols = true,
  excludeAmbiguous = false,
} = {}) {
  const size = Math.min(128, Math.max(4, Math.floor(Number(length)) || defaultPasswordLength));
  const groups = passwordAlphabet({ upper, lower, digits, symbols, excludeAmbiguous });
  if (!groups.length) throw new Error("empty-alphabet");
  const alphabet = groups.join("");
  const chars = [];
  for (const group of groups) {
    chars.push(group[pickIndex(group.length)]);
  }
  while (chars.length < size) {
    chars.push(alphabet[pickIndex(alphabet.length)]);
  }
  for (let index = chars.length - 1; index > 0; index -= 1) {
    const swap = pickIndex(index + 1);
    [chars[index], chars[swap]] = [chars[swap], chars[index]];
  }
  return chars.join("");
}

export async function generateId(format, options = {}) {
  switch (format) {
    case "uuid-v1":
      return formatUuid(generateUuidV1(options.now), options);
    case "uuid-v3":
      return formatUuid(await generateUuidV3(options.namespace, options.name), options);
    case "uuid-v4":
      return formatUuid(generateUuidV4(), options);
    case "uuid-v5":
      return formatUuid(await generateUuidV5(options.namespace, options.name), options);
    case "uuid-v6":
      return formatUuid(generateUuidV6(options.now), options);
    case "uuid-v7":
      return formatUuid(generateUuidV7(options.now), options);
    case "ulid": {
      const value = generateUlid(options.now);
      return options.uppercase ? value : value.toLowerCase();
    }
    case "nanoid":
      return generateNanoId(options.length);
    case "hex":
      return generateHex(options.byteLength, options);
    case "password":
      return generatePassword(options);
    default:
      throw new Error(`unsupported-format:${format}`);
  }
}

export async function generateIds(format, count = 1, options = {}) {
  const size = Math.min(maxBatchCount, Math.max(1, Math.floor(Number(count)) || 1));
  const values = [];
  for (let index = 0; index < size; index += 1) {
    const nameBased = format === "uuid-v3" || format === "uuid-v5";
    const name = nameBased
      ? (size === 1 ? (options.name ?? "") : `${options.name || "item"}-${index + 1}`)
      : options.name;
    values.push(await generateId(format, { ...options, name }));
  }
  return values;
}

function parseUuid(value) {
  if (!UUID_PATTERN.test(value)) return null;
  const compact = value.replace(/-/g, "").toLowerCase();
  const version = Number.parseInt(compact[12], 16);
  const variantNibble = Number.parseInt(compact[16], 16);
  const variant = variantNibble >= 8 && variantNibble <= 11
    ? "RFC 4122"
    : variantNibble >= 12
      ? "Microsoft"
      : "NCS";
  return {
    ok: version >= 1 && version <= 8 && variant === "RFC 4122",
    kind: "uuid",
    version,
    variant,
    normalized: formatUuid(compact, { hyphens: true, uppercase: false }),
  };
}

function parseUlid(value) {
  if (!ULID_PATTERN.test(value)) return null;
  return {
    ok: true,
    kind: "ulid",
    normalized: value.toUpperCase(),
  };
}

function parseObjectId(value) {
  if (!OBJECT_ID_PATTERN.test(value)) return null;
  return {
    ok: true,
    kind: "object-id",
    normalized: value.toLowerCase(),
  };
}

function parseHex(value) {
  if (!HEX_PATTERN.test(value) || value.length < 8 || value.length % 2 !== 0) return null;
  return {
    ok: true,
    kind: "hex",
    normalized: value.toLowerCase(),
  };
}

export function validateId(raw) {
  const value = String(raw ?? "").trim();
  if (!value) {
    return { ok: false, kind: "empty", error: "empty", normalized: "" };
  }

  const uuid = parseUuid(value);
  if (uuid) {
    return uuid.ok
      ? uuid
      : { ...uuid, error: uuid.version < 1 || uuid.version > 8 ? "uuid-version" : "uuid-variant" };
  }

  const ulid = parseUlid(value);
  if (ulid) return ulid;

  const objectId = parseObjectId(value);
  if (objectId) return objectId;

  const hex = parseHex(value);
  if (hex) return hex;

  if (/^[A-Za-z0-9_-]+$/.test(value) && value.length >= 8 && value.length <= 128) {
    return { ok: true, kind: "nanoid-like", normalized: value };
  }

  if (/^[\x21-\x7E]+$/.test(value) && value.length >= 4 && value.length <= 128) {
    return { ok: true, kind: "password-like", normalized: value };
  }

  return { ok: false, kind: "unknown", error: "unrecognized", normalized: value };
}

export function validateIds(text) {
  const lines = String(text ?? "").split(/\r?\n/);
  if (lines.length === 1 && !lines[0].trim()) return [];
  return lines
    .map((line, index) => ({
      line: index + 1,
      input: line,
      result: validateId(line),
    }))
    .filter((entry) => entry.input.trim());
}
