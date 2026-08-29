import assert from "node:assert/strict";
import { test } from "node:test";
import { formatXML } from "./xml.js";

test("pretty-prints nested xml", () => {
  const result = formatXML("<a><b>1</b><c/></a>");
  assert.equal(result.ok, true);
  assert.equal(result.text, "<a>\n  <b>1</b>\n  <c/>\n</a>\n");
});

test("strips comments while formatting", () => {
  const result = formatXML("<!--x--><root><i/></root>");
  assert.equal(result.ok, true);
  assert.equal(result.text.includes("<!--"), false);
  assert.match(result.text, /<root>/);
});

test("rejects empty and oversized xml", () => {
  assert.equal(formatXML("").error, "empty");
  assert.equal(formatXML("   ").error, "empty");
  assert.equal(formatXML("x".repeat(1_000_001)).error, "too-large");
});
