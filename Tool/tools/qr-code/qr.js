import QRCode from "qrcode";

export const maxPayload = 2_000;
export const minSize = 64;
export const maxSize = 1024;
export const errorLevels = Object.freeze(["L", "M", "Q", "H"]);
export const defaultSize = 256;
export const defaultLogoRatio = 0.2;
export const maxLogoRatio = 0.28;

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

export function clampLogoRatio(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return defaultLogoRatio;
  return Math.min(maxLogoRatio, Math.max(0.12, Math.round(n * 100) / 100));
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

/** Draw a centered logo on an existing QR data URL (browser only). */
export async function overlayLogo(qrDataURL, logoDataURL, size, logoRatio = defaultLogoRatio) {
  if (typeof document === "undefined") {
    return { ok: false, error: "no-canvas", dataURL: qrDataURL };
  }
  const ratio = clampLogoRatio(logoRatio);
  try {
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d");
    if (!ctx) return { ok: false, error: "encode-failed", dataURL: qrDataURL };

    const qr = await loadImage(qrDataURL);
    ctx.drawImage(qr, 0, 0, size, size);

    const logo = await loadImage(logoDataURL);
    const logoSize = Math.max(16, Math.round(size * ratio));
    const pad = Math.max(2, Math.round(logoSize * 0.14));
    const box = logoSize + pad * 2;
    const x = (size - box) / 2;
    const y = (size - box) / 2;

    ctx.fillStyle = "#ffffff";
    fillRoundRect(ctx, x, y, box, box, Math.round(pad * 1.2));
    ctx.drawImage(logo, x + pad, y + pad, logoSize, logoSize);

    return { ok: true, error: null, dataURL: canvas.toDataURL("image/png"), logoSize };
  } catch (error) {
    return { ok: false, error: error?.message || "logo-failed", dataURL: qrDataURL };
  }
}

export async function generateQRDataURL(input, options = {}) {
  const payload = normalizePayload(input);
  if (!payload.ok) return payload;

  const width = resolveSize(options.size);
  const hasLogo = Boolean(options.logoDataURL);
  let errorCorrectionLevel = errorLevels.includes(options.errorLevel)
    ? options.errorLevel
    : "M";
  // Logo punches the center — prefer high recovery.
  if (hasLogo && errorCorrectionLevel !== "H") errorCorrectionLevel = "H";

  const margin = Number.isFinite(options.margin) ? Math.max(0, Math.min(8, options.margin)) : 2;
  const dark = typeof options.dark === "string" && options.dark ? options.dark : "#000000";
  const light = typeof options.light === "string" && options.light ? options.light : "#ffffff";

  try {
    let dataURL = await QRCode.toDataURL(payload.text, {
      errorCorrectionLevel,
      margin,
      width,
      color: { dark, light },
    });

    let logoApplied = false;
    if (hasLogo) {
      const overlay = await overlayLogo(dataURL, options.logoDataURL, width, options.logoRatio);
      if (overlay.ok) {
        dataURL = overlay.dataURL;
        logoApplied = true;
      } else if (overlay.error && overlay.error !== "no-canvas") {
        return { ok: false, error: overlay.error };
      }
    }

    return {
      ok: true,
      dataURL,
      width,
      errorCorrectionLevel,
      bytes: payload.text.length,
      logoApplied,
    };
  } catch (error) {
    return { ok: false, error: error?.message || "encode-failed" };
  }
}
