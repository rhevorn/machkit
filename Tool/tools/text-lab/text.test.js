import assert from "node:assert/strict";
import { test } from "node:test";
import { textStats, transformText } from "./text.js";

test("computes stats", () => {
  const stats = textStats("a\nb\n\nc");
  assert.equal(stats.lines, 4);
  assert.equal(stats.nonEmpty, 3);
});

test("dedupes and sorts lines", () => {
  const deduped = transformText("b\na\nb\n", "dedupe");
  assert.equal(deduped.ok, true);
  assert.equal(deduped.text, "b\na\n");

  const sorted = transformText("b\na\nc", "sortAsc");
  assert.equal(sorted.text, "a\nb\nc");
});

test("case and blank helpers", () => {
  assert.equal(transformText("Ab C", "lower").text, "ab c");
  assert.equal(transformText("a\n\nb\n", "removeBlank").text, "a\nb");
  assert.match(transformText("x\ny", "lineNumbers").text, /^1 {2}x\n2 {2}y$/);
});
