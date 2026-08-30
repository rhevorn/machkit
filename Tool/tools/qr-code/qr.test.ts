import assert from "node:assert/strict";
import { test } from "node:test";
import {
  clampLogoRatio,
  defaultSize,
  generateQRDataURL,
  maxSize,
  minSize,
  normalizeHexColor,
  normalizePayload,
  qrStyles,
  resolveDotShape,
  resolveMargin,
  resolveSize,
} from "./qr.js";

test("normalizes payload limits", () => {
  assert.equal(normalizePayload("").error, "empty");
  assert.equal(normalizePayload("   ").error, "empty");
  assert.equal(normalizePayload("a".repeat(2001)).error, "too-large");
  assert.equal(normalizePayload("hello").ok, true);
});

test("exposes style presets with shapes", () => {
  assert.equal(qrStyles.length, 4);
  assert.deepEqual(
    qrStyles.map((style) => style.id),
    ["classic", "rounded", "dots", "inverted"],
  );
  assert.ok(qrStyles.every((style) => style.dotShape && style.eyeShape));
});

test("resolves size, margin, shape, and color helpers", () => {
  assert.equal(defaultSize, 256);
  assert.equal(resolveSize(128), 128);
  assert.equal(resolveSize("256"), 256);
  assert.equal(resolveSize(32), minSize);
  assert.equal(resolveSize(9999), maxSize);
  assert.equal(resolveSize("abc"), defaultSize);
  assert.equal(resolveMargin(3), 3);
  assert.equal(resolveMargin(99), 4);
  assert.equal(resolveDotShape("circle"), "circle");
  assert.equal(resolveDotShape("star"), "square");
  assert.equal(normalizeHexColor("#ABC", "#000000"), "#000000");
  assert.equal(normalizeHexColor("#AaBbCc", "#000000"), "#aabbcc");
  assert.equal(clampLogoRatio(0.5), 0.28);
  assert.equal(clampLogoRatio(0.05), 0.12);
  assert.equal(clampLogoRatio(Number.NaN), 0.22);
});

test("generates a data URL for valid text", async () => {
  const result = await generateQRDataURL("https://machkit.app", { size: 128, errorLevel: "M" });
  assert.equal(result.ok, true);
  assert.match(String(result.dataURL), /^data:image\/png;base64,/);
  assert.equal(result.width, 128);
  assert.equal(typeof result.version, "number");
});

test("forces high error correction when a logo is requested", async () => {
  const result = await generateQRDataURL("https://machkit.app", {
    size: 160,
    errorLevel: "L",
    logoDataURL: "data:image/png;base64,invalid",
  });
  // Node has no canvas for overlay — either encode-only with H, or logo-failed.
  if (result.ok) {
    assert.equal(result.errorCorrectionLevel, "H");
    assert.equal(result.logoApplied, false);
  } else {
    assert.equal(result.error, "logo-failed");
  }
});
