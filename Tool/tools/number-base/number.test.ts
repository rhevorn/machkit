import assert from "node:assert/strict";
import { test } from "node:test";
import {
  convertBases,
  convertBytes,
  convertCategory,
  convertLinear,
  convertTemperature,
  formatNumber,
  unitsForCategory,
} from "./number.js";

test("converts decimal to other bases", () => {
  const result = convertBases("255");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).hex, "0xFF");
  assert.equal(((result.formats as any)).bin, "0b11111111");
  assert.equal(((result.formats as any)).oct, "0o377");
});

test("accepts prefixed hex input", () => {
  assert.equal((convertBases("0x10").formats as any).dec, "16");
});

test("converts byte units", () => {
  const result = convertBytes("1", "KiB");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).B, "1024");
  assert.equal(((result.formats as any)).KB, "1.024");
});

test("converts petabyte scale", () => {
  const result = convertBytes("1", "PB");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).TB, "1000");
  assert.equal(((result.formats as any)).B, "1000000000000000");
});

test("converts time units", () => {
  const result = convertLinear("1000", "ms", "time");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).s, "1");
  assert.equal(((result.formats as any)).min, "0.0166666666667");
});

test("converts length units", () => {
  const result = convertLinear("1", "km", "length");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).m, "1000");
  assert.equal(((result.formats as any)).cm, "100000");
});

test("converts temperature", () => {
  const result = convertTemperature("100", "C");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).C, "100");
  assert.equal(((result.formats as any)).F, "212");
  assert.equal(((result.formats as any)).K, "373.15");
});

test("converts angle and speed", () => {
  const angle = convertLinear("180", "deg", "angle");
  assert.equal(angle.ok, true);
  assert.equal((angle.formats as any).turn, "0.5");
  assert.ok(Math.abs(Number((angle.formats as any).rad) - Math.PI) < 1e-9);

  const speed = convertLinear("36", "kmh", "speed");
  assert.equal(speed.ok, true);
  assert.equal((speed.formats as any).mps, "10");
});

test("formats small numbers", () => {
  assert.equal(formatNumber(0), "0");
  assert.match(formatNumber(1e-9), /e-/i);
});

test("routes categories and lists units", () => {
  const mass = convertCategory("mass", "1", "kg");
  assert.equal(mass.ok, true);
  assert.equal((mass.formats as any).g, "1000");

  const area = convertCategory("area", "1", "ha");
  assert.equal(area.ok, true);
  assert.equal((area.formats as any).m2, "10000");

  assert.ok(unitsForCategory("temperature").some((unit) => unit.id === "C"));
  assert.equal(convertCategory("nope", "1", "x").ok, false);
});

test("accepts negative decimal bases", () => {
  const result = convertBases("-10");
  assert.equal(result.ok, true);
  assert.equal(((result.formats as any)).hex, "-0xA");
});
