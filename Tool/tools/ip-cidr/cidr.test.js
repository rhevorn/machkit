import test from "node:test";
import assert from "node:assert/strict";
import { catalogIssues } from "../../src/i18n-catalog.js";
import { messages } from "./messages.js";
import { formatIPv4, ipInCIDR, parseCIDR, parseIPv4 } from "./cidr.js";

test("catalog keys stay complete", () => {
  assert.deepEqual(catalogIssues(messages), []);
});

test("parses ipv4 and formats back", () => {
  assert.equal(parseIPv4("192.168.1.10"), ((192 << 24) >>> 0) + (168 << 16) + (1 << 8) + 10);
  assert.equal(formatIPv4(parseIPv4("10.0.0.1")), "10.0.0.1");
  assert.equal(parseIPv4("10.0.0.256"), null);
});

test("calculates cidr details", () => {
  const result = parseCIDR("192.168.1.10/24");
  assert.equal(result.ok, true);
  assert.equal(result.network, "192.168.1.0");
  assert.equal(result.broadcast, "192.168.1.255");
  assert.equal(result.netmask, "255.255.255.0");
  assert.equal(result.firstHost, "192.168.1.1");
  assert.equal(result.lastHost, "192.168.1.254");
  assert.equal(result.hostCount, 254);
});

test("handles host routes and slashless addresses", () => {
  assert.equal(parseCIDR("10.0.0.1/31").hostCount, 2);
  assert.equal(parseCIDR("10.0.0.1/32").hostCount, 1);
  assert.equal(parseCIDR("10.0.0.1").prefix, 32);
  assert.equal(parseCIDR("").ok, false);
});

test("checks membership", () => {
  assert.equal(ipInCIDR("192.168.1.20", "192.168.1.0/24").inside, true);
  assert.equal(ipInCIDR("10.0.0.1", "192.168.1.0/24").inside, false);
});
