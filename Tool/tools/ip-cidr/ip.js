/** IPv4 / IPv6 inspection helpers (no DNS lookups). */

export function parseIPv4(input) {
  const text = String(input ?? "").trim();
  const parts = text.split(".");
  if (parts.length !== 4) return null;
  const octets = [];
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part)) return null;
    const value = Number(part);
    if (value > 255) return null;
    octets.push(value);
  }
  const integer =
    ((octets[0] << 24) >>> 0) +
    ((octets[1] << 16) >>> 0) +
    ((octets[2] << 8) >>> 0) +
    (octets[3] >>> 0);
  return { octets, integer };
}

export function formatIPv4(integer) {
  const n = integer >>> 0;
  return `${(n >>> 24) & 255}.${(n >>> 16) & 255}.${(n >>> 8) & 255}.${n & 255}`;
}

function splitZone(text) {
  const idx = text.indexOf("%");
  if (idx === -1) return { head: text, zone: "" };
  return { head: text.slice(0, idx), zone: text.slice(idx + 1) };
}

export function expandIPv6(input) {
  const raw = String(input ?? "").trim().toLowerCase();
  if (!raw || raw.includes(":::")) return null;
  const { head, zone } = splitZone(raw);

  let body = head;
  let mapped = null;
  if (body.includes(".")) {
    const lastColon = body.lastIndexOf(":");
    if (lastColon === -1) return null;
    const v4 = parseIPv4(body.slice(lastColon + 1));
    if (!v4) return null;
    mapped = [
      ((v4.octets[0] << 8) | v4.octets[1]).toString(16),
      ((v4.octets[2] << 8) | v4.octets[3]).toString(16),
    ];
    body = body.slice(0, lastColon);
  }

  const sides = body.split("::");
  if (sides.length > 2) return null;
  const left = sides[0] ? sides[0].split(":").filter(Boolean) : [];
  const right = sides.length === 2 ? (sides[1] ? sides[1].split(":").filter(Boolean) : []) : [];
  const tail = mapped || [];
  const present = left.length + right.length + tail.length;
  const total = 8;

  let groups;
  if (sides.length === 2) {
    const missing = total - present;
    if (missing <= 0) return null;
    groups = [...left, ...Array(missing).fill("0"), ...right, ...tail];
  } else {
    groups = [...left, ...tail];
    if (groups.length !== total) return null;
  }

  if (groups.length !== 8) return null;
  for (const group of groups) {
    if (!/^[0-9a-f]{1,4}$/.test(group)) return null;
  }
  return { groups: groups.map((g) => g.padStart(4, "0")), zone };
}

export function compressIPv6(groups) {
  const normalized = groups.map((g) => g.replace(/^0+(?=\w)/, "") || "0");
  let bestStart = -1;
  let bestLen = 0;
  let start = -1;
  let len = 0;
  for (let i = 0; i <= normalized.length; i += 1) {
    if (i < normalized.length && normalized[i] === "0") {
      if (start === -1) start = i;
      len += 1;
    } else {
      if (len > bestLen) {
        bestStart = start;
        bestLen = len;
      }
      start = -1;
      len = 0;
    }
  }
  if (bestLen < 2) return normalized.join(":");
  const head = normalized.slice(0, bestStart).join(":");
  const tail = normalized.slice(bestStart + bestLen).join(":");
  if (!head && !tail) return "::";
  if (!head) return `::${tail}`;
  if (!tail) return `${head}::`;
  return `${head}::${tail}`;
}

function ipv4Class(octets) {
  const first = octets[0];
  if (first < 128) return "A";
  if (first < 192) return "B";
  if (first < 224) return "C";
  if (first < 240) return "D";
  return "E";
}

function ipv4Kind(octets, integer) {
  if (integer === 0) return "unspecified";
  if (octets[0] === 127) return "loopback";
  if (octets[0] === 10) return "private";
  if (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) return "private";
  if (octets[0] === 192 && octets[1] === 168) return "private";
  if (octets[0] === 169 && octets[1] === 254) return "link-local";
  if (octets[0] >= 224 && octets[0] < 240) return "multicast";
  if (octets[0] >= 240) return "reserved";
  return "public";
}

function ipv6Kind(groups) {
  const joined = groups.join("");
  if (joined === "0".repeat(32)) return "unspecified";
  if (joined === `${"0".repeat(31)}1`) return "loopback";
  const g0 = groups[0];
  if (/^fe[89ab]/.test(g0)) return "link-local";
  if (/^fd|^fc/.test(g0)) return "unique-local";
  if (g0.startsWith("ff")) return "multicast";
  if (groups.slice(0, 5).every((g) => g === "0000") && (groups[5] === "0000" || groups[5] === "ffff")) {
    return groups[5] === "ffff" ? "ipv4-mapped" : "ipv4-compatible";
  }
  return "global";
}

export function inspectIP(input) {
  const text = String(input ?? "").trim();
  if (!text) return { ok: false, error: "empty" };

  const v4 = parseIPv4(text);
  if (v4) {
    return {
      ok: true,
      version: 4,
      address: formatIPv4(v4.integer),
      integer: String(v4.integer >>> 0),
      hex: `0x${v4.integer.toString(16).toUpperCase().padStart(8, "0")}`,
      binary: v4.octets.map((n) => n.toString(2).padStart(8, "0")).join("."),
      reverse: `${[...v4.octets].reverse().join(".")}.in-addr.arpa`,
      class: ipv4Class(v4.octets),
      kind: ipv4Kind(v4.octets, v4.integer),
    };
  }

  const v6 = expandIPv6(text);
  if (!v6) return { ok: false, error: "invalid" };

  const kind = ipv6Kind(v6.groups);
  const result = {
    ok: true,
    version: 6,
    address: compressIPv6(v6.groups),
    expanded: v6.groups.join(":"),
    compressed: compressIPv6(v6.groups),
    reverse: `${[...v6.groups.join("")].reverse().join(".")}.ip6.arpa`,
    kind,
    zone: v6.zone || "",
  };

  if (kind === "ipv4-mapped" || kind === "ipv4-compatible") {
    const hi = Number.parseInt(v6.groups[6], 16);
    const lo = Number.parseInt(v6.groups[7], 16);
    result.mappedIPv4 = `${(hi >> 8) & 255}.${hi & 255}.${(lo >> 8) & 255}.${lo & 255}`;
  }

  return result;
}
