import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues, supportedLocales } from "./i18n-catalog.js";
import { messages as timestampMessages } from "../tools/timestamp-converter/messages.js";
import { messages as codecMessages } from "../tools/codec/messages.js";
import { messages as jsonMessages } from "../tools/json-formatter/messages.js";
import { labels as hostsMessages } from "../tools/hosts-manager/messages.js";

for (const [name, catalog] of Object.entries({
  timestamp: timestampMessages,
  codec: codecMessages,
  json: jsonMessages,
  hosts: hostsMessages,
})) {
  test(`${name} translations have the same non-empty keys`, () => {
    assert.deepEqual(catalogIssues(catalog), []);
  });
}

test("fully localized tools cover every supported locale", () => {
  for (const catalog of [timestampMessages, codecMessages, jsonMessages, hostsMessages]) {
    assert.deepEqual(Object.keys(catalog).sort(), [...supportedLocales].sort());
  }
});
