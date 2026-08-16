import assert from "node:assert/strict";
import { test } from "node:test";
import { buildCurl, buildFetch, formatRawBody, parseCurl } from "./curl.js";

test("formats raw JSON body", () => {
  const result = formatRawBody('{"ok":true,"n":1}');
  assert.equal(result.ok, true);
  assert.equal(result.kind, "json");
  assert.match(result.text, /\{\n {2}"ok": true,\n {2}"n": 1\n\}\n/);
});

test("formats raw XML body", () => {
  const result = formatRawBody("<root><a>1</a></root>");
  assert.equal(result.ok, true);
  assert.equal(result.kind, "xml");
  assert.match(result.text, /<root>/);
});

test("rejects unsupported raw body formatting", () => {
  const result = formatRawBody("plain text");
  assert.equal(result.ok, false);
  assert.equal(result.error, "unsupported");
});

test("parses a common curl command", () => {
  const input =
    "curl -X POST 'https://example.com/api?lang=zh' -H 'Content-Type: application/json' -H 'Authorization: Bearer t' --data-raw '{\"ok\":true}' -L";
  const result = parseCurl(input);
  assert.equal(result.ok, true);
  assert.equal(result.request.method, "POST");
  assert.equal(result.request.url, "https://example.com/api");
  assert.equal(result.request.query[0].key, "lang");
  assert.equal(result.request.bodyMode, "raw");
  assert.equal(result.request.body, '{"ok":true}');
  assert.equal(result.request.followRedirects, true);
});

test("parses multipart form data and files", () => {
  const result = parseCurl(
    "curl https://example.com/upload -F 'name=machkit' -F 'file=@/tmp/a.png' -F 'note=hello'",
  );
  assert.equal(result.ok, true);
  assert.equal(result.request.bodyMode, "formdata");
  assert.equal(result.request.method, "POST");
  assert.equal(result.request.formFields[0].kind, "text");
  assert.equal(result.request.formFields[1].kind, "file");
  assert.equal(result.request.formFields[1].value, "/tmp/a.png");
});

test("parses urlencoded fields", () => {
  const result = parseCurl(
    "curl -X POST https://example.com/login --data-urlencode 'user=pong' --data-urlencode 'pass=secret'",
  );
  assert.equal(result.ok, true);
  assert.equal(result.request.bodyMode, "urlencoded");
  assert.equal(result.request.formFields.length, 2);
  assert.equal(result.request.formFields[0].value, "pong");
});

test("builds formdata and urlencoded curl", () => {
  const formCurl = buildCurl({
    method: "POST",
    url: "https://example.com/upload",
    headers: [],
    query: [],
    bodyMode: "formdata",
    formFields: [
      { id: "1", key: "title", value: "demo", kind: "text" },
      { id: "2", key: "file", value: "/tmp/a.png", kind: "file" },
    ],
  });
  assert.match(formCurl, /-F/);
  assert.match(formCurl, /file=@\/tmp\/a\.png/);

  const encoded = buildCurl({
    method: "POST",
    url: "https://example.com/login",
    headers: [],
    query: [],
    bodyMode: "urlencoded",
    formFields: [{ id: "1", key: "user", value: "pong", kind: "text" }],
  });
  assert.match(encoded, /--data-urlencode/);
  assert.match(encoded, /application\/x-www-form-urlencoded/);
});

test("round-trips through buildCurl", () => {
  const parsed = parseCurl(
    "curl -X PUT https://httpbin.org/put -H 'Accept: application/json' --data-raw 'hello'",
  );
  assert.equal(parsed.ok, true);
  const built = buildCurl(parsed.request);
  const again = parseCurl(built);
  assert.equal(again.ok, true);
  assert.equal(again.request.method, "PUT");
  assert.equal(again.request.body, "hello");
});

test("builds fetch snippet for form modes", () => {
  const snippet = buildFetch({
    method: "POST",
    url: "https://example.com",
    headers: [],
    query: [],
    bodyMode: "formdata",
    formFields: [{ id: "1", key: "file", value: "/tmp/a.png", kind: "file" }],
  });
  assert.match(snippet, /FormData/);
  assert.match(snippet, /append/);
});

test("rejects empty", () => {
  assert.equal(parseCurl("").error, "empty");
  assert.equal(parseCurl("wget https://x").error, "not-curl");
});
