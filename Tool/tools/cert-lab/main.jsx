import React, { useMemo, useRef, useState } from "react";
import { CopySimple, Eraser, UploadSimple } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  PropertyList,
  PropertyRow,
  ResultPanel,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { inspectCertificatePem } from "./cert.js";
import { messages } from "./messages.js";

function statusLabel(text, status) {
  if (status === "expired") return text.statusExpired;
  if (status === "not-yet-valid") return text.statusNotYetValid;
  return text.statusValid;
}

function CertPanel({ cert, index, text }) {
  const validity = `${cert.notBeforeLocal} → ${cert.notAfterLocal}`;
  const san = cert.san?.length ? cert.san.join(", ") : "";

  return (
    <ResultPanel
      title={
        <>
          #{index + 1}
          <span className="mx-2 text-border">|</span>
          <span className={cert.status === "valid" ? "text-foreground" : "text-danger"}>
            {statusLabel(text, cert.status)}
          </span>
          {cert.isCA ? (
            <>
              <span className="mx-2 text-border">|</span>
              <span className="text-secondary">{text.isCA}</span>
            </>
          ) : null}
        </>
      }
      actions={
        <Button variant="ghost" size="sm" onClick={() => machkit.copy(cert.pem)}>
          <CopySimple size={15} />
          {text.copyPem}
        </Button>
      }
    >
      <PropertyList>
        <PropertyRow label={text.subject} value={cert.subject} copyLabel={text.copy} />
        <PropertyRow label={text.issuer} value={cert.issuer} copyLabel={text.copy} />
        <PropertyRow label={text.serial} value={cert.serialNumber} copyLabel={text.copy} />
        <PropertyRow label={text.validity} value={validity} copyLabel={text.copy} mono={false} />
        <PropertyRow label={text.sha1} value={cert.sha1} copyLabel={text.copy} />
        <PropertyRow label={text.sha256} value={cert.sha256} copyLabel={text.copy} />
        <PropertyRow label={text.san} value={san || text.none} copyLabel={text.copy} />
      </PropertyList>
    </ResultPanel>
  );
}

function CertLabTool() {
  const text = useToolMessages(messages);
  const fileRef = useRef(null);
  const [pem, setPem] = useState("");

  const result = useMemo(() => inspectCertificatePem(pem), [pem]);

  const status = !pem.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label:
            result.error === "too-large"
              ? text.tooLarge
              : result.error === "no-certificate"
                ? text.noCertificate
                : text.invalidCertificate,
        }
      : {
          tone: result.certificates.some((c) => c.status !== "valid") ? "danger" : "info",
          label: `${result.count} ${text.found}`,
        };

  function onImportFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setPem(String(reader.result || ""));
    reader.readAsText(file);
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="gap-2">
          <span className="machkit-control-label shrink-0">{text.pem}</span>
          <div className="mx-1 h-5 w-px shrink-0 bg-border" aria-hidden="true" />
          <ActionGroup>
            <Button variant="ghost" size="sm" onClick={() => fileRef.current?.click()}>
              <UploadSimple size={15} />
              {text.import}
            </Button>
            <input
              ref={fileRef}
              type="file"
              accept=".pem,.crt,.cer,.txt,application/x-pem-file,application/pkix-cert,text/plain"
              className="hidden"
              onChange={(event) => {
                onImportFile(event.target.files?.[0]);
                event.target.value = "";
              }}
            />
            <Button variant="ghost" size="sm" disabled={!pem.trim()} onClick={() => machkit.copy(pem.trim())}>
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button variant="ghost" size="sm" onClick={() => setPem("")}>
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </ActionGroup>
        </ToolToolbar>

        <Textarea
          className="min-h-[120px] font-mono text-[12px]"
          value={pem}
          onChange={(event) => setPem(event.target.value)}
          placeholder={text.placeholder}
          spellCheck={false}
        />

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        {result.ok
          ? result.certificates.map((cert, index) => (
              <CertPanel key={`${cert.serialNumber}-${index}`} cert={cert} index={index} text={text} />
            ))
          : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CertLabTool />, { name: "Certificate Lab" });
