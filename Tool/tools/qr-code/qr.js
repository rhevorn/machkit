import QRCode from "qrcode";

export const maxPayload = 2_000;
export const sizes = Object.freeze([128, 192, 256, 320, 512]);
export const errorLevels = Object.freeze(["L", "M", "Q", "H"]);

export function normalizePayload(input) {
  const text = String(input ?? "");
  if (!text.trim()) return { ok: false, error: "empty" };
  if (text.length > maxPayload) return { ok: false, error: "too-large" };
  return { ok: true, text };
}

export async function generateQRDataURL(input, options = {}) {
  const payload = normalizePayload(input);
  if (!payload.ok) return payload;

  const width = sizes.includes(options.size) ? options.size : 256;
  const errorCorrectionLevel = errorLevels.includes(options.errorLevel)
    ? options.errorLevel
    : "M";
  const margin = Number.isFinite(options.margin) ? Math.max(0, Math.min(8, options.margin)) : 2;
  const dark = typeof options.dark === "string" && options.dark ? options.dark : "#000000";
  const light = typeof options.light === "string" && options.light ? options.light : "#ffffff";

  try {
    const dataURL = await QRCode.toDataURL(payload.text, {
      errorCorrectionLevel,
      margin,
      width,
      color: { dark, light },
    });
    return {
      ok: true,
      dataURL,
      width,
      errorCorrectionLevel,
      bytes: payload.text.length,
    };
  } catch (error) {
    return { ok: false, error: error?.message || "encode-failed" };
  }
}
