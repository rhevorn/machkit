import assert from "node:assert/strict";
import { test } from "node:test";
import forge from "node-forge";
import { extractPemBlocks, inspectCertificatePem, maxCertInput } from "./cert.js";

function samplePem() {
  const keys = forge.pki.rsa.generateKeyPair(1024);
  const cert = forge.pki.createCertificate();
  cert.publicKey = keys.publicKey;
  cert.serialNumber = "0A0B";
  cert.validity.notBefore = new Date("2024-01-01T00:00:00Z");
  cert.validity.notAfter = new Date("2030-01-01T00:00:00Z");
  cert.setSubject([
    { name: "commonName", value: "machkit.test" },
    { name: "organizationName", value: "MachKit" },
  ]);
  cert.setIssuer(cert.subject.attributes);
  cert.sign(keys.privateKey, forge.md.sha256.create());
  return forge.pki.certificateToPem(cert);
}

test("parses pem certificates", () => {
  const result = inspectCertificatePem(samplePem(), new Date("2026-01-01T00:00:00Z"));
  assert.equal(result.ok, true);
  assert.equal(result.certificates.length, 1);
  assert.match((result.certificates[0] as any).subject, /machkit\.test/);
  assert.equal((result.certificates[0] as any).status, "valid");
  assert.match((result.certificates[0] as any).sha256, /:/);
});

test("detects expired certificates", () => {
  const result = inspectCertificatePem(samplePem(), new Date("2031-01-01T00:00:00Z"));
  assert.equal(result.ok, true);
  assert.equal((result.certificates[0] as any).status, "expired");
});

test("rejects empty and junk", () => {
  assert.equal(inspectCertificatePem("").error, "empty");
  assert.equal(inspectCertificatePem("not a cert").error, "no-certificate");
});

test("detects not-yet-valid certificates and extracts pem blocks", () => {
  const pem = samplePem();
  const result = inspectCertificatePem(pem, new Date("2020-01-01T00:00:00Z"));
  assert.equal(result.ok, true);
  assert.equal((result.certificates[0] as any).status, "not-yet-valid");

  const blocks = extractPemBlocks(`${pem}\n${pem}`);
  assert.equal(blocks.length, 2);
  assert.equal(blocks[0].type, "CERTIFICATE");
});

test("rejects oversized input", () => {
  assert.equal(inspectCertificatePem("x".repeat(maxCertInput + 1)).error, "too-large");
});
