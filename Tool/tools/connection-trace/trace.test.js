import assert from "node:assert/strict";
import { test } from "node:test";
import { formatMs, normalizeTarget, stepTone } from "./trace.js";

test("normalizes target", () => {
  assert.equal(normalizeTarget("  example.com "), "example.com");
});

test("formats milliseconds", () => {
  assert.equal(formatMs(0.42), "0.42 ms");
  assert.equal(formatMs(12.6), "13 ms");
  assert.equal(formatMs(null), "—");
});

test("step tone", () => {
  assert.equal(stepTone({ ok: true }), "ok");
  assert.equal(stepTone({ ok: false }), "danger");
});
