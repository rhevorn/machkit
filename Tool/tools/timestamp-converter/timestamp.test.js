import test from "node:test";
import assert from "node:assert/strict";
import {
  applyRelativeSteps,
  formatISO8601,
  formatLocalDateTime,
  formatReadableDate,
  formatRFC2822,
  formatRFC3339,
  localDateTimeValue,
  millisecondsFromLocalDateTime,
  millisecondsFromTimestamp,
  shiftMilliseconds,
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
  assert.equal(formatLocalDateTime(milliseconds, "Asia/Shanghai"), "2026-08-11 16:30:45");
  assert.match(formatReadableDate(milliseconds, "Asia/Shanghai", "en"), /August 11, 2026/);
  assert.match(formatReadableDate(milliseconds, "Asia/Shanghai", "en"), /16:30:45/);
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

test("shifts fixed durations and calendar months in a zone", () => {
  const base = Date.UTC(2026, 7, 11, 8, 30, 45);
  assert.equal(shiftMilliseconds(base, 2, "days", "later"), base + 2 * 86_400_000);
  assert.equal(shiftMilliseconds(base, 1, "weeks", "ago"), base - 7 * 86_400_000);
  assert.equal(
    localDateTimeValue(shiftMilliseconds(base, 30, "days", "ago", "Asia/Shanghai"), "Asia/Shanghai"),
    "2026-07-12T16:30:45",
  );
  assert.equal(
    localDateTimeValue(shiftMilliseconds(base, 1, "months", "later", "Asia/Shanghai"), "Asia/Shanghai"),
    "2026-09-11T16:30:45",
  );
  assert.equal(
    localDateTimeValue(shiftMilliseconds(Date.UTC(2026, 0, 31, 4, 0, 0), 1, "months", "later", "Asia/Shanghai"), "Asia/Shanghai"),
    "2026-02-28T12:00:00",
  );
});

test("applies chained relative steps in order", () => {
  const base = Date.UTC(2026, 7, 11, 8, 30, 45);
  const result = applyRelativeSteps(
    base,
    [
      { operator: "add", amount: 30, unit: "days" },
      { operator: "subtract", amount: 2, unit: "hours" },
      { operator: "add", amount: 1, unit: "weeks" },
    ],
    "UTC",
  );
  assert.equal(result, base + 30 * 86_400_000 - 2 * 3_600_000 + 7 * 86_400_000);
});
