import QRCode from "qrcode";

export const maxPayload = 2_000;
export const minSize = 64;
export const maxSize = 1024;
export const errorLevels = Object.freeze(["L", "M", "Q", "H"]);
export const defaultSize = 256;
export const defaultLogoRatio = 0.22;
export const maxLogoRatio = 0.28;
export const defaultMargin = 2;
export const margins = Object.freeze([0, 1, 2, 3, 4]);
export const dotShapes = Object.freeze(["square", "rounded", "circle"]);
export const eyeShapes = Object.freeze(["square", "rounded", "circle"]);

/** Approx recoverable damage; matches common QR UI labels. */
export const errorLevelPercents = Object.freeze({
  L: "7%",
  M: "15%",
  Q: "25%",
  H: "30%",
});

/**
 * Style presets seed colors + module shapes. Users can override afterward.
 */
export const qrStyles = Object.freeze([
  {
    id: "classic",
    dark: "#000000",
    light: "#ffffff",
    dotShape: "square",
    eyeShape: "square",
  },
  {
    id: "rounded",
    dark: "#087fff",
    light: "#ffffff",
    dotShape: "rounded",
    eyeShape: "rounded",
  },
  {
    id: "dots",
    dark: "#1d1d1f",
    light: "#ffffff",
    dotShape: "circle",
    eyeShape: "rounded",
  },
  {
    id: "inverted",
    dark: "#f5f5f7",
    light: "#1d1d1f",
    dotShape: "square",
    eyeShape: "square",
  },
]);

export function normalizePayload(input) {
  const text = String(input ?? "");
  if (!text.trim()) return { ok: false, error: "empty" };
  if (text.length > maxPayload) return { ok: false, error: "too-large" };
  return { ok: true, text };
}

export function resolveSize(value) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n)) return defaultSize;
  return Math.min(maxSize, Math.max(minSize, n));
}

export function resolveMargin(value) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n)) return defaultMargin;
  return Math.min(4, Math.max(0, n));
}

export function resolveDotShape(value) {
  return dotShapes.includes(value) ? value : "square";
}

export function resolveEyeShape(value) {
  return eyeShapes.includes(value) ? value : "square";
}

export function clampLogoRatio(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return defaultLogoRatio;
  return Math.min(maxLogoRatio, Math.max(0.12, Math.round(n * 100) / 100));
}

export function normalizeHexColor(value, fallback) {
  const raw = String(value ?? "").trim();
  if (/^#[0-9a-fA-F]{6}$/.test(raw)) return raw.toLowerCase();
  if (/^[0-9a-fA-F]{6}$/.test(raw)) return `#${raw.toLowerCase()}`;
  return fallback;
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("logo-failed"));
    image.src = src;
  });
}

function fillRoundRect(ctx, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + width, y, x + width, y + height, r);
  ctx.arcTo(x + width, y + height, x, y + height, r);
  ctx.arcTo(x, y + height, x, y, r);
  ctx.arcTo(x, y, x + width, y, r);
  ctx.closePath();
  ctx.fill();
}

function logoDrawSize(logo, maxSide) {
  const naturalW = Math.max(1, logo.naturalWidth || logo.width || 1);
  const naturalH = Math.max(1, logo.naturalHeight || logo.height || 1);
  const scale = Math.min(maxSide / naturalW, maxSide / naturalH);
  return {
    width: Math.max(1, Math.round(naturalW * scale)),
    height: Math.max(1, Math.round(naturalH * scale)),
  };
}

function isFinderCell(row, col, moduleCount) {
  const inTopLeft = row < 7 && col < 7;
  const inTopRight = row < 7 && col >= moduleCount - 7;
  const inBottomLeft = row >= moduleCount - 7 && col < 7;
  return inTopLeft || inTopRight || inBottomLeft;
}

function finderOrigins(moduleCount) {
  return [
    [0, 0],
    [0, moduleCount - 7],
    [moduleCount - 7, 0],
  ];
}

function paintModule(ctx, x, y, size, shape, color) {
  ctx.fillStyle = color;
  if (shape === "circle") {
    const radius = size * 0.42;
    const cx = x + size / 2;
    const cy = y + size / 2;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();
    return;
  }
  if (shape === "rounded") {
    fillRoundRect(ctx, x + size * 0.08, y + size * 0.08, size * 0.84, size * 0.84, size * 0.28);
    return;
  }
  ctx.fillRect(x, y, size, size);
}

function paintFinder(ctx, originX, originY, cell, shape, dark, light) {
  const outer = cell * 7;
  const x = originX;
  const y = originY;
  ctx.fillStyle = dark;
  if (shape === "circle") {
    const cx = x + outer / 2;
    const cy = y + outer / 2;
    ctx.beginPath();
    ctx.arc(cx, cy, outer * 0.48, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = light;
    ctx.beginPath();
    ctx.arc(cx, cy, outer * 0.32, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = dark;
    ctx.beginPath();
    ctx.arc(cx, cy, outer * 0.18, 0, Math.PI * 2);
    ctx.fill();
    return;
  }
  if (shape === "rounded") {
    fillRoundRect(ctx, x, y, outer, outer, cell * 1.1);
    ctx.fillStyle = light;
    fillRoundRect(ctx, x + cell, y + cell, cell * 5, cell * 5, cell * 0.9);
    ctx.fillStyle = dark;
    fillRoundRect(ctx, x + cell * 2, y + cell * 2, cell * 3, cell * 3, cell * 0.7);
    return;
  }
  ctx.fillRect(x, y, outer, outer);
  ctx.fillStyle = light;
  ctx.fillRect(x + cell, y + cell, cell * 5, cell * 5);
  ctx.fillStyle = dark;
  ctx.fillRect(x + cell * 2, y + cell * 2, cell * 3, cell * 3);
}

/** Draw a centered logo onto an existing square canvas (browser only). */
export async function drawLogoOnCanvas(canvas, logoDataURL, logoRatio = defaultLogoRatio) {
  if (typeof document === "undefined") {
    return { ok: false, error: "no-canvas" };
  }
  const ctx = canvas.getContext("2d");
  if (!ctx) return { ok: false, error: "encode-failed" };

  const size = canvas.width;
  const ratio = clampLogoRatio(logoRatio);
  const maxLogo = Math.max(24, Math.round(size * ratio));

  try {
    const logo = await loadImage(logoDataURL);
    const { width: drawW, height: drawH } = logoDrawSize(logo, maxLogo);
    const pad = Math.max(3, Math.round(Math.max(drawW, drawH) * 0.14));
    const box = Math.max(drawW, drawH) + pad * 2;
    const x = Math.round((size - box) / 2);
    const y = Math.round((size - box) / 2);
    const logoX = Math.round(x + (box - drawW) / 2);
    const logoY = Math.round(y + (box - drawH) / 2);

    ctx.fillStyle = "#ffffff";
    fillRoundRect(ctx, x, y, box, box, Math.round(pad * 1.2));
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(logo, logoX, logoY, drawW, drawH);

    return { ok: true, error: null, logoSize: Math.max(drawW, drawH) };
  } catch (error) {
    return { ok: false, error: error?.message || "logo-failed" };
  }
}

/**
 * Render QR modules onto a canvas with optional shapes/colors.
 * Returns false when canvas APIs are unavailable (e.g. Node tests).
 */
export function renderQRMatrixToCanvas(canvas, text, options = {}) {
  if (typeof document === "undefined" || !canvas?.getContext) return false;

  let errorCorrectionLevel = errorLevels.includes(options.errorLevel)
    ? options.errorLevel
    : "M";
  if (options.logoDataURL && errorCorrectionLevel !== "H") errorCorrectionLevel = "H";

  const width = resolveSize(options.size);
  const margin = resolveMargin(options.margin);
  const dark = normalizeHexColor(options.dark, "#000000");
  const light = normalizeHexColor(options.light, "#ffffff");
  const eyeDark = normalizeHexColor(options.eyeDark, dark);
  const dotShape = resolveDotShape(options.dotShape);
  const eyeShape = resolveEyeShape(options.eyeShape);

  const qr = QRCode.create(text, { errorCorrectionLevel });
  const modules = qr.modules;
  const moduleCount = modules.size;
  const cell = width / (moduleCount + margin * 2);

  canvas.width = width;
  canvas.height = width;
  const ctx = canvas.getContext("2d");
  if (!ctx) return false;

  ctx.fillStyle = light;
  ctx.fillRect(0, 0, width, width);

  for (let row = 0; row < moduleCount; row += 1) {
    for (let col = 0; col < moduleCount; col += 1) {
      if (!modules.get(row, col)) continue;
      if (isFinderCell(row, col, moduleCount)) continue;
      const x = (col + margin) * cell;
      const y = (row + margin) * cell;
      paintModule(ctx, x, y, cell, dotShape, dark);
    }
  }

  for (const [row, col] of finderOrigins(moduleCount)) {
    const x = (col + margin) * cell;
    const y = (row + margin) * cell;
    paintFinder(ctx, x, y, cell, eyeShape, eyeDark, light);
  }

  return {
    ok: true,
    width,
    errorCorrectionLevel,
    version: qr.version,
    moduleCount,
  };
}

export async function generateQRDataURL(input, options = {}) {
  const payload = normalizePayload(input);
  if (!payload.ok) return payload;

  const width = resolveSize(options.size);
  const hasLogo = Boolean(options.logoDataURL);
  let errorCorrectionLevel = errorLevels.includes(options.errorLevel)
    ? options.errorLevel
    : "M";
  if (hasLogo && errorCorrectionLevel !== "H") errorCorrectionLevel = "H";

  const margin = resolveMargin(options.margin);
  const dark = normalizeHexColor(options.dark, "#000000");
  const light = normalizeHexColor(options.light, "#ffffff");
  const dotShape = resolveDotShape(options.dotShape);
  const eyeShape = resolveEyeShape(options.eyeShape);
  const needsCustomDraw = typeof document !== "undefined";

  try {
    let dataURL;
    let logoApplied = false;
    let version = null;
    let moduleCount = null;

    if (needsCustomDraw) {
      const canvas = document.createElement("canvas");
      const rendered = renderQRMatrixToCanvas(canvas, payload.text, {
        ...options,
        size: width,
        margin,
        dark,
        light,
        errorCorrectionLevel,
        logoDataURL: options.logoDataURL,
      });
      if (!rendered || !rendered.ok) {
        return { ok: false, error: "encode-failed" };
      }
      version = rendered.version;
      moduleCount = rendered.moduleCount;
      errorCorrectionLevel = rendered.errorCorrectionLevel;

      if (hasLogo) {
        const drawn = await drawLogoOnCanvas(canvas, options.logoDataURL, options.logoRatio);
        if (!drawn.ok && drawn.error !== "no-canvas") {
          return { ok: false, error: drawn.error };
        }
        logoApplied = drawn.ok;
      }
      dataURL = canvas.toDataURL("image/png");
    } else {
      // Node tests: library encoder (shapes ignored without canvas).
      dataURL = await QRCode.toDataURL(payload.text, {
        errorCorrectionLevel,
        margin,
        width,
        color: { dark, light },
      });
      const meta = QRCode.create(payload.text, { errorCorrectionLevel });
      version = meta.version;
      moduleCount = meta.modules.size;
    }


    return {
      ok: true,
      dataURL,
      width,
      errorCorrectionLevel,
      bytes: payload.text.length,
      logoApplied,
      version,
      moduleCount,
      margin,
      dark,
      light,
      dotShape,
      eyeShape,
    };
  } catch (error) {
    return { ok: false, error: error?.message || "encode-failed" };
  }
}
