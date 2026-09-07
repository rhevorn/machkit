import { useEffect, useRef, useState } from "react";
import {
  ArrowsLeftRightIcon,
  CopySimpleIcon,
  DownloadSimpleIcon,
  EraserIcon,
  FileArrowUpIcon,
} from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  IconButton,
  Input,
  PropertyList,
  PropertyRow,
  SegmentedControl,
  SelectControl,
  SidebarNavItem,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolPage,
  ToolSidebar,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import {
  convertCodec,
  hashAlgorithmGroups,
  hexCaseVariants,
  inspectDataURI,
  isHMACAlgorithm,
  md5VariantsFromHex,
  type ConvertCodecResult,
  type DataURIInfo,
} from "./codec.js";
import { messages } from "./messages.js";

type CodecMessages = (typeof messages)["en"];

type HashFamily = (typeof hashAlgorithmGroups)[number]["id"];

type SidebarItem = {
  id: string;
  code: string;
  hashFamily?: HashFamily;
  algorithms?: readonly string[];
  variants?: readonly string[];
};

const BASE_VARIANTS = [
  "base16",
  "base32",
  "base36",
  "base58",
  "base62",
  "base64",
  "base85",
] as const;
const DEFAULT_BASE_VARIANT = "base64";

const ENCODING_VARIANTS = ["unicode", "utf-8", "url", "ascii", "native"] as const;
const DEFAULT_ENCODING_VARIANT = "unicode";

const MAX_INPUT_BYTES = 100 * 1024 * 1024;

type DataURIKind = "text" | "image" | "file";

const DATA_URI_KIND_OPTIONS = ["text", "image", "file"] as const;

const HASH_FAMILY_DEFAULTS: Record<HashFamily, string> = {
  digest: "MD5",
  sha: "SHA-256",
  hmac: "HMAC-SHA-256",
};

const HASH_FAMILY_CODES: Record<HashFamily, string> = {
  digest: "MD5",
  sha: "SHA",
  hmac: "HMAC",
};

const CODEC_GROUPS: { id: string; items: SidebarItem[] }[] = [
  {
    id: "binary",
    items: [
      { id: "base", code: "B", variants: BASE_VARIANTS },
      { id: "radix", code: "N" },
    ],
  },
  {
    id: "text",
    items: [
      { id: "encoding", code: "\\u", variants: ENCODING_VARIANTS },
      { id: "html", code: "<>" },
      { id: "escape", code: "\\n" },
    ],
  },
  {
    id: "transfer",
    items: [
      { id: "punycode", code: "IDN" },
      { id: "gbk", code: "GB" },
      { id: "quoted-printable", code: "QP" },
      { id: "data-uri", code: "URI" },
    ],
  },
  {
    id: "digest",
    items: hashAlgorithmGroups.map((group) => ({
      id: group.id,
      code: HASH_FAMILY_CODES[group.id],
      hashFamily: group.id,
      algorithms: group.items,
    })),
  },
];

const RADIX_OPTIONS = Array.from({ length: 35 }, (_, index) => index + 2);

type WorkerReply = {
  id: number;
  result: ConvertCodecResult;
};

function messageFor(text: CodecMessages, key: string): string {
  return (text as Record<string, string>)[key] || key;
}

function groupLabel(text: CodecMessages, groupID: string): string {
  if (groupID === "binary") return text.groupBinary;
  if (groupID === "text") return text.groupText;
  if (groupID === "transfer") return text.groupTransfer;
  if (groupID === "digest") return text.groupDigest;
  return groupID;
}

function hashFamilyForAlgorithm(algorithm: string): HashFamily {
  if (algorithm === "MD5") return "digest";
  if (isHMACAlgorithm(algorithm)) return "hmac";
  return "sha";
}

function hashItemLabel(text: CodecMessages, family: HashFamily): string {
  if (family === "digest") return "MD5";
  if (family === "sha") return text.hashGroupSHA;
  return text.hashGroupHMAC;
}

function CodecTool() {
  const text = useToolMessages(messages);
  const [tab, setTab] = useState<string>(DEFAULT_BASE_VARIANT);
  const [direction, setDirection] = useState("encode");
  const [input, setInput] = useState("");
  const [output, setOutput] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [algorithm, setAlgorithm] = useState("MD5");
  const [hmacKey, setHmacKey] = useState("");
  const [urlMode, setUrlMode] = useState("component");
  const [base64URL, setBase64URL] = useState(false);
  const [fromRadix, setFromRadix] = useState(10);
  const [toRadix, setToRadix] = useState(16);
  const [dataURIFileName, setDataURIFileName] = useState<string | null>(null);
  const [dataURIMediaURL, setDataURIMediaURL] = useState<string | null>(null);
  const [dataURIInputKind, setDataURIInputKind] = useState<DataURIKind>("text");
  const [savingDataURI, setSavingDataURI] = useState(false);
  const rememberedAlgorithms = useRef<Record<HashFamily, string>>({ ...HASH_FAMILY_DEFAULTS });
  const rememberedBase = useRef<string>(DEFAULT_BASE_VARIANT);
  const rememberedEncoding = useRef<string>(DEFAULT_ENCODING_VARIANT);
  const dataURIFileRef = useRef<HTMLInputElement | null>(null);
  const workerRef = useRef<Worker | null>(null);
  const conversionIDRef = useRef(0);
  const dataURIMode = tab === "data-uri";
  const radixMode = tab === "radix";

  const hashMode = tab === "hash";
  const baseMode = (BASE_VARIANTS as readonly string[]).includes(tab);
  const encodingMode = (ENCODING_VARIANTS as readonly string[]).includes(tab);
  const hashFamily = hashFamilyForAlgorithm(algorithm);
  const activeHashItem = CODEC_GROUPS.find((group) => group.id === "digest")?.items.find(
    (item) => item.hashFamily === hashFamily,
  );
  const hashAlgorithms = activeHashItem?.algorithms ?? [];
  const hmacMode = hashMode && isHMACAlgorithm(algorithm);
  const showMD5Variants = hashMode && algorithm === "MD5";
  const md5Variants =
    showMD5Variants && output && !error ? md5VariantsFromHex(output) : null;
  const hexVariants =
    hashMode && !showMD5Variants && output && !error ? hexCaseVariants(output) : null;

  const dataURISource =
    dataURIMode && !error
      ? direction === "encode"
        ? output || dataURIMediaURL || ""
        : input
      : "";
  const dataURIInfo: DataURIInfo | null = (() => {
    if (!dataURIMode || !dataURISource.trim()) return null;
    const inspected = inspectDataURI(dataURISource);
    return inspected.ok ? inspected : null;
  })();

  const dataURIInputPreview: DataURIInfo | null = (() => {
    if (!dataURIMode || direction !== "encode" || !dataURIMediaURL) return null;
    const inspected = inspectDataURI(dataURIMediaURL);
    return inspected.ok ? inspected : null;
  })();

  const dataURITextOutput =
    direction === "decode" && dataURIInfo?.isText && dataURIInfo.text !== null
      ? dataURIInfo.text
      : output;

  const dataURIEncodeMediaInput =
    dataURIMode && direction === "encode" && dataURIInputKind !== "text";

  useEffect(() => {
    if (typeof Worker === "undefined") return undefined;
    const worker = new Worker(new URL("./codec.worker.ts", import.meta.url), { type: "module" });
    workerRef.current = worker;
    worker.onmessage = ({ data }: MessageEvent<WorkerReply>) => {
      if (data.id !== conversionIDRef.current) return;
      setOutput(data.result.value);
      setError(data.result.ok ? null : data.result.error);
    };
    return () => {
      worker.terminate();
      workerRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (
      dataURIMode &&
      direction === "encode" &&
      dataURIMediaURL &&
      (dataURIInputKind === "image" || dataURIInputKind === "file")
    ) {
      return undefined;
    }
    let cancelled = false;
    const id = conversionIDRef.current + 1;
    conversionIDRef.current = id;
    const parameters = {
      tab,
      direction: hashMode || radixMode ? "encode" : direction,
      input,
      urlMode,
      base64URL,
      algorithm,
      hmacKey,
      fromRadix,
      toRadix,
    };
    const timer = window.setTimeout(() => {
      if (input.length > MAX_INPUT_BYTES) {
        setOutput("");
        setError(dataURIMode ? "data-uri-too-large" : "input-too-large");
        return;
      }
      if (workerRef.current) {
        workerRef.current.postMessage({ id, parameters });
        return;
      }
      convertCodec(parameters)
        .then((result) => {
          if (cancelled || id !== conversionIDRef.current) return;
          setOutput(result.value);
          setError(result.ok ? null : result.error);
        })
        .catch(() => {
          if (!cancelled) setError("unsupported");
        });
    }, 80);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [
    tab,
    direction,
    input,
    urlMode,
    base64URL,
    algorithm,
    hmacKey,
    hashMode,
    radixMode,
    fromRadix,
    toRadix,
    dataURIMode,
    dataURIMediaURL,
    dataURIInputKind,
  ]);

  function selectItem(item: SidebarItem) {
    if (item.hashFamily && item.algorithms) {
      setTab("hash");
      const next =
        rememberedAlgorithms.current[item.hashFamily] ??
        HASH_FAMILY_DEFAULTS[item.hashFamily] ??
        item.algorithms[0];
      setAlgorithm(next);
      setDirection("encode");
    } else if (item.id === "base" && item.variants) {
      setTab(rememberedBase.current);
    } else if (item.id === "encoding" && item.variants) {
      setTab(rememberedEncoding.current);
    } else {
      setTab(item.id);
    }
    setDataURIFileName(null);
    setDataURIMediaURL(null);
    setDataURIInputKind("text");
    setError(null);
  }

  function clearDataURIMedia() {
    setDataURIFileName(null);
    setDataURIMediaURL(null);
    if (dataURIFileRef.current) dataURIFileRef.current.value = "";
  }

  function changeDataURIInputKind(value: string) {
    if (value !== "text" && value !== "image" && value !== "file") return;
    setDataURIInputKind(value);
    setError(null);
    if (value === "text") {
      if (dataURIMediaURL) {
        setInput("");
        clearDataURIMedia();
        setOutput("");
      }
      return;
    }
    setInput("");
    clearDataURIMedia();
    setOutput("");
  }

  function onDataURIFile(file: File | undefined) {
    if (!file || direction !== "encode" || dataURIInputKind === "text") return;
    if (dataURIInputKind === "image" && !file.type.startsWith("image/")) {
      setError("unsupported");
      return;
    }
    if (file.size > MAX_INPUT_BYTES) {
      setError("data-uri-too-large");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const result = typeof reader.result === "string" ? reader.result : "";
      if (!result) {
        setError("unsupported");
        return;
      }
      setInput("");
      setDataURIFileName(file.name);
      setDataURIMediaURL(result);
      setOutput(result);
      setError(null);
    };
    reader.onerror = () => setError("unsupported");
    reader.readAsDataURL(file);
  }

  async function saveDataURIPayload(info: DataURIInfo) {
    if (!info.dataBase64 || savingDataURI) return;
    setSavingDataURI(true);
    try {
      const baseName = dataURIFileName?.replace(/\.[^.]+$/, "").trim();
      await machkit.saveFile({
        name: baseName ? `${baseName}.${info.extension}` : info.suggestedName,
        dataBase64: info.dataBase64,
        mimeType: info.mime.split(";")[0] || "application/octet-stream",
      });
    } finally {
      setSavingDataURI(false);
    }
  }

  function renderDataURIMediaPanel(options: {
    kind: DataURIKind;
    info: DataURIInfo | null;
    emptyLabel: string;
    onPick?: () => void;
    showSave?: boolean;
  }) {
    const { kind, info, emptyLabel, onPick, showSave = false } = options;
    if (kind === "image") {
      if (info?.isImage) {
        return (
          <div className="flex min-h-0 flex-1 basis-0 flex-col gap-2 overflow-hidden">
            <div className="flex min-h-0 flex-1 items-center justify-center overflow-hidden rounded-panel bg-muted/45 p-3">
              <img
                src={info.dataURL}
                alt={text.dataUriPreview}
                className="max-h-full max-w-full object-contain"
              />
            </div>
            {onPick || dataURIFileName ? (
              <div className="flex shrink-0 items-center gap-2">
                {onPick ? (
                  <Button variant="ghost" size="sm" onClick={onPick}>
                    <FileArrowUpIcon size={15} />
                    {text.chooseFile}
                  </Button>
                ) : null}
                {dataURIFileName ? (
                  <span className="truncate text-[11px] text-tertiary">{dataURIFileName}</span>
                ) : null}
              </div>
            ) : null}
          </div>
        );
      }
      return (
        <div className="flex min-h-0 flex-1 basis-0 flex-col items-center justify-center gap-3 rounded-panel border border-dashed border-border bg-muted/30 px-4">
          <p className="text-center text-[12px] text-tertiary">
            {info ? text.dataUriNotImage : emptyLabel}
          </p>
          {onPick ? (
            <Button variant="secondary" size="sm" onClick={onPick}>
              <FileArrowUpIcon size={15} />
              {text.chooseFile}
            </Button>
          ) : null}
        </div>
      );
    }

    return (
      <div className="flex min-h-0 flex-1 basis-0 flex-col items-center justify-center gap-3 rounded-panel border border-dashed border-border bg-muted/30 px-4">
        {info ? (
          <>
            {info.isImage ? (
              <div className="flex max-h-[50%] w-full items-center justify-center overflow-hidden rounded-panel bg-muted/45 p-2">
                <img
                  src={info.dataURL}
                  alt={text.dataUriPreview}
                  className="max-h-40 max-w-full object-contain"
                />
              </div>
            ) : null}
            <div className="space-y-1 text-center text-[12px] text-secondary">
              {dataURIFileName ? <div className="truncate font-medium">{dataURIFileName}</div> : null}
              <div>{info.mime}</div>
              <div>{text.dataUriBytes.replace("{n}", String(info.byteLength))}</div>
              {showSave ? <div className="text-tertiary">{text.dataUriSaveHint}</div> : null}
            </div>
            <div className="flex flex-wrap items-center justify-center gap-2">
              {onPick ? (
                <Button variant="secondary" size="sm" onClick={onPick}>
                  <FileArrowUpIcon size={15} />
                  {text.chooseFile}
                </Button>
              ) : null}
              {showSave ? (
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={savingDataURI || !info.dataBase64}
                  onClick={() => void saveDataURIPayload(info)}
                >
                  <DownloadSimpleIcon size={15} />
                  {text.saveFile}
                </Button>
              ) : null}
            </div>
          </>
        ) : (
          <>
            <p className="text-center text-[12px] text-tertiary">{emptyLabel}</p>
            {onPick ? (
              <Button variant="secondary" size="sm" onClick={onPick}>
                <FileArrowUpIcon size={15} />
                {text.chooseFile}
              </Button>
            ) : null}
          </>
        )}
      </div>
    );
  }

  function isItemActive(item: SidebarItem): boolean {
    if (item.hashFamily) return hashMode && hashFamily === item.hashFamily;
    if (item.id === "base") return baseMode;
    if (item.id === "encoding") return encodingMode;
    return tab === item.id;
  }

  function changeAlgorithm(value: string) {
    setAlgorithm(value);
    rememberedAlgorithms.current[hashFamilyForAlgorithm(value)] = value;
    setError(null);
  }

  function changeBaseVariant(value: string) {
    rememberedBase.current = value;
    setTab(value);
    setError(null);
  }

  function changeEncodingVariant(value: string) {
    rememberedEncoding.current = value;
    setTab(value);
    setError(null);
  }

  const swap = () => {
    if (hashMode || error) return;

    if (radixMode) {
      if (!output.trim() && !input.trim()) return;
      const previousInput = input;
      const previousOutput = output;
      const previousFrom = fromRadix;
      setInput(previousOutput);
      setOutput(previousInput);
      setFromRadix(toRadix);
      setToRadix(previousFrom);
      setError(null);
      return;
    }

    if (dataURIMode) {
      const encoded = (output.trim() || dataURIMediaURL || "").trim();
      const decodedText =
        direction === "decode" && dataURIInfo?.isText && dataURIInfo.text !== null
          ? dataURIInfo.text
          : direction === "decode"
            ? output.trim()
            : input.trim();
      if (direction === "encode") {
        if (!encoded) return;
        const inspected = inspectDataURI(encoded);
        clearDataURIMedia();
        setDataURIInputKind("text");
        setDirection("decode");
        setInput(encoded);
        setOutput(inspected.ok && inspected.text !== null ? inspected.text : "");
        setError(null);
        return;
      }
      if (!input.trim()) return;
      clearDataURIMedia();
      setDataURIInputKind("text");
      setDirection("encode");
      if (decodedText) {
        setInput(decodedText);
        setOutput("");
      } else {
        // Binary decode: move data URI into encode as text input
        setInput(input.trim());
        setOutput("");
      }
      setError(null);
      return;
    }

    if (!output.trim()) return;
    const previousInput = input;
    const previousOutput = output;
    setInput(previousOutput);
    setOutput(previousInput);
    setDirection((value) => (value === "encode" ? "decode" : "encode"));
    setError(null);
  };

  const clearAll = () => {
    setInput("");
    setOutput("");
    setHmacKey("");
    clearDataURIMedia();
    setDataURIInputKind("text");
    setError(null);
  };

  const titleLabel = hashMode
    ? hashItemLabel(text, hashFamily)
    : baseMode
      ? text.base
      : encodingMode
        ? text.encoding
        : messageFor(text, tab);

  const encodingIntro = encodingMode
    ? messageFor(text, `intro-${tab}`)
    : dataURIMode
      ? direction === "encode"
        ? text.dataUriEncodeIntro
        : text.dataUriDecodeIntro
      : radixMode
        ? text.radixIntro
        : null;
  const inputPlaceholder = encodingMode
    ? messageFor(text, `ph-${tab}-${direction === "decode" ? "decode" : "encode"}`)
    : dataURIMode
      ? direction === "encode"
        ? text.dataUriEncodePlaceholder
        : text.dataUriDecodePlaceholder
      : radixMode
        ? text.radixPlaceholder
        : text.placeholder;
  const outputPlaceholder = encodingMode
    ? messageFor(text, `out-${tab}-${direction === "decode" ? "decode" : "encode"}`)
    : dataURIMode
      ? direction === "encode"
        ? text.dataUriEncodeOutputPlaceholder
        : text.dataUriDecodeOutputPlaceholder
      : radixMode
        ? text.radixOutputPlaceholder
        : text.empty;

  const resultPanel = showMD5Variants ? (
    <PropertyList className="shrink-0 overflow-hidden rounded-panel bg-muted/45">
      <PropertyRow label={text.hash32Lower} value={md5Variants?.lower32} copyLabel={text.copy} />
      <PropertyRow label={text.hash32Upper} value={md5Variants?.upper32} copyLabel={text.copy} />
      <PropertyRow label={text.hash16Lower} value={md5Variants?.lower16} copyLabel={text.copy} />
      <PropertyRow label={text.hash16Upper} value={md5Variants?.upper16} copyLabel={text.copy} />
    </PropertyList>
  ) : hexVariants ? (
    <PropertyList className="shrink-0 overflow-hidden rounded-panel bg-muted/45">
      <PropertyRow label={text.hashLower} value={hexVariants.lower} copyLabel={text.copy} />
      <PropertyRow label={text.hashUpper} value={hexVariants.upper} copyLabel={text.copy} />
    </PropertyList>
  ) : dataURIMode ? (
    direction === "encode" ? (
      <Textarea
        value={output}
        readOnly
        placeholder={outputPlaceholder}
        invalid={Boolean(error)}
        aria-label={text.output}
        className="min-h-0 w-full flex-1 basis-0 resize-none bg-field font-mono text-[12px]"
      />
    ) : dataURIInfo?.isImage && dataURIInfo.isText ? (
      <div className="flex min-h-0 flex-1 basis-0 flex-col gap-2 overflow-hidden">
        <div className="flex max-h-[40%] shrink-0 items-center justify-center overflow-hidden rounded-panel bg-muted/45 p-2">
          <img
            src={dataURIInfo.dataURL}
            alt={text.dataUriPreview}
            className="max-h-full max-w-full object-contain"
          />
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-2">
          <span className="text-[11px] text-tertiary">
            {dataURIInfo.mime} · {text.dataUriBytes.replace("{n}", String(dataURIInfo.byteLength))}
          </span>
          <Button
            variant="ghost"
            size="sm"
            disabled={savingDataURI || !dataURIInfo.dataBase64}
            onClick={() => void saveDataURIPayload(dataURIInfo)}
          >
            <DownloadSimpleIcon size={15} />
            {text.saveFile}
          </Button>
        </div>
        <Textarea
          value={dataURITextOutput}
          readOnly
          placeholder={outputPlaceholder}
          invalid={Boolean(error)}
          aria-label={text.output}
          className="min-h-0 w-full flex-1 basis-0 resize-none bg-field font-mono text-[12px]"
        />
      </div>
    ) : dataURIInfo?.isImage ? (
      renderDataURIMediaPanel({
        kind: "image",
        info: dataURIInfo,
        emptyLabel: outputPlaceholder,
        showSave: true,
      })
    ) : dataURIInfo && !dataURIInfo.isText ? (
      renderDataURIMediaPanel({
        kind: "file",
        info: dataURIInfo,
        emptyLabel: outputPlaceholder,
        showSave: true,
      })
    ) : (
      <Textarea
        value={dataURITextOutput}
        readOnly
        placeholder={outputPlaceholder}
        invalid={Boolean(error)}
        aria-label={text.output}
        className="min-h-0 w-full flex-1 basis-0 resize-none bg-field font-mono text-[12px]"
      />
    )
  ) : (
    <Textarea
      value={output}
      readOnly
      placeholder={outputPlaceholder}
      invalid={Boolean(error)}
      aria-label={text.output}
      className="min-h-0 w-full flex-1 basis-0 resize-none bg-field"
    />
  );

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex min-h-0 flex-1 gap-[var(--machkit-layout-content-padding)] bg-surface">
        <ToolSidebar width={160} muted className="min-h-0 self-stretch">
          {CODEC_GROUPS.map((group) => (
            <div key={group.id} className="flex flex-col gap-[4px]">
              <div className="machkit-sidebar-label px-2 py-[4px]">{groupLabel(text, group.id)}</div>
              <nav className="flex flex-col gap-[4px]" aria-label={groupLabel(text, group.id)}>
                {group.items.map((item) => (
                  <SidebarNavItem
                    key={item.id}
                    active={isItemActive(item)}
                    code={item.code}
                    label={
                      item.hashFamily
                        ? hashItemLabel(text, item.hashFamily)
                        : item.id === "base"
                          ? text.base
                          : item.id === "encoding"
                            ? text.encoding
                            : messageFor(text, item.id)
                    }
                    onClick={() => selectItem(item)}
                  />
                ))}
              </nav>
            </div>
          ))}
        </ToolSidebar>

        <section className="flex min-h-0 min-w-0 flex-1 flex-col">
          <header className="flex h-11 shrink-0 items-center gap-2">
            <span className="truncate text-sm font-semibold">{titleLabel}</span>
            {hashMode && hashAlgorithms.length > 1 ? (
              <SelectControl
                variant="ghost"
                value={algorithm}
                onChange={changeAlgorithm}
                label={text.algorithm}
                className="flex-none"
                options={hashAlgorithms.map((value) => ({ value, label: value }))}
              />
            ) : null}
            {baseMode ? (
              <SelectControl
                variant="ghost"
                value={tab}
                onChange={changeBaseVariant}
                label={text.base}
                className="flex-none"
                options={BASE_VARIANTS.map((value) => ({
                  value,
                  label: messageFor(text, value),
                }))}
              />
            ) : null}
            {encodingMode ? (
              <SelectControl
                variant="ghost"
                value={tab}
                onChange={changeEncodingVariant}
                label={text.encoding}
                className="flex-none"
                options={ENCODING_VARIANTS.map((value) => ({
                  value,
                  label: messageFor(text, value),
                }))}
              />
            ) : null}
            <ActionGroup>
              <Button
                variant="ghost"
                size="sm"
                disabled={!input && !output && !hmacKey && !dataURIMediaURL}
                onClick={clearAll}
              >
                <EraserIcon size={15} />
                {text.clear}
              </Button>
            </ActionGroup>
          </header>
          {encodingIntro ? (
            <p className="mb-2 shrink-0 text-[11px] leading-relaxed text-tertiary">{encodingIntro}</p>
          ) : null}

          <div className="flex min-h-0 flex-1 flex-col gap-2.5 overflow-hidden">
            {hashMode || radixMode ? null : (
              <ToolToolbar className="flex-wrap gap-2 border-b-0">
                <div className="flex items-center gap-2">
                  <SegmentedControl
                    value={direction}
                    onChange={(value) => {
                      setDirection(value);
                      if (dataURIMode) {
                        clearDataURIMedia();
                        setDataURIInputKind("text");
                        setInput("");
                        setOutput("");
                        setError(null);
                      }
                    }}
                    label={text.direction}
                    size="compact"
                    className="w-[168px] flex-none"
                    options={[
                      {
                        value: "encode",
                        label: tab === "escape" ? text.escapeAction : text.encode,
                      },
                      {
                        value: "decode",
                        label: tab === "escape" ? text.unescapeAction : text.decode,
                      },
                    ]}
                  />
                  <IconButton
                    label={text.swap}
                    disabled={
                      Boolean(error) ||
                      (dataURIMode
                        ? direction === "encode"
                          ? !(output.trim() || dataURIMediaURL)
                          : !input.trim()
                        : !output.trim())
                    }
                    onClick={swap}
                    className="size-8.5"
                  >
                    <ArrowsLeftRightIcon size={15} />
                  </IconButton>
                </div>

                {tab === "base64" ? (
                  <ActionGroup>
                    <CheckboxField
                      checked={base64URL}
                      onCheckedChange={(checked) => setBase64URL(checked === true)}
                      label={text.base64URL}
                    />
                  </ActionGroup>
                ) : null}

                {tab === "url" ? (
                  <ActionGroup className="min-w-0 gap-2">
                    <span className="machkit-control-label whitespace-nowrap">{text.urlMode}</span>
                    <SelectControl
                      variant="ghost"
                      value={urlMode}
                      onChange={setUrlMode}
                      label={text.urlMode}
                      className="flex-none"
                      options={[
                        { value: "component", label: text.component },
                        { value: "uri", label: text.uri },
                      ]}
                    />
                  </ActionGroup>
                ) : null}
              </ToolToolbar>
            )}

            {radixMode ? (
              <ToolToolbar className="flex-wrap gap-2 border-b-0">
                <div className="flex min-w-0 flex-wrap items-center gap-2">
                  <span className="machkit-control-label whitespace-nowrap">{text.radixFrom}</span>
                  <SelectControl
                    variant="ghost"
                    value={String(fromRadix)}
                    onChange={(value) => setFromRadix(Number(value))}
                    label={text.radixFrom}
                    className="flex-none"
                    options={RADIX_OPTIONS.map((value) => ({
                      value: String(value),
                      label: text.radixBaseLabel.replace("{n}", String(value)),
                    }))}
                  />
                  <IconButton
                    label={text.swap}
                    disabled={Boolean(error) || (!input.trim() && !output.trim())}
                    onClick={swap}
                    className="size-8.5"
                  >
                    <ArrowsLeftRightIcon size={15} />
                  </IconButton>
                  <span className="machkit-control-label whitespace-nowrap">{text.radixTo}</span>
                  <SelectControl
                    variant="ghost"
                    value={String(toRadix)}
                    onChange={(value) => setToRadix(Number(value))}
                    label={text.radixTo}
                    className="flex-none"
                    options={RADIX_OPTIONS.map((value) => ({
                      value: String(value),
                      label: text.radixBaseLabel.replace("{n}", String(value)),
                    }))}
                  />
                </div>
              </ToolToolbar>
            ) : null}

            {hmacMode ? (
              <div className="flex shrink-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.hmacKey}</span>
                <Input
                  value={hmacKey}
                  onChange={(event) => setHmacKey(event.target.value)}
                  placeholder={text.hmacKeyPlaceholder}
                  aria-label={text.hmacKey}
                  spellCheck={false}
                  className="font-mono text-[12px]"
                />
              </div>
            ) : null}

            <div className="flex h-8 shrink-0 items-center gap-2">
              <span className="machkit-control-label">{text.input}</span>
              {dataURIMode && direction === "encode" ? (
                <SelectControl
                  variant="ghost"
                  value={dataURIInputKind}
                  onChange={changeDataURIInputKind}
                  label={text.dataUriType}
                  className="flex-none"
                  options={DATA_URI_KIND_OPTIONS.map((value) => ({
                    value,
                    label:
                      value === "text"
                        ? text.dataUriTypeText
                        : value === "image"
                          ? text.dataUriTypeImage
                          : text.dataUriTypeFile,
                  }))}
                />
              ) : null}
            </div>
            {dataURIMode ? (
              <input
                ref={dataURIFileRef}
                type="file"
                accept={dataURIInputKind === "image" ? "image/*" : undefined}
                className="hidden"
                onChange={(event) => {
                  onDataURIFile(event.target.files?.[0]);
                  event.target.value = "";
                }}
              />
            ) : null}
            {dataURIEncodeMediaInput ? (
              renderDataURIMediaPanel({
                kind: dataURIInputKind,
                info: dataURIInputPreview,
                emptyLabel:
                  dataURIInputKind === "image" ? text.dataUriImageEmpty : text.dataUriFileEmpty,
                onPick: () => dataURIFileRef.current?.click(),
              })
            ) : (
              <Textarea
                value={input}
                onChange={(event) => {
                  if (dataURIMode) clearDataURIMedia();
                  setInput(event.target.value);
                }}
                placeholder={inputPlaceholder}
                aria-label={text.input}
                className="min-h-0 w-full flex-1 basis-0 resize-none"
              />
            )}

            <div className="flex h-8 shrink-0 items-center gap-2">
              <span className="machkit-control-label">{text.output}</span>
              {hashMode && (showMD5Variants || hexVariants) ? null : dataURIMode &&
                direction === "decode" &&
                dataURIInfo &&
                !dataURIInfo.isText ? null : (
                <ActionGroup>
                  <Button
                    variant="ghost"
                    size="sm"
                    disabled={Boolean(error) || !(dataURIMode ? dataURITextOutput || output : output)}
                    onClick={() =>
                      machkit.copy(
                        dataURIMode && direction === "decode" ? dataURITextOutput || output : output,
                      )
                    }
                  >
                    <CopySimpleIcon size={15} />
                    {text.copy}
                  </Button>
                </ActionGroup>
              )}
            </div>
            {resultPanel}
            {error ? <StatusStrip tone="danger">{messageFor(text, error)}</StatusStrip> : null}
          </div>
        </section>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CodecTool />, { name: "Codec" });
