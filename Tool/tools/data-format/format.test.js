import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
import { convertFormat, parseFormat } from "./format.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

test("converts yaml to json", () => {
  const result = convertFormat("name: machkit\nversion: 2\n", "yaml", "json");
  assert.equal(result.ok, true);
  assert.match(result.text, /"name": "machkit"/);
});

test("converts json to toml", () => {
  const result = convertFormat('{"name":"machkit","version":2}', "json", "toml");
  assert.equal(result.ok, true);
  assert.match(result.text, /name = "machkit"/);
});

test("rejects toml array roots", () => {
  const result = convertFormat("[1, 2, 3]", "json", "toml");
  assert.equal(result.ok, false);
  assert.equal(result.error, "toml-root-object");
});

test("parses toml", () => {
  const parsed = parseFormat('title = "demo"\ncount = 3\n', "toml");
  assert.equal(parsed.ok, true);
  assert.equal(parsed.value.title, "demo");
  assert.equal(parsed.value.count, 3);
});
