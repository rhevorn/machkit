import assert from "node:assert/strict";
import { test } from "node:test";
import {
  compositeOver,
  contrastRatio,
  hsvToRgb,
  parseColor,
  rgbToHex,
  rgbToHsl,
  rgbToHsv,
} from "./color.js";

test("parses hex and expands short form", () => {
  const result = parseColor("#0af");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.hex, "#00AAFF");
  assert.deepEqual(result.rgb, { r: 0, g: 170, b: 255, a: 1 });
});

test("parses rgb and hsl strings", () => {
  const rgb = parseColor("rgb(255, 0, 128)");
  assert.equal(rgb.ok, true);
  if (!rgb.ok) return;
  assert.equal(rgb.hex, "#FF0080");
  const hsl = parseColor("hsl(210, 50%, 40%)");
  assert.equal(hsl.ok, true);
  if (!hsl.ok) return;
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
  const gray = parseColor("#777777");
  assert.equal(gray.ok, true);
  if (!gray.ok) return;
  assert.ok(gray.contrast.onWhite >= 4);
});

test("composites semi-transparent colors before contrast", () => {
  const opaqueBlack = parseColor("#000000");
  const halfBlack = parseColor("rgba(0, 0, 0, 0.5)");
  assert.equal(opaqueBlack.ok, true);
  assert.equal(halfBlack.ok, true);
  if (!opaqueBlack.ok || !halfBlack.ok) return;

  assert.equal(opaqueBlack.contrast.onWhite, 21);
  // 50% black over white → #808080, much lower contrast than opaque black.
  assert.ok(halfBlack.contrast.onWhite < opaqueBlack.contrast.onWhite);
  assert.equal(
    halfBlack.contrast.onWhite,
    contrastRatio(compositeOver({ r: 0, g: 0, b: 0, a: 0.5 }, { r: 255, g: 255, b: 255 }), {
      r: 255,
      g: 255,
      b: 255,
    }),
  );

  const clear = parseColor("rgba(255, 0, 0, 0)");
  assert.equal(clear.ok, true);
  if (!clear.ok) return;
  assert.equal(clear.contrast.onWhite, 1);
});

test("rejects invalid colors", () => {
  const empty = parseColor("");
  assert.equal(empty.ok, false);
  if (empty.ok) return;
  assert.equal(empty.error, "empty");
  const invalid = parseColor("not-a-color");
  assert.equal(invalid.ok, false);
  if (invalid.ok) return;
  assert.equal(invalid.error, "invalid");
});
