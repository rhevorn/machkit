export const maxNumberInput = 200;

const BYTE_UNITS = [
  { id: "B", factor: 1n },
  { id: "KB", factor: 1000n },
  { id: "MB", factor: 1_000_000n },
  { id: "GB", factor: 1_000_000_000n },
  { id: "TB", factor: 1_000_000_000_000n },
  { id: "KiB", factor: 1024n },
  { id: "MiB", factor: 1024n ** 2n },
  { id: "GiB", factor: 1024n ** 3n },
  { id: "TiB", factor: 1024n ** 4n },
];

export const byteUnits = Object.freeze(BYTE_UNITS.map((unit) => unit.id));

function stripSeparators(text) {
  return String(text ?? "").trim().replace(/[_\s,]/g, "");
}

export function parseInteger(input, base) {
  const raw = stripSeparators(input);
  if (!raw) return { ok: false, error: "empty", value: null };
  if (raw.length > maxNumberInput) return { ok: false, error: "too-large", value: null };

  let text = raw;
  let detected = base;
  if (base === "auto") {
    if (/^0x/i.test(text)) {
      detected = 16;
      text = text.slice(2);
    } else if (/^0b/i.test(text)) {
      detected = 2;
      text = text.slice(2);
    } else if (/^0o/i.test(text)) {
      detected = 8;
      text = text.slice(2);
    } else {
      detected = 10;
    }
  }

  const radix = Number(detected);
  if (![2, 8, 10, 16].includes(radix)) return { ok: false, error: "invalid-base", value: null };

  const pattern =
    radix === 2 ? /^[01]+$/i :
    radix === 8 ? /^[0-7]+$/i :
    radix === 16 ? /^[0-9a-f]+$/i :
    /^-?\d+$/;

  const negative = text.startsWith("-");
  if (negative && radix !== 10) return { ok: false, error: "invalid", value: null };
  const body = negative ? text.slice(1) : text;
  if (!pattern.test(negative ? text : body) && !(negative && /^-?\d+$/.test(text))) {
    return { ok: false, error: "invalid", value: null };
  }
  if (radix !== 10 && !pattern.test(body)) return { ok: false, error: "invalid", value: null };
  if (radix === 10 && !/^-?\d+$/.test(text)) return { ok: false, error: "invalid", value: null };

  try {
    const prefix = radix === 16 ? "0x" : radix === 2 ? "0b" : radix === 8 ? "0o" : "";
    const value = BigInt(radix === 10 ? text : `${prefix}${body}`);
    return { ok: true, error: null, value, base: radix };
  } catch {
    return { ok: false, error: "invalid", value: null };
  }
}

export function formatInteger(value, base) {
  const radix = Number(base);
  if (typeof value !== "bigint") return "";
  if (radix === 10) return value.toString(10);
  const negative = value < 0n;
  const abs = negative ? -value : value;
  const body = abs.toString(radix);
  const prefix = radix === 16 ? "0x" : radix === 2 ? "0b" : radix === 8 ? "0o" : "";
  return `${negative ? "-" : ""}${prefix}${radix === 16 ? body.toUpperCase() : body}`;
}

export function convertBases(input, fromBase = "auto") {
  const parsed = parseInteger(input, fromBase);
  if (!parsed.ok) return { ok: false, error: parsed.error, formats: null };
  return {
    ok: true,
    error: null,
    value: parsed.value,
    formats: {
      bin: formatInteger(parsed.value, 2),
      oct: formatInteger(parsed.value, 8),
      dec: formatInteger(parsed.value, 10),
      hex: formatInteger(parsed.value, 16),
    },
  };
}

export function parseByteAmount(input, unit = "B") {
  const raw = stripSeparators(input);
  if (!raw) return { ok: false, error: "empty", bytes: null };
  if (!/^\d+(\.\d+)?$/.test(raw)) return { ok: false, error: "invalid", bytes: null };
  const meta = BYTE_UNITS.find((item) => item.id === unit);
  if (!meta) return { ok: false, error: "invalid-unit", bytes: null };

  const [whole, fraction = ""] = raw.split(".");
  const wholePart = BigInt(whole || "0") * meta.factor;
  if (!fraction) return { ok: true, error: null, bytes: wholePart };

  // Convert fractional part using integer math against the unit factor.
  const scale = 10n ** BigInt(fraction.length);
  const fracPart = (BigInt(fraction) * meta.factor) / scale;
  return { ok: true, error: null, bytes: wholePart + fracPart };
}

export function formatBytes(bytes) {
  if (typeof bytes !== "bigint" || bytes < 0n) return { ok: false, error: "invalid", formats: null };
  const formats = {};
  for (const unit of BYTE_UNITS) {
    if (unit.factor === 1n) {
      formats[unit.id] = bytes.toString(10);
      continue;
    }
    const whole = bytes / unit.factor;
    const rem = bytes % unit.factor;
    if (rem === 0n) {
      formats[unit.id] = whole.toString(10);
    } else {
      const scaled = Number(bytes) / Number(unit.factor);
      formats[unit.id] = Number.isFinite(scaled) ? String(Number(scaled.toPrecision(8))) : whole.toString(10);
    }
  }
  return { ok: true, error: null, bytes, formats };
}

export function convertBytes(input, unit = "B") {
  const parsed = parseByteAmount(input, unit);
  if (!parsed.ok) return { ok: false, error: parsed.error, formats: null };
  return formatBytes(parsed.bytes);
}
