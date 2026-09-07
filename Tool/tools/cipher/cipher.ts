import { chacha20poly1305, xchacha20poly1305 } from "@noble/ciphers/chacha.js";
import forge from "node-forge";
import smCrypto from "sm-crypto";
import {
  bytesToBase64,
  bytesToHex,
  decodeBytes,
  encodeBytes,
  forgeBytesFromUint8,
  randomBytes,
  uint8FromForgeBytes,
  type ByteEncoding,
  type CipherPayloadEncoding,
} from "./cipher-bytes.js";

export type CipherDirection = "encrypt" | "decrypt";
export type CipherBackend = "webcrypto" | "forge" | "noble" | "sm";

export type CipherMode =
  | "AES-GCM"
  | "AES-CBC"
  | "AES-CTR"
  | "AES-ECB"
  | "ChaCha20-Poly1305"
  | "XChaCha20-Poly1305"
  | "RSA-OAEP"
  | "RSA-PKCS1-v1_5"
  | "DES-CBC"
  | "3DES-CBC"
  | "SM4"
  | "SM2";

export type CipherAlgorithmMeta = {
  id: CipherMode;
  code: string;
  group: "aes" | "chacha" | "rsa" | "des" | "sm";
  backend: CipherBackend;
  needsIV: boolean;
  ivLength: number | null;
  keyBytes: number[] | null;
  asymmetric: boolean;
};

type ForgeBlockAlgorithm = "AES-ECB" | "DES-CBC" | "3DES-CBC";
type RsaPadding = "RSA-OAEP" | "RSAES-PKCS1-V1_5";

export const cipherAlgorithmCatalog: readonly CipherAlgorithmMeta[] = Object.freeze([
  { id: "AES-GCM", code: "GCM", group: "aes", backend: "webcrypto", needsIV: true, ivLength: 12, keyBytes: [16, 24, 32], asymmetric: false },
  { id: "AES-CBC", code: "CBC", group: "aes", backend: "webcrypto", needsIV: true, ivLength: 16, keyBytes: [16, 24, 32], asymmetric: false },
  { id: "AES-CTR", code: "CTR", group: "aes", backend: "webcrypto", needsIV: true, ivLength: 16, keyBytes: [16, 24, 32], asymmetric: false },
  { id: "AES-ECB", code: "ECB", group: "aes", backend: "forge", needsIV: false, ivLength: null, keyBytes: [16, 24, 32], asymmetric: false },
  { id: "ChaCha20-Poly1305", code: "Cha", group: "chacha", backend: "noble", needsIV: true, ivLength: 12, keyBytes: [32], asymmetric: false },
  { id: "XChaCha20-Poly1305", code: "XCh", group: "chacha", backend: "noble", needsIV: true, ivLength: 24, keyBytes: [32], asymmetric: false },
  { id: "RSA-OAEP", code: "OAE", group: "rsa", backend: "forge", needsIV: false, ivLength: null, keyBytes: null, asymmetric: true },
  { id: "RSA-PKCS1-v1_5", code: "PK1", group: "rsa", backend: "forge", needsIV: false, ivLength: null, keyBytes: null, asymmetric: true },
  { id: "DES-CBC", code: "DES", group: "des", backend: "forge", needsIV: true, ivLength: 8, keyBytes: [8], asymmetric: false },
  { id: "3DES-CBC", code: "3DE", group: "des", backend: "forge", needsIV: true, ivLength: 8, keyBytes: [16, 24], asymmetric: false },
  { id: "SM4", code: "SM4", group: "sm", backend: "sm", needsIV: false, ivLength: null, keyBytes: [16], asymmetric: false },
  { id: "SM2", code: "SM2", group: "sm", backend: "sm", needsIV: false, ivLength: null, keyBytes: null, asymmetric: true },
]);

export const cipherAlgorithmGroups = Object.freeze([
  { id: "aes" as const, items: cipherAlgorithmCatalog.filter((item) => item.group === "aes") },
  { id: "chacha" as const, items: cipherAlgorithmCatalog.filter((item) => item.group === "chacha") },
  { id: "rsa" as const, items: cipherAlgorithmCatalog.filter((item) => item.group === "rsa") },
  { id: "des" as const, items: cipherAlgorithmCatalog.filter((item) => item.group === "des") },
  { id: "sm" as const, items: cipherAlgorithmCatalog.filter((item) => item.group === "sm") },
]);

export const cipherModes = Object.freeze(cipherAlgorithmCatalog.map((item) => item.id));
export const byteEncodings = Object.freeze(["utf8", "hex", "base64"] as const);
export const payloadEncodings = Object.freeze(["utf8", "hex", "base64"] as const);
export const outputEncodings = Object.freeze(["hex", "base64"] as const);

export type CipherParams = {
  mode: CipherMode;
  direction: CipherDirection;
  input: string;
  key: string;
  iv: string;
  publicKey?: string;
  privateKey?: string;
  keyEncoding?: ByteEncoding;
  ivEncoding?: ByteEncoding;
  inputEncoding?: CipherPayloadEncoding;
  outputEncoding?: "hex" | "base64";
};

export type CipherResult = {
  ok: boolean;
  value: string;
  error: string | null;
};

export type RsaKeyPairPem = {
  publicKey: string;
  privateKey: string;
};

const MAX_INPUT_CHARS = 2_000_000;
const { sm2, sm4 } = smCrypto as {
  sm2: {
    generateKeyPairHex: () => { publicKey: string; privateKey: string };
    getPublicKeyFromPrivateKey: (privateKey: string) => string;
    doEncrypt: (msg: string, publicKey: string, cipherMode?: number) => string;
    doDecrypt: (cipherModeText: string, privateKey: string, cipherMode?: number) => string;
  };
  sm4: {
    encrypt: (msg: string, key: string, options?: Record<string, unknown>) => string;
    decrypt: (cipherText: string, key: string, options?: Record<string, unknown>) => string;
  };
};

export function getAlgorithmMeta(mode: CipherMode): CipherAlgorithmMeta {
  const meta = cipherAlgorithmCatalog.find((item) => item.id === mode);
  if (!meta) throw new Error(`unknown-mode:${mode}`);
  return meta;
}

export function suggestedKey(bits = 256, encoding: ByteEncoding = "hex"): string {
  if (!Number.isInteger(bits) || bits <= 0 || bits % 8 !== 0) {
    throw new Error(`invalid-key-bits:${bits}`);
  }
  return encodeSuggested(randomBytes(bits / 8), encoding);
}

export function suggestedKeyForMode(mode: CipherMode, encoding: ByteEncoding = "hex"): string {
  const meta = getAlgorithmMeta(mode);
  const bytes = meta.keyBytes?.[meta.keyBytes.length - 1] ?? 32;
  return suggestedKey(bytes * 8, encoding);
}

export function suggestedIV(mode: CipherMode, encoding: ByteEncoding = "hex"): string {
  const meta = getAlgorithmMeta(mode);
  const length = meta.ivLength ?? 16;
  return encodeSuggested(randomBytes(length), encoding);
}

function encodeSuggested(bytes: Uint8Array, encoding: ByteEncoding): string {
  if (encoding === "base64") return bytesToBase64(bytes);
  return bytesToHex(bytes);
}

export function generateRsaKeyPairPem(bits = 2048): RsaKeyPairPem {
  const privateKey = generateRsaPrivateKeyPem(bits);
  const derived = publicKeyPemFromRsaPrivateKey(privateKey);
  if (!derived.ok) throw new Error(derived.error);
  return { publicKey: derived.value, privateKey };
}

export function generateRsaPrivateKeyPem(bits = 2048): string {
  const pair = forge.pki.rsa.generateKeyPair({ bits, e: 0x10001 });
  return forge.pki.privateKeyToPem(pair.privateKey);
}

export function publicKeyPemFromRsaPrivateKey(privatePem: string): { ok: true; value: string } | { ok: false; error: string } {
  try {
    const privateKey = forge.pki.privateKeyFromPem(privatePem.trim());
    const publicKey = forge.pki.setRsaPublicKey(privateKey.n, privateKey.e);
    return { ok: true, value: forge.pki.publicKeyToPem(publicKey) };
  } catch {
    return { ok: false, error: "invalid-private-key" };
  }
}

export function generateSm2KeyPair(): RsaKeyPairPem {
  const privateKey = generateSm2PrivateKey();
  const derived = publicKeyFromSm2PrivateKey(privateKey);
  if (!derived.ok) throw new Error(derived.error);
  return { publicKey: derived.value, privateKey };
}

export function generateSm2PrivateKey(): string {
  return sm2.generateKeyPairHex().privateKey;
}

export function publicKeyFromSm2PrivateKey(privateKeyHex: string): { ok: true; value: string } | { ok: false; error: string } {
  try {
    const publicKey = sm2.getPublicKeyFromPrivateKey(privateKeyHex.trim());
    if (!publicKey) return { ok: false, error: "invalid-private-key" };
    return { ok: true, value: publicKey };
  } catch {
    return { ok: false, error: "invalid-private-key" };
  }
}

function finishOutput(
  bytes: Uint8Array,
  direction: CipherDirection,
  outputEncoding: "hex" | "base64",
): CipherResult {
  if (direction === "encrypt") {
    const encoded = encodeBytes(bytes, outputEncoding);
    return encoded.ok ? { ok: true, value: encoded.value, error: null } : { ok: false, value: "", error: encoded.error };
  }
  const asText = encodeBytes(bytes, "utf8");
  if (asText.ok) return { ok: true, value: asText.value, error: null };
  const fallback = encodeBytes(bytes, outputEncoding);
  return fallback.ok
    ? { ok: true, value: fallback.value, error: null }
    : { ok: false, value: "", error: "decrypt-failed" };
}

function validateSymmetricKey(meta: CipherAlgorithmMeta, bytes: Uint8Array): string | null {
  if (!meta.keyBytes) return null;
  return meta.keyBytes.includes(bytes.length) ? null : "invalid-key-length";
}

function ivErrorFor(meta: CipherAlgorithmMeta): string {
  if (meta.ivLength === 24) return "invalid-iv-xchacha";
  if (meta.ivLength === 12) return "invalid-iv-gcm";
  if (meta.ivLength === 8) return "invalid-iv-8";
  if (meta.id === "AES-CTR") return "invalid-iv-ctr";
  return "invalid-iv-cbc";
}

async function runWebCryptoAes(
  meta: CipherAlgorithmMeta,
  direction: CipherDirection,
  key: Uint8Array,
  iv: Uint8Array,
  payload: Uint8Array,
  outputEncoding: "hex" | "base64",
): Promise<CipherResult> {
  const name = meta.id as "AES-GCM" | "AES-CBC" | "AES-CTR";
  const cryptoKey = await crypto.subtle.importKey("raw", key as BufferSource, { name }, false, ["encrypt", "decrypt"]);
  try {
    if (direction === "encrypt") {
      const encrypted = new Uint8Array(
        await crypto.subtle.encrypt(
          name === "AES-CTR"
            ? { name, counter: iv as BufferSource, length: 64 }
            : { name, iv: iv as BufferSource },
          cryptoKey,
          payload as BufferSource,
        ),
      );
      return finishOutput(encrypted, direction, outputEncoding);
    }
    const decrypted = new Uint8Array(
      await crypto.subtle.decrypt(
        name === "AES-CTR"
          ? { name, counter: iv as BufferSource, length: 64 }
          : { name, iv: iv as BufferSource },
        cryptoKey,
        payload as BufferSource,
      ),
    );
    return finishOutput(decrypted, direction, outputEncoding);
  } catch {
    return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
  }
}

function runForgeBlockCipher(
  algorithm: ForgeBlockAlgorithm,
  direction: CipherDirection,
  key: Uint8Array,
  iv: Uint8Array | null,
  payload: Uint8Array,
  outputEncoding: "hex" | "base64",
): CipherResult {
  try {
    const keyBin = forgeBytesFromUint8(key);
    const startOptions = iv ? { iv: forgeBytesFromUint8(iv) } : {};
    if (direction === "encrypt") {
      const cipher = forge.cipher.createCipher(algorithm, keyBin);
      cipher.start(startOptions);
      cipher.update(forge.util.createBuffer(forgeBytesFromUint8(payload)));
      if (!cipher.finish()) return { ok: false, value: "", error: "encrypt-failed" };
      return finishOutput(uint8FromForgeBytes(cipher.output.getBytes()), direction, outputEncoding);
    }
    const decipher = forge.cipher.createDecipher(algorithm, keyBin);
    decipher.start(startOptions);
    decipher.update(forge.util.createBuffer(forgeBytesFromUint8(payload)));
    if (!decipher.finish()) return { ok: false, value: "", error: "decrypt-failed" };
    return finishOutput(uint8FromForgeBytes(decipher.output.getBytes()), direction, outputEncoding);
  } catch {
    return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
  }
}

function runRsa(
  padding: RsaPadding,
  direction: CipherDirection,
  publicPem: string,
  privatePem: string,
  payload: Uint8Array,
  outputEncoding: "hex" | "base64",
): CipherResult {
  try {
    if (direction === "encrypt") {
      if (!publicPem.trim()) return { ok: false, value: "", error: "missing-public-key" };
      const publicKey = forge.pki.publicKeyFromPem(publicPem);
      const encrypted =
        padding === "RSA-OAEP"
          ? publicKey.encrypt(forgeBytesFromUint8(payload), "RSA-OAEP", {
              md: forge.md.sha256.create(),
              mgf1: { md: forge.md.sha256.create() },
            })
          : publicKey.encrypt(forgeBytesFromUint8(payload), "RSAES-PKCS1-V1_5");
      return finishOutput(uint8FromForgeBytes(encrypted), direction, outputEncoding);
    }
    if (!privatePem.trim()) return { ok: false, value: "", error: "missing-private-key" };
    const privateKey = forge.pki.privateKeyFromPem(privatePem);
    const decrypted =
      padding === "RSA-OAEP"
        ? privateKey.decrypt(forgeBytesFromUint8(payload), "RSA-OAEP", {
            md: forge.md.sha256.create(),
            mgf1: { md: forge.md.sha256.create() },
          })
        : privateKey.decrypt(forgeBytesFromUint8(payload), "RSAES-PKCS1-V1_5");
    return finishOutput(uint8FromForgeBytes(decrypted), direction, outputEncoding);
  } catch {
    return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
  }
}

export async function runCipher(params: CipherParams): Promise<CipherResult> {
  const mode = params.mode;
  const meta = getAlgorithmMeta(mode);
  const direction = params.direction;
  const keyEncoding = params.keyEncoding ?? "hex";
  const ivEncoding = params.ivEncoding ?? "hex";
  const inputEncoding = params.inputEncoding ?? (direction === "encrypt" ? "utf8" : "hex");
  const outputEncoding = params.outputEncoding ?? "hex";
  const input = String(params.input ?? "");

  if (input.length > MAX_INPUT_CHARS) return { ok: false, value: "", error: "input-too-large" };

  if (meta.asymmetric) {
    const payloadParsed = decodeBytes(input, inputEncoding === "utf8" ? "utf8" : inputEncoding);
    if (!payloadParsed.ok) return { ok: false, value: "", error: payloadParsed.error };
    if (mode === "RSA-OAEP") {
      return runRsa("RSA-OAEP", direction, params.publicKey ?? "", params.privateKey ?? "", payloadParsed.bytes, outputEncoding);
    }
    if (mode === "RSA-PKCS1-v1_5") {
      return runRsa("RSAES-PKCS1-V1_5", direction, params.publicKey ?? "", params.privateKey ?? "", payloadParsed.bytes, outputEncoding);
    }
    if (mode === "SM2") {
      try {
        if (direction === "encrypt") {
          if (!(params.publicKey ?? "").trim()) return { ok: false, value: "", error: "missing-public-key" };
          const cipherHex = sm2.doEncrypt(new TextDecoder().decode(payloadParsed.bytes), params.publicKey!.trim(), 1);
          return { ok: true, value: cipherHex, error: null };
        }
        if (!(params.privateKey ?? "").trim()) return { ok: false, value: "", error: "missing-private-key" };
        const plain = sm2.doDecrypt(input.replace(/\s+/g, ""), params.privateKey!.trim(), 1);
        if (!plain && plain !== "") return { ok: false, value: "", error: "decrypt-failed" };
        return { ok: true, value: plain, error: null };
      } catch {
        return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
      }
    }
  }

  const keyText = String(params.key ?? "");
  if (!keyText.trim()) return { ok: false, value: "", error: "missing-key" };
  const keyParsed = decodeBytes(keyText.trim(), keyEncoding);
  if (!keyParsed.ok) return { ok: false, value: "", error: keyParsed.error };
  const keyError = validateSymmetricKey(meta, keyParsed.bytes);
  if (keyError) return { ok: false, value: "", error: keyError };

  let ivBytes: Uint8Array | null = null;
  if (meta.needsIV) {
    const ivText = String(params.iv ?? "");
    if (!ivText.trim()) return { ok: false, value: "", error: "missing-iv" };
    const ivParsed = decodeBytes(ivText.trim(), ivEncoding);
    if (!ivParsed.ok) return { ok: false, value: "", error: ivParsed.error };
    if (meta.ivLength != null && ivParsed.bytes.length !== meta.ivLength) {
      return { ok: false, value: "", error: ivErrorFor(meta) };
    }
    ivBytes = ivParsed.bytes;
  }

  const payloadParsed = decodeBytes(input, inputEncoding === "utf8" ? "utf8" : inputEncoding);
  if (!payloadParsed.ok) return { ok: false, value: "", error: payloadParsed.error };

  if (meta.backend === "webcrypto" && (mode === "AES-GCM" || mode === "AES-CBC" || mode === "AES-CTR")) {
    return runWebCryptoAes(meta, direction, keyParsed.bytes, ivBytes!, payloadParsed.bytes, outputEncoding);
  }

  if (meta.backend === "forge" && (mode === "AES-ECB" || mode === "DES-CBC" || mode === "3DES-CBC")) {
    return runForgeBlockCipher(mode, direction, keyParsed.bytes, ivBytes, payloadParsed.bytes, outputEncoding);
  }

  if (meta.backend === "noble" && mode === "ChaCha20-Poly1305") {
    try {
      const cipher = chacha20poly1305(keyParsed.bytes, ivBytes!);
      if (direction === "encrypt") {
        return finishOutput(cipher.encrypt(payloadParsed.bytes), direction, outputEncoding);
      }
      return finishOutput(cipher.decrypt(payloadParsed.bytes), direction, outputEncoding);
    } catch {
      return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
    }
  }

  if (meta.backend === "noble" && mode === "XChaCha20-Poly1305") {
    try {
      const cipher = xchacha20poly1305(keyParsed.bytes, ivBytes!);
      if (direction === "encrypt") {
        return finishOutput(cipher.encrypt(payloadParsed.bytes), direction, outputEncoding);
      }
      return finishOutput(cipher.decrypt(payloadParsed.bytes), direction, outputEncoding);
    } catch {
      return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
    }
  }

  if (meta.backend === "sm" && mode === "SM4") {
    try {
      const keyHex = bytesToHex(keyParsed.bytes);
      if (direction === "encrypt") {
        const text = new TextDecoder().decode(payloadParsed.bytes);
        const cipherHex = sm4.encrypt(text, keyHex);
        return { ok: true, value: cipherHex, error: null };
      }
      const plain = sm4.decrypt(input.replace(/\s+/g, ""), keyHex);
      return { ok: true, value: plain, error: null };
    } catch {
      return { ok: false, value: "", error: direction === "encrypt" ? "encrypt-failed" : "decrypt-failed" };
    }
  }

  return { ok: false, value: "", error: "unsupported" };
}

export {
  decodeBytes,
  encodeBytes,
  bytesToHex,
  bytesToBase64,
  randomBytes,
  type ByteEncoding,
  type CipherPayloadEncoding,
} from "./cipher-bytes.js";
