import assert from "node:assert/strict";
import { test } from "node:test";
import { createJwt, inspectJwt } from "./jwt.js";

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

test("rejects junk", () => {
  assert.equal(inspectJwt("").error, "empty");
  assert.equal(inspectJwt("a.b").error, "invalid-format");
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
