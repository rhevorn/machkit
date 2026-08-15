import assert from "node:assert/strict";
import { test } from "node:test";
import { buildURL, parseURL } from "./url.js";

test("parses absolute URLs and query pairs", () => {
  const result = parseURL("https://user:pass@example.com:8443/path?x=1&y=2#hash");
  assert.equal(result.ok, true);
  assert.equal(result.parts.hostname, "example.com");
  assert.equal(result.parts.port, "8443");
  assert.deepEqual(result.query, [
    { key: "x", value: "1" },
    { key: "y", value: "2" },
  ]);
});

test("builds URL from parts and query", () => {
  const built = buildURL(
    { protocol: "https", hostname: "machkit.app", pathname: "/tools", hash: "qr" },
    [{ key: "lang", value: "zh" }],
  );
  assert.equal(built.ok, true);
  assert.equal(built.href, "https://machkit.app/tools?lang=zh#qr");
});

test("rejects empty and invalid input", () => {
  assert.equal(parseURL("").error, "empty");
  assert.equal(parseURL("://not-a-url").error, "invalid");
});
