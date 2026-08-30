export const SPECIAL = Object.freeze({
  setuid: 0o4000,
  setgid: 0o2000,
  sticky: 0o1000,
});

export const PERM = Object.freeze({
  r: 4,
  w: 2,
  x: 1,
});

export type PermBit = keyof typeof PERM;
export type SpecialFlag = keyof typeof SPECIAL;
export type Who = "owner" | "group" | "other";

export type ModeBits = {
  owner: { r: boolean; w: boolean; x: boolean };
  group: { r: boolean; w: boolean; x: boolean };
  other: { r: boolean; w: boolean; x: boolean };
  setuid: boolean;
  setgid: boolean;
  sticky: boolean;
};

export type ModeDescription = {
  mode: number;
  octal: string;
  symbolic: string;
  bits: ModeBits;
  chmod: string;
};

export type ParseResult =
  | { ok: true; error: null; mode: number }
  | { ok: false; error: string; mode: null };

export type InspectResult =
  | ({ ok: true; error?: undefined } & ModeDescription)
  | { ok: false; error: string };

export function clampMode(value: unknown): number {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.min(0o7777, Math.trunc(n));
}

export function parseOctal(input: unknown): ParseResult {
  const raw = String(input ?? "").trim().replace(/^0o/i, "");
  if (!raw) return { ok: false as const, error: "empty", mode: null };
  if (!/^[0-7]{3,4}$/.test(raw)) return { ok: false as const, error: "invalid", mode: null };
  return { ok: true as const, error: null, mode: Number.parseInt(raw, 8) };
}

export function parseSymbolic(input: unknown): ParseResult {
  let raw = String(input ?? "").trim();
  if (!raw) return { ok: false as const, error: "empty", mode: null };
  if (/^[bcdlps-]/.test(raw) && raw.length === 10) raw = raw.slice(1);
  const match = raw.match(/^([r-][w-][xsS-])([r-][w-][xsS-])([r-][w-][xtT-])$/);
  if (!match) return { ok: false as const, error: "invalid", mode: null };

  let mode = 0;
  const classes = [match[1], match[2], match[3]] as [string, string, string];
  classes.forEach((chunk, index) => {
    const shift = (2 - index) * 3;
    if (chunk[0] === "r") mode |= PERM.r << shift;
    if (chunk[1] === "w") mode |= PERM.w << shift;
    const exec = chunk[2];
    if (exec === "x" || exec === "s" || exec === "t") mode |= PERM.x << shift;
  });
  if (/s|S/.test(classes[0][2]!)) mode |= SPECIAL.setuid;
  if (/s|S/.test(classes[1][2]!)) mode |= SPECIAL.setgid;
  if (/t|T/.test(classes[2][2]!)) mode |= SPECIAL.sticky;
  return { ok: true as const, error: null, mode };
}

export function formatOctal(mode: unknown): string {
  const value = clampMode(mode);
  return (value & 0o7777).toString(8).padStart(value > 0o777 ? 4 : 3, "0");
}

function execChar(hasExec: boolean, special: boolean, kind: "setuid" | "setgid" | "sticky"): string {
  if (kind === "sticky") {
    if (special && hasExec) return "t";
    if (special) return "T";
    return hasExec ? "x" : "-";
  }
  if (special && hasExec) return "s";
  if (special) return "S";
  return hasExec ? "x" : "-";
}

export function formatSymbolic(mode: unknown): string {
  const value = clampMode(mode);
  const owner = value >> 6;
  const group = value >> 3;
  const other = value;
  const setuid = Boolean(value & SPECIAL.setuid);
  const setgid = Boolean(value & SPECIAL.setgid);
  const sticky = Boolean(value & SPECIAL.sticky);

  const part = (bits: number, special: boolean, kind: "setuid" | "setgid" | "sticky") =>
    `${bits & PERM.r ? "r" : "-"}${bits & PERM.w ? "w" : "-"}${execChar(Boolean(bits & PERM.x), special, kind)}`;

  return `${part(owner, setuid, "setuid")}${part(group, setgid, "setgid")}${part(other, sticky, "sticky")}`;
}

export function describeMode(mode: unknown): ModeDescription {
  const value = clampMode(mode);
  const bits: ModeBits = {
    owner: {
      r: Boolean(value & (PERM.r << 6)),
      w: Boolean(value & (PERM.w << 6)),
      x: Boolean(value & (PERM.x << 6)),
    },
    group: {
      r: Boolean(value & (PERM.r << 3)),
      w: Boolean(value & (PERM.w << 3)),
      x: Boolean(value & (PERM.x << 3)),
    },
    other: {
      r: Boolean(value & PERM.r),
      w: Boolean(value & PERM.w),
      x: Boolean(value & PERM.x),
    },
    setuid: Boolean(value & SPECIAL.setuid),
    setgid: Boolean(value & SPECIAL.setgid),
    sticky: Boolean(value & SPECIAL.sticky),
  };
  return {
    mode: value,
    octal: formatOctal(value),
    symbolic: formatSymbolic(value),
    bits,
    chmod: `chmod ${formatOctal(value)}`,
  };
}

export function toggleBit(mode: unknown, who: Who, perm: PermBit): ModeDescription {
  const value = clampMode(mode);
  const shift = who === "owner" ? 6 : who === "group" ? 3 : 0;
  const mask = (PERM[perm] || 0) << shift;
  return describeMode(value ^ mask);
}

export function toggleSpecial(mode: unknown, flag: SpecialFlag): ModeDescription {
  const value = clampMode(mode);
  const mask = SPECIAL[flag] || 0;
  return describeMode(value ^ mask);
}

export function inspectPermission(input: unknown): InspectResult {
  const raw = String(input ?? "").trim();
  if (!raw) return { ok: false as const, error: "empty" };
  const octal = parseOctal(raw);
  if (octal.ok) return { ok: true as const, ...describeMode(octal.mode) };
  const symbolic = parseSymbolic(raw);
  if (symbolic.ok) return { ok: true as const, ...describeMode(symbolic.mode) };
  return { ok: false as const, error: "invalid" };
}
