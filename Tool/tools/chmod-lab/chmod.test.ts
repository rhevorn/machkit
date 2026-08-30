import assert from "node:assert/strict";
import { test } from "node:test";
import {
  clampMode,
  describeMode,
  formatSymbolic,
  inspectPermission,
  parseOctal,
  toggleBit,
  toggleSpecial,
} from "./chmod.js";

test("parses octal modes", () => {
  assert.equal(parseOctal("755").mode, 0o755);
  assert.equal(parseOctal("0o644").mode, 0o644);
  assert.equal(formatSymbolic(0o755), "rwxr-xr-x");
  assert.equal(describeMode(0o644).chmod, "chmod 644");
});

test("parses symbolic modes including ls prefix", () => {
  const a = inspectPermission("rwxr-xr-x");
  const b = inspectPermission("-rw-r--r--");
  const c = inspectPermission("drwxr-xr-x");
  assert.equal(a.ok && a.octal, "755");
  assert.equal(b.ok && b.octal, "644");
  assert.equal(c.ok && c.octal, "755");
});

test("toggles permission bits", () => {
  const next = toggleBit(0o644, "owner", "x");
  assert.equal(next.octal, "744");
  assert.equal(next.symbolic, "rwxr--r--");
});

test("handles setuid sticky", () => {
  assert.equal(formatSymbolic(0o4755), "rwsr-xr-x");
  const inspected = inspectPermission("rwsr-xr-t");
  assert.equal(inspected.ok && inspected.octal, "5755");
  assert.equal(formatSymbolic(0o4644), "rwSr--r--");
});

test("toggles special bits and clamps modes", () => {
  assert.equal(toggleSpecial(0o755, "sticky").octal, "1755");
  assert.equal(clampMode(-1), 0);
  assert.equal(clampMode(0o10000), 0o7777);
  assert.equal(inspectPermission("rwxrwxrwxrwx").ok, false);
});
