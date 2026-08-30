import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowsClockwise, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  Input,
  SegmentedControl,
  SelectControl,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import {
  defaultHexBytes,
  defaultNanoLength,
  defaultStringLength,
  generateIds,
  maxBatchCount,
  stringAlphabet,
  uuidNamespaces,
  type UuidNamespaceKey,
} from "./id.js";
import { messages } from "./messages.js";

const PREFS_KEY = "string-generator.prefs";
const DEFAULT_COUNT = 3;
const formats = new Set(["uuid", "ulid", "nanoid", "hex", "string"]);
const uuidVersions = new Set(["v1", "v3", "v4", "v5", "v6", "v7"]);
const namespaceKeys = new Set(["dns", "url", "oid", "x500"]);

type GeneratorFormat = "uuid" | "ulid" | "nanoid" | "hex" | "string";
type UuidVersion = "v1" | "v3" | "v4" | "v5" | "v6" | "v7";

type Prefs = {
  format: GeneratorFormat;
  uuidVersion: UuidVersion;
  count: string;
  length: string;
  stringLength: string;
  byteLength: string;
  uppercase: boolean;
  hyphens: boolean;
  namespaceKey: UuidNamespaceKey;
  name: string;
  charsetUpper: boolean;
  charsetLower: boolean;
  charsetDigits: boolean;
  charsetSymbols: boolean;
  excludeAmbiguous: boolean;
};

const defaultPrefs: Prefs = {
  format: "uuid",
  uuidVersion: "v4",
  count: String(DEFAULT_COUNT),
  length: String(defaultNanoLength),
  stringLength: String(defaultStringLength),
  byteLength: String(defaultHexBytes),
  uppercase: false,
  hyphens: true,
  namespaceKey: "dns",
  name: "www.example.com",
  charsetUpper: true,
  charsetLower: true,
  charsetDigits: true,
  charsetSymbols: true,
  excludeAmbiguous: false,
};

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function normalizePrefs(raw: unknown): Prefs {
  if (!raw || typeof raw !== "object") return { ...defaultPrefs };
  const record = raw as Record<string, unknown>;
  const formatRaw = record.format === "string" ? "string" : record.format;
  const stringLengthRaw = record.stringLength ?? record.passwordLength;
  return {
    format: formats.has(String(formatRaw)) ? (formatRaw as GeneratorFormat) : defaultPrefs.format,
    uuidVersion: uuidVersions.has(String(record.uuidVersion))
      ? (record.uuidVersion as UuidVersion)
      : defaultPrefs.uuidVersion,
    count: String(clampInt(record.count, 1, maxBatchCount, DEFAULT_COUNT)),
    length: String(clampInt(record.length, 1, 128, defaultNanoLength)),
    stringLength: String(clampInt(stringLengthRaw, 4, 128, defaultStringLength)),
    byteLength: String(clampInt(record.byteLength, 1, 64, defaultHexBytes)),
    uppercase: asBoolean(record.uppercase, defaultPrefs.uppercase),
    hyphens: asBoolean(record.hyphens, defaultPrefs.hyphens),
    namespaceKey: namespaceKeys.has(String(record.namespaceKey))
      ? (record.namespaceKey as UuidNamespaceKey)
      : defaultPrefs.namespaceKey,
    name: typeof record.name === "string" ? record.name : defaultPrefs.name,
    charsetUpper: asBoolean(record.charsetUpper, defaultPrefs.charsetUpper),
    charsetLower: asBoolean(record.charsetLower, defaultPrefs.charsetLower),
    charsetDigits: asBoolean(record.charsetDigits, defaultPrefs.charsetDigits),
    charsetSymbols: asBoolean(record.charsetSymbols, defaultPrefs.charsetSymbols),
    excludeAmbiguous: asBoolean(record.excludeAmbiguous, defaultPrefs.excludeAmbiguous),
  };
}

async function loadPrefs(): Promise<Prefs> {
  try {
    const raw = await machkit.getItem(PREFS_KEY);
    if (!raw) return { ...defaultPrefs };
    return normalizePrefs(JSON.parse(raw));
  } catch {
    return { ...defaultPrefs };
  }
}

function OptionNumber({
  label,
  id,
  value,
  onChange,
  onBlur,
  minWidth = "w-16",
}: {
  label: string;
  id: string;
  value: string;
  onChange: (event: React.ChangeEvent<HTMLInputElement>) => void;
  onBlur?: (event: React.FocusEvent<HTMLInputElement>) => void;
  minWidth?: string;
}) {
  return (
    <div className="flex items-center gap-2">
      <label htmlFor={id} className="machkit-control-label whitespace-nowrap">{label}</label>
      <Input
        id={id}
        inputMode="numeric"
        className={minWidth}
        value={value}
        onChange={onChange}
        onBlur={onBlur}
      />
    </div>
  );
}

const COUNT_OPTIONS = [1, 3, 5, 10, 20, 50, 100, 200, 500];

function CountSelect({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  const current = String(clampInt(value, 1, maxBatchCount, DEFAULT_COUNT));
  const options = useMemo(() => {
    const values = new Set(COUNT_OPTIONS.map(String));
    values.add(current);
    return [...values]
      .sort((left, right) => Number(left) - Number(right))
      .map((item) => ({ value: item, label: item }));
  }, [current]);

  return (
    <div className="flex items-center gap-2">
      <span className="machkit-control-label whitespace-nowrap">{label}</span>
      <SelectControl
        value={current}
        onChange={onChange}
        label={label}
        className="w-[80px]"
        options={options}
      />
    </div>
  );
}

const HEX_BYTE_PRESETS = ["8", "16", "32"];

function ByteLengthControl({
  label,
  id,
  value,
  onChange,
  customLabel,
}: {
  label: string;
  id: string;
  value: string;
  onChange: (value: string) => void;
  customLabel: string;
}) {
  const clamped = String(clampInt(value, 1, 64, defaultHexBytes));
  const isPreset = HEX_BYTE_PRESETS.includes(clamped);
  const [customOpen, setCustomOpen] = useState(!isPreset);
  const segmentValue = customOpen || !isPreset ? "custom" : clamped;

  useEffect(() => {
    if (!HEX_BYTE_PRESETS.includes(String(clampInt(value, 1, 64, defaultHexBytes)))) {
      setCustomOpen(true);
    }
  }, [value]);

  return (
    <div className="flex min-w-0 items-center gap-2">
      <label htmlFor={id} className="machkit-control-label whitespace-nowrap">{label}</label>
      <SegmentedControl
        value={segmentValue}
        onChange={(next) => {
          if (next === "custom") {
            setCustomOpen(true);
            return;
          }
          setCustomOpen(false);
          onChange(next);
        }}
        label={label}
        size="compact"
        className="w-[220px] flex-none"
        options={[
          { value: "8", label: "8" },
          { value: "16", label: "16" },
          { value: "32", label: "32" },
          { value: "custom", label: customLabel },
        ]}
      />
      {segmentValue === "custom" ? (
        <Input
          id={id}
          inputMode="numeric"
          className="w-14"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          onBlur={() => onChange(String(clampInt(value, 1, 64, defaultHexBytes)))}
        />
      ) : null}
    </div>
  );
}

function resolveFormat(format: GeneratorFormat, uuidVersion: UuidVersion): string {
  return format === "uuid" ? `uuid-${uuidVersion}` : format;
}

function StringGenerator() {
  const text = useToolMessages(messages);
  const [ready, setReady] = useState(false);
  const [format, setFormat] = useState<GeneratorFormat>(defaultPrefs.format);
  const [uuidVersion, setUuidVersion] = useState<UuidVersion>(defaultPrefs.uuidVersion);
  const [count, setCount] = useState(defaultPrefs.count);
  const [length, setLength] = useState(defaultPrefs.length);
  const [stringLength, setStringLength] = useState(defaultPrefs.stringLength);
  const [byteLength, setByteLength] = useState(defaultPrefs.byteLength);
  const [uppercase, setUppercase] = useState(defaultPrefs.uppercase);
  const [hyphens, setHyphens] = useState(defaultPrefs.hyphens);
  const [namespaceKey, setNamespaceKey] = useState<UuidNamespaceKey>(defaultPrefs.namespaceKey);
  const [name, setName] = useState(defaultPrefs.name);
  const [charsetUpper, setCharsetUpper] = useState(defaultPrefs.charsetUpper);
  const [charsetLower, setCharsetLower] = useState(defaultPrefs.charsetLower);
  const [charsetDigits, setCharsetDigits] = useState(defaultPrefs.charsetDigits);
  const [charsetSymbols, setCharsetSymbols] = useState(defaultPrefs.charsetSymbols);
  const [excludeAmbiguous, setExcludeAmbiguous] = useState(defaultPrefs.excludeAmbiguous);
  const [results, setResults] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const generationIDRef = useRef(0);
  const regenerationTimerRef = useRef(0);

  const formatOptions = useMemo(
    () => [
      { value: "uuid", label: text.uuid },
      { value: "ulid", label: text.ulid },
      { value: "nanoid", label: text.nanoid },
      { value: "hex", label: text.hex },
      { value: "string", label: text.string },
    ],
    [text],
  );

  const versionOptions = useMemo(
    () => [
      { value: "v1", label: text.versionV1 },
      { value: "v3", label: text.versionV3 },
      { value: "v4", label: text.versionV4 },
      { value: "v5", label: text.versionV5 },
      { value: "v6", label: text.versionV6 },
      { value: "v7", label: text.versionV7 },
    ],
    [text],
  );

  const namespaceOptions = useMemo(
    () => [
      { value: "dns", label: text.nsDns },
      { value: "url", label: text.nsUrl },
      { value: "oid", label: text.nsOid },
      { value: "x500", label: text.nsX500 },
    ],
    [text],
  );

  const resultText = results.join("\n");
  const isNameBased = format === "uuid" && (uuidVersion === "v3" || uuidVersion === "v5");
  const hasStringAlphabet = stringAlphabet({
    upper: charsetUpper,
    lower: charsetLower,
    digits: charsetDigits,
    symbols: charsetSymbols,
    excludeAmbiguous,
  }).length > 0;

  const currentPrefs = (): Prefs => ({
    format,
    uuidVersion,
    count: String(clampInt(count, 1, maxBatchCount, DEFAULT_COUNT)),
    length: String(clampInt(length, 1, 128, defaultNanoLength)),
    stringLength: String(clampInt(stringLength, 4, 128, defaultStringLength)),
    byteLength: String(clampInt(byteLength, 1, 64, defaultHexBytes)),
    uppercase,
    hyphens,
    namespaceKey,
    name,
    charsetUpper,
    charsetLower,
    charsetDigits,
    charsetSymbols,
    excludeAmbiguous,
  });

  const applyPrefs = (prefs: Prefs) => {
    setFormat(prefs.format);
    setUuidVersion(prefs.uuidVersion);
    setCount(prefs.count);
    setLength(prefs.length);
    setStringLength(prefs.stringLength);
    setByteLength(prefs.byteLength);
    setUppercase(prefs.uppercase);
    setHyphens(prefs.hyphens);
    setNamespaceKey(prefs.namespaceKey);
    setName(prefs.name);
    setCharsetUpper(prefs.charsetUpper);
    setCharsetLower(prefs.charsetLower);
    setCharsetDigits(prefs.charsetDigits);
    setCharsetSymbols(prefs.charsetSymbols);
    setExcludeAmbiguous(prefs.excludeAmbiguous);
  };

  const regenerate = async (prefs: Prefs = currentPrefs()) => {
    const generationID = ++generationIDRef.current;
    const resolved = resolveFormat(prefs.format, prefs.uuidVersion);
    const options = {
      uppercase: prefs.uppercase,
      hyphens: prefs.hyphens,
      length: prefs.format === "string"
        ? clampInt(prefs.stringLength, 4, 128, defaultStringLength)
        : clampInt(prefs.length, 1, 128, defaultNanoLength),
      byteLength: clampInt(prefs.byteLength, 1, 64, defaultHexBytes),
      upper: prefs.charsetUpper,
      lower: prefs.charsetLower,
      digits: prefs.charsetDigits,
      symbols: prefs.charsetSymbols,
      excludeAmbiguous: prefs.excludeAmbiguous,
      namespace: uuidNamespaces[prefs.namespaceKey] || uuidNamespaces.dns,
      name: prefs.name,
    };
    if (prefs.format === "string" && !stringAlphabet(options).length) {
      if (generationID !== generationIDRef.current) return;
      setError("alphabet-empty");
      setResults([]);
      return;
    }
    const nextResults = await generateIds(
      resolved,
      clampInt(prefs.count, 1, maxBatchCount, DEFAULT_COUNT),
      options,
    );
    if (generationID !== generationIDRef.current) return;
    setError(null);
    setResults(nextResults);
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const prefs = await loadPrefs();
      if (cancelled) return;
      applyPrefs(prefs);
      setReady(true);
    })();
    return () => {
      cancelled = true;
      generationIDRef.current += 1;
    };
  }, []);

  useEffect(() => {
    if (!ready) return undefined;
    const prefs = currentPrefs();
    machkit.setItem(PREFS_KEY, JSON.stringify(prefs)).catch(() => {});
    window.clearTimeout(regenerationTimerRef.current);
    const timer = window.setTimeout(() => {
      regenerationTimerRef.current = 0;
      regenerate(prefs);
    }, 120);
    regenerationTimerRef.current = timer;
    return () => {
      window.clearTimeout(timer);
      if (regenerationTimerRef.current === timer) regenerationTimerRef.current = 0;
    };
  }, [
    ready,
    format,
    uuidVersion,
    count,
    length,
    stringLength,
    byteLength,
    uppercase,
    hyphens,
    namespaceKey,
    name,
    charsetUpper,
    charsetLower,
    charsetDigits,
    charsetSymbols,
    excludeAmbiguous,
  ]);

  const regenerateNow = () => {
    window.clearTimeout(regenerationTimerRef.current);
    regenerationTimerRef.current = 0;
    regenerate(currentPrefs());
  };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-4 pb-5">
        <ToolToolbar className="gap-2">
          <SegmentedControl
            value={format}
            onChange={(value) => setFormat(value as GeneratorFormat)}
            label={text.format}
            size="compact"
            className="min-w-0 w-full"
            options={formatOptions}
          />
          </ToolToolbar>

        <ToolToolbar className="flex-wrap gap-x-4 gap-y-2">
          {format === "uuid" ? (
            <SegmentedControl
              value={uuidVersion}
              onChange={(value) => setUuidVersion(value as UuidVersion)}
              label={text.version}
              size="compact"
              className="w-[288px] flex-none"
              options={versionOptions}
            />
          ) : null}

          <CountSelect
            label={text.count}
            value={count}
            onChange={setCount}
          />

          {format === "nanoid" ? (
            <OptionNumber
              label={text.length}
              id="string-length"
              value={length}
              onChange={(event) => setLength(event.target.value)}
              onBlur={() => setLength(String(clampInt(length, 1, 128, defaultNanoLength)))}
            />
          ) : null}

          {format === "string" ? (
            <OptionNumber
              label={text.length}
              id="string-random-length"
              value={stringLength}
              onChange={(event) => setStringLength(event.target.value)}
              onBlur={() => setStringLength(String(clampInt(stringLength, 4, 128, defaultStringLength)))}
            />
          ) : null}

          {format === "hex" ? (
            <ByteLengthControl
              label={text.bytes}
              id="string-bytes"
              value={byteLength}
              onChange={setByteLength}
              customLabel={text.custom}
            />
          ) : null}

          <ActionGroup>
            <Button
              variant="secondary"
              size="sm"
              disabled={format === "string" && !hasStringAlphabet}
              onClick={regenerateNow}
            >
              <ArrowsClockwise size={15} />
              {text.regenerate}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        {(isNameBased || format === "string" || format === "uuid" || format === "ulid" || format === "hex") ? (
          <ToolToolbar className="flex-wrap gap-x-4 gap-y-2">
            {isNameBased ? (
              <>
                <div className="flex min-w-0 items-center gap-2">
                  <span className="machkit-control-label whitespace-nowrap">{text.namespace}</span>
                  <SelectControl
                    value={namespaceKey}
                    onChange={(value) => setNamespaceKey(value as UuidNamespaceKey)}
                    label={text.namespace}
                    className="w-[120px]"
                    options={namespaceOptions}
                  />
                </div>
                <div className="flex min-w-0 flex-1 items-center gap-2">
                  <label htmlFor="string-name" className="machkit-control-label whitespace-nowrap">
                    {text.name}
                  </label>
                  <Input
                    id="string-name"
                    className="min-w-[160px] flex-1"
                    value={name}
                    onChange={(event) => setName(event.target.value)}
                    placeholder={text.namePlaceholder}
                  />
                </div>
              </>
            ) : null}

            {format === "string" ? (
              <>
                <CheckboxField
                  checked={charsetUpper}
                  onCheckedChange={(checked) => setCharsetUpper(checked === true)}
                  label={text.charsetUpper}
                />
                <CheckboxField
                  checked={charsetLower}
                  onCheckedChange={(checked) => setCharsetLower(checked === true)}
                  label={text.charsetLower}
                />
                <CheckboxField
                  checked={charsetDigits}
                  onCheckedChange={(checked) => setCharsetDigits(checked === true)}
                  label={text.charsetDigits}
                />
                <CheckboxField
                  checked={charsetSymbols}
                  onCheckedChange={(checked) => setCharsetSymbols(checked === true)}
                  label={text.charsetSymbols}
                />
                <CheckboxField
                  checked={excludeAmbiguous}
                  onCheckedChange={(checked) => setExcludeAmbiguous(checked === true)}
                  label={text.excludeAmbiguous}
                />
              </>
            ) : null}

            {format === "uuid" || format === "ulid" || format === "hex" ? (
              <>
                <CheckboxField
                  checked={uppercase}
                  onCheckedChange={(checked) => setUppercase(checked === true)}
                  label={text.uppercase}
                />
                {format === "uuid" ? (
                  <CheckboxField
                    checked={hyphens}
                    onCheckedChange={(checked) => setHyphens(checked === true)}
                    label={text.hyphens}
                  />
                ) : null}
              </>
            ) : null}
          </ToolToolbar>
        ) : null}

        {error === "alphabet-empty" ? (
          <StatusStrip tone="danger">{text.alphabetEmpty}</StatusStrip>
        ) : null}

        <div className="flex w-full flex-col gap-2">
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.results}</span>
            {results.length ? <span className="text-xs text-tertiary">{results.length}</span> : null}
            <span className="text-xs text-tertiary">{text.clickToCopy}</span>
            <ActionGroup>
              <Button
                variant="ghost"
                size="sm"
                disabled={!resultText}
                onClick={() => machkit.copy(resultText)}
              >
                <CopySimple size={16} />
                {text.copyAll}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                disabled={!resultText}
                onClick={() => setResults([])}
              >
                <Eraser size={16} />
                {text.clear}
              </Button>
            </ActionGroup>
          </div>

          {results.length ? (
            <ol
              className="max-h-[360px] overflow-auto rounded-control border border-border bg-field"
              aria-label={text.results}
            >
              {results.map((value, index) => (
                <li key={`${index}-${value}`} className="border-b border-border last:border-b-0">
                  <Button
                    type="button"
                    variant="ghost"
                    className="flex h-auto w-full items-center justify-start gap-3 rounded-none px-3.5 py-2.5 text-left font-normal hover:bg-muted"
                    title={text.clickToCopy}
                    onClick={() => machkit.copy(value)}
                  >
                    <span className="w-7 shrink-0 text-xs tabular-nums text-tertiary">{index + 1}</span>
                    <span className="min-w-0 flex-1 truncate font-mono text-[13px] text-foreground">{value}</span>
                    <CopySimple size={14} className="shrink-0 text-tertiary" />
                  </Button>
                </li>
              ))}
            </ol>
          ) : (
            <StatusStrip tone="neutral">
              {error === "alphabet-empty" ? text.alphabetEmpty : text.empty}
            </StatusStrip>
          )}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<StringGenerator />, { name: "String Generator" });
