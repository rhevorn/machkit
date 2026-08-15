import assert from "node:assert/strict";
import { test } from "node:test";
import {
  formatDuration,
  inspectPortExpression,
  isTerminalState,
  normalizeHost,
  presets,
  progressPercent,
} from "./scan.js";

test("accepts individual ports and ranges", () => {
  assert.deepEqual(inspectPortExpression("22,80,8000-8002"), { ok: true, error: null, count: 5 });
  assert.equal(inspectPortExpression("80,80,79-81").count, 3);
});

test("accepts the complete TCP range", () => {
  assert.equal(inspectPortExpression("1-65535").count, 65_535);
  assert.equal(presets.all, "1-65535");
});

test("rejects invalid ports", () => {
  assert.equal(inspectPortExpression("0").error, "invalid-port");
  assert.equal(inspectPortExpression("80-20").error, "invalid-range");
  assert.equal(inspectPortExpression("65536").error, "invalid-port");
});

test("formats progress and duration", () => {
  assert.equal(progressPercent(50, 200), 25);
  assert.equal(formatDuration(750), "750 ms");
  assert.equal(formatDuration(2_500), "2.5 s");
  assert.equal(formatDuration(65_000), "1m 5s");
});

test("normalizes host and terminal states", () => {
  assert.equal(normalizeHost(" localhost "), "localhost");
  assert.equal(isTerminalState("completed"), true);
  assert.equal(isTerminalState("running"), false);
});
