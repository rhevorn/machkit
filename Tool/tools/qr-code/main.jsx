import React, { useEffect, useMemo, useRef, useState } from "react";
import { DownloadSimple, Image as ImageIcon } from "@phosphor-icons/react";
import {
  Button,
  ColorPicker,
  Input,
  SelectControl,
  Slider,
  StatusStrip,
  ToolContent,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  defaultMargin,
  defaultSize,
  dotShapes,
  errorLevelPercents,
  errorLevels,
  eyeShapes,
  generateQRDataURL,
  margins,
  maxSize,
  minSize,
  normalizeHexColor,
  qrStyles,
  resolveSize,
} from "./qr.js";
import { messages } from "./messages.js";

const STYLE_LABEL_KEYS = {
  classic: "styleClassic",
  rounded: "styleRounded",
  dots: "styleDots",
  inverted: "styleInverted",
};

const DOT_LABEL_KEYS = {
  square: "shapeSquare",
  rounded: "shapeRounded",
  circle: "shapeCircle",
};

const EYE_LABEL_KEYS = {
  square: "shapeSquare",
  rounded: "shapeRounded",
  circle: "shapeCircle",
};

/** CSS display size; bitmap is generated at 2× for Retina sharpness. */
const PREVIEW_SIDE = 200;
const PREVIEW_BITMAP = PREVIEW_SIDE * 2;

async function saveDataURL(dataURL, filename) {
  const comma = String(dataURL || "").indexOf(",");
  const dataBase64 = comma >= 0 ? dataURL.slice(comma + 1) : "";
  if (!dataBase64) return false;
  const saved = await machkit.saveFile({
    name: filename,
    dataBase64,
    mimeType: "image/png",
  });
  return Boolean(saved);
}

function ColorField({ label, value, onChange }) {
  const hex = normalizeHexColor(value, "#000000");
  const [draft, setDraft] = useState(hex);

  useEffect(() => {
    setDraft(hex);
  }, [hex]);

  return (
    <div className="flex min-w-0 flex-col gap-1">
      <span className="machkit-control-label">{label}</span>
      <div className="flex h-[var(--machkit-size-control)] items-center gap-2">
        <ColorPicker label={label} value={hex} onChange={onChange} align="start" />
        <Input
          className="min-w-0 flex-1 font-mono text-[13px] uppercase"
          value={draft}
          onChange={(event) => {
            const next = event.target.value;
            setDraft(next);
            if (/^#?[0-9a-fA-F]{6}$/.test(next.trim())) {
              onChange(normalizeHexColor(next, hex));
            }
          }}
          onBlur={() => {
            const next = normalizeHexColor(draft, hex);
            setDraft(next);
            onChange(next);
          }}
          spellCheck={false}
          aria-label={label}
        />
      </div>
    </div>
  );
}

function OptionRow({ children }) {
  return <div className="grid grid-cols-2 gap-2.5 [&>*]:min-w-0">{children}</div>;
}

function ControlField({ label, children }) {
  return (
    <div className="flex min-w-0 flex-col gap-1">
      <span className="machkit-control-label">{label}</span>
      {children}
    </div>
  );
}

function QrCodeTool() {
  const text = useToolMessages(messages);
  const logoInputRef = useRef(null);
  const [content, setContent] = useState("https://machkit.app");
  const [sizeText, setSizeText] = useState(String(defaultSize));
  const [styleId, setStyleId] = useState(qrStyles[0].id);
  const [dark, setDark] = useState(qrStyles[0].dark);
  const [light, setLight] = useState(qrStyles[0].light);
  const [dotShape, setDotShape] = useState(qrStyles[0].dotShape);
  const [eyeShape, setEyeShape] = useState(qrStyles[0].eyeShape);
  const [eyeDark, setEyeDark] = useState(qrStyles[0].dark);
  const [margin, setMargin] = useState(defaultMargin);
  const [errorLevel, setErrorLevel] = useState("M");
  const [logoDataURL, setLogoDataURL] = useState("");
  const [result, setResult] = useState({ ok: false, error: "empty" });
  const [busy, setBusy] = useState(false);
  const [downloading, setDownloading] = useState(false);

  const size = useMemo(() => resolveSize(sizeText), [sizeText]);
  const level = logoDataURL ? "H" : errorLevel;
  const levelIndex = Math.max(0, errorLevels.indexOf(level));
  const levelMarks = useMemo(
    () =>
      errorLevels.map((item, index) => ({
        value: index,
        label: errorLevelPercents[item],
      })),
    [],
  );

  const renderOptions = useMemo(
    () => ({
      errorLevel: level,
      logoDataURL: logoDataURL || undefined,
      dark,
      light,
      eyeDark,
      dotShape,
      eyeShape,
      margin,
    }),
    [level, logoDataURL, dark, light, eyeDark, dotShape, eyeShape, margin],
  );

  const styleOptions = useMemo(
    () =>
      qrStyles.map((item) => ({
        value: item.id,
        label: text[STYLE_LABEL_KEYS[item.id]] || item.id,
      })),
    [text],
  );
  const dotOptions = useMemo(
    () =>
      dotShapes.map((value) => ({
        value,
        label: text[DOT_LABEL_KEYS[value]] || value,
      })),
    [text],
  );
  const eyeOptions = useMemo(
    () =>
      eyeShapes.map((value) => ({
        value,
        label: text[EYE_LABEL_KEYS[value]] || value,
      })),
    [text],
  );
  const marginOptions = useMemo(
    () =>
      margins.map((value) => ({
        value: String(value),
        label: text.marginModules.replace("{n}", String(value)),
      })),
    [text],
  );

  useEffect(() => {
    let cancelled = false;
    setBusy(true);
    generateQRDataURL(content, {
      ...renderOptions,
      size: PREVIEW_BITMAP,
    }).then((next) => {
      if (cancelled) return;
      setResult(next);
      setBusy(false);
    });
    return () => {
      cancelled = true;
    };
  }, [content, renderOptions]);

  const trimmed = content.trim();
  const status = !trimmed
    ? null
    : result.error === "too-large"
      ? { tone: "danger", label: text.tooLarge }
      : result.error === "logo-failed" || (!busy && !result.ok)
        ? { tone: "danger", label: text.failed }
        : null;

  function applyStyle(id) {
    const preset = qrStyles.find((item) => item.id === id) || qrStyles[0];
    setStyleId(preset.id);
    setDark(preset.dark);
    setLight(preset.light);
    setDotShape(preset.dotShape);
    setEyeShape(preset.eyeShape);
    setEyeDark(preset.dark);
  }

  function onLogoFile(file) {
    if (!file) return;
    const type = String(file.type || "");
    const name = String(file.name || "");
    const looksLikeImage =
      type.startsWith("image/") ||
      /\.(png|jpe?g|webp|gif|svg)$/i.test(name);
    if (!looksLikeImage) return;
    const reader = new FileReader();
    reader.onload = () => {
      setLogoDataURL(String(reader.result || ""));
      setErrorLevel("H");
    };
    reader.readAsDataURL(file);
  }

  function commitSize() {
    setSizeText(String(resolveSize(sizeText)));
  }

  async function downloadPng() {
    if (!trimmed || downloading || !result.ok) return;
    setDownloading(true);
    try {
      const next = await generateQRDataURL(content, {
        ...renderOptions,
        size,
      });
      if (next.ok) {
        await saveDataURL(next.dataURL, `qrcode-${styleId}-${size}.png`);
      }
    } finally {
      setDownloading(false);
    }
  }

  const meta =
    result.ok && result.version != null
      ? text.versionMeta
          .replace("{v}", String(result.version))
          .replace("{n}", String(result.moduleCount))
      : null;

  return (
    <ToolPage title={text.title} adaptiveHeight={false}>
      <ToolContent className="flex h-full min-h-0 flex-1 flex-col gap-2.5 overflow-auto pt-3 pb-4">
        <div className="flex shrink-0 flex-col gap-1">
          <label htmlFor="qr-content" className="machkit-control-label">
            {text.content}
          </label>
          <Input
            id="qr-content"
            className="w-full font-mono text-[13px]"
            value={content}
            onChange={(event) => setContent(event.target.value)}
            placeholder={text.placeholder}
            spellCheck={false}
          />
        </div>

        {status ? <StatusStrip tone={status.tone}>{status.label}</StatusStrip> : null}

        <div className="grid min-h-0 flex-1 gap-3 max-[640px]:grid-cols-1 grid-cols-[minmax(0,1fr)_minmax(220px,248px)]">
          <div className="flex min-w-0 flex-col gap-2.5">
            <ControlField label={text.style}>
              <SelectControl
                value={styleId}
                onChange={applyStyle}
                label={text.style}
                options={styleOptions}
                className="w-full"
              />
            </ControlField>

            <ControlField label={text.logo}>
              <div className="flex h-[var(--machkit-size-control)] flex-wrap items-center gap-1">
                <Button variant="secondary" size="sm" onClick={() => logoInputRef.current?.click()}>
                  <ImageIcon size={15} />
                  {logoDataURL ? text.changeLogo : text.addLogo}
                </Button>
                {logoDataURL ? (
                  <Button variant="ghost" size="sm" onClick={() => setLogoDataURL("")}>
                    {text.clearLogo}
                  </Button>
                ) : null}
                <input
                  ref={logoInputRef}
                  type="file"
                  accept="image/png,image/jpeg,image/webp,image/svg+xml,.png,.jpg,.jpeg,.webp,.svg"
                  className="hidden"
                  onClick={(event) => event.stopPropagation()}
                  onChange={(event) => {
                    onLogoFile(event.target.files?.[0]);
                    event.target.value = "";
                  }}
                />
              </div>
              {logoDataURL ? (
                <p className="mt-1 text-[11px] text-tertiary">{text.logoHint}</p>
              ) : null}
            </ControlField>

            <OptionRow>
              <ColorField label={text.darkColor} value={dark} onChange={setDark} />
              <ColorField label={text.lightColor} value={light} onChange={setLight} />
            </OptionRow>
            <ColorField label={text.eyeColor} value={eyeDark} onChange={setEyeDark} />

            <OptionRow>
              <ControlField label={text.dotShape}>
                <SelectControl
                  value={dotShape}
                  onChange={setDotShape}
                  label={text.dotShape}
                  options={dotOptions}
                  className="w-full"
                />
              </ControlField>
              <ControlField label={text.eyeShape}>
                <SelectControl
                  value={eyeShape}
                  onChange={setEyeShape}
                  label={text.eyeShape}
                  options={eyeOptions}
                  className="w-full"
                />
              </ControlField>
            </OptionRow>

            <OptionRow>
              <ControlField label={text.size}>
                <div className="flex h-[var(--machkit-size-control)] items-center gap-2">
                  <Input
                    className="min-w-0 flex-1 text-center font-mono text-[13px]"
                    inputMode="numeric"
                    value={sizeText}
                    onChange={(event) => setSizeText(event.target.value.replace(/[^\d]/g, ""))}
                    onBlur={commitSize}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") event.currentTarget.blur();
                    }}
                    aria-label={text.size}
                    title={`${minSize}–${maxSize}px`}
                  />
                  <span className="shrink-0 text-xs text-tertiary">px</span>
                </div>
              </ControlField>
              <ControlField label={text.margin}>
                <SelectControl
                  value={String(margin)}
                  onChange={(value) => setMargin(Number(value))}
                  label={text.margin}
                  options={marginOptions}
                  className="w-full"
                />
              </ControlField>
            </OptionRow>

            <Slider
              label={text.errorLevel}
              value={levelIndex}
              displayValue={`${level} · ${errorLevelPercents[level]}`}
              min={0}
              max={errorLevels.length - 1}
              step={1}
              marks={levelMarks}
              disabled={Boolean(logoDataURL)}
              onChange={(index) => setErrorLevel(errorLevels[index] || "M")}
              className={logoDataURL ? "opacity-60" : undefined}
            />
          </div>

          <div className="flex min-h-0 min-w-0 flex-col items-center justify-center gap-2 self-stretch">
            <div
              className="machkit-panel grid place-items-center overflow-hidden p-3"
              style={{ background: light }}
            >
              {result.ok ? (
                <img
                  src={result.dataURL}
                  alt={text.preview}
                  width={PREVIEW_SIDE}
                  height={PREVIEW_SIDE}
                  className="block"
                  style={{ width: PREVIEW_SIDE, height: PREVIEW_SIDE }}
                />
              ) : (
                <div
                  className="grid place-items-center px-3 text-center text-[11px] text-tertiary"
                  style={{ width: PREVIEW_SIDE, height: PREVIEW_SIDE }}
                >
                  {busy ? text.generate : text.empty}
                </div>
              )}
            </div>
            {meta ? <p className="text-[11px] text-tertiary tabular-nums">{meta}</p> : null}
            <Button
              variant="secondary"
              size="sm"
              className="w-full max-w-[200px]"
              disabled={!result.ok || downloading}
              onClick={downloadPng}
            >
              <DownloadSimple size={15} />
              {downloading ? "…" : text.download}
            </Button>
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<QrCodeTool />, { name: "QR Code" });
