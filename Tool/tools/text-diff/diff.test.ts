import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
import { diffLines } from "./diff.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

test("diffs equal texts", () => {
  const result = diffLines("a\nb\n", "a\nb\n");
  assert.equal(result.ok, true);
  assert.equal(result.stats.equal, 2);
  assert.equal(result.stats.added, 0);
  assert.equal(result.stats.removed, 0);
});

test("diffs inserts and deletes", () => {
  const result = diffLines("one\ntwo\nthree", "one\nTWO\nthree\nfour");
  assert.equal(result.ok, true);
  assert.equal(result.stats.removed, 1);
  assert.equal(result.stats.added, 2);
  assert.ok(result.rows.some((row) => row.type === "delete" && row.leftText === "two"));
  assert.ok(result.rows.some((row) => row.type === "insert" && row.rightText === "TWO"));
  assert.ok(result.rows.some((row) => row.type === "insert" && row.rightText === "four"));
});

test("can ignore whitespace", () => {
  const result = diffLines("a  b", "a b", { ignoreWhitespace: true });
  assert.equal(result.ok, true);
  assert.equal(result.stats.equal, 1);
  assert.equal(result.stats.added + result.stats.removed, 0);
});

test("rejects oversized input and too many lines", () => {
  assert.equal(diffLines("a".repeat(400_001), "b").error, "input-too-large");
  assert.equal(diffLines("\n".repeat(4_001), "x").error, "too-many-lines");
});

test("rejects when edit distance exceeds budget", () => {
  const left = Array.from({ length: 500 }, (_, i) => `L${i}`).join("\n");
  const right = Array.from({ length: 500 }, (_, i) => `R${i}`).join("\n");
  // Completely disjoint lines force D ≈ 1000; with a tiny shared alphabet this
  // still finishes, so build a larger disjoint pair near the distance cap.
  const leftBig = Array.from({ length: 3_000 }, (_, i) => `A${i}`).join("\n");
  const rightBig = Array.from({ length: 3_000 }, (_, i) => `B${i}`).join("\n");
  const result = diffLines(leftBig, rightBig);
  assert.equal(result.ok, false);
  assert.equal(result.error, "too-complex");
  // Sanity: smaller unrelated inputs still succeed.
  assert.equal(diffLines(left, right).ok, true);
});

test("diffs empty strings", () => {
  const result = diffLines("", "");
  assert.equal(result.ok, true);
  assert.equal(result.stats.equal, 0);
});
