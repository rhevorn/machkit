import forge from "node-forge";

export const maxCertInput = 200_000;

const PEM_BLOCK =
  /-----BEGIN ([A-Z0-9 ]+)-----([\s\S]*?)-----END \1-----/g;

export type CertificateStatus = "valid" | "expired" | "not-yet-valid";

export type CertificateInfo = {
  type: string;
  pem: string;
  subject: string;
  issuer: string;
  subjectAttrs: Record<string, unknown>;
  issuerAttrs: Record<string, unknown>;
  serialNumber: string;
  notBefore: string;
  notAfter: string;
  notBeforeLocal: string;
  notAfterLocal: string;
  status: CertificateStatus;
  version: number;
  signatureOid: string;
  signatureAlgorithm: string;
  sha1: string;
  sha256: string;
  san: string[];
  isCA: boolean;
};

export type InspectCertificateResult =
  | { ok: true; error: null; certificates: CertificateInfo[]; count: number }
  | { ok: false; error: string; certificates: CertificateInfo[] };

export function extractPemBlocks(input: unknown) {
  const text = String(input ?? "");
  const blocks: Array<{ type: string; pem: string; body: string }> = [];
  let match: RegExpExecArray | null;
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

type CertAttr = { shortName?: string; name?: string; type?: string; value?: unknown };
function attrsToObject(attributes: CertAttr[] = []) {
  const out: Record<string, unknown> = {};
  for (const attr of attributes) {
    const key = attr.shortName || attr.name || attr.type;
    if (!key) continue;
    out[key] = attr.value;
  }
  return out;
}

function formatDn(attributes: CertAttr[] = []) {
  return attributes
    .map((attr) => {
      const key = attr.shortName || attr.name || attr.type;
      return key ? `${key}=${attr.value}` : "";
    })
    .filter(Boolean)
    .join(", ");
}

function fingerprint(
  cert: forge.pki.Certificate,
  md: { create(): { update(msg: string): { digest(): { toHex(): string } } } },
): string {
  const der = forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes();
  const digest = md.create().update(der).digest().toHex();
  return digest.match(/.{2}/g)!.join(":").toUpperCase();
}

export function inspectCertificatePem(input: unknown, now = new Date()): InspectCertificateResult {
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

  const certificates: CertificateInfo[] = [];
  for (const block of blocks) {
    try {
      const cert = forge.pki.certificateFromPem(block.pem);
      const notBefore = cert.validity.notBefore;
      const notAfter = cert.validity.notAfter;
      let status: CertificateStatus = "valid";
      if (now < notBefore) status = "not-yet-valid";
      else if (now > notAfter) status = "expired";

      const sanExt = cert.getExtension("subjectAltName") as
        | { altNames?: Array<{ value?: string; ip?: string }> }
        | null;
      const san: string[] = [];
      if (sanExt?.altNames) {
        for (const item of sanExt.altNames) {
          const entry = item.ip ?? item.value;
          if (entry) san.push(String(entry));
        }
      }

      certificates.push({
        type: block.type,
        pem: block.pem,
        subject: formatDn(cert.subject.attributes as CertAttr[]),
        issuer: formatDn(cert.issuer.attributes as CertAttr[]),
        subjectAttrs: attrsToObject(cert.subject.attributes as CertAttr[]),
        issuerAttrs: attrsToObject(cert.issuer.attributes as CertAttr[]),
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
        isCA: Boolean((cert.getExtension("basicConstraints") as { cA?: boolean } | null)?.cA),
      });
    } catch {
      // Skip unreadable blocks so multi-PEM input can partially succeed.
    }
  }

  if (!certificates.length) return { ok: false, error: "invalid-certificate", certificates: [] };

  return { ok: true, error: null, certificates, count: certificates.length };
}
