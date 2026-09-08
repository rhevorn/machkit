import assert from "node:assert/strict";
import { test } from "node:test";
import {
  cipherAlgorithmCatalog,
  decodeBytes,
  encodeBytes,
  generateRsaKeyPairPem,
  generateRsaPrivateKeyPem,
  generateSm2KeyPair,
  generateSm2PrivateKey,
  getAlgorithmMeta,
  maxCipherInputChars,
  publicKeyFromSm2PrivateKey,
  publicKeyPemFromRsaPrivateKey,
  runCipher,
  suggestedIV,
  suggestedKey,
  suggestedKeyForMode,
} from "./cipher.js";
import { bytesToHex, randomBytes } from "./cipher-bytes.js";

test("decodes and encodes hex and base64", () => {
  const hex = decodeBytes("48656c6c6f", "hex");
  assert.equal(hex.ok, true);
  if (!hex.ok) return;
  const asText = encodeBytes(hex.bytes, "utf8");
  assert.equal(asText.ok, true);
  if (!asText.ok) return;
  assert.equal(asText.value, "Hello");
});

test("catalog includes modern and compatibility algorithms", () => {
  const ids = cipherAlgorithmCatalog.map((item) => item.id).sort();
  assert.deepEqual(ids, [
    "3DES-CBC",
    "AES-CBC",
    "AES-CTR",
    "AES-ECB",
    "AES-GCM",
    "ChaCha20-Poly1305",
    "DES-CBC",
    "RSA-OAEP",
    "RSA-PKCS1-v1_5",
    "SM2",
    "SM4",
    "XChaCha20-Poly1305",
  ]);
  assert.equal(getAlgorithmMeta("AES-GCM").asymmetric, false);
  assert.equal(getAlgorithmMeta("RSA-OAEP").asymmetric, true);
  assert.equal(getAlgorithmMeta("DES-CBC").group, "des");
});

test("suggested key and iv lengths match algorithm requirements", () => {
  const key = decodeBytes(suggestedKey(256), "hex");
  assert.equal(key.ok && key.bytes.length, 32);
  const desKey = decodeBytes(suggestedKeyForMode("DES-CBC"), "hex");
  assert.equal(desKey.ok && desKey.bytes.length, 8);
  const gcm = decodeBytes(suggestedIV("AES-GCM"), "hex");
  assert.equal(gcm.ok && gcm.bytes.length, 12);
  const cbc = decodeBytes(suggestedIV("AES-CBC"), "hex");
  assert.equal(cbc.ok && cbc.bytes.length, 16);
  const ctr = decodeBytes(suggestedIV("AES-CTR"), "hex");
  assert.equal(ctr.ok && ctr.bytes.length, 16);
  const desIv = decodeBytes(suggestedIV("DES-CBC"), "hex");
  assert.equal(desIv.ok && desIv.bytes.length, 8);
  const xcha = decodeBytes(suggestedIV("XChaCha20-Poly1305"), "hex");
  assert.equal(xcha.ok && xcha.bytes.length, 24);
});

test("AES-GCM / CBC / CTR round trips", async () => {
  for (const mode of ["AES-GCM", "AES-CBC", "AES-CTR"] as const) {
    const key = suggestedKey(256);
    const iv = suggestedIV(mode);
    const encrypted = await runCipher({ mode, direction: "encrypt", input: `hello ${mode}`, key, iv });
    assert.equal(encrypted.ok, true, mode);
    const decrypted = await runCipher({
      mode,
      direction: "decrypt",
      input: encrypted.value,
      key,
      iv,
      inputEncoding: "hex",
    });
    assert.equal(decrypted.value, `hello ${mode}`, mode);
  }
});

test("AES-ECB round trip", async () => {
  const key = suggestedKey(256);
  const encrypted = await runCipher({ mode: "AES-ECB", direction: "encrypt", input: "hello ecb", key, iv: "" });
  assert.equal(encrypted.ok, true);
  const decrypted = await runCipher({
    mode: "AES-ECB",
    direction: "decrypt",
    input: encrypted.value,
    key,
    iv: "",
    inputEncoding: "hex",
  });
  assert.equal(decrypted.value, "hello ecb");
});

test("ChaCha20-Poly1305 and XChaCha20-Poly1305 round trips", async () => {
  for (const mode of ["ChaCha20-Poly1305", "XChaCha20-Poly1305"] as const) {
    const key = bytesToHex(randomBytes(32));
    const iv = suggestedIV(mode);
    const encrypted = await runCipher({
      mode,
      direction: "encrypt",
      input: `hello ${mode}`,
      key,
      iv,
    });
    assert.equal(encrypted.ok, true, mode);
    const decrypted = await runCipher({
      mode,
      direction: "decrypt",
      input: encrypted.value,
      key,
      iv,
      inputEncoding: "hex",
    });
    assert.equal(decrypted.value, `hello ${mode}`, mode);
  }
});

test("DES-CBC and 3DES-CBC round trips", async () => {
  const desKey = suggestedKeyForMode("DES-CBC");
  const desIv = suggestedIV("DES-CBC");
  const desEnc = await runCipher({
    mode: "DES-CBC",
    direction: "encrypt",
    input: "hello des",
    key: desKey,
    iv: desIv,
  });
  assert.equal(desEnc.ok, true);
  const desDec = await runCipher({
    mode: "DES-CBC",
    direction: "decrypt",
    input: desEnc.value,
    key: desKey,
    iv: desIv,
    inputEncoding: "hex",
  });
  assert.equal(desDec.value, "hello des");

  const tdesKey = suggestedKeyForMode("3DES-CBC");
  const tdesIv = suggestedIV("3DES-CBC");
  const tdesEnc = await runCipher({
    mode: "3DES-CBC",
    direction: "encrypt",
    input: "hello 3des",
    key: tdesKey,
    iv: tdesIv,
  });
  assert.equal(tdesEnc.ok, true);
  const tdesDec = await runCipher({
    mode: "3DES-CBC",
    direction: "decrypt",
    input: tdesEnc.value,
    key: tdesKey,
    iv: tdesIv,
    inputEncoding: "hex",
  });
  assert.equal(tdesDec.value, "hello 3des");
});

test("SM4 and SM2 round trips", async () => {
  const sm4Key = bytesToHex(randomBytes(16));
  const sm4Enc = await runCipher({ mode: "SM4", direction: "encrypt", input: "hello sm4", key: sm4Key, iv: "" });
  assert.equal(sm4Enc.ok, true);
  const sm4Dec = await runCipher({
    mode: "SM4",
    direction: "decrypt",
    input: sm4Enc.value,
    key: sm4Key,
    iv: "",
    inputEncoding: "hex",
  });
  assert.equal(sm4Dec.value, "hello sm4");

  const pair = generateSm2KeyPair();
  const sm2Enc = await runCipher({
    mode: "SM2",
    direction: "encrypt",
    input: "hello sm2",
    key: "",
    iv: "",
    publicKey: pair.publicKey,
  });
  assert.equal(sm2Enc.ok, true);
  const sm2Dec = await runCipher({
    mode: "SM2",
    direction: "decrypt",
    input: sm2Enc.value,
    key: "",
    iv: "",
    privateKey: pair.privateKey,
    inputEncoding: "hex",
  });
  assert.equal(sm2Dec.value, "hello sm2");
});

test("RSA / SM2 public key derives from private key", () => {
  const rsaPrivate = generateRsaPrivateKeyPem(1024);
  const rsaPublic = publicKeyPemFromRsaPrivateKey(rsaPrivate);
  assert.equal(rsaPublic.ok, true);
  if (!rsaPublic.ok) return;

  const sm2Private = generateSm2PrivateKey();
  const sm2Public = publicKeyFromSm2PrivateKey(sm2Private);
  assert.equal(sm2Public.ok, true);
  if (!sm2Public.ok) return;

  assert.match(rsaPublic.value, /BEGIN PUBLIC KEY/);
  assert.equal(sm2Public.value.startsWith("04"), true);
});

test("RSA-OAEP and RSA-PKCS1-v1_5 round trips", async () => {
  const pair = generateRsaKeyPairPem(1024);
  for (const mode of ["RSA-OAEP", "RSA-PKCS1-v1_5"] as const) {
    const encrypted = await runCipher({
      mode,
      direction: "encrypt",
      input: `hello ${mode}`,
      key: "",
      iv: "",
      publicKey: pair.publicKey,
    });
    assert.equal(encrypted.ok, true, mode);
    const decrypted = await runCipher({
      mode,
      direction: "decrypt",
      input: encrypted.value,
      key: "",
      iv: "",
      privateKey: pair.privateKey,
      inputEncoding: "hex",
    });
    assert.equal(decrypted.value, `hello ${mode}`, mode);
  }
});

test("rejects invalid AES-CTR iv length", async () => {
  const bad = await runCipher({
    mode: "AES-CTR",
    direction: "encrypt",
    input: "x",
    key: suggestedKey(256),
    iv: "00",
  });
  assert.equal(bad.error, "invalid-iv-ctr");
});

test("rejects invalid DES key and XChaCha nonce lengths", async () => {
  const badKey = await runCipher({
    mode: "DES-CBC",
    direction: "encrypt",
    input: "x",
    key: suggestedKey(256),
    iv: suggestedIV("DES-CBC"),
  });
  assert.equal(badKey.error, "invalid-key-length");

  const badIv = await runCipher({
    mode: "XChaCha20-Poly1305",
    direction: "encrypt",
    input: "x",
    key: bytesToHex(randomBytes(32)),
    iv: bytesToHex(randomBytes(12)),
  });
  assert.equal(badIv.error, "invalid-iv-xchacha");
});

test("rejects input larger than the configured maximum", async () => {
  const oversized = "x".repeat(maxCipherInputChars + 1);
  const result = await runCipher({
    mode: "AES-GCM",
    direction: "encrypt",
    input: oversized,
    key: suggestedKey(256),
    iv: suggestedIV("AES-GCM"),
  });
  assert.equal(result.ok, false);
  assert.equal(result.error, "input-too-large");
});
