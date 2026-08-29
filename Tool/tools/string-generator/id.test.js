import test from "node:test";
import assert from "node:assert/strict";
import {
  formatUuid,
  generateHex,
  generateId,
  generateIds,
  generateNanoId,
  generateString,
  generateUlid,
  generateUuidV1,
  generateUuidV3,
  generateUuidV4,
  generateUuidV5,
  generateUuidV6,
  generateUuidV7,
  maxBatchCount,
  uuidNamespaces,
  validateId,
  validateIds,
} from "./id.js";

test("generates RFC-looking UUID v4 values", () => {
  const value = generateUuidV4();
  assert.match(value, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});

test("generates UUID v1 and v6 with version bits", () => {
  assert.match(generateUuidV1(), /^[0-9a-f]{8}-[0-9a-f]{4}-1[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.match(generateUuidV6(), /^[0-9a-f]{8}-[0-9a-f]{4}-6[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});

test("generates UUID v7 with version and variant bits", () => {
  const value = generateUuidV7(1_700_000_000_000);
  assert.match(value, /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  const compact = value.replaceAll("-", "");
  const timestamp = Number.parseInt(compact.slice(0, 12), 16);
  assert.equal(timestamp, 1_700_000_000_000);
});

test("generates deterministic UUID v3 and v5", async () => {
  assert.equal(await generateUuidV3(uuidNamespaces.dns, "www.example.com"), "5df41881-3aed-3515-88a7-2f4a814cf09e");
  assert.equal(await generateUuidV5(uuidNamespaces.dns, "www.example.com"), "2ed6657d-e927-568b-95e1-2665a8aea6a2");
});

test("formats UUID casing and hyphens", () => {
  const value = "550e8400-e29b-41d4-a716-446655440000";
  assert.equal(formatUuid(value, { uppercase: true }), "550E8400-E29B-41D4-A716-446655440000");
  assert.equal(formatUuid(value, { hyphens: false }), "550e8400e29b41d4a716446655440000");
});

test("generates ULID, Nano ID, and hex", () => {
  assert.match(generateUlid(1_700_000_000_000), /^[0-7][0-9A-HJKMNP-TV-Z]{25}$/);
  assert.match(generateNanoId(12), /^[A-Za-z0-9_-]{12}$/);
  assert.match(generateHex(8), /^[0-9a-f]{16}$/);
  assert.match(generateHex(8, { uppercase: true }), /^[0-9A-F]{16}$/);
});

test("batches generation with a hard cap", async () => {
  const values = await generateIds("uuid-v4", 12);
  assert.equal(values.length, 12);
  assert.equal(new Set(values).size, 12);
  assert.equal((await generateIds("nanoid", maxBatchCount + 50)).length, maxBatchCount);
});

test("generateId supports format options", async () => {
  assert.match(await generateId("uuid-v4", { uppercase: true }), /[A-F]/);
  assert.match(await generateId("ulid", { uppercase: false }), /^[0-7][0-9a-hjkmnpqrstvwxyz]{25}$/);
  assert.equal((await generateId("nanoid", { length: 8 })).length, 8);
  assert.equal((await generateId("hex", { byteLength: 4 })).length, 8);
  assert.match(await generateId("uuid-v1"), /-1[0-9a-f]{3}-/);
  assert.match(await generateId("uuid-v6"), /-6[0-9a-f]{3}-/);
});

test("generates strings with required character classes", () => {
  const value = generateString({
    length: 20,
    upper: true,
    lower: true,
    digits: true,
    symbols: true,
  });
  assert.equal(value.length, 20);
  assert.match(value, /[A-Z]/);
  assert.match(value, /[a-z]/);
  assert.match(value, /[0-9]/);
  assert.match(value, /[!@#$%^&*()\-_=+[\]{};:,.?/]/);

  const digitsOnly = generateString({
    length: 8,
    upper: false,
    lower: false,
    digits: true,
    symbols: false,
  });
  assert.match(digitsOnly, /^[0-9]{8}$/);

  const unambiguous = generateString({
    length: 24,
    upper: true,
    lower: true,
    digits: true,
    symbols: false,
    excludeAmbiguous: true,
  });
  assert.equal(/[0OIl1]/.test(unambiguous), false);
  assert.throws(() => generateString({ upper: false, lower: false, digits: false, symbols: false }));
});

test("validates UUID, ULID, ObjectId, and rejects junk", () => {
  assert.equal(validateId("550e8400-e29b-41d4-a716-446655440000").kind, "uuid");
  assert.equal(validateId("550e8400-e29b-41d4-a716-446655440000").version, 4);
  assert.equal(validateId("018f3b4c-7c2a-7a3d-9f1e-2b3c4d5e6f70").version, 7);
  assert.equal(validateId("01ARZ3NDEKTSV4RRFFQ69G5FAV").kind, "ulid");
  assert.equal(validateId("507f1f77bcf86cd799439011").kind, "object-id");
  assert.equal(validateId("Str0ng!Pass").kind, "string-like");
  assert.equal(validateId("not an id").ok, false);
  assert.equal(validateId("").error, "empty");
});

test("validates multiline input and skips blank lines", () => {
  const results = validateIds("550e8400-e29b-41d4-a716-446655440000\n\nbad\n01ARZ3NDEKTSV4RRFFQ69G5FAV");
  assert.equal(results.length, 3);
  assert.equal(results[0].result.ok, true);
  assert.equal(results[1].result.ok, false);
  assert.equal(results[2].result.kind, "ulid");
});
