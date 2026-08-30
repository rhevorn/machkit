import { useEffect, useMemo, useRef, useState } from "react";
import { DownloadSimpleIcon, EraserIcon, ImageIcon, TrashIcon, UploadSimpleIcon } from "@phosphor-icons/react";
import JSZip from "jszip";
import {
  Button,
  CheckboxField,
  Input,
  SegmentedControl,
  Slider,
  StatusStrip,
  ToolContent,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import {
  defaultQuality,
  defaultTargetKB,
  dimensionUnits,
  formatBytes,
  maxBatchCount,
  parseTargetSize,
  processImage,
  ratioLabel,
  type DimensionUnit,
  type ImageFormatOption,
  type ImageMode,
  type ProcessImageOptions,
  type ProcessImageResult,
  type ProcessImageSuccess,
} from "./image.js";
import { messages } from "./messages.js";
import type { InlineMessageTone } from "@/ui/inline-message.js";
import type { ReactNode } from "react";

type TargetUnit = "KB" | "MB";

type QueueItemResult =
  | (ProcessImageSuccess & { url: string })
  | { ok: false; error: string; url?: undefined };

type QueueItem = {
  id: string;
  file: File;
  preview: string;
  result: QueueItemResult | null;
};

type ProgressState = { current: number; total: number };

function parseDimensionInput(value: unknown): number {
  const text = String(value ?? "").trim().toLowerCase();
  if (!text || text === "auto") return 0;
  const n = Number(text);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

async function saveBlob(blob: Blob, name: string) {
  const buffer = await blob.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return machkit.saveFile({
    name,
    dataBase64: btoa(binary),
    mimeType: blob.type || "application/octet-stream",
    timeout: 120_000,
  });
}

function ControlField({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-1">
      <span className="machkit-control-label">{label}</span>
      {children}
    </div>
  );
}

function ImageProcessTool() {
  const text = useToolMessages(messages);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const runTokenRef = useRef(0);
  const [items, setItems] = useState<QueueItem[]>([]);
  const [format, setFormat] = useState<ImageFormatOption>("jpeg");
  const [mode, setMode] = useState<ImageMode>("dimensions");
  const [quality, setQuality] = useState(defaultQuality);
  const [targetAmount, setTargetAmount] = useState(String(defaultTargetKB));
  const [targetUnit, setTargetUnit] = useState<TargetUnit>("KB");
  const [width, setWidth] = useState("");
  const [height, setHeight] = useState("");
  const [dimUnit, setDimUnit] = useState<DimensionUnit>("px");
  const [lockAspect, setLockAspect] = useState(true);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<ProgressState | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    return () => {
      runTokenRef.current += 1;
    };
  }, []);

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
      { value: "dimensions", label: text.modeDimensions },
      { value: "quality", label: text.modeQuality },
      { value: "size", label: text.modeSize },
    ],
    [text.modeDimensions, text.modeQuality, text.modeSize],
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
  const status: { tone: InlineMessageTone; label: string } | null = error
    ? { tone: "danger", label: error }
    : busy && progress
      ? {
          tone: "info",
          label: `${text.processing} ${progress.current} / ${progress.total}`,
        }
      : doneCount
        ? { tone: "info", label: `${text.done} · ${doneCount}/${items.length}` }
        : null;

  function addFiles(fileList: FileList | File[] | null | undefined) {
    const images = Array.from(fileList || []).filter(
      (file): file is File =>
        String(file.type || "").startsWith("image/") ||
        /\.(jpe?g|png|webp|gif|bmp|tiff?|heic|heif|avif|ico|svg)$/i.test(file.name),
    );
    if (!images.length) {
      if (!items.length) setError(text.empty);
      return;
    }

    const room = maxBatchCount - items.length;
    if (room <= 0) {
      setError(text.tooMany);
      return;
    }

    const existing = new Set(
      items.map((item) => `${item.file.name}:${item.file.size}:${item.file.lastModified}`),
    );
    const unique = images.filter(
      (file) => !existing.has(`${file.name}:${file.size}:${file.lastModified}`),
    );
    const additions = unique.slice(0, room).map((file) => ({
      id: `${file.name}-${file.size}-${file.lastModified}-${crypto.randomUUID()}`,
      file,
      preview: URL.createObjectURL(file),
      result: null,
    }));
    if (!additions.length) {
      setError("");
      return;
    }

    setError(unique.length > room ? text.tooMany : "");
    setItems((prev) => [...prev, ...additions].slice(0, maxBatchCount));
  }

  function clearAll() {
    runTokenRef.current += 1;
    items.forEach((item) => {
      if (item.preview) URL.revokeObjectURL(item.preview);
      if (item.result?.url) URL.revokeObjectURL(item.result.url);
    });
    setItems([]);
    setError("");
    setProgress(null);
    setBusy(false);
  }

  function removeItem(id: string) {
    setItems((prev) => {
      const target = prev.find((item) => item.id === id);
      if (target?.preview) URL.revokeObjectURL(target.preview);
      if (target?.result?.url) URL.revokeObjectURL(target.result.url);
      return prev.filter((item) => item.id !== id);
    });
  }

  function buildOptions():
    | { options: ProcessImageOptions; error?: undefined }
    | { error: "invalid-target"; options?: undefined } {
    const options: ProcessImageOptions = { format, mode };
    if (mode === "quality") {
      options.quality = quality;
    } else if (mode === "size") {
      const parsed = parseTargetSize(targetAmount, targetUnit);
      if (!parsed.ok) return { error: "invalid-target" };
      options.targetBytes = parsed.bytes;
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
    const runToken = ++runTokenRef.current;
    const snapshot = items.map((item) => {
      if (item.result?.url) URL.revokeObjectURL(item.result.url);
      return { ...item, result: null };
    });
    setBusy(true);
    setError("");
    setProgress({ current: 0, total: snapshot.length });
    setItems(snapshot);

    const next: QueueItem[] = [];
    for (let index = 0; index < snapshot.length; index += 1) {
      if (runToken !== runTokenRef.current) return;
      const item = snapshot[index];
      setProgress({ current: index, total: snapshot.length });
      const result: ProcessImageResult = await processImage(item.file, built.options!);
      if (runToken !== runTokenRef.current) return;
      const updated: QueueItem = result.ok
        ? { ...item, result: { ...result, url: URL.createObjectURL(result.blob) } }
        : { ...item, result: { ok: false, error: result.error } };
      next.push(updated);
      setItems([...next, ...snapshot.slice(index + 1)]);
      setProgress({ current: index + 1, total: snapshot.length });
    }

    if (runToken !== runTokenRef.current) return;
    setBusy(false);
    setProgress(null);
    if (next.some((item) => item.result?.error === "too-large")) setError(text.tooLarge);
    else if (next.some((item) => item.result?.error === "invalid-target")) setError(text.invalidTarget);
  }

  async function downloadOne(blob: Blob, name: string) {
    try {
      const saved = await saveBlob(blob, name);
      if (saved === null) return;
      setError("");
    } catch {
      setError(text.saveFailed);
    }
  }

  async function downloadZip() {
    const ready = items.filter((item) => item.result?.ok);
    if (!ready.length) return;
    try {
      const zip = new JSZip();
      const used = new Map<string, number>();
      for (const item of ready) {
        if (!item.result?.ok) continue;
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
      const saved = await saveBlob(blob, "machkit-images.zip");
      if (saved === null) return;
      setError("");
    } catch {
      setError(text.saveFailed);
    }
  }

  const dropZone = (
    <div
      className={`relative flex w-full flex-col items-center justify-center gap-2 overflow-hidden rounded-panel border border-dashed px-4 text-center ${
        items.length ? "h-auto min-h-[88px] py-4" : "min-h-0 flex-1 py-8"
      } ${dragOver ? "border-accent bg-accent-soft" : "border-border bg-field"}`}
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
      {/* Overlay the native picker so WKWebView honors `multiple` (not nested in <button>). */}
      <input
        ref={inputRef}
        type="file"
        accept="image/*,.jpg,.jpeg,.png,.webp,.gif,.bmp,.tif,.tiff,.heic,.heif,.avif,.ico,.svg"
        multiple
        className="absolute inset-0 z-10 cursor-pointer opacity-0"
        aria-label={text.choose}
        onChange={(event) => {
          addFiles(event.target.files);
          event.target.value = "";
        }}
      />
      <ImageIcon size={items.length ? 22 : 28} className="pointer-events-none text-secondary" />
      <span className="pointer-events-none text-sm text-foreground">{text.drop}</span>
      <span className="pointer-events-none inline-flex items-center gap-1 text-[12px] text-accent">
        <UploadSimpleIcon size={14} />
        {text.choose}
      </span>
    </div>
  );

  return (
    <ToolPage title={text.title} adaptiveHeight={false}>
      <ToolContent className="flex h-full min-h-0 flex-1 flex-col gap-3 overflow-hidden pt-3 pb-4">
        <div className="grid min-h-0 flex-1 gap-4 max-[780px]:grid-cols-1 grid-cols-[minmax(220px,260px)_minmax(0,1fr)]">
          <aside className="flex min-h-0 min-w-0 flex-col gap-3 overflow-auto">
            <ControlField label={text.convertTo}>
              <SegmentedControl
                value={format}
                onChange={(value) => setFormat(value as ImageFormatOption)}
                label={text.convertTo}
                size="compact"
                className="w-full"
                options={formatOptions}
              />
            </ControlField>

            <ControlField label={text.mode}>
              <SegmentedControl
                value={mode}
                onChange={(value) => setMode(value as ImageMode)}
                label={text.mode}
                size="compact"
                className="w-full"
                options={modeOptions}
              />
            </ControlField>

            {mode === "quality" ? (
              <Slider
                label={text.quality}
                className="w-full"
                min={0.05}
                max={1}
                step={0.05}
                value={quality}
                displayValue={Math.round(quality * 100)}
                disabled={format === "png"}
                onChange={(next) => setQuality(next)}
              />
            ) : null}

            {mode === "size" ? (
              <ControlField label={text.targetSize}>
                <div className="flex h-[var(--machkit-size-control)] items-center gap-2">
                  <Input
                    className="min-w-0 flex-1 font-mono text-[13px]"
                    value={targetAmount}
                    onChange={(event) => setTargetAmount(event.target.value)}
                    placeholder="200"
                    spellCheck={false}
                  />
                  <SegmentedControl
                    value={targetUnit}
                    onChange={(value) => setTargetUnit(value as TargetUnit)}
                    label={text.targetSize}
                    size="compact"
                    className="w-[108px] shrink-0"
                    options={unitOptions}
                  />
                </div>
              </ControlField>
            ) : null}

            {mode === "dimensions" ? (
              <>
                <div className="grid grid-cols-2 gap-2.5">
                  <ControlField label={text.width}>
                    <div className="flex h-[var(--machkit-size-control)] items-center gap-1.5">
                      <Input
                        className="min-w-0 flex-1 font-mono text-[13px]"
                        value={width}
                        onChange={(event) => setWidth(event.target.value)}
                        placeholder={text.auto}
                        spellCheck={false}
                      />
                    </div>
                  </ControlField>
                  <ControlField label={text.height}>
                    <div className="flex h-[var(--machkit-size-control)] items-center gap-1.5">
                      <Input
                        className="min-w-0 flex-1 font-mono text-[13px]"
                        value={height}
                        onChange={(event) => setHeight(event.target.value)}
                        placeholder={text.auto}
                        spellCheck={false}
                      />
                    </div>
                  </ControlField>
                </div>
                <ControlField label={text.dimUnit}>
                  <SegmentedControl
                    value={dimUnit}
                    onChange={(value) => setDimUnit(value as DimensionUnit)}
                    label={text.dimUnit}
                    size="compact"
                    className="w-full"
                    options={dimUnitOptions}
                  />
                </ControlField>
                <CheckboxField
                  checked={lockAspect}
                  onCheckedChange={(value) => setLockAspect(value === true)}
                  label={text.lockAspect}
                />
                <Slider
                  label={text.quality}
                  className="w-full"
                  min={0.05}
                  max={1}
                  step={0.05}
                  value={quality}
                  displayValue={Math.round(quality * 100)}
                  disabled={format === "png"}
                  onChange={(next) => setQuality(next)}
                />
              </>
            ) : null}

            <div className="mt-auto flex flex-col gap-1.5 pt-2">
              <Button variant="default" size="sm" disabled={!items.length || busy} onClick={processAll}>
                {text.process}
              </Button>
              <Button variant="secondary" size="sm" disabled={doneCount === 0 || busy} onClick={downloadZip}>
                <DownloadSimpleIcon size={15} />
                {text.downloadAll}
              </Button>
              <Button variant="ghost" size="sm" disabled={!items.length || busy} onClick={clearAll}>
                <EraserIcon size={15} />
                {text.clear}
              </Button>
            </div>
          </aside>

          <div className="flex min-h-0 min-w-0 flex-col gap-2.5">
            {status ? <StatusStrip tone={status.tone}>{status.label}</StatusStrip> : null}

            {busy && progress ? (
              <div
                className="w-full shrink-0"
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={progressPercent}
              >
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

            {dropZone}

            {items.length ? (
              <div className="machkit-panel flex min-h-0 flex-1 flex-col overflow-hidden">
                <div className="min-h-0 flex-1 overflow-auto divide-y divide-border">
                  {items.map((item) => {
                    const result = item.result;
                    return (
                      <div key={item.id} className="flex items-center gap-3 px-3 py-2.5">
                        <img
                          src={result?.ok ? result.url : item.preview}
                          alt=""
                          className="size-12 shrink-0 rounded-md bg-muted object-cover"
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
                                  {text.output}: {formatBytes(result.outputBytes)} (
                                  {ratioLabel(result.inputBytes, result.outputBytes)})
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
                              onClick={() => downloadOne(result.blob, result.name)}
                            >
                              <DownloadSimpleIcon size={15} />
                              {text.download}
                            </Button>
                          ) : null}
                          <Button
                            variant="ghost"
                            size="sm"
                            aria-label={text.remove}
                            title={text.remove}
                            onClick={() => removeItem(item.id)}
                          >
                            <TrashIcon size={15} />
                          </Button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ImageProcessTool />, { name: "Image Tools" });
