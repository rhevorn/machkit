import React, { useEffect, useMemo, useRef, useState } from "react";
import { CopySimple, DownloadSimple, Eraser, Image as ImageIcon } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  ResultPanel,
  SegmentedControl,
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
import {
  defaultSize,
  errorLevels,
  generateQRDataURL,
  maxSize,
  minSize,
  resolveSize,
} from "./qr.js";
import { messages } from "./messages.js";

/** Compact window ≈ 720px; content pad ~56 → ~664. Right 280 fits 256px QR + panel pad. */
const PREVIEW_COLUMN = "280px";
const PREVIEW_MAX = 248;

function QrCodeTool() {
  const text = useToolMessages(messages);
  const logoInputRef = useRef(null);
  const [content, setContent] = useState("https://machkit.app");
  const [sizeText, setSizeText] = useState(String(defaultSize));
  const [errorLevel, setErrorLevel] = useState("M");
  const [logoDataURL, setLogoDataURL] = useState("");
  const [result, setResult] = useState({ ok: false, error: "empty" });
  const [busy, setBusy] = useState(false);

  const size = useMemo(() => resolveSize(sizeText), [sizeText]);
  const levelOptions = useMemo(
    () => errorLevels.map((value) => ({ value, label: value })),
    [],
  );

  useEffect(() => {
    let cancelled = false;
    setBusy(true);
    generateQRDataURL(content, {
      size,
      errorLevel: logoDataURL ? "H" : errorLevel,
      logoDataURL: logoDataURL || undefined,
    }).then((next) => {
      if (!cancelled) {
        setResult(next);
        setBusy(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [content, size, errorLevel, logoDataURL]);

  const status = !content.trim()
    ? { tone: "neutral", label: text.empty }
    : result.error === "too-large"
      ? { tone: "danger", label: text.tooLarge }
      : result.error === "logo-failed"
        ? { tone: "danger", label: text.failed }
        : !result.ok
          ? { tone: "danger", label: text.failed }
          : {
              tone: "info",
              label: busy
                ? text.generate
                : `${result.bytes} ${text.bytes} · ${result.width}px · ${result.errorCorrectionLevel}${
                    result.logoApplied ? ` · ${text.logo}` : ""
                  }`,
            };

  const previewSide = result.ok ? Math.min(result.width, PREVIEW_MAX) : PREVIEW_MAX;

  function downloadPng() {
    if (!result.ok || !result.dataURL) return;
    const link = document.createElement("a");
    link.href = result.dataURL;
    link.download = "qrcode.png";
    link.click();
  }

  function onLogoFile(file) {
    if (!file || !String(file.type || "").startsWith("image/")) return;
    const reader = new FileReader();
    reader.onload = () => {
      setLogoDataURL(String(reader.result || ""));
      setErrorLevel("H");
    };
    reader.readAsDataURL(file);
  }

  function clearLogo() {
    setLogoDataURL("");
  }

  function commitSize() {
    setSizeText(String(resolveSize(sizeText)));
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="flex-wrap gap-y-2 border-b border-border pb-3">
          <div className="flex items-center gap-2">
            <span className="machkit-control-label shrink-0">{text.size}</span>
            <Input
              className="w-[88px] shrink-0 text-center font-mono"
              inputMode="numeric"
              value={sizeText}
              onChange={(event) => setSizeText(event.target.value.replace(/[^\d]/g, ""))}
              onBlur={commitSize}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.currentTarget.blur();
                }
              }}
              aria-label={text.size}
              title={`${minSize}–${maxSize}px`}
            />
            <span className="text-xs text-tertiary">px</span>
          </div>

          <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />

          <div className="flex min-w-0 items-center gap-2">
            <span className="machkit-control-label shrink-0">{text.errorLevel}</span>
            <SegmentedControl
              value={logoDataURL ? "H" : errorLevel}
              onChange={(value) => {
                if (!logoDataURL) setErrorLevel(value);
              }}
              label={text.errorLevel}
              size="compact"
              className={`w-[168px] shrink-0${logoDataURL ? " pointer-events-none opacity-60" : ""}`}
              options={levelOptions}
            />
          </div>

          <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />

          <div className="flex items-center gap-1">
            <span className="machkit-control-label shrink-0">{text.logo}</span>
            <Button variant="ghost" size="sm" onClick={() => logoInputRef.current?.click()}>
              <ImageIcon size={15} />
              {logoDataURL ? text.changeLogo : text.addLogo}
            </Button>
            {logoDataURL ? (
              <Button variant="ghost" size="sm" onClick={clearLogo}>
                {text.clearLogo}
              </Button>
            ) : null}
            <input
              ref={logoInputRef}
              type="file"
              accept="image/png,image/jpeg,image/webp,image/svg+xml,.png,.jpg,.jpeg,.webp,.svg"
              className="hidden"
              onChange={(event) => {
                onLogoFile(event.target.files?.[0]);
                event.target.value = "";
              }}
            />
          </div>
        </ToolToolbar>

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>
        {logoDataURL ? (
          <p className="text-[11px] text-tertiary">{text.logoHint}</p>
        ) : null}

        <div
          className="grid w-full items-stretch gap-3"
          style={{ gridTemplateColumns: `minmax(0, 1fr) ${PREVIEW_COLUMN}` }}
        >
          <div className="flex min-h-0 min-w-0 flex-col gap-1.5">
            <label htmlFor="qr-content" className="machkit-control-label">
              {text.content}
            </label>
            <Textarea
              id="qr-content"
              className="min-h-[240px] flex-1 font-mono text-[12px]"
              value={content}
              onChange={(event) => setContent(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>

          <div className="flex min-h-0 min-w-0 flex-col gap-1.5">
            <span className="machkit-control-label">{text.preview}</span>
            <ResultPanel
              className="flex min-h-[240px] flex-1 flex-col"
              bodyClassName="flex min-h-[240px] flex-1 flex-col items-center justify-center p-4"
            >
              {result.ok ? (
                <img
                  src={result.dataURL}
                  alt={text.preview}
                  width={previewSide}
                  height={previewSide}
                  className="rounded-sm bg-white"
                  style={{ width: previewSide, height: previewSide }}
                />
              ) : (
                <p className="text-xs text-tertiary">{text.empty}</p>
              )}
            </ResultPanel>
          </div>
        </div>

        <ToolToolbar className="border-t border-border pt-3">
          <ActionGroup className="ml-0">
            <Button variant="ghost" size="sm" disabled={!content.trim()} onClick={() => machkit.copy(content)}>
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button variant="ghost" size="sm" disabled={!result.ok} onClick={downloadPng}>
              <DownloadSimple size={15} />
              {text.download}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setContent("");
                clearLogo();
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </ActionGroup>
        </ToolToolbar>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<QrCodeTool />, { name: "QR Code" });
