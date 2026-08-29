import assert from "node:assert/strict";
import { test } from "node:test";
import { contrastRatio, hsvToRgb, parseColor, rgbToHex, rgbToHsl, rgbToHsv } from "./color.js";

test("parses hex and expands short form", () => {
  const result = parseColor("#0af");
  assert.equal(result.ok, true);
  assert.equal(result.hex, "#00AAFF");
  assert.deepEqual(result.rgb, { r: 0, g: 170, b: 255, a: 1 });
});

test("parses rgb and hsl strings", () => {
  assert.equal(parseColor("rgb(255, 0, 128)").hex, "#FF0080");
  const hsl = parseColor("hsl(210, 50%, 40%)");
  assert.equal(hsl.ok, true);
  assert.equal(hsl.formats.hsl.startsWith("hsl(210"), true);
});

test("converts rgb to hsl and hex", () => {
  assert.deepEqual(rgbToHsl({ r: 255, g: 0, b: 0 }), { h: 0, s: 100, l: 50 });
  assert.equal(rgbToHex({ r: 16, g: 32, b: 48 }), "#102030");
});

test("round-trips hsv conversions", () => {
  const source = { r: 10, g: 132, b: 255 };
  const hsv = rgbToHsv(source);
  const rgb = hsvToRgb(hsv);
  assert.equal(Math.abs(rgb.r - source.r) <= 1, true);
  assert.equal(Math.abs(rgb.g - source.g) <= 1, true);
  assert.equal(Math.abs(rgb.b - source.b) <= 1, true);
  assert.equal(rgbToHex(hsvToRgb({ h: 0, s: 100, v: 100 })), "#FF0000");
});

test("computes contrast ratios", () => {
  assert.equal(contrastRatio({ r: 0, g: 0, b: 0 }, { r: 255, g: 255, b: 255 }), 21);
  assert.ok(parseColor("#777777").contrast.onWhite >= 4);
});

test("rejects invalid colors", () => {
  assert.equal(parseColor("").error, "empty");
  assert.equal(parseColor("not-a-color").error, "invalid");
});
