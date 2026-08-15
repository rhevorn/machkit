import assert from "node:assert/strict";
import { test } from "node:test";
import { compressIPv6, expandIPv6, inspectIP } from "./ip.js";

test("inspects IPv4 details", () => {
  const result = inspectIP("192.168.1.10");
  assert.equal(result.ok, true);
  assert.equal(result.version, 4);
  assert.equal(result.kind, "private");
  assert.equal(result.class, "C");
  assert.equal(result.reverse, "10.1.168.192.in-addr.arpa");
});

test("expands and compresses IPv6", () => {
  const expanded = expandIPv6("2001:db8::1");
  assert.deepEqual(expanded.groups, [
    "2001", "0db8", "0000", "0000", "0000", "0000", "0000", "0001",
  ]);
  assert.equal(compressIPv6(expanded.groups), "2001:db8::1");
});

test("handles IPv4-mapped IPv6", () => {
  const result = inspectIP("::ffff:192.0.2.128");
  assert.equal(result.ok, true);
  assert.equal(result.kind, "ipv4-mapped");
  assert.equal(result.mappedIPv4, "192.0.2.128");
});
