import assert from "node:assert/strict";
import { test } from "node:test";
import forge from "node-forge";
import { inspectCertificatePem } from "./cert.js";

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
  assert.match(result.certificates[0].subject, /machkit\.test/);
  assert.equal(result.certificates[0].status, "valid");
  assert.match(result.certificates[0].sha256, /:/);
});

test("detects expired certificates", () => {
  const result = inspectCertificatePem(samplePem(), new Date("2031-01-01T00:00:00Z"));
  assert.equal(result.ok, true);
  assert.equal(result.certificates[0].status, "expired");
});

test("rejects empty and junk", () => {
  assert.equal(inspectCertificatePem("").error, "empty");
  assert.equal(inspectCertificatePem("not a cert").error, "no-certificate");
});
