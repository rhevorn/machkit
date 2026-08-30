import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
import {
  compileRegex,
  findMatches,
  highlightSegments,
  normalizeFlags,
  replaceMatches,
} from "./regex.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

test("normalizes and compiles flags", () => {
  assert.equal(normalizeFlags("gigim"), "gim");
  assert.equal(compileRegex("(", "g").ok, false);
  assert.equal(compileRegex("abc", "gi").ok, true);
});

test("finds matches with capture groups", () => {
  const result = findMatches(String.raw`(\w+)@(\w+)`, "g", "a@b c@d");
  assert.equal(result.ok, true);
  assert.equal(result.matches.length, 2);
  assert.equal(result.matches[0].groups[0].value, "a");
  assert.equal(result.matches[0].groups[1].value, "b");
});

test("normalizes dirty flags that already include d", () => {
  const result = findMatches("a", "dgX", "aa");
  assert.equal(result.ok, true);
  assert.equal(result.matches.length, 2);
});

test("truncates when maxMatches is exceeded", () => {
  const result = findMatches("a", "g", "aaaa", { maxMatches: 2 });
  assert.equal(result.ok, true);
  assert.equal(result.matches.length, 2);
  assert.equal(result.truncated, true);
});

test("zero-length matches do not consume maxMatches", () => {
  // a* matches empty at every position in "bcd". Counting those toward maxMatches
  // would truncate after two empties; skipping them should finish without truncation.
  const result = findMatches("a*", "g", "bcd", { maxMatches: 2 });
  assert.equal(result.ok, true);
  assert.equal(result.matches.length, 0);
  assert.equal(result.truncated, false);
});

test("aborts when match loop exceeds time or step budget", () => {
  const input = "a".repeat(80_000);
  const started = Date.now();
  const result = findMatches("a", "g", input, {
    maxMatches: 100_000,
    maxBudgetMs: 5,
    maxSteps: 2_000,
  });
  const elapsed = Date.now() - started;
  assert.ok(elapsed < 2_000, `expected budget abort within 2s, took ${elapsed}ms`);
  assert.equal(result.error, "budget-exceeded");
  assert.equal(result.truncated, true);
  assert.ok(result.matches.length > 0);
  assert.ok(result.matches.length < 80_000);
});

test("replace also respects budget", () => {
  const input = "a".repeat(80_000);
  const started = Date.now();
  const result = replaceMatches("a", "g", input, "b", { maxBudgetMs: 5, maxSteps: 2_000 });
  const elapsed = Date.now() - started;
  assert.ok(elapsed < 2_000, `expected budget abort within 2s, took ${elapsed}ms`);
  assert.equal(result.ok, false);
  assert.equal(result.error, "budget-exceeded");
});

test("captures named groups and non-global single match", () => {
  const named = findMatches(String.raw`(?<digit>\d+)`, "g", "a12b");
  assert.equal(named.matches[0].named!.digit, "12");
  const once = findMatches("a", "", "aa");
  assert.equal(once.matches.length, 1);
});

test("replaces with common whitespace preset style", () => {
  const result = replaceMatches(String.raw`[ \t]+`, "g", "a   b\tc", " ");
  assert.equal(result.ok, true);
  assert.equal(result.value, "a b c");
});

test("builds highlight segments", () => {
  const matches = findMatches("b+", "g", "abbbc").matches;
  const segments = highlightSegments("abbbc", matches);
  assert.deepEqual(segments.map((item) => item.type), ["text", "match", "text"]);
  assert.equal(segments[1].value, "bbb");
});
