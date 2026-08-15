import assert from "node:assert/strict";
import { test } from "node:test";
import { generateQRDataURL, normalizePayload } from "./qr.js";

test("normalizes payload limits", () => {
  assert.equal(normalizePayload("").error, "empty");
  assert.equal(normalizePayload("   ").error, "empty");
  assert.equal(normalizePayload("a".repeat(2001)).error, "too-large");
  assert.equal(normalizePayload("hello").ok, true);
});

test("generates a data URL for valid text", async () => {
  const result = await generateQRDataURL("https://machkit.app", { size: 128, errorLevel: "M" });
  assert.equal(result.ok, true);
  assert.match(result.dataURL, /^data:image\/png;base64,/);
  assert.equal(result.width, 128);
});
