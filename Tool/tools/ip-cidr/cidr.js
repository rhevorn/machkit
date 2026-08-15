/** IPv4 CIDR helpers. Values are unsigned 32-bit integers. */

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
  return ((octets[0] << 24) >>> 0) + ((octets[1] << 16) >>> 0) + ((octets[2] << 8) >>> 0) + (octets[3] >>> 0);
}

export function formatIPv4(value) {
  const n = value >>> 0;
  return `${(n >>> 24) & 255}.${(n >>> 16) & 255}.${(n >>> 8) & 255}.${n & 255}`;
}

export function parseCIDR(input) {
  const text = String(input ?? "").trim();
  if (!text) return { ok: false, error: "empty" };
  const [ipPart, prefixPart] = text.split("/");
  const address = parseIPv4(ipPart);
  if (address === null) return { ok: false, error: "invalid-ip" };

  let prefix = 32;
  if (prefixPart !== undefined) {
    if (!/^\d{1,2}$/.test(prefixPart)) return { ok: false, error: "invalid-prefix" };
    prefix = Number(prefixPart);
    if (prefix > 32) return { ok: false, error: "invalid-prefix" };
  }

  const mask = prefix === 0 ? 0 : ((0xffffffff << (32 - prefix)) >>> 0);
  const network = (address & mask) >>> 0;
  const broadcast = (network | (~mask >>> 0)) >>> 0;
  const hostCount = prefix >= 31 ? (prefix === 32 ? 1 : 2) : (2 ** (32 - prefix)) - 2;
  const firstHost = prefix >= 31 ? network : (network + 1) >>> 0;
  const lastHost = prefix >= 31 ? broadcast : (broadcast - 1) >>> 0;
  const wildcard = (~mask) >>> 0;

  return {
    ok: true,
    error: null,
    address: formatIPv4(address),
    prefix,
    cidr: `${formatIPv4(network)}/${prefix}`,
    network: formatIPv4(network),
    broadcast: formatIPv4(broadcast),
    netmask: formatIPv4(mask),
    wildcard: formatIPv4(wildcard),
    firstHost: formatIPv4(firstHost),
    lastHost: formatIPv4(lastHost),
    hostCount,
    addressInteger: address,
    networkInteger: network,
    broadcastInteger: broadcast,
  };
}

export function ipInCIDR(ipInput, cidrInput) {
  const ip = parseIPv4(ipInput);
  const cidr = parseCIDR(cidrInput);
  if (ip === null) return { ok: false, error: "invalid-ip", inside: false };
  if (!cidr.ok) return { ok: false, error: cidr.error, inside: false };
  const inside = ip >= cidr.networkInteger && ip <= cidr.broadcastInteger;
  return { ok: true, error: null, inside };
}
