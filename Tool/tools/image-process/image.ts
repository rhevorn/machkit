export const maxBatchCount = 50;
export const maxInputBytes = 40 * 1024 * 1024;
export const formats = Object.freeze(["keep", "jpeg", "png", "webp"] as const);
export const modes = Object.freeze(["quality", "size", "dimensions"] as const);
export const dimensionUnits = Object.freeze(["px", "%", "cm", "mm", "in"] as const);
export const defaultQuality = 0.8;
export const defaultTargetKB = 200;
export const defaultDpi = 96;

export type ImageFormatOption = (typeof formats)[number];
export type ImageMode = (typeof modes)[number];
export type DimensionUnit = (typeof dimensionUnits)[number];
export type OutputFormat = "jpeg" | "png" | "webp";

const MIME = {
  jpeg: "image/jpeg",
  jpg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  gif: "image/gif",
  bmp: "image/bmp",
} as const;

export type DimensionOptions = {
  maxEdge?: number;
  width?: number;
  height?: number;
  unit?: DimensionUnit | string;
  dpi?: number;
  lockAspect?: boolean;
};

export type ProcessImageOptions = {
  format?: ImageFormatOption | string;
  mode?: ImageMode | string;
  quality?: number;
  targetBytes?: number;
  width?: number;
  height?: number;
  unit?: DimensionUnit | string;
  maxEdge?: number;
  lockAspect?: boolean;
  dpi?: number;
};

export type ProcessImageSuccess = {
  ok: true;
  error: null;
  blob: Blob;
  name: string;
  mime: string;
  format: OutputFormat;
  width: number;
  height: number;
  inputBytes: number;
  outputBytes: number;
  scaled: boolean;
  quality: number | null;
  mode: ImageMode;
  metTarget?: boolean;
};

export type ProcessImageFailure = {
  ok: false;
  error: string;
};

export type ProcessImageResult = ProcessImageSuccess | ProcessImageFailure;

export type EncodeTargetSuccess = {
  ok: true;
  blob: Blob;
  quality: number;
  width: number;
  height: number;
  format: OutputFormat;
  metTarget: boolean;
  error?: undefined;
};

export type EncodeTargetFailure = {
  ok: false;
  error: string;
};

export type EncodeTargetResult = EncodeTargetSuccess | EncodeTargetFailure;

function isDimensionUnit(value: string): value is DimensionUnit {
  return (dimensionUnits as readonly string[]).includes(value);
}

function isImageMode(value: string): value is ImageMode {
  return (modes as readonly string[]).includes(value);
}

function isOutputFormat(value: string): value is OutputFormat {
  return value === "jpeg" || value === "png" || value === "webp";
}

export function clampQuality(value: unknown): number {
  const n = Number(value);
  if (!Number.isFinite(n)) return defaultQuality;
  return Math.min(1, Math.max(0.05, Math.round(n * 100) / 100));
}

export function clampDimension(value: unknown): number {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.min(8192, Math.round(n));
}

/** Convert a dimension amount into pixels. `%` uses referencePx (source side). */
export function toPixels(
  amount: unknown,
  unit: DimensionUnit | string = "px",
  referencePx = 0,
  dpi = defaultDpi,
): number {
  const n = Number(amount);
  if (!Number.isFinite(n) || n <= 0) return 0;
  const safeDpi = Number.isFinite(dpi) && dpi > 0 ? dpi : defaultDpi;
  switch (unit) {
    case "%":
      return Math.max(1, Math.round(referencePx * (n / 100)));
    case "cm":
      return Math.max(1, Math.round((n / 2.54) * safeDpi));
    case "mm":
      return Math.max(1, Math.round((n / 25.4) * safeDpi));
    case "in":
      return Math.max(1, Math.round(n * safeDpi));
    default:
      return Math.max(1, Math.round(n));
  }
}

export function clampTargetBytes(value: unknown): number {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.min(maxInputBytes, Math.round(n));
}

/** Parse UI target size into bytes. unit: KB | MB */
export function parseTargetSize(
  amount: unknown,
  unit: "KB" | "MB" | string = "KB",
): { ok: true; error: null; bytes: number } | { ok: false; error: string; bytes: number } {
  const n = Number(amount);
  if (!Number.isFinite(n) || n <= 0) return { ok: false, error: "invalid-target", bytes: 0 };
  const factor = unit === "MB" ? 1024 * 1024 : 1024;
  const bytes = clampTargetBytes(n * factor);
  if (!bytes) return { ok: false, error: "invalid-target", bytes: 0 };
  return { ok: true, error: null, bytes };
}

export function detectFormatFromMime(mime: unknown): OutputFormat | null {
  const value = String(mime || "").toLowerCase();
  if (value.includes("jpeg") || value.includes("jpg")) return "jpeg";
  if (value.includes("png")) return "png";
  if (value.includes("webp")) return "webp";
  return null;
}

export function detectFormatFromName(name: unknown): OutputFormat | null {
  const ext = String(name || "").split(".").pop()?.toLowerCase();
  if (ext === "jpg" || ext === "jpeg") return "jpeg";
  if (ext === "png") return "png";
  if (ext === "webp") return "webp";
  return null;
}

export function resolveOutputFormat(
  inputFormat: OutputFormat | null | undefined,
  requested: unknown,
): OutputFormat {
  const value = String(requested || "");
  if (value && value !== "keep" && isOutputFormat(value)) return value;
  return inputFormat || "jpeg";
}

export function outputExtension(format: OutputFormat | string): string {
  if (format === "jpeg") return "jpg";
  return format;
}

export function outputFileName(originalName: unknown, format: OutputFormat | string): string {
  const base = String(originalName || "image").replace(/\.[^.]+$/, "") || "image";
  const safe = base.replace(/[^\w.\-()\u4e00-\u9fff]+/g, "_");
  return `${safe}.${outputExtension(format)}`;
}

/** @deprecated Prefer resolveDimensions */
export function fitWithin(width: number, height: number, maxEdge: number) {
  return resolveDimensions(width, height, { maxEdge });
}

/**
 * Resolve output pixel size.
 * - maxEdge: longest side limit
 * - width / height: explicit amounts in `unit` (px | % | cm | mm | in)
 * - both width+height with lockAspect: fit inside box (contain)
 * - both without lockAspect: exact size (may distort)
 */
export function resolveDimensions(
  srcWidth: number,
  srcHeight: number,
  options: DimensionOptions = {},
): { width: number; height: number; scaled: boolean } {
  const srcW = Math.max(1, Math.round(srcWidth));
  const srcH = Math.max(1, Math.round(srcHeight));
  const maxEdge = clampDimension(options.maxEdge);
  const unitValue = String(options.unit || "px");
  const unit = isDimensionUnit(unitValue) ? unitValue : "px";
  const dpi = options.dpi || defaultDpi;
  const rawW = Number(options.width);
  const rawH = Number(options.height);
  const wantW = rawW > 0 ? clampDimension(toPixels(rawW, unit, srcW, dpi)) : 0;
  const wantH = rawH > 0 ? clampDimension(toPixels(rawH, unit, srcH, dpi)) : 0;
  const lockAspect = options.lockAspect !== false;

  if (!maxEdge && !wantW && !wantH) {
    return { width: srcW, height: srcH, scaled: false };
  }

  if (maxEdge && !wantW && !wantH) {
    if (srcW <= maxEdge && srcH <= maxEdge) {
      return { width: srcW, height: srcH, scaled: false };
    }
    const scale = maxEdge / Math.max(srcW, srcH);
    return {
      width: Math.max(1, Math.round(srcW * scale)),
      height: Math.max(1, Math.round(srcH * scale)),
      scaled: true,
    };
  }

  if (wantW && wantH) {
    if (!lockAspect) {
      return { width: wantW, height: wantH, scaled: wantW !== srcW || wantH !== srcH };
    }
    const scale = Math.min(wantW / srcW, wantH / srcH);
    return {
      width: Math.max(1, Math.round(srcW * scale)),
      height: Math.max(1, Math.round(srcH * scale)),
      scaled: scale !== 1,
    };
  }

  if (wantW) {
    const scale = wantW / srcW;
    return {
      width: wantW,
      height: lockAspect ? Math.max(1, Math.round(srcH * scale)) : srcH,
      scaled: true,
    };
  }

  const scale = wantH / srcH;
  return {
    width: lockAspect ? Math.max(1, Math.round(srcW * scale)) : srcW,
    height: wantH,
    scaled: true,
  };
}

export function formatBytes(bytes: unknown): string {
  const n = Number(bytes);
  if (!Number.isFinite(n) || n < 0) return "—";
  if (n < 1024) return `${Math.round(n)} B`;
  if (n < 1024 ** 2) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 ** 3) return `${(n / 1024 ** 2).toFixed(2)} MB`;
  return `${(n / 1024 ** 3).toFixed(2)} GB`;
}

export function ratioLabel(before: unknown, after: unknown): string {
  const from = Number(before);
  const to = Number(after);
  if (!Number.isFinite(from) || !Number.isFinite(to) || from <= 0) return "—";
  const ratio = to / from;
  const percent = Math.round((1 - ratio) * 100);
  if (percent > 0) return `−${percent}%`;
  if (percent < 0) return `+${Math.abs(percent)}%`;
  return "0%";
}

function loadImageElement(file: Blob): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("decode-failed"));
    };
    image.src = url;
  });
}

function canvasToBlob(
  canvas: HTMLCanvasElement,
  mime: string,
  quality?: number,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) reject(new Error("encode-failed"));
        else resolve(blob);
      },
      mime,
      quality,
    );
  });
}

function drawToCanvas(
  image: CanvasImageSource,
  width: number,
  height: number,
  format: OutputFormat,
): HTMLCanvasElement | null {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { alpha: format !== "jpeg" });
  if (!ctx) return null;
  if (format === "jpeg") {
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, width, height);
  }
  ctx.drawImage(image, 0, 0, width, height);
  return canvas;
}

async function encodeCanvas(
  canvas: HTMLCanvasElement,
  format: OutputFormat,
  quality?: number,
): Promise<Blob> {
  const mime = MIME[format] || "image/jpeg";
  const blob = await canvasToBlob(canvas, mime, format === "png" ? undefined : quality);
  return blob;
}

type EncodeCandidate = {
  blob: Blob;
  quality: number;
  width: number;
  height: number;
  format: OutputFormat;
};

/**
 * Binary-search quality (and optionally scale down) to meet a target byte size.
 * Lossy formats only; PNG falls back to WebP for size targeting.
 */
export async function encodeToTargetSize(
  image: CanvasImageSource,
  baseWidth: number,
  baseHeight: number,
  format: OutputFormat,
  targetBytes: number,
): Promise<EncodeTargetResult> {
  let outputFormat: OutputFormat = format === "png" ? "webp" : format;
  if (outputFormat !== "jpeg" && outputFormat !== "webp") outputFormat = "jpeg";

  let width = baseWidth;
  let height = baseHeight;
  let best: EncodeCandidate | null = null;

  for (let scalePass = 0; scalePass < 8; scalePass += 1) {
    const canvas = drawToCanvas(image, width, height, outputFormat);
    if (!canvas) return { ok: false, error: "encode-failed" };

    let low = 0.05;
    let high = 1;
    let passBest: EncodeCandidate | null = null;

    for (let i = 0; i < 8; i += 1) {
      const mid = (low + high) / 2;
      const blob = await encodeCanvas(canvas, outputFormat, mid);
      const candidate: EncodeCandidate = { blob, quality: mid, width, height, format: outputFormat };
      if (!passBest || Math.abs(blob.size - targetBytes) < Math.abs(passBest.blob.size - targetBytes)) {
        passBest = candidate;
      }
      if (blob.size > targetBytes) high = mid;
      else low = mid;
    }

    best = passBest;
    if (passBest && passBest.blob.size <= targetBytes) break;

    // Still too large at lowest quality — shrink dimensions and retry.
    width = Math.max(1, Math.round(width * 0.85));
    height = Math.max(1, Math.round(height * 0.85));
    if (width < 32 && height < 32) break;
  }

  if (!best) return { ok: false, error: "encode-failed" };
  return {
    ok: true,
    ...best,
    metTarget: best.blob.size <= targetBytes,
  };
}

/**
 * Process a single image File or Blob in the browser.
 */
export async function processImage(
  file: Blob & { name?: string; type?: string },
  options: ProcessImageOptions = {},
): Promise<ProcessImageResult> {
  if (!file) return { ok: false, error: "empty" };
  if (file.size > maxInputBytes) return { ok: false, error: "too-large" };

  const modeValue = String(options.mode || "quality");
  const mode = isImageMode(modeValue) ? modeValue : "quality";
  const inputFormat =
    detectFormatFromMime(file.type) || detectFormatFromName(file.name) || "jpeg";
  let format = resolveOutputFormat(inputFormat, options.format || "keep");

  try {
    const image = await loadImageElement(file);
    const srcW = image.naturalWidth || image.width;
    const srcH = image.naturalHeight || image.height;

    const fitted = resolveDimensions(srcW, srcH, {
      width: options.width,
      height: options.height,
      unit: options.unit,
      maxEdge: options.maxEdge,
      lockAspect: options.lockAspect,
      dpi: options.dpi,
    });

    if (mode === "size") {
      const targetBytes = clampTargetBytes(options.targetBytes);
      if (!targetBytes) return { ok: false, error: "invalid-target" };

      const encoded = await encodeToTargetSize(
        image,
        fitted.width,
        fitted.height,
        format,
        targetBytes,
      );
      if (!encoded.ok) return encoded;

      format = encoded.format;
      const name = outputFileName(file.name || "image", format);
      return {
        ok: true,
        error: null,
        blob: encoded.blob,
        name,
        mime: MIME[format],
        format,
        width: encoded.width,
        height: encoded.height,
        inputBytes: file.size,
        outputBytes: encoded.blob.size,
        scaled: encoded.width !== srcW || encoded.height !== srcH,
        quality: encoded.quality,
        metTarget: encoded.metTarget,
        mode,
      };
    }

    const quality = clampQuality(options.quality ?? defaultQuality);
    const canvas = drawToCanvas(image, fitted.width, fitted.height, format);
    if (!canvas) return { ok: false, error: "encode-failed" };
    const blob = await encodeCanvas(canvas, format, quality);
    const name = outputFileName(file.name || "image", format);

    return {
      ok: true,
      error: null,
      blob,
      name,
      mime: MIME[format] || "image/jpeg",
      format,
      width: fitted.width,
      height: fitted.height,
      inputBytes: file.size,
      outputBytes: blob.size,
      scaled: fitted.scaled,
      quality: format === "png" ? null : quality,
      mode,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "decode-failed";
    return { ok: false, error: message || "decode-failed" };
  }
}

export const compressImage = processImage;

export function validateBatch(files: ArrayLike<unknown> | null | undefined): {
  ok: boolean;
  error: string | null;
  files: unknown[];
} {
  const list = Array.from(files || []);
  if (!list.length) return { ok: false, error: "empty", files: [] };
  if (list.length > maxBatchCount) return { ok: false, error: "too-many", files: [] };
  return { ok: true, error: null, files: list };
}
