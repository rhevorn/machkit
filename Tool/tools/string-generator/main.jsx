import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowsClockwise, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  CheckboxField,
  InlineMessage,
  Input,
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
import {
  defaultHexBytes,
  defaultNanoLength,
  defaultPasswordLength,
  generateIds,
  maxBatchCount,
  passwordAlphabet,
  uuidNamespaces,
} from "./id.js";
import { messages } from "./messages.js";

const PREFS_KEY = "string-generator.prefs";
const DEFAULT_COUNT = 10;
const formats = new Set(["uuid", "ulid", "nanoid", "hex", "password"]);
const uuidVersions = new Set(["v1", "v3", "v4", "v5", "v6", "v7"]);
const namespaceKeys = new Set(["dns", "url", "oid", "x500"]);

const defaultPrefs = {
  format: "uuid",
  uuidVersion: "v4",
  count: String(DEFAULT_COUNT),
  length: String(defaultNanoLength),
  passwordLength: String(defaultPasswordLength),
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

function clampInt(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function asBoolean(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizePrefs(raw) {
  if (!raw || typeof raw !== "object") return { ...defaultPrefs };
  return {
    format: formats.has(raw.format) ? raw.format : defaultPrefs.format,
    uuidVersion: uuidVersions.has(raw.uuidVersion) ? raw.uuidVersion : defaultPrefs.uuidVersion,
    count: String(clampInt(raw.count, 1, maxBatchCount, DEFAULT_COUNT)),
    length: String(clampInt(raw.length, 1, 128, defaultNanoLength)),
    passwordLength: String(clampInt(raw.passwordLength, 4, 128, defaultPasswordLength)),
    byteLength: String(clampInt(raw.byteLength, 1, 64, defaultHexBytes)),
    uppercase: asBoolean(raw.uppercase, defaultPrefs.uppercase),
    hyphens: asBoolean(raw.hyphens, defaultPrefs.hyphens),
    namespaceKey: namespaceKeys.has(raw.namespaceKey) ? raw.namespaceKey : defaultPrefs.namespaceKey,
    name: typeof raw.name === "string" ? raw.name : defaultPrefs.name,
    charsetUpper: asBoolean(raw.charsetUpper, defaultPrefs.charsetUpper),
    charsetLower: asBoolean(raw.charsetLower, defaultPrefs.charsetLower),
    charsetDigits: asBoolean(raw.charsetDigits, defaultPrefs.charsetDigits),
    charsetSymbols: asBoolean(raw.charsetSymbols, defaultPrefs.charsetSymbols),
    excludeAmbiguous: asBoolean(raw.excludeAmbiguous, defaultPrefs.excludeAmbiguous),
  };
}

async function loadPrefs() {
  try {
    const raw = await machkit.getItem(PREFS_KEY);
    if (!raw) return { ...defaultPrefs };
    return normalizePrefs(JSON.parse(raw));
  } catch {
    return { ...defaultPrefs };
  }
}

function OptionNumber({ label, id, value, onChange, onBlur, minWidth = "w-16" }) {
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

function resolveFormat(format, uuidVersion) {
  return format === "uuid" ? `uuid-${uuidVersion}` : format;
}

function StringGenerator() {
  const text = useToolMessages(messages);
  const [ready, setReady] = useState(false);
  const [format, setFormat] = useState(defaultPrefs.format);
  const [uuidVersion, setUuidVersion] = useState(defaultPrefs.uuidVersion);
  const [count, setCount] = useState(defaultPrefs.count);
  const [length, setLength] = useState(defaultPrefs.length);
  const [passwordLength, setPasswordLength] = useState(defaultPrefs.passwordLength);
  const [byteLength, setByteLength] = useState(defaultPrefs.byteLength);
  const [uppercase, setUppercase] = useState(defaultPrefs.uppercase);
  const [hyphens, setHyphens] = useState(defaultPrefs.hyphens);
  const [namespaceKey, setNamespaceKey] = useState(defaultPrefs.namespaceKey);
  const [name, setName] = useState(defaultPrefs.name);
  const [charsetUpper, setCharsetUpper] = useState(defaultPrefs.charsetUpper);
  const [charsetLower, setCharsetLower] = useState(defaultPrefs.charsetLower);
  const [charsetDigits, setCharsetDigits] = useState(defaultPrefs.charsetDigits);
  const [charsetSymbols, setCharsetSymbols] = useState(defaultPrefs.charsetSymbols);
  const [excludeAmbiguous, setExcludeAmbiguous] = useState(defaultPrefs.excludeAmbiguous);
  const [results, setResults] = useState([]);
  const [error, setError] = useState(null);
  const generationIDRef = useRef(0);

  const formatOptions = useMemo(
    () => [
      { value: "uuid", label: text.uuid },
      { value: "ulid", label: text.ulid },
      { value: "nanoid", label: text.nanoid },
      { value: "hex", label: text.hex },
      { value: "password", label: text.password },
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
  const hasPasswordAlphabet = passwordAlphabet({
    upper: charsetUpper,
    lower: charsetLower,
    digits: charsetDigits,
    symbols: charsetSymbols,
    excludeAmbiguous,
  }).length > 0;

  const currentPrefs = () => ({
    format,
    uuidVersion,
    count: String(clampInt(count, 1, maxBatchCount, DEFAULT_COUNT)),
    length: String(clampInt(length, 1, 128, defaultNanoLength)),
    passwordLength: String(clampInt(passwordLength, 4, 128, defaultPasswordLength)),
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

  const persistPrefs = (prefs = currentPrefs()) => {
    machkit.setItem(PREFS_KEY, JSON.stringify(prefs)).catch(() => {});
  };

  const applyPrefs = (prefs) => {
    setFormat(prefs.format);
    setUuidVersion(prefs.uuidVersion);
    setCount(prefs.count);
    setLength(prefs.length);
    setPasswordLength(prefs.passwordLength);
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

  const regenerate = async (prefs = currentPrefs()) => {
    const generationID = ++generationIDRef.current;
    const resolved = resolveFormat(prefs.format, prefs.uuidVersion);
    const options = {
      uppercase: prefs.uppercase,
      hyphens: prefs.hyphens,
      length: prefs.format === "password"
        ? clampInt(prefs.passwordLength, 4, 128, defaultPasswordLength)
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
    if (prefs.format === "password" && !passwordAlphabet(options).length) {
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
      await regenerate(prefs);
    })();
    return () => {
      cancelled = true;
      generationIDRef.current += 1;
    };
  }, []);

  useEffect(() => {
    if (!ready) return;
    persistPrefs(currentPrefs());
  }, [
    ready,
    format,
    uuidVersion,
    count,
    length,
    passwordLength,
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

  const changeFormat = (nextFormat) => {
    const next = { ...currentPrefs(), format: nextFormat };
    setFormat(nextFormat);
    regenerate(next);
  };

  const changeUuidVersion = (nextVersion) => {
    const next = { ...currentPrefs(), uuidVersion: nextVersion };
    setUuidVersion(nextVersion);
    regenerate(next);
  };

  return (
    <ToolPage title={text.title} adaptiveHeight>
      <ToolContent className="flex flex-col pt-4 pb-5">
        <div className="machkit-toolbar gap-2">
          <SegmentedControl
            value={format}
            onChange={changeFormat}
            label={text.format}
            size="compact"
            className="min-w-0 w-full"
            options={formatOptions}
          />
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <div className="machkit-toolbar flex-wrap gap-x-4 gap-y-2">
          {format === "uuid" ? (
            <SegmentedControl
              value={uuidVersion}
              onChange={changeUuidVersion}
              label={text.version}
              size="compact"
              className="w-[288px] flex-none"
              options={versionOptions}
            />
          ) : null}

          <OptionNumber
            label={text.count}
            id="string-count"
            value={count}
            onChange={(event) => setCount(event.target.value)}
            onBlur={() => setCount(String(clampInt(count, 1, maxBatchCount, DEFAULT_COUNT)))}
          />

          {isNameBased ? (
            <>
              <div className="flex min-w-0 items-center gap-2">
                <span className="machkit-control-label whitespace-nowrap">{text.namespace}</span>
                <SelectControl
                  value={namespaceKey}
                  onChange={setNamespaceKey}
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

          {format === "nanoid" ? (
            <OptionNumber
              label={text.length}
              id="string-length"
              value={length}
              onChange={(event) => setLength(event.target.value)}
              onBlur={() => setLength(String(clampInt(length, 1, 128, defaultNanoLength)))}
            />
          ) : null}

          {format === "password" ? (
            <OptionNumber
              label={text.length}
              id="string-password-length"
              value={passwordLength}
              onChange={(event) => setPasswordLength(event.target.value)}
              onBlur={() => setPasswordLength(String(clampInt(passwordLength, 4, 128, defaultPasswordLength)))}
            />
          ) : null}

          {format === "hex" ? (
            <OptionNumber
              label={text.bytes}
              id="string-bytes"
              value={byteLength}
              onChange={(event) => setByteLength(event.target.value)}
              onBlur={() => setByteLength(String(clampInt(byteLength, 1, 64, defaultHexBytes)))}
            />
          ) : null}

          {format === "password" ? (
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
          ) : (
            <>
              {format !== "nanoid" ? (
                <CheckboxField
                  checked={uppercase}
                  onCheckedChange={(checked) => setUppercase(checked === true)}
                  label={text.uppercase}
                />
              ) : null}
              {format === "uuid" ? (
                <CheckboxField
                  checked={hyphens}
                  onCheckedChange={(checked) => setHyphens(checked === true)}
                  label={text.hyphens}
                />
              ) : null}
            </>
          )}

          <div className="ml-auto">
            <Button
              variant="secondary"
              size="sm"
              disabled={format === "password" && !hasPasswordAlphabet}
              onClick={() => regenerate(currentPrefs())}
            >
              <ArrowsClockwise size={15} />
              {text.regenerate}
            </Button>
          </div>
        </div>

        {error === "alphabet-empty" ? (
          <InlineMessage tone="danger">{text.alphabetEmpty}</InlineMessage>
        ) : null}

        <div className="flex w-full flex-col gap-2 pt-1">
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.results}</span>
            {results.length ? <span className="text-xs text-tertiary">{results.length}</span> : null}
            <div className="ml-auto flex gap-1">
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
            </div>
          </div>
          {results.length ? (
            <Textarea
              className="min-h-[260px] font-mono text-[13px] leading-6"
              value={resultText}
              aria-label={text.results}
              readOnly
              spellCheck={false}
            />
          ) : (
            <InlineMessage tone="neutral">
              {error === "alphabet-empty" ? text.alphabetEmpty : text.empty}
            </InlineMessage>
          )}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<StringGenerator />, { name: "String Generator" });
