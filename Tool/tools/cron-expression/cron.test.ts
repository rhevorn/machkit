import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
import { nextCronRuns, parseCron } from "./cron.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

test("parses five-field cron", () => {
  const parsed = parseCron("*/15 9-17 * * 1-5");
  assert.equal(parsed.ok, true);
  assert.deepEqual(parsed.fields!.minute.slice(0, 3), [0, 15, 30]);
  assert.equal(parsed.fields!.hour.includes(9), true);
  assert.equal(parsed.fields!.dayOfWeek.includes(0), false);
});

test("accepts Sunday as 7", () => {
  const parsed = parseCron("0 9 * * 7");
  assert.equal(parsed.ok, true);
  assert.deepEqual(parsed.fields!.dayOfWeek, [0]);
});

test("finds upcoming runs", () => {
  const from = new Date("2026-08-15T08:00:00");
  const result = nextCronRuns("0 9 * * *", { count: 3, from });
  assert.equal(result.ok, true);
  assert.equal(result.runs.length, 3);
  assert.equal(result.runs[0].getHours(), 9);
  assert.equal(result.runs[0].getMinutes(), 0);
});
