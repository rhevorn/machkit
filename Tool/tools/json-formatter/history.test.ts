import test from "node:test";
import assert from "node:assert/strict";
import {
  HISTORY_MAX_ENTRIES,
  makePreview,
  normalizeHistory,
  parseHistoryPayload,
  pushHistoryEntry,
  removeHistoryEntry,
  serializeHistory,
} from "./history.js";

test("makePreview collapses whitespace and truncates", () => {
  assert.equal(makePreview("  { \"a\": 1 }  "), '{ "a": 1 }');
  assert.equal(makePreview("x".repeat(100), 10).endsWith("…"), true);
});

test("pushHistoryEntry prepends and dedupes identical source", () => {
  const first = pushHistoryEntry([], '{"a":1}', { now: 1, idFactory: () => "a" });
  assert.equal(first.entries.length, 1);
  const second = pushHistoryEntry(first.entries, '{"b":2}', { now: 2, idFactory: () => "b" });
  assert.deepEqual(second.entries.map((item) => item.id), ["b", "a"]);
  const again = pushHistoryEntry(second.entries, '{"a":1}', { now: 3, idFactory: () => "a2" });
  assert.deepEqual(again.entries.map((item) => item.source), ['{"a":1}', '{"b":2}']);
  assert.equal(again.entries[0].id, "a2");
});

test("pushHistoryEntry caps at 100 entries", () => {
  let entries: ReturnType<typeof pushHistoryEntry>["entries"] = [];
  for (let index = 0; index < HISTORY_MAX_ENTRIES + 25; index += 1) {
    entries = pushHistoryEntry(entries, `{"n":${index}}`, {
      now: index,
      idFactory: () => `id-${index}`,
    }).entries;
  }
  assert.equal(entries.length, HISTORY_MAX_ENTRIES);
  assert.equal(entries[0].source, `{"n":${HISTORY_MAX_ENTRIES + 24}}`);
});

test("pushHistoryEntry rejects oversized source", () => {
  const huge = "x".repeat(200_001);
  const result = pushHistoryEntry([], huge, { now: 1, idFactory: () => "x" });
  assert.equal(result.changed, false);
  assert.equal(result.entries.length, 0);
});

test("parse and serialize round-trip", () => {
  const { entries } = pushHistoryEntry([], '{"ok":true}', { now: 9, idFactory: () => "one" });
  const raw = serializeHistory(entries);
  assert.deepEqual(parseHistoryPayload(raw), entries);
  assert.deepEqual(parseHistoryPayload("not-json"), []);
  assert.deepEqual(normalizeHistory([{ source: "" }, null, { source: '{"a":1}', id: "k" }]).length, 1);
});

test("removeHistoryEntry drops by id", () => {
  const { entries } = pushHistoryEntry(
    pushHistoryEntry([], '{"a":1}', { now: 1, idFactory: () => "a" }).entries,
    '{"b":2}',
    { now: 2, idFactory: () => "b" },
  );
  assert.deepEqual(removeHistoryEntry(entries, "b").map((item) => item.id), ["a"]);
});
