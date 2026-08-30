import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildURL,
  decodeURIComponentSafe,
  encodeURIComponentSafe,
  maxURLInput,
  parseURL,
} from "./url.js";

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

test("parses hostnames without scheme by assuming https", () => {
  const result = parseURL("example.com/path");
  assert.equal(result.ok, true);
  assert.equal(result.parts.protocol, "https");
  assert.equal(result.parts.hostname, "example.com");
  assert.equal(result.parts.pathname, "/path");
});

test("builds URL from parts and query", () => {
  const built = buildURL(
    { protocol: "https", hostname: "machkit.app", pathname: "/tools", hash: "qr" },
    [{ key: "lang", value: "zh" }],
  );
  assert.equal(built.ok, true);
  assert.equal(built.href, "https://machkit.app/tools?lang=zh#qr");
});

test("rejects empty invalid and oversized input", () => {
  assert.equal(parseURL("").error, "empty");
  assert.equal(parseURL("://not-a-url").error, "invalid");
  assert.equal(parseURL("x".repeat(maxURLInput + 1)).error, "too-large");
  assert.equal(buildURL({ hostname: "" }).error, "missing-host");
});

test("encodes and decodes URI components safely", () => {
  assert.equal(encodeURIComponentSafe("a b&中"), "a%20b%26%E4%B8%AD");
  assert.deepEqual(decodeURIComponentSafe("a%20b"), { ok: true, text: "a b" });
  assert.equal(decodeURIComponentSafe("a+b").text, "a b");
  assert.equal(decodeURIComponentSafe("%E0%A4%A").ok, false);
});
