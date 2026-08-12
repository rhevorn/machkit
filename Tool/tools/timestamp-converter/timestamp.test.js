import test from "node:test";
import assert from "node:assert/strict";
import {
  formatISO8601,
  formatRFC2822,
  formatRFC3339,
  localDateTimeValue,
  millisecondsFromLocalDateTime,
  millisecondsFromTimestamp,
  timestampFromMilliseconds,
} from "./timestamp.js";

test("converts supported timestamp units without losing integer precision", () => {
  assert.equal(timestampFromMilliseconds(1_700_000_000_000, "seconds"), "1700000000");
  assert.equal(timestampFromMilliseconds(1_700_000_000_000, "milliseconds"), "1700000000000");
  assert.equal(timestampFromMilliseconds(1_700_000_000_000, "nanoseconds"), "1700000000000000000");
});

test("formats common interchange date standards", () => {
  const milliseconds = Date.UTC(2026, 7, 11, 8, 30, 45);
  assert.equal(formatISO8601(milliseconds), "2026-08-11T08:30:45.000Z");
  assert.equal(formatRFC3339(milliseconds, "Asia/Shanghai"), "2026-08-11T16:30:45+08:00");
  assert.equal(formatRFC2822(milliseconds, "Asia/Shanghai"), "Tue, 11 Aug 2026 16:30:45 +0800");
});

test("parses valid integers and rejects invalid values", () => {
  assert.equal(millisecondsFromTimestamp("1700000000", "seconds"), 1_700_000_000_000);
  assert.equal(millisecondsFromTimestamp("1700000000000000000", "nanoseconds"), 1_700_000_000_000);
  assert.equal(millisecondsFromTimestamp("1.5", "seconds"), null);
  assert.equal(millisecondsFromTimestamp("timestamp", "milliseconds"), null);
});

test("converts a zoned local date deterministically", () => {
  const value = "2026-08-11T16:30:45";
  const milliseconds = millisecondsFromLocalDateTime(value, "Asia/Shanghai");
  assert.equal(milliseconds, Date.UTC(2026, 7, 11, 8, 30, 45));
  assert.equal(localDateTimeValue(milliseconds, "Asia/Shanghai"), value);
});
