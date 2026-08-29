import React, { useEffect, useMemo, useRef, useState } from "react";
import { BracketsCurly, CopySimple, Eraser, FolderOpen, GearSix, Play, Plus, Trash, X } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  Input,
  ResultPanel,
  SegmentedControl,
  SelectControl,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  bodyModes,
  buildCurl,
  buildFetch,
  createEmptyRequest,
  createFormField,
  createPair,
  formatRawBody,
  httpMethods,
  parseCurl,
} from "./curl.js";
import { messages } from "./messages.js";

const EMPTY_PAIR = Object.freeze({ id: "__empty__", key: "", value: "" });

/** 3 Input rows: h-9.5 + py-2*2 + border, with a little slack so three fit. */
const LIST_MAX_H = "max-h-[calc(3*(2.375rem+1.25rem)+2px)] overflow-y-auto";
/** Raw body: same height as three input rows. */
const BODY_H = "h-[calc(3*(2.375rem+1.25rem)+2px)]";

function PairEditor({ label, rows, onChange, text, compact }) {
  const list = rows.length ? rows : [EMPTY_PAIR];

  function updateRow(id, patch) {
    if (id === EMPTY_PAIR.id) {
      onChange([createPair(patch.key ?? "", patch.value ?? "")]);
      return;
    }
    onChange(rows.map((row) => (row.id === id ? { ...row, ...patch } : row)));
  }

  function removeRow(id) {
    if (id === EMPTY_PAIR.id) return;
    onChange(rows.filter((row) => row.id !== id));
  }

  return (
    <div className="flex min-h-0 flex-col gap-1.5">
      <div className="flex items-center justify-between gap-2">
        <span className="machkit-control-label">{label}</span>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onChange([...(rows.length ? rows : []), createPair()])}
        >
          <Plus size={15} />
          {text.addRow}
        </Button>
      </div>
      <div className={`overflow-hidden ${compact ? LIST_MAX_H : ""}`}>
        {list.map((row) => (
          <div key={row.id} className="flex items-center gap-2 py-1.5">
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.key}
              placeholder={text.key}
              onChange={(event) => updateRow(row.id, { key: event.target.value })}
              spellCheck={false}
            />
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.value}
              placeholder={text.value}
              onChange={(event) => updateRow(row.id, { value: event.target.value })}
              spellCheck={false}
            />
            <Button
              variant="ghost"
              size="sm"
              className="shrink-0"
              disabled={row.id === EMPTY_PAIR.id && !rows.length}
              onClick={() => removeRow(row.id)}
            >
              <Trash size={15} />
            </Button>
          </div>
        ))}
      </div>
    </div>
  );
}

function FormFieldEditor({ label, rows, onChange, text, allowFile }) {
  const list = rows.length ? rows : [createFormField()];
  const pickingRef = useRef(false);

  function updateRow(id, patch) {
    if (!rows.length) {
      onChange([createFormField(patch.key ?? "", patch.value ?? "", patch.kind ?? "text")]);
      return;
    }
    onChange(rows.map((row) => (row.id === id ? { ...row, ...patch } : row)));
  }

  async function chooseFile(row) {
    if (pickingRef.current) return;
    pickingRef.current = true;
    try {
      const picked = await machkit.pickFile({ prompt: text.chooseFile });
      if (!picked?.path) return;
      if (!rows.length) {
        onChange([createFormField(row.key || "file", picked.path, "file")]);
        return;
      }
      updateRow(row.id, { kind: "file", value: picked.path });
    } catch {
      // keep typed path
    } finally {
      pickingRef.current = false;
    }
  }

  return (
    <div className="flex min-h-0 flex-col gap-1.5">
      <div className="flex items-center justify-between gap-2">
        <span className="machkit-control-label">{label}</span>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onChange([...(rows.length ? rows : []), createFormField()])}
        >
          <Plus size={15} />
          {text.addRow}
        </Button>
      </div>
      <div className={`overflow-hidden ${LIST_MAX_H}`}>
        {list.map((row) => (
          <div key={row.id} className="flex items-center gap-2 py-1.5">
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.key}
              placeholder={text.key}
              onChange={(event) => updateRow(row.id, { key: event.target.value })}
              spellCheck={false}
            />
            {allowFile ? (
              <Button
                variant="secondary"
                size="compact"
                className="shrink-0 px-2 font-mono text-[11px] font-normal"
                onClick={() => updateRow(row.id, { kind: row.kind === "file" ? "text" : "file" })}
                title={text.fieldType}
              >
                {row.kind === "file" ? text.fieldFile : text.fieldText}
              </Button>
            ) : null}
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.value}
              placeholder={row.kind === "file" ? text.filePathPlaceholder : text.value}
              onChange={(event) => updateRow(row.id, { value: event.target.value })}
              spellCheck={false}
            />
            {allowFile && row.kind === "file" ? (
              <Button
                variant="ghost"
                size="sm"
                className="shrink-0"
                onClick={() => chooseFile(row)}
                title={text.chooseFile}
              >
                <FolderOpen size={15} />
              </Button>
            ) : null}
            <Button
              variant="ghost"
              size="sm"
              className="shrink-0"
              onClick={() => onChange(rows.filter((item) => item.id !== row.id))}
            >
              <Trash size={15} />
            </Button>
          </div>
        ))}
      </div>
      {allowFile ? <p className="text-[11px] text-tertiary">{text.fileHint}</p> : null}
    </div>
  );
}

function OptionsDialog({ open, onClose, request, patchRequest, text }) {
  useEffect(() => {
    if (!open) return undefined;
    const onKeyDown = (event) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/35 p-4"
      role="presentation"
      onClick={onClose}
    >
      <ResultPanel
        className="w-full max-w-[360px] shadow-popover"
        role="dialog"
        aria-modal="true"
        aria-label={text.optionsTitle}
        title={text.optionsTitle}
        actions={
          <Button variant="ghost" size="sm" onClick={onClose} aria-label={text.close}>
            <X size={16} />
          </Button>
        }
        bodyClassName="flex flex-col gap-3 px-4 py-4"
        onClick={(event) => event.stopPropagation()}
      >
        <CheckboxField
          checked={Boolean(request.insecure)}
          onCheckedChange={(checked) => patchRequest({ insecure: Boolean(checked) })}
          label={text.insecure}
        />
        <CheckboxField
          checked={Boolean(request.followRedirects)}
          onCheckedChange={(checked) => patchRequest({ followRedirects: Boolean(checked) })}
          label={text.followRedirects}
        />
        <CheckboxField
          checked={Boolean(request.compressed)}
          onCheckedChange={(checked) => patchRequest({ compressed: Boolean(checked) })}
          label={text.compressed}
        />
        <div className="-mx-4 -mb-4 mt-1 flex justify-end border-t border-border px-4 py-3">
          <Button variant="secondary" size="sm" onClick={onClose}>
            {text.close}
          </Button>
        </div>
      </ResultPanel>
    </div>
  );
}

const SPLIT_STORAGE_KEY = "machkit.curl-lab.leftRatio";
const DEFAULT_LEFT_RATIO = 0.5;
const MIN_LEFT_RATIO = 0.26;
const MAX_LEFT_RATIO = 0.74;

function readLeftRatio() {
  try {
    const value = Number(window.localStorage.getItem(SPLIT_STORAGE_KEY));
    if (Number.isFinite(value) && value >= MIN_LEFT_RATIO && value <= MAX_LEFT_RATIO) return value;
  } catch {
    // ignore
  }
  return DEFAULT_LEFT_RATIO;
}

function clampLeftRatio(value) {
  return Math.min(MAX_LEFT_RATIO, Math.max(MIN_LEFT_RATIO, value));
}

function HorizontalSplit({ left, right, label }) {
  const containerRef = useRef(null);
  const [leftRatio, setLeftRatio] = useState(readLeftRatio);
  const dragRef = useRef(null);

  useEffect(() => {
    try {
      window.localStorage.setItem(SPLIT_STORAGE_KEY, String(leftRatio));
    } catch {
      // ignore
    }
  }, [leftRatio]);

  function endDrag(event) {
    if (!dragRef.current) return;
    dragRef.current = null;
    document.body.style.removeProperty("cursor");
    document.body.style.removeProperty("user-select");
    try {
      event.currentTarget.releasePointerCapture(event.pointerId);
    } catch {
      // ignore
    }
  }

  return (
    <div ref={containerRef} className="flex min-h-0 flex-1 overflow-hidden">
      <div
        className="flex min-h-0 min-w-0 flex-col overflow-hidden pr-1"
        style={{ flex: `0 0 ${leftRatio * 100}%` }}
      >
        {left}
      </div>
      <div
        role="separator"
        aria-orientation="vertical"
        aria-label={label}
        aria-valuemin={Math.round(MIN_LEFT_RATIO * 100)}
        aria-valuemax={Math.round(MAX_LEFT_RATIO * 100)}
        aria-valuenow={Math.round(leftRatio * 100)}
        tabIndex={0}
        className="group relative z-10 w-3 shrink-0 cursor-col-resize touch-none outline-none"
        onPointerDown={(event) => {
          if (event.button !== 0) return;
          const container = containerRef.current;
          if (!container) return;
          event.preventDefault();
          const rect = container.getBoundingClientRect();
          dragRef.current = { left: rect.left, width: rect.width };
          document.body.style.cursor = "col-resize";
          document.body.style.userSelect = "none";
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerMove={(event) => {
          const drag = dragRef.current;
          if (!drag || drag.width <= 0) return;
          setLeftRatio(clampLeftRatio((event.clientX - drag.left) / drag.width));
        }}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={(event) => {
          if (event.key === "ArrowLeft") {
            event.preventDefault();
            setLeftRatio((ratio) => clampLeftRatio(ratio - 0.02));
          } else if (event.key === "ArrowRight") {
            event.preventDefault();
            setLeftRatio((ratio) => clampLeftRatio(ratio + 0.02));
          }
        }}
      >
        <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-border transition-colors group-hover:bg-accent group-focus-visible:bg-accent group-active:bg-accent" />
      </div>
      <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden pl-1">{right}</div>
    </div>
  );
}

function CurlLabTool() {
  const text = useToolMessages(messages);
  const [request, setRequest] = useState(() => createEmptyRequest());
  const [curlText, setCurlText] = useState(() => buildCurl(createEmptyRequest()));
  const [editSource, setEditSource] = useState("form");
  const [codeMode, setCodeMode] = useState("curl");
  const [parseError, setParseError] = useState(null);
  const [running, setRunning] = useState(false);
  const [runError, setRunError] = useState(null);
  const [runResult, setRunResult] = useState(null);
  const [optionsOpen, setOptionsOpen] = useState(false);
  const [bodyFormatError, setBodyFormatError] = useState(null);
  const runLock = useRef(false);
  const runGeneration = useRef(0);

  const fetchSnippet = useMemo(() => buildFetch(request), [request]);
  const bodyMode = bodyModes.includes(request.bodyMode) ? request.bodyMode : "none";
  const codeText = codeMode === "fetch" ? fetchSnippet : curlText;
  const enabledFlagCount = [request.insecure, request.followRedirects, request.compressed].filter(Boolean)
    .length;

  useEffect(() => () => {
    runGeneration.current += 1;
    if (machkit.isEmbedded) {
      machkit.curlLab("cancel").catch(() => {});
    }
  }, []);

  useEffect(() => {
    if (editSource !== "form") return;
    setCurlText(buildCurl(request));
    setParseError(null);
  }, [request, editSource]);

  useEffect(() => {
    if (editSource !== "curl" || codeMode !== "curl") return;
    const parsed = parseCurl(curlText);
    if (parsed.ok) {
      setRequest(parsed.request);
      setParseError(null);
    } else {
      setParseError(parsed.error);
    }
  }, [curlText, editSource, codeMode]);

  function patchRequest(patch) {
    setEditSource("form");
    setBodyFormatError(null);
    setRequest((prev) => ({ ...prev, ...patch }));
  }

  function formatBody() {
    const result = formatRawBody(request.body);
    if (!result.ok) {
      setBodyFormatError(result.error);
      return;
    }
    setBodyFormatError(null);
    patchRequest({ body: result.text });
  }

  function setPairs(key, rows) {
    setEditSource("form");
    setRequest((prev) => ({ ...prev, [key]: rows }));
  }

  function onBodyModeChange(next) {
    setEditSource("form");
    setRequest((prev) => {
      const patch = { bodyMode: next };
      if ((next === "urlencoded" || next === "formdata") && !(prev.formFields || []).length) {
        patch.formFields = [createFormField()];
      }
      if (next !== "none" && (prev.method === "GET" || prev.method === "HEAD") && next !== "urlencoded") {
        patch.method = "POST";
      }
      return { ...prev, ...patch };
    });
  }

  function onCurlChange(value) {
    setEditSource("curl");
    setCurlText(value);
  }

  function clearAll() {
    const empty = createEmptyRequest();
    setEditSource("form");
    setRequest(empty);
    setCurlText(buildCurl(empty));
    setParseError(null);
    setRunError(null);
    setRunResult(null);
  }

  async function runRequest() {
    if (runLock.current || running) return;
    const url = String(request.url || "").trim();
    if (!url) {
      setRunError("empty-url");
      return;
    }
    if (!machkit.isEmbedded) {
      setRunError("app-only");
      return;
    }

    const generation = ++runGeneration.current;
    runLock.current = true;
    setRunning(true);
    setRunError(null);
    try {
      const result = await machkit.curlLab("run", {
        method: request.method,
        url: request.url,
        headers: (request.headers || []).map(({ key, value }) => ({ key, value })),
        query: (request.query || []).map(({ key, value }) => ({ key, value })),
        bodyMode: request.bodyMode,
        body: request.body || "",
        formFields: (request.formFields || []).map(({ key, value, kind }) => ({
          key,
          value,
          kind,
        })),
        insecure: Boolean(request.insecure),
        followRedirects: Boolean(request.followRedirects),
        compressed: Boolean(request.compressed),
      });
      if (generation !== runGeneration.current) return;
      if (result?.error && !result?.ok && result?.statusCode == null) {
        setRunResult(result);
        setRunError(String(result.error));
      } else {
        setRunResult(result);
        setRunError(null);
      }
    } catch (error) {
      if (generation !== runGeneration.current) return;
      setRunResult(null);
      setRunError(error instanceof Error ? error.message : "run-failed");
    } finally {
      if (generation === runGeneration.current) {
        setRunning(false);
        runLock.current = false;
      }
    }
  }

  async function cancelRequest() {
    if (!running) return;
    runGeneration.current += 1;
    runLock.current = false;
    setRunning(false);
    setRunError("canceled");
    try {
      await machkit.curlLab("cancel");
    } catch {
      // Native cancel is best-effort; UI already reflects canceled state.
    }
  }

  const status = running
    ? { tone: "info", label: text.running }
    : runError
      ? { tone: "danger", label: runErrorLabel(runError, text) }
      : bodyFormatError
        ? { tone: "danger", label: bodyFormatErrorLabel(bodyFormatError, text) }
      : parseError
        ? {
            tone: "danger",
            label:
              parseError === "empty"
                ? text.empty
                : parseError === "too-large"
                  ? text.tooLarge
                  : parseError === "missing-url"
                    ? text.missingUrl
                    : text.notCurl,
          }
        : null;

  const bodyModeOptions = [
    { value: "none", label: text.bodyNone },
    { value: "raw", label: text.bodyRaw },
    { value: "urlencoded", label: text.bodyUrlencoded },
    { value: "formdata", label: text.bodyFormData },
  ];

  const responseSummary =
    runResult?.statusCode != null
      ? text.runStatus
          .replace("{status}", String(runResult.statusCode ?? "—"))
          .replace(
            "{ms}",
            runResult.durationMs != null ? String(Math.round(runResult.durationMs)) : "—",
          )
      : text.response;

  return (
    <ToolPage title={text.title} adaptiveHeight={false}>
      <ToolContent className="flex h-full min-h-0 flex-col gap-2 pt-3 pb-4">
        {status ? <StatusStrip tone={status.tone}>{status.label}</StatusStrip> : null}

        <HorizontalSplit
          label={text.splitResize}
          left={
            <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
              <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto pt-0.5">
                <ToolToolbar className="gap-2">
                  <SelectControl
                    value={request.method}
                    onChange={(method) => patchRequest({ method })}
                    label={text.method}
                    className="w-[108px] flex-none"
                    options={httpMethods.map((value) => ({ value, label: value }))}
                  />
                  <Input
                    className="min-w-0 flex-1 font-mono text-[12px]"
                    value={request.url}
                    onChange={(event) => patchRequest({ url: event.target.value })}
                    placeholder="https://"
                    spellCheck={false}
                  />
                  <ActionGroup>
                    {running ? (
                      <Button
                        variant="secondary"
                        size="sm"
                        className="shrink-0"
                        onClick={cancelRequest}
                      >
                        <X size={15} />
                        {text.cancel}
                      </Button>
                    ) : (
                      <Button
                        variant="default"
                        size="sm"
                        className="shrink-0"
                        onClick={runRequest}
                      >
                        <Play size={15} weight="fill" />
                        {text.run}
                      </Button>
                    )}
                  </ActionGroup>
                </ToolToolbar>

                <div className="flex flex-col gap-1.5">
                  <span className="machkit-control-label">{text.bodyMode}</span>
                  <SegmentedControl
                    value={bodyMode}
                    onChange={onBodyModeChange}
                    label={text.bodyMode}
                    size="compact"
                    className="w-full"
                    options={bodyModeOptions}
                  />
                </div>

                {bodyMode === "raw" ? (
                  <div className="flex min-w-0 flex-col gap-1.5">
                    <div className="flex items-center justify-between gap-2">
                      <span className="machkit-control-label">{text.body}</span>
                      <Button
                        variant="ghost"
                        size="sm"
                        disabled={!String(request.body || "").trim()}
                        onClick={formatBody}
                      >
                        <BracketsCurly size={15} />
                        {text.formatBody}
                      </Button>
                    </div>
                    <Textarea
                      className={`${BODY_H} resize-none overflow-y-auto font-mono text-[12px]`}
                      value={request.body}
                      onChange={(event) => patchRequest({ body: event.target.value })}
                      placeholder={text.bodyPlaceholder}
                      spellCheck={false}
                    />
                  </div>
                ) : null}

                {bodyMode === "urlencoded" ? (
                  <FormFieldEditor
                    label={text.formFields}
                    rows={request.formFields || []}
                    onChange={(rows) => setPairs("formFields", rows)}
                    text={text}
                    allowFile={false}
                  />
                ) : null}

                {bodyMode === "formdata" ? (
                  <FormFieldEditor
                    label={text.formFields}
                    rows={request.formFields || []}
                    onChange={(rows) => setPairs("formFields", rows)}
                    text={text}
                    allowFile
                  />
                ) : null}

                <PairEditor
                  label={text.query}
                  rows={request.query || []}
                  onChange={(rows) => setPairs("query", rows)}
                  text={text}
                  compact
                />

                <PairEditor
                  label={text.headers}
                  rows={request.headers || []}
                  onChange={(rows) => setPairs("headers", rows)}
                  text={text}
                  compact
                />
              </div>
            </section>
          }
          right={
            <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden">
              <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
                <div className="flex shrink-0 items-center justify-between gap-2 pb-2">
                  <SegmentedControl
                    value={codeMode}
                    onChange={setCodeMode}
                    label={text.output}
                    size="compact"
                    className="max-w-[220px]"
                    options={[
                      { value: "curl", label: text.curl },
                      { value: "fetch", label: text.fetch },
                    ]}
                  />
                  <div className="flex min-w-0 items-center gap-1.5">
                    {codeMode === "curl" ? (
                      <span className="truncate text-[11px] text-tertiary">{text.parseHint}</span>
                    ) : null}
                    <Button
                      variant="ghost"
                      size="sm"
                      className="shrink-0"
                      onClick={() => machkit.copy(codeText)}
                      disabled={!codeText}
                    >
                      <CopySimple size={15} />
                      {text.copy}
                    </Button>
                  </div>
                </div>
                {codeMode === "curl" ? (
                  <Textarea
                    className="min-h-0 flex-1 resize-none font-mono text-[12px] leading-relaxed"
                    value={curlText}
                    onChange={(event) => onCurlChange(event.target.value)}
                    placeholder={text.curlPlaceholder}
                    spellCheck={false}
                  />
                ) : (
                  <ResultPanel
                    className="min-h-0 flex-1"
                    bodyClassName="h-full min-h-0 overflow-auto px-3 py-2.5 font-mono text-[12px] leading-relaxed whitespace-pre-wrap break-all"
                  >
                    <pre className="m-0 font-inherit whitespace-pre-wrap break-all">{fetchSnippet}</pre>
                  </ResultPanel>
                )}
              </section>

              <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
                <div className="flex shrink-0 items-center justify-between gap-2 pb-2">
                  <div className="flex min-w-0 items-center gap-2">
                    <span className="truncate text-[12px] font-medium text-foreground">{responseSummary}</span>
                    {runResult?.bodyTruncated ? (
                      <span className="shrink-0 text-[11px] text-tertiary">{text.bodyTruncated}</span>
                    ) : null}
                  </div>
                  <ActionGroup>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setOptionsOpen(true)}
                      title={text.options}
                    >
                      <GearSix size={15} />
                      {text.options}
                      {enabledFlagCount ? (
                        <span className="rounded-full bg-muted px-1.5 text-[10px] tabular-nums text-secondary">
                          {enabledFlagCount}
                        </span>
                      ) : null}
                    </Button>
                    <Button variant="ghost" size="sm" onClick={clearAll}>
                      <Eraser size={15} />
                      {text.clear}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={!runResult}
                      onClick={() => machkit.copy(formatRunResult(runResult, text))}
                    >
                      <CopySimple size={15} />
                      {text.copy}
                    </Button>
                  </ActionGroup>
                </div>
                <ResultPanel
                  className="min-h-0 flex-1"
                  bodyClassName="h-full min-h-0 overflow-auto px-3 py-2.5 font-mono text-[12px] leading-relaxed whitespace-pre-wrap break-all text-secondary"
                >
                  <pre className="m-0 font-inherit whitespace-pre-wrap break-all">
                    {formatRunResult(runResult, text) || text.responseEmpty}
                  </pre>
                </ResultPanel>
              </section>
            </div>
          }
        />
      </ToolContent>

      <OptionsDialog
        open={optionsOpen}
        onClose={() => setOptionsOpen(false)}
        request={request}
        patchRequest={patchRequest}
        text={text}
      />
    </ToolPage>
  );
}

function formatRunResult(result, text) {
  if (!result) return "";
  const lines = [];
  if (result.statusCode != null) lines.push(`${text.status}: ${result.statusCode}`);
  if (result.durationMs != null) lines.push(`${text.duration}: ${Math.round(result.durationMs)} ms`);
  if (result.effectiveURL) lines.push(`${text.effectiveURL}: ${result.effectiveURL}`);
  if (result.error) lines.push(`${text.error}: ${result.error}`);
  if (lines.length) lines.push("");
  if (result.headers) {
    lines.push(text.responseHeaders);
    lines.push(String(result.headers));
    lines.push("");
  }
  lines.push(text.responseBody);
  lines.push(String(result.body ?? ""));
  return lines.join("\n");
}

function bodyFormatErrorLabel(code, text) {
  switch (code) {
    case "empty":
      return text.formatBodyEmpty || "Body is empty";
    case "unsupported":
      return text.formatBodyUnsupported || "Only JSON or XML can be formatted";
    case "invalid-xml":
    case "too-large":
      return text.formatBodyFailed || "Unable to format body";
    default:
      return text.formatBodyFailed || "Unable to format body";
  }
}

function runErrorLabel(code, text) {
  switch (code) {
    case "empty-url":
      return text.missingUrl;
    case "app-only":
      return text.runAppOnly;
    case "invalid-url":
      return text.invalidUrl;
    case "unsupported-scheme":
      return text.unsupportedScheme;
    case "missing-file":
      return text.missingFile;
    case "file-too-large":
      return text.fileTooLarge;
    case "timeout":
      return text.runTimeout;
    case "canceled":
      return text.runCanceled;
    default:
      return typeof code === "string" && code ? code : text.runFailed;
  }
}

mountTool(<CurlLabTool />, { name: "cURL Lab" });
