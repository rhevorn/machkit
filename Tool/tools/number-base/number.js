export const maxNumberInput = 200;

const BYTE_UNITS = [
  { id: "B", factor: 1n },
  { id: "KB", factor: 1000n },
  { id: "MB", factor: 1_000_000n },
  { id: "GB", factor: 1_000_000_000n },
  { id: "TB", factor: 1_000_000_000_000n },
  { id: "PB", factor: 1_000_000_000_000_000n },
  { id: "EB", factor: 1_000_000_000_000_000_000n },
  { id: "KiB", factor: 1024n },
  { id: "MiB", factor: 1024n ** 2n },
  { id: "GiB", factor: 1024n ** 3n },
  { id: "TiB", factor: 1024n ** 4n },
  { id: "PiB", factor: 1024n ** 5n },
  { id: "EiB", factor: 1024n ** 6n },
];

/** Linear unit tables: factor converts the unit into the category base. */
const LINEAR = {
  time: Object.freeze([
    { id: "ns", label: "ns", factor: 1e-9 },
    { id: "us", label: "μs", factor: 1e-6 },
    { id: "ms", label: "ms", factor: 1e-3 },
    { id: "s", label: "s", factor: 1 },
    { id: "min", label: "min", factor: 60 },
    { id: "h", label: "h", factor: 3600 },
    { id: "d", label: "d", factor: 86400 },
    { id: "wk", label: "wk", factor: 604800 },
  ]),
  length: Object.freeze([
    { id: "nm", label: "nm", factor: 1e-9 },
    { id: "um", label: "μm", factor: 1e-6 },
    { id: "mm", label: "mm", factor: 1e-3 },
    { id: "cm", label: "cm", factor: 1e-2 },
    { id: "m", label: "m", factor: 1 },
    { id: "km", label: "km", factor: 1e3 },
    { id: "in", label: "in", factor: 0.0254 },
    { id: "ft", label: "ft", factor: 0.3048 },
    { id: "yd", label: "yd", factor: 0.9144 },
    { id: "mi", label: "mi", factor: 1609.344 },
    { id: "nmi", label: "nmi", factor: 1852 },
  ]),
  mass: Object.freeze([
    { id: "ug", label: "μg", factor: 1e-9 },
    { id: "mg", label: "mg", factor: 1e-6 },
    { id: "g", label: "g", factor: 1e-3 },
    { id: "kg", label: "kg", factor: 1 },
    { id: "t", label: "t", factor: 1e3 },
    { id: "oz", label: "oz", factor: 0.028349523125 },
    { id: "lb", label: "lb", factor: 0.45359237 },
  ]),
  angle: Object.freeze([
    { id: "deg", label: "°", factor: 1 },
    { id: "rad", label: "rad", factor: 180 / Math.PI },
    { id: "gon", label: "gon", factor: 0.9 },
    { id: "turn", label: "turn", factor: 360 },
  ]),
  speed: Object.freeze([
    { id: "mps", label: "m/s", factor: 1 },
    { id: "kmh", label: "km/h", factor: 1 / 3.6 },
    { id: "mph", label: "mph", factor: 0.44704 },
    { id: "kn", label: "kn", factor: 0.514444 },
    { id: "fts", label: "ft/s", factor: 0.3048 },
  ]),
  area: Object.freeze([
    { id: "mm2", label: "mm²", factor: 1e-6 },
    { id: "cm2", label: "cm²", factor: 1e-4 },
    { id: "m2", label: "m²", factor: 1 },
    { id: "km2", label: "km²", factor: 1e6 },
    { id: "ha", label: "ha", factor: 1e4 },
    { id: "acre", label: "acre", factor: 4046.8564224 },
    { id: "in2", label: "in²", factor: 0.00064516 },
    { id: "ft2", label: "ft²", factor: 0.09290304 },
  ]),
};

export const TEMPERATURE_UNITS = Object.freeze(["C", "F", "K"]);

export const byteUnits = Object.freeze(BYTE_UNITS.map((unit) => unit.id));

export const unitCategories = Object.freeze([
  "bases",
  "bytes",
  "time",
  "length",
  "mass",
  "temperature",
  "angle",
  "speed",
  "area",
]);

export const defaultUnits = Object.freeze({
  bytes: "MiB",
  time: "ms",
  length: "m",
  mass: "kg",
  temperature: "C",
  angle: "deg",
  speed: "kmh",
  area: "m2",
});

export function unitsForCategory(category) {
  if (category === "bytes") return byteUnits.map((id) => ({ id, label: id }));
  if (category === "temperature") {
    return TEMPERATURE_UNITS.map((id) => ({
      id,
      label: id === "C" ? "°C" : id === "F" ? "°F" : "K",
    }));
  }
  const list = LINEAR[category];
  return list ? list.map((unit) => ({ id: unit.id, label: unit.label })) : [];
}

function stripSeparators(text) {
  return String(text ?? "").trim().replace(/[_\s,]/g, "");
}

export function formatNumber(value) {
  if (!Number.isFinite(value)) return "";
  if (value === 0) return "0";
  const abs = Math.abs(value);
  if (abs >= 1e12 || abs < 1e-6) return Number(value.toPrecision(8)).toString();
  return Number(value.toPrecision(12)).toString();
}

export function parseFloatAmount(input) {
  const raw = stripSeparators(input);
  if (!raw) return { ok: false, error: "empty", value: null };
  if (raw.length > maxNumberInput) return { ok: false, error: "too-large", value: null };
  if (!/^-?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(raw)) return { ok: false, error: "invalid", value: null };
  const value = Number(raw);
  if (!Number.isFinite(value)) return { ok: false, error: "invalid", value: null };
  return { ok: true, error: null, value };
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

export function convertLinear(input, unitId, category) {
  const units = LINEAR[category];
  if (!units) return { ok: false, error: "invalid-unit", formats: null, rows: null };
  const parsed = parseFloatAmount(input);
  if (!parsed.ok) return { ok: false, error: parsed.error, formats: null, rows: null };
  const from = units.find((item) => item.id === unitId);
  if (!from) return { ok: false, error: "invalid-unit", formats: null, rows: null };

  const base = parsed.value * from.factor;
  const formats = {};
  const rows = [];
  for (const unit of units) {
    const text = formatNumber(base / unit.factor);
    formats[unit.id] = text;
    rows.push({ id: unit.id, label: unit.label, value: text });
  }
  return { ok: true, error: null, formats, rows };
}

function toCelsius(value, unit) {
  if (unit === "C") return value;
  if (unit === "F") return ((value - 32) * 5) / 9;
  if (unit === "K") return value - 273.15;
  return NaN;
}

function fromCelsius(celsius, unit) {
  if (unit === "C") return celsius;
  if (unit === "F") return (celsius * 9) / 5 + 32;
  if (unit === "K") return celsius + 273.15;
  return NaN;
}

export function convertTemperature(input, unit = "C") {
  const parsed = parseFloatAmount(input);
  if (!parsed.ok) return { ok: false, error: parsed.error, formats: null, rows: null };
  if (!TEMPERATURE_UNITS.includes(unit)) {
    return { ok: false, error: "invalid-unit", formats: null, rows: null };
  }

  const celsius = toCelsius(parsed.value, unit);
  if (!Number.isFinite(celsius)) return { ok: false, error: "invalid", formats: null, rows: null };

  const formats = {};
  const rows = [];
  for (const id of TEMPERATURE_UNITS) {
    const text = formatNumber(fromCelsius(celsius, id));
    formats[id] = text;
    rows.push({
      id,
      label: id === "C" ? "°C" : id === "F" ? "°F" : "K",
      value: text,
    });
  }
  return { ok: true, error: null, formats, rows };
}

export function convertCategory(category, input, unit) {
  if (category === "bases") return convertBases(input);
  if (category === "bytes") return convertBytes(input, unit);
  if (category === "temperature") return convertTemperature(input, unit);
  if (LINEAR[category]) return convertLinear(input, unit, category);
  return { ok: false, error: "invalid-unit", formats: null };
}
