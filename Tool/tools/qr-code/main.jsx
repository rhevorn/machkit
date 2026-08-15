import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, DownloadSimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  SegmentedControl,
  SelectControl,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { errorLevels, generateQRDataURL, sizes } from "./qr.js";
import { messages } from "./messages.js";

function QrCodeTool() {
  const text = useToolMessages(messages);
  const [content, setContent] = useState("https://machkit.app");
  const [size, setSize] = useState(256);
  const [errorLevel, setErrorLevel] = useState("M");
  const [result, setResult] = useState({ ok: false, error: "empty" });
  const [busy, setBusy] = useState(false);

  const sizeOptions = useMemo(
    () => sizes.map((value) => ({ value: String(value), label: `${value}px` })),
    [],
  );
  const levelOptions = useMemo(
    () => errorLevels.map((value) => ({ value, label: value })),
    [],
  );

  useEffect(() => {
    let cancelled = false;
    setBusy(true);
    generateQRDataURL(content, { size, errorLevel }).then((next) => {
      if (!cancelled) {
        setResult(next);
        setBusy(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [content, size, errorLevel]);

  const status = !content.trim()
    ? { tone: "neutral", label: text.empty }
    : result.error === "too-large"
      ? { tone: "danger", label: text.tooLarge }
      : !result.ok
        ? { tone: "danger", label: text.failed }
        : {
            tone: "info",
            label: busy
              ? text.generate
              : `${result.bytes} ${text.bytes} · ${result.width}px · ${result.errorCorrectionLevel}`,
          };

  function downloadPng() {
    if (!result.ok || !result.dataURL) return;
    const link = document.createElement("a");
    link.href = result.dataURL;
    link.download = "qrcode.png";
    link.click();
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar flex-wrap gap-x-3 gap-y-2">
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.size}</span>
            <SelectControl
              value={String(size)}
              onChange={(value) => setSize(Number(value))}
              label={text.size}
              className="w-[110px] flex-none"
              options={sizeOptions}
            />
          </div>
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.errorLevel}</span>
            <SegmentedControl
              value={errorLevel}
              onChange={setErrorLevel}
              label={text.errorLevel}
              size="compact"
              className="w-[180px] flex-none"
              options={levelOptions}
            />
          </div>
          <div className="ml-auto flex items-center gap-1">
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
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-3 lg:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <label htmlFor="qr-content" className="machkit-control-label">
              {text.content}
            </label>
            <Textarea
              id="qr-content"
              className="min-h-[180px] font-mono text-[12px]"
              value={content}
              onChange={(event) => setContent(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>

          <div className="machkit-panel flex min-h-[220px] items-center justify-center p-4">
            {result.ok ? (
              <img
                src={result.dataURL}
                alt={text.preview}
                width={result.width}
                height={result.width}
                className="max-h-full max-w-full rounded-sm bg-white"
              />
            ) : (
              <p className="text-xs text-tertiary">{text.empty}</p>
            )}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<QrCodeTool />, { name: "QR Code" });
