export const maxColorInput = 200;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function round(value, digits = 0) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function channelToHex(value) {
  return clamp(Math.round(value), 0, 255).toString(16).padStart(2, "0");
}

export function rgbToHex({ r, g, b, a = 1 }) {
  const hex = `#${channelToHex(r)}${channelToHex(g)}${channelToHex(b)}`;
  if (a >= 1) return hex.toUpperCase();
  return `${hex}${channelToHex(a * 255)}`.toUpperCase();
}

export function rgbToHsl({ r, g, b }) {
  const rn = r / 255;
  const gn = g / 255;
  const bn = b / 255;
  const max = Math.max(rn, gn, bn);
  const min = Math.min(rn, gn, bn);
  const delta = max - min;
  let h = 0;
  if (delta !== 0) {
    if (max === rn) h = ((gn - bn) / delta) % 6;
    else if (max === gn) h = (bn - rn) / delta + 2;
    else h = (rn - gn) / delta + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  const l = (max + min) / 2;
  const s = delta === 0 ? 0 : delta / (1 - Math.abs(2 * l - 1));
  return { h: round(h, 1), s: round(s * 100, 1), l: round(l * 100, 1) };
}

export function rgbToHsv({ r, g, b }) {
  const rn = r / 255;
  const gn = g / 255;
  const bn = b / 255;
  const max = Math.max(rn, gn, bn);
  const min = Math.min(rn, gn, bn);
  const delta = max - min;
  let h = 0;
  if (delta !== 0) {
    if (max === rn) h = ((gn - bn) / delta) % 6;
    else if (max === gn) h = (bn - rn) / delta + 2;
    else h = (rn - gn) / delta + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  const s = max === 0 ? 0 : delta / max;
  return { h: round(h, 1), s: round(s * 100, 1), v: round(max * 100, 1) };
}

export function hslToRgb({ h, s, l }) {
  const sat = clamp(s, 0, 100) / 100;
  const light = clamp(l, 0, 100) / 100;
  const hue = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * light - 1)) * sat;
  const x = c * (1 - Math.abs(((hue / 60) % 2) - 1));
  const m = light - c / 2;
  let rp = 0;
  let gp = 0;
  let bp = 0;
  if (hue < 60) [rp, gp, bp] = [c, x, 0];
  else if (hue < 120) [rp, gp, bp] = [x, c, 0];
  else if (hue < 180) [rp, gp, bp] = [0, c, x];
  else if (hue < 240) [rp, gp, bp] = [0, x, c];
  else if (hue < 300) [rp, gp, bp] = [x, 0, c];
  else [rp, gp, bp] = [c, 0, x];
  return {
    r: Math.round((rp + m) * 255),
    g: Math.round((gp + m) * 255),
    b: Math.round((bp + m) * 255),
  };
}

function relativeLuminance({ r, g, b }) {
  const toLinear = (channel) => {
    const value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  };
  const R = toLinear(r);
  const G = toLinear(g);
  const B = toLinear(b);
  return 0.2126 * R + 0.7152 * G + 0.0722 * B;
}

export function contrastRatio(left, right) {
  const l1 = relativeLuminance(left);
  const l2 = relativeLuminance(right);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return round((lighter + 0.05) / (darker + 0.05), 2);
}

function parseHex(raw) {
  const value = raw.replace(/^#/, "").trim();
  if (![3, 4, 6, 8].includes(value.length) || !/^[0-9a-fA-F]+$/.test(value)) {
    return null;
  }
  const expand = (chunk) => chunk.split("").map((ch) => ch + ch).join("");
  const full = value.length <= 4 ? expand(value) : value;
  const r = Number.parseInt(full.slice(0, 2), 16);
  const g = Number.parseInt(full.slice(2, 4), 16);
  const b = Number.parseInt(full.slice(4, 6), 16);
  const a = full.length === 8 ? Number.parseInt(full.slice(6, 8), 16) / 255 : 1;
  return { r, g, b, a: round(a, 3) };
}

function parseRgb(raw) {
  const match = raw.match(
    /^rgba?\(\s*([+-]?\d*\.?\d+%?)\s*[,\s]\s*([+-]?\d*\.?\d+%?)\s*[,\s]\s*([+-]?\d*\.?\d+%?)(?:\s*[,/]\s*([+-]?\d*\.?\d+%?))?\s*\)$/i,
  );
  if (!match) return null;
  const toByte = (token) => {
    if (token.endsWith("%")) return clamp((Number.parseFloat(token) / 100) * 255, 0, 255);
    return clamp(Number.parseFloat(token), 0, 255);
  };
  const toAlpha = (token) => {
    if (token == null) return 1;
    if (token.endsWith("%")) return clamp(Number.parseFloat(token) / 100, 0, 1);
    return clamp(Number.parseFloat(token), 0, 1);
  };
  return {
    r: Math.round(toByte(match[1])),
    g: Math.round(toByte(match[2])),
    b: Math.round(toByte(match[3])),
    a: round(toAlpha(match[4]), 3),
  };
}

function parseHsl(raw) {
  const match = raw.match(
    /^hsla?\(\s*([+-]?\d*\.?\d+)(?:deg)?\s*[,\s]\s*([+-]?\d*\.?\d+)%\s*[,\s]\s*([+-]?\d*\.?\d+)%(?:\s*[,/]\s*([+-]?\d*\.?\d+%?))?\s*\)$/i,
  );
  if (!match) return null;
  const toAlpha = (token) => {
    if (token == null) return 1;
    if (token.endsWith("%")) return clamp(Number.parseFloat(token) / 100, 0, 1);
    return clamp(Number.parseFloat(token), 0, 1);
  };
  const rgb = hslToRgb({
    h: Number.parseFloat(match[1]),
    s: Number.parseFloat(match[2]),
    l: Number.parseFloat(match[3]),
  });
  return { ...rgb, a: round(toAlpha(match[4]), 3) };
}

export function parseColor(input) {
  const raw = String(input ?? "").trim();
  if (!raw) return { ok: false, error: "empty" };
  if (raw.length > maxColorInput) return { ok: false, error: "too-large" };

  let rgb = null;
  if (raw.startsWith("#") || /^[0-9a-fA-F]{3,8}$/.test(raw)) {
    rgb = parseHex(raw.startsWith("#") ? raw : `#${raw}`);
  } else if (/^rgba?\(/i.test(raw)) {
    rgb = parseRgb(raw);
  } else if (/^hsla?\(/i.test(raw)) {
    rgb = parseHsl(raw);
  }

  if (!rgb) return { ok: false, error: "invalid" };

  const hsl = rgbToHsl(rgb);
  const hsv = rgbToHsv(rgb);
  const hex = rgbToHex(rgb);
  const alpha = rgb.a ?? 1;
  const rgbCss =
    alpha < 1
      ? `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`
      : `rgb(${rgb.r}, ${rgb.g}, ${rgb.b})`;
  const hslCss =
    alpha < 1
      ? `hsla(${hsl.h}, ${hsl.s}%, ${hsl.l}%, ${alpha})`
      : `hsl(${hsl.h}, ${hsl.s}%, ${hsl.l}%)`;
  const hsvCss = `hsv(${hsv.h}, ${hsv.s}%, ${hsv.v}%)`;

  return {
    ok: true,
    rgb,
    hsl,
    hsv,
    hex,
    formats: {
      hex,
      rgb: rgbCss,
      hsl: hslCss,
      hsv: hsvCss,
    },
    contrast: {
      onWhite: contrastRatio(rgb, { r: 255, g: 255, b: 255 }),
      onBlack: contrastRatio(rgb, { r: 0, g: 0, b: 0 }),
    },
  };
}

export function colorFromChannels({ r, g, b, a = 1 }) {
  return parseColor(rgbToHex({ r, g, b, a }));
}
