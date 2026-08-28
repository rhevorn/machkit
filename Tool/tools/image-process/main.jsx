import React, { useMemo, useRef, useState } from "react";
import { DownloadSimple, Eraser, Image as ImageIcon, Trash, UploadSimple } from "@phosphor-icons/react";
import JSZip from "jszip";
import {
  Button,
  CheckboxField,
  InlineMessage,
  Input,
  SegmentedControl,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  defaultQuality,
  defaultTargetKB,
  dimensionUnits,
  formatBytes,
  maxBatchCount,
  parseTargetSize,
  processImage,
  ratioLabel,
  validateBatch,
} from "./image.js";
import { messages } from "./messages.js";

function parseDimensionInput(value) {
  const text = String(value ?? "").trim().toLowerCase();
  if (!text || text === "auto") return 0;
  const n = Number(text);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1_000);
}

function ImageProcessTool() {
  const text = useToolMessages(messages);
  const inputRef = useRef(null);
  const [items, setItems] = useState([]);
  const [format, setFormat] = useState("jpeg");
  const [mode, setMode] = useState("quality");
  const [quality, setQuality] = useState(defaultQuality);
  const [targetAmount, setTargetAmount] = useState(String(defaultTargetKB));
  const [targetUnit, setTargetUnit] = useState("KB");
  const [width, setWidth] = useState("");
  const [height, setHeight] = useState("");
  const [dimUnit, setDimUnit] = useState("px");
  const [lockAspect, setLockAspect] = useState(true);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(null);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState("");

  const formatOptions = useMemo(
    () => [
      { value: "keep", label: text.keep },
      { value: "jpeg", label: "JPEG" },
      { value: "png", label: "PNG" },
      { value: "webp", label: "WebP" },
    ],
    [text.keep],
  );

  const modeOptions = useMemo(
    () => [
      { value: "quality", label: text.modeQuality },
      { value: "size", label: text.modeSize },
      { value: "dimensions", label: text.modeDimensions },
    ],
    [text.modeQuality, text.modeSize, text.modeDimensions],
  );

  const unitOptions = useMemo(
    () => [
      { value: "KB", label: text.unitKB },
      { value: "MB", label: text.unitMB },
    ],
    [text.unitKB, text.unitMB],
  );

  const dimUnitOptions = useMemo(
    () => dimensionUnits.map((unit) => ({ value: unit, label: unit })),
    [],
  );

  const doneCount = items.filter((item) => item.result?.ok).length;
  const progressPercent = progress?.total
    ? Math.round((progress.current / progress.total) * 100)
    : 0;
  const status = error
    ? { tone: "danger", label: error }
    : busy && progress
      ? {
          tone: "info",
          label: `${text.processing} ${progress.current} / ${progress.total}`,
        }
      : !items.length
        ? { tone: "neutral", label: text.empty }
        : doneCount
          ? { tone: "info", label: `${text.done} · ${doneCount}/${items.length}` }
          : { tone: "neutral", label: `${items.length} / ${maxBatchCount}` };

  function addFiles(fileList) {
    const images = Array.from(fileList || []).filter((file) =>
      String(file.type || "").startsWith("image/") ||
      /\.(jpe?g|png|webp|gif|bmp|tiff?|heic|heif|avif|ico|svg)$/i.test(file.name),
    );
    const next = validateBatch([...items.map((item) => item.file), ...images]);
    if (!next.ok) {
      setError(next.error === "too-many" ? text.tooMany : text.empty);
      return;
    }
    setError("");
    setItems((prev) => {
      const existing = new Set(prev.map((item) => `${item.file.name}:${item.file.size}:${item.file.lastModified}`));
      const additions = images
        .filter((file) => !existing.has(`${file.name}:${file.size}:${file.lastModified}`))
        .slice(0, maxBatchCount - prev.length)
        .map((file) => ({
          id: `${file.name}-${file.size}-${file.lastModified}-${crypto.randomUUID()}`,
          file,
          preview: URL.createObjectURL(file),
          result: null,
        }));
      return [...prev, ...additions].slice(0, maxBatchCount);
    });
  }

  function clearAll() {
    items.forEach((item) => {
      if (item.preview) URL.revokeObjectURL(item.preview);
      if (item.result?.url) URL.revokeObjectURL(item.result.url);
    });
    setItems([]);
    setError("");
    setProgress(null);
  }

  function removeItem(id) {
    setItems((prev) => {
      const target = prev.find((item) => item.id === id);
      if (target?.preview) URL.revokeObjectURL(target.preview);
      if (target?.result?.url) URL.revokeObjectURL(target.result.url);
      return prev.filter((item) => item.id !== id);
    });
  }

  function buildOptions() {
    const options = { format, mode };
    if (mode === "quality") {
      options.quality = quality;
    } else if (mode === "size") {
      const parsed = parseTargetSize(targetAmount, targetUnit);
      if (!parsed.ok) return { error: "invalid-target" };
      options.targetBytes = parsed.bytes;
      // Size mode works best with lossy output; keep user format unless PNG.
      if (format === "png") options.format = "webp";
    } else {
      options.width = parseDimensionInput(width);
      options.height = parseDimensionInput(height);
      options.unit = dimUnit;
      options.lockAspect = lockAspect;
      options.quality = quality;
    }
    return { options };
  }

  async function processAll() {
    if (!items.length || busy) return;
    const built = buildOptions();
    if (built.error === "invalid-target") {
      setError(text.invalidTarget);
      return;
    }
    const snapshot = items.map((item) => {
      if (item.result?.url) URL.revokeObjectURL(item.result.url);
      return { ...item, result: null };
    });
    setBusy(true);
    setError("");
    setProgress({ current: 0, total: snapshot.length });
    setItems(snapshot);

    const next = [];
    for (let index = 0; index < snapshot.length; index += 1) {
      const item = snapshot[index];
      setProgress({ current: index, total: snapshot.length });
      const result = await processImage(item.file, built.options);
      const updated = result.ok
        ? { ...item, result: { ...result, url: URL.createObjectURL(result.blob) } }
        : { ...item, result: { ok: false, error: result.error } };
      next.push(updated);
      setItems([...next, ...snapshot.slice(index + 1)]);
      setProgress({ current: index + 1, total: snapshot.length });
    }

    setBusy(false);
    setProgress(null);
    if (next.some((item) => item.result?.error === "too-large")) setError(text.tooLarge);
    else if (next.some((item) => item.result?.error === "invalid-target")) setError(text.invalidTarget);
  }

  async function downloadZip() {
    const ready = items.filter((item) => item.result?.ok);
    if (!ready.length) return;
    const zip = new JSZip();
    const used = new Map();
    for (const item of ready) {
      let name = item.result.name;
      const count = used.get(name) || 0;
      used.set(name, count + 1);
      if (count > 0) {
        const ext = name.includes(".") ? name.slice(name.lastIndexOf(".")) : "";
        const base = ext ? name.slice(0, -ext.length) : name;
        name = `${base}-${count}${ext}`;
      }
      zip.file(name, item.result.blob);
    }
    const blob = await zip.generateAsync({ type: "blob" });
    downloadBlob(blob, "machkit-images.zip");
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="flex w-full flex-col gap-2.5 border-b border-border pb-3">
          <div className="flex w-full items-center gap-2">
            <span className="machkit-control-label w-16 shrink-0">{text.convertTo}</span>
            <SegmentedControl
              value={format}
              onChange={setFormat}
              label={text.convertTo}
              size="compact"
              className="min-w-0 flex-1"
              options={formatOptions}
            />
            <div className="flex shrink-0 items-center gap-1">
              <Button variant="ghost" size="sm" disabled={!items.length || busy} onClick={processAll}>
                {text.process}
              </Button>
              <Button variant="ghost" size="sm" disabled={doneCount === 0 || busy} onClick={downloadZip}>
                <DownloadSimple size={15} />
                {text.downloadAll}
              </Button>
              <Button variant="ghost" size="sm" disabled={!items.length || busy} onClick={clearAll}>
                <Eraser size={15} />
                {text.clear}
              </Button>
              <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
            </div>
          </div>

          <div className="flex w-full items-center gap-2">
            <span className="machkit-control-label w-16 shrink-0">{text.mode}</span>
            <SegmentedControl
              value={mode}
              onChange={setMode}
              label={text.mode}
              size="compact"
              className="min-w-0 flex-1"
              options={modeOptions}
            />
          </div>

          {mode === "quality" ? (
            <div className="flex w-full items-center gap-2">
              <span className="machkit-control-label w-16 shrink-0">{text.quality}</span>
              <input
                type="range"
                min="0.05"
                max="1"
                step="0.05"
                value={quality}
                disabled={format === "png"}
                onChange={(event) => setQuality(Number(event.target.value))}
                className="w-40 shrink-0 accent-[var(--color-accent)]"
              />
              <span className="w-10 shrink-0 text-right font-mono text-[12px] text-secondary">
                {Math.round(quality * 100)}
              </span>
            </div>
          ) : null}

          {mode === "size" ? (
            <div className="flex w-full items-center gap-2">
              <span className="machkit-control-label w-16 shrink-0">{text.targetSize}</span>
              <Input
                className="min-w-0 flex-1 font-mono"
                value={targetAmount}
                onChange={(event) => setTargetAmount(event.target.value)}
                placeholder="200"
                spellCheck={false}
              />
              <SegmentedControl
                value={targetUnit}
                onChange={setTargetUnit}
                label={text.targetSize}
                size="compact"
                className="w-[120px] shrink-0"
                options={unitOptions}
              />
            </div>
          ) : null}

          {mode === "dimensions" ? (
            <>
              <div className="flex w-full items-center gap-2">
                <div className="flex items-center gap-2">
                  <span className="machkit-control-label w-16 shrink-0">{text.width}</span>
                  <Input
                    className="w-28 shrink-0 font-mono"
                    value={width}
                    onChange={(event) => setWidth(event.target.value)}
                    placeholder={text.auto}
                    spellCheck={false}
                  />
                  <span className="shrink-0 text-[12px] text-tertiary">{dimUnit}</span>
                </div>
                <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />
                <div className="flex items-center gap-2">
                  <span className="machkit-control-label w-16 shrink-0">{text.height}</span>
                  <Input
                    className="w-28 shrink-0 font-mono"
                    value={height}
                    onChange={(event) => setHeight(event.target.value)}
                    placeholder={text.auto}
                    spellCheck={false}
                  />
                  <span className="shrink-0 text-[12px] text-tertiary">{dimUnit}</span>
                </div>
                <div className="ml-auto flex items-center gap-3">
                  <SegmentedControl
                    value={dimUnit}
                    onChange={setDimUnit}
                    label={text.dimUnit}
                    size="compact"
                    className="w-[220px] shrink-0"
                    options={dimUnitOptions}
                  />
                  <CheckboxField
                    checked={lockAspect}
                    onCheckedChange={(value) => setLockAspect(value === true)}
                    label={text.lockAspect}
                  />
                </div>
              </div>
              <div className="flex w-full items-center gap-2">
                <span className="machkit-control-label w-16 shrink-0">{text.quality}</span>
                <input
                  type="range"
                  min="0.05"
                  max="1"
                  step="0.05"
                  value={quality}
                  disabled={format === "png"}
                  onChange={(event) => setQuality(Number(event.target.value))}
                  className="w-40 shrink-0 accent-[var(--color-accent)]"
                />
                <span className="w-10 shrink-0 text-right font-mono text-[12px] text-secondary">
                  {Math.round(quality * 100)}
                </span>
              </div>
            </>
          ) : null}
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        {busy && progress ? (
          <div className="w-full" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={progressPercent}>
            <div className="mb-1.5 flex items-center justify-between text-[11px] text-secondary">
              <span>{text.processing}</span>
              <span className="font-mono">
                {progress.current} / {progress.total} · {progressPercent}%
              </span>
            </div>
            <div className="h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-accent transition-[width] duration-150 ease-out"
                style={{ width: `${progressPercent}%` }}
              />
            </div>
          </div>
        ) : null}

        <button
          type="button"
          className={`flex min-h-[120px] flex-col items-center justify-center gap-2 rounded-panel border border-dashed px-4 py-6 text-center transition-colors ${
            dragOver ? "border-accent bg-accent-soft" : "border-border bg-field hover:border-accent/50"
          }`}
          onClick={() => inputRef.current?.click()}
          onDragEnter={(event) => {
            event.preventDefault();
            setDragOver(true);
          }}
          onDragOver={(event) => event.preventDefault()}
          onDragLeave={() => setDragOver(false)}
          onDrop={(event) => {
            event.preventDefault();
            setDragOver(false);
            addFiles(event.dataTransfer.files);
          }}
        >
          <ImageIcon size={28} className="text-secondary" />
          <span className="text-sm text-foreground">{text.drop}</span>
          <span className="inline-flex items-center gap-1 text-[12px] text-accent">
            <UploadSimple size={14} />
            {text.choose}
          </span>
          <input
            ref={inputRef}
            type="file"
            accept="image/*,.jpg,.jpeg,.png,.webp,.gif,.bmp,.tif,.tiff,.heic,.heif,.avif,.ico,.svg"
            multiple
            className="hidden"
            onChange={(event) => {
              addFiles(event.target.files);
              event.target.value = "";
            }}
          />
        </button>

        {items.length ? (
          <div className="machkit-panel divide-y divide-border">
            {items.map((item) => {
              const result = item.result;
              return (
                <div key={item.id} className="flex items-center gap-3 px-3 py-2">
                  <img
                    src={result?.ok ? result.url : item.preview}
                    alt=""
                    className="size-12 shrink-0 rounded-md object-cover bg-muted"
                  />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[12px] text-foreground">
                      {result?.ok ? result.name : item.file.name}
                    </div>
                    <div className="mt-0.5 flex flex-wrap gap-x-3 gap-y-0.5 text-[11px] text-tertiary">
                      <span>
                        {text.original}: {formatBytes(item.file.size)}
                      </span>
                      {result?.ok ? (
                        <>
                          <span>
                            {text.output}: {formatBytes(result.outputBytes)} ({ratioLabel(result.inputBytes, result.outputBytes)})
                          </span>
                          <span>
                            {text.size}: {result.width}×{result.height}
                          </span>
                          {result.mode === "size" ? (
                            <span>{result.metTarget ? text.belowTarget : text.aboveTarget}</span>
                          ) : null}
                        </>
                      ) : result && !result.ok ? (
                        <span className="text-danger">{text.failed}</span>
                      ) : null}
                    </div>
                  </div>
                  <div className="flex shrink-0 items-center gap-1">
                    {result?.ok ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => downloadBlob(result.blob, result.name)}
                      >
                        <DownloadSimple size={15} />
                        {text.download}
                      </Button>
                    ) : null}
                    <Button variant="ghost" size="sm" onClick={() => removeItem(item.id)}>
                      <Trash size={15} />
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        ) : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ImageProcessTool />, { name: "Image Tools" });
