import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, Eraser, Plus, Trash } from "@phosphor-icons/react";
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
  bodyModes,
  buildCurl,
  buildFetch,
  createEmptyRequest,
  createFormField,
  createPair,
  httpMethods,
  parseCurl,
} from "./curl.js";
import { messages } from "./messages.js";

const EMPTY_PAIR = Object.freeze({ id: "__empty__", key: "", value: "" });

function PairEditor({ label, rows, onChange, text }) {
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
    <div className="flex flex-col gap-1.5">
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
      <div className="machkit-panel overflow-hidden">
        {list.map((row) => (
          <div key={row.id} className="flex items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
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

  function updateRow(id, patch) {
    if (!rows.length) {
      onChange([createFormField(patch.key ?? "", patch.value ?? "", patch.kind ?? "text")]);
      return;
    }
    onChange(rows.map((row) => (row.id === id ? { ...row, ...patch } : row)));
  }

  return (
    <div className="flex flex-col gap-1.5">
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
      <div className="machkit-panel overflow-hidden">
        {list.map((row) => (
          <div key={row.id} className="flex items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.key}
              placeholder={text.key}
              onChange={(event) => updateRow(row.id, { key: event.target.value })}
              spellCheck={false}
            />
            {allowFile ? (
              <button
                type="button"
                className="shrink-0 rounded-md border border-border px-2 py-1 font-mono text-[11px] text-secondary hover:bg-surface-secondary"
                onClick={() => updateRow(row.id, { kind: row.kind === "file" ? "text" : "file" })}
                title={text.fieldType}
              >
                {row.kind === "file" ? text.fieldFile : text.fieldText}
              </button>
            ) : null}
            <Input
              className="min-w-0 flex-1 font-mono text-[12px]"
              value={row.value}
              placeholder={row.kind === "file" ? text.filePathPlaceholder : text.value}
              onChange={(event) => updateRow(row.id, { value: event.target.value })}
              spellCheck={false}
            />
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

function CurlLabTool() {
  const text = useToolMessages(messages);
  const [request, setRequest] = useState(() => createEmptyRequest());
  const [curlText, setCurlText] = useState(() => buildCurl(createEmptyRequest()));
  const [editSource, setEditSource] = useState("form");
  const [outputMode, setOutputMode] = useState("curl");
  const [parseError, setParseError] = useState(null);

  const fetchSnippet = useMemo(() => buildFetch(request), [request]);
  const bodyMode = bodyModes.includes(request.bodyMode) ? request.bodyMode : "none";
  const outputText = outputMode === "fetch" ? fetchSnippet : curlText;

  useEffect(() => {
    if (editSource !== "form") return;
    setCurlText(buildCurl(request));
    setParseError(null);
  }, [request, editSource]);

  useEffect(() => {
    if (editSource !== "curl" || outputMode !== "curl") return;
    const parsed = parseCurl(curlText);
    if (parsed.ok) {
      setRequest(parsed.request);
      setParseError(null);
    } else {
      setParseError(parsed.error);
    }
  }, [curlText, editSource, outputMode]);

  function patchRequest(patch) {
    setEditSource("form");
    setRequest((prev) => ({ ...prev, ...patch }));
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
  }

  const status = parseError
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
    : !String(request.url || "").trim() && !curlText.trim()
      ? { tone: "neutral", label: text.empty }
      : { tone: "info", label: text.synced };

  const bodyModeOptions = [
    { value: "none", label: text.bodyNone },
    { value: "raw", label: text.bodyRaw },
    { value: "urlencoded", label: text.bodyUrlencoded },
    { value: "formdata", label: text.bodyFormData },
  ];

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <span className="machkit-control-label shrink-0">{text.title}</span>
          <div className="mx-1 h-5 w-px shrink-0 bg-border" aria-hidden="true" />
          <Button variant="ghost" size="sm" onClick={() => machkit.copy(outputText)}>
            <CopySimple size={15} />
            {text.copy}
          </Button>
          <Button variant="ghost" size="sm" onClick={clearAll}>
            <Eraser size={15} />
            {text.clear}
          </Button>
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid min-w-0 gap-3 lg:grid-cols-2">
          <div className="flex min-w-0 flex-col gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="machkit-control-label shrink-0">{text.method}</span>
              <SelectControl
                value={request.method}
                onChange={(method) => patchRequest({ method })}
                label={text.method}
                className="w-[110px] flex-none"
                options={httpMethods.map((value) => ({ value, label: value }))}
              />
              <div className="mx-1 h-5 w-px shrink-0 bg-border" aria-hidden="true" />
              <span className="machkit-control-label shrink-0">{text.url}</span>
              <Input
                className="min-w-0 flex-1 font-mono text-[12px]"
                value={request.url}
                onChange={(event) => patchRequest({ url: event.target.value })}
                placeholder="https://"
                spellCheck={false}
              />
            </div>

            <PairEditor
              label={text.query}
              rows={request.query || []}
              onChange={(rows) => setPairs("query", rows)}
              text={text}
            />

            <PairEditor
              label={text.headers}
              rows={request.headers || []}
              onChange={(rows) => setPairs("headers", rows)}
              text={text}
            />

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
                <span className="machkit-control-label">{text.body}</span>
                <Textarea
                  className="min-h-[96px] font-mono text-[12px]"
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

            <div className="machkit-panel flex flex-wrap items-center gap-x-4 gap-y-2 px-3 py-2.5">
              <span className="text-[12px] text-secondary">{text.flags}</span>
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
            </div>
          </div>

          <div className="flex min-w-0 flex-col gap-1.5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <SegmentedControl
                value={outputMode}
                onChange={setOutputMode}
                label={text.output}
                size="compact"
                options={[
                  { value: "curl", label: text.curl },
                  { value: "fetch", label: text.fetch },
                ]}
              />
              {outputMode === "curl" ? (
                <span className="text-[11px] text-tertiary">{text.parseHint}</span>
              ) : null}
            </div>
            {outputMode === "curl" ? (
              <Textarea
                className="min-h-[240px] max-h-[320px] flex-1 font-mono text-[12px] leading-relaxed"
                value={curlText}
                onChange={(event) => onCurlChange(event.target.value)}
                placeholder={text.curlPlaceholder}
                spellCheck={false}
              />
            ) : (
              <pre className="machkit-panel min-h-[240px] max-h-[320px] flex-1 overflow-auto px-3 py-2.5 font-mono text-[12px] leading-relaxed whitespace-pre-wrap break-all">
                {fetchSnippet}
              </pre>
            )}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CurlLabTool />, { name: "cURL Lab" });
