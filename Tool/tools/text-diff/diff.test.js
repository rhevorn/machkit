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
