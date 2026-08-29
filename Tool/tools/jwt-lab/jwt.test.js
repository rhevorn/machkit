import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createJwt,
  defaultGeneratePayload,
  formatUnixSeconds,
  inspectJwt,
  maxJwtLength,
  parseJsonObject,
} from "./jwt.js";

function makeToken(header, payload) {
  const enc = (value) =>
    Buffer.from(JSON.stringify(value))
      .toString("base64")
      .replace(/=+$/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");
  return `${enc(header)}.${enc(payload)}.sig`;
}

test("decodes a valid jwt", () => {
  const token = makeToken({ alg: "HS256", typ: "JWT" }, { sub: "42", exp: 4102444800 });
  const result = inspectJwt(token, Date.UTC(2026, 0, 1));
  assert.equal(result.ok, true);
  assert.equal(result.payload.sub, "42");
  assert.equal(result.algorithm, "HS256");
  assert.equal(result.status, "ok");
});

test("marks expired tokens", () => {
  const token = makeToken({ alg: "none" }, { exp: 1 });
  const result = inspectJwt(token, Date.UTC(2026, 0, 1));
  assert.equal(result.ok, true);
  assert.equal(result.status, "expired");
});

test("marks not-before tokens", () => {
  const token = makeToken({ alg: "none" }, { nbf: 4102444800 });
  const result = inspectJwt(token, Date.UTC(2026, 0, 1));
  assert.equal(result.ok, true);
  assert.equal(result.status, "not-before");
});

test("rejects junk and oversized tokens", () => {
  assert.equal(inspectJwt("").error, "empty");
  assert.equal(inspectJwt("a.b").error, "invalid-format");
  assert.equal(inspectJwt(`${"a".repeat(maxJwtLength)}.b.c`).error, "too-large");
});

test("formats unix seconds and parses json objects", () => {
  const past = formatUnixSeconds(1, Date.UTC(2026, 0, 1));
  assert.equal(past.expired, true);
  assert.equal(formatUnixSeconds("nope"), null);

  assert.equal(parseJsonObject("").error, "empty");
  assert.equal(parseJsonObject("[1]").error, "invalid-object");
  assert.equal(parseJsonObject("{").error, "invalid-json");
  assert.equal(parseJsonObject('{"a":1}').ok, true);

  const fixed = Date.UTC(2026, 0, 1);
  const payload = defaultGeneratePayload(fixed);
  assert.equal(payload.iat, Math.floor(fixed / 1000));
  assert.equal(payload.exp - payload.iat, 60 * 60 * 24 * 30);
});

test("creates and decodes an HS256 token", async () => {
  const created = await createJwt({
    headerText: JSON.stringify({ typ: "JWT" }),
    payloadText: JSON.stringify({ sub: "machkit", name: "demo" }),
    secret: "machkit-secret",
    algorithm: "HS256",
  });
  assert.equal(created.ok, true);
  assert.match(created.token, /^eyJ/);
  const decoded = inspectJwt(created.token);
  assert.equal(decoded.ok, true);
  assert.equal(decoded.payload.sub, "machkit");
  assert.equal(decoded.algorithm, "HS256");
  assert.ok(decoded.parts.signature.length > 10);
});

test("creates HS512 tokens", async () => {
  const created = await createJwt({
    headerText: "{}",
    payloadText: JSON.stringify({ role: "admin" }),
    secret: "secret",
    algorithm: "HS512",
  });
  assert.equal(created.ok, true);
  assert.equal(inspectJwt(created.token).algorithm, "HS512");
});

test("creates unsigned none tokens", async () => {
  const created = await createJwt({
    headerText: "{}",
    payloadText: JSON.stringify({ role: "guest" }),
    algorithm: "none",
  });
  assert.equal(created.ok, true);
  assert.equal(created.token.endsWith("."), true);
  assert.equal(inspectJwt(created.token).payload.role, "guest");
});

test("requires secret for HMAC algorithms", async () => {
  const created = await createJwt({
    headerText: "{}",
    payloadText: "{}",
    secret: "",
    algorithm: "HS256",
  });
  assert.equal(created.ok, false);
  assert.equal(created.error, "missing-secret");
});

test("rejects invalid generate json", async () => {
  const created = await createJwt({
    headerText: "[]",
    payloadText: "{}",
    secret: "x",
    algorithm: "HS256",
  });
  assert.equal(created.ok, false);
  assert.equal(created.error, "invalid-object");
});
