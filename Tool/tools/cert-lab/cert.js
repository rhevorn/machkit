import forge from "node-forge";

export const maxCertInput = 200_000;

const PEM_BLOCK =
  /-----BEGIN ([A-Z0-9 ]+)-----([\s\S]*?)-----END \1-----/g;

export function extractPemBlocks(input) {
  const text = String(input ?? "");
  const blocks = [];
  let match;
  const re = new RegExp(PEM_BLOCK.source, "g");
  while ((match = re.exec(text))) {
    blocks.push({
      type: match[1].trim(),
      pem: match[0].trim(),
      body: match[2].replace(/\s+/g, ""),
    });
  }
  return blocks;
}

function attrsToObject(attributes = []) {
  const out = {};
  for (const attr of attributes) {
    const key = attr.shortName || attr.name || attr.type;
    if (!key) continue;
    out[key] = attr.value;
  }
  return out;
}

function formatDn(attributes = []) {
  return attributes
    .map((attr) => {
      const key = attr.shortName || attr.name || attr.type;
      return key ? `${key}=${attr.value}` : "";
    })
    .filter(Boolean)
    .join(", ");
}

function fingerprint(cert, md) {
  const der = forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes();
  const digest = md.create().update(der).digest().toHex();
  return digest.match(/.{2}/g).join(":").toUpperCase();
}

export function inspectCertificatePem(input, now = new Date()) {
  const raw = String(input ?? "").trim();
  if (!raw) return { ok: false, error: "empty", certificates: [] };
  if (raw.length > maxCertInput) return { ok: false, error: "too-large", certificates: [] };

  let blocks = extractPemBlocks(raw).filter((block) => block.type.includes("CERTIFICATE"));
  if (!blocks.length) {
    // Try bare base64 by wrapping as PEM.
    const compact = raw.replace(/\s+/g, "");
    if (/^[A-Za-z0-9+/]+=*$/.test(compact) && compact.length > 100) {
      const wrapped = compact.match(/.{1,64}/g)?.join("\n") || compact;
      blocks = [
        {
          type: "CERTIFICATE",
          pem: `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----`,
          body: compact,
        },
      ];
    }
  }

  if (!blocks.length) return { ok: false, error: "no-certificate", certificates: [] };

  const certificates = [];
  for (const block of blocks) {
    try {
      const cert = forge.pki.certificateFromPem(block.pem);
      const notBefore = cert.validity.notBefore;
      const notAfter = cert.validity.notAfter;
      let status = "valid";
      if (now < notBefore) status = "not-yet-valid";
      else if (now > notAfter) status = "expired";

      const sanExt = cert.getExtension("subjectAltName");
      const san = [];
      if (sanExt?.altNames) {
        for (const item of sanExt.altNames) {
          if (item.value) san.push(String(item.value));
        }
      }

      certificates.push({
        type: block.type,
        pem: block.pem,
        subject: formatDn(cert.subject.attributes),
        issuer: formatDn(cert.issuer.attributes),
        subjectAttrs: attrsToObject(cert.subject.attributes),
        issuerAttrs: attrsToObject(cert.issuer.attributes),
        serialNumber: (cert.serialNumber || "").toUpperCase(),
        notBefore: notBefore.toISOString(),
        notAfter: notAfter.toISOString(),
        notBeforeLocal: notBefore.toLocaleString(),
        notAfterLocal: notAfter.toLocaleString(),
        status,
        version: (cert.version ?? 0) + 1,
        signatureOid: cert.signatureOid || "",
        signatureAlgorithm: cert.siginfo?.algorithmOid || cert.signatureOid || "",
        sha1: fingerprint(cert, forge.md.sha1),
        sha256: fingerprint(cert, forge.md.sha256),
        san,
        isCA: Boolean(cert.getExtension("basicConstraints")?.cA),
      });
    } catch {
      return { ok: false, error: "invalid-certificate", certificates: [] };
    }
  }

  return { ok: true, error: null, certificates, count: certificates.length };
}
