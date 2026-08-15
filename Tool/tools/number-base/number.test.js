import assert from "node:assert/strict";
import { test } from "node:test";
import { convertBases, convertBytes } from "./number.js";

test("converts decimal to other bases", () => {
  const result = convertBases("255");
  assert.equal(result.ok, true);
  assert.equal(result.formats.hex, "0xFF");
  assert.equal(result.formats.bin, "0b11111111");
  assert.equal(result.formats.oct, "0o377");
});

test("accepts prefixed hex input", () => {
  assert.equal(convertBases("0x10").formats.dec, "16");
});

test("converts byte units", () => {
  const result = convertBytes("1", "KiB");
  assert.equal(result.ok, true);
  assert.equal(result.formats.B, "1024");
  assert.equal(result.formats.KB, "1.024");
});
