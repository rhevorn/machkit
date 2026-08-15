import React, { useEffect, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { BracketsCurly, CopySimple, Eraser, MagnifyingGlass, TextAa, TreeStructure } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Input,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { useMachKitEditorTheme } from "@/ui/codemirror-theme.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  byteSize,
  formatJSON,
  minifyJSON,
  parseJSON,
  queryPath,
  sortKeysDeep,
  stringifyValue,
} from "./json.js";

import { messages } from "./messages.js";

function formatBytes(size) {
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(size < 10_240 ? 1 : 0)} KB`;
  return `${(size / (1024 * 1024)).toFixed(2)} MB`;
}

function JsonFormatter() {
  const text = useToolMessages(messages);
  const editorTheme = useMachKitEditorTheme();
  const [source, setSource] = useState("");
  const [path, setPath] = useState("");
  const [transformError, setTransformError] = useState("");
  const [analysis, setAnalysis] = useState(() => ({
    source: "",
    path: "",
    parsed: parseJSON(""),
    pathQuery: { ok: true, error: null, matches: [] },
  }));
  const workerRef = useRef(null);
  const analysisIDRef = useRef(0);
  const transformIDRef = useRef(0);

  useEffect(() => {
    if (typeof Worker === "undefined") return undefined;
    const worker = new Worker(new URL("./json.worker.js", import.meta.url), { type: "module" });
    workerRef.current = worker;
    worker.onmessage = ({ data }) => {
      if (data.type === "transform") {
        if (data.id !== transformIDRef.current) return;
        if (data.ok) {
          setTransformError("");
          setSource(data.source);
        } else {
          setTransformError(data.error);
        }
        return;
      }
      if (data.id !== analysisIDRef.current) return;
      setAnalysis(data);
      if (data.normalizedSource) setSource(data.normalizedSource);
    };
    return () => {
      worker.terminate();
      workerRef.current = null;
    };
  }, []);

  useEffect(() => {
    const id = analysisIDRef.current + 1;
    analysisIDRef.current = id;
    const timer = window.setTimeout(() => {
      if (source.length > 5_000_000) {
        setAnalysis({
          source,
          path,
          parsed: { ok: false, error: "input-too-large", data: null, unwrapped: false },
          pathQuery: { ok: true, error: null, matches: [] },
        });
        return;
      }
      if (workerRef.current) {
        workerRef.current.postMessage({ id, type: "analyze", source, path });
        return;
      }
      const nextParsed = parseJSON(source);
      setAnalysis({
        source,
        path,
        parsed: nextParsed,
        pathQuery: nextParsed.ok ? queryPath(nextParsed.data, path) : { ok: true, error: null, matches: [] },
      });
    }, 120);
    return () => window.clearTimeout(timer);
  }, [source, path]);

  const isAnalyzing = analysis.source !== source || analysis.path !== path;
  const parsed = isAnalyzing
    ? { ok: false, error: "analyzing", data: null, unwrapped: false }
    : analysis.parsed;
  const pathQuery = isAnalyzing
    ? { ok: true, error: null, matches: [] }
    : analysis.pathQuery;

  const status = !source.trim()
    ? { tone: "neutral", label: text.empty }
    : parsed.ok
      ? { tone: "info", label: `${text.valid} · ${formatBytes(byteSize(source))}` }
      : parsed.error === "analyzing"
        ? { tone: "neutral", label: text.analyzing || "Analyzing…" }
        : parsed.error === "input-too-large"
          ? { tone: "danger", label: text.tooLarge || "Input is too large (5 MB maximum)" }
          : { tone: "danger", label: `${text.invalid}: ${parsed.error}` };

  const pathStatus = (() => {
    if (!path.trim() || !parsed.ok) return null;
    if (!pathQuery.ok) return { tone: "danger", label: `${text.pathError}: ${pathQuery.error}` };
    if (!pathQuery.matches.length) return { tone: "neutral", label: text.noMatches };
    const count = pathQuery.matches.length;
    return {
      tone: "info",
      label: `${count} ${count === 1 ? text.match : text.matches}`,
    };
  })();

  const mutate = (operation) => {
    if (!parsed.ok) return;
    setTransformError("");
    if (workerRef.current) {
      const id = transformIDRef.current + 1;
      transformIDRef.current = id;
      workerRef.current.postMessage({ id, type: "transform", source, operation });
      return;
    }
    try {
      const transformed = operation === "minify"
        ? minifyJSON(parsed.data)
        : operation === "sort"
          ? formatJSON(sortKeysDeep(parsed.data))
          : formatJSON(parsed.data);
      setSource(transformed);
    } catch (error) {
      setTransformError(error instanceof Error ? error.message : "Unable to transform JSON");
    }
  };

  const showResults = Boolean(path.trim()) && parsed.ok && pathQuery.ok && pathQuery.matches.length > 0;

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex min-h-0 flex-1 flex-col pt-4">
        <div className="machkit-toolbar flex-wrap pb-1.5">
          <Button variant="secondary" size="sm" disabled={!parsed.ok} onClick={() => mutate("format")}>
            <BracketsCurly size={15} />
            {text.format}
          </Button>
          <Button variant="secondary" size="sm" disabled={!parsed.ok} onClick={() => mutate("minify")}>
            <TextAa size={15} />
            {text.minify}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={!parsed.ok}
            onClick={() => mutate("sort")}
          >
            <TreeStructure size={15} />
            {text.sort}
          </Button>
          <div className="ml-auto flex items-center gap-2">
            <Button variant="ghost" size="sm" disabled={!source} onClick={() => machkit.copy(source)}>
              <CopySimple size={16} />
              <span className="max-[560px]:hidden">{text.copy}</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              disabled={!source && !path}
              onClick={() => {
                setSource("");
                setPath("");
              }}
            >
              <Eraser size={16} />
              <span className="max-[560px]:hidden">{text.clear}</span>
            </Button>
            <ToolInfoButton info={text.info} className="size-8" />
          </div>
        </div>

        <div className="machkit-toolbar gap-2">
          <MagnifyingGlass size={15} className="shrink-0 text-secondary" />
          <span className="machkit-control-label">{text.path}</span>
          <Input
            value={path}
            onChange={(event) => setPath(event.target.value)}
            placeholder={text.pathPlaceholder}
            aria-label={text.path}
            invalid={Boolean(path.trim()) && parsed.ok && !pathQuery.ok}
          />
          {pathStatus ? (
            <span className={`shrink-0 text-xs ${pathStatus.tone === "danger" ? "text-danger" : "text-secondary"}`}>
              {pathStatus.label}
            </span>
          ) : null}
        </div>

        <div className={`grid min-h-0 flex-1 gap-4 py-4 ${showResults ? "min-[900px]:grid-cols-[minmax(0,1.35fr)_minmax(280px,0.9fr)]" : ""}`}>
          <div className="flex min-h-0 flex-col gap-3">
            <div className="json-code-editor machkit-panel min-h-[360px] flex-1">
              <CodeMirror
                value={source}
                height="100%"
                theme={editorTheme}
                basicSetup={{
                  lineNumbers: true,
                  highlightActiveLine: true,
                  highlightActiveLineGutter: true,
                  foldGutter: true,
                  dropCursor: false,
                  allowMultipleSelections: false,
                  indentOnInput: true,
                }}
                onChange={setSource}
                placeholder={text.placeholder}
                className="h-full min-h-[360px]"
              />
            </div>
            <InlineMessage tone={transformError ? "danger" : status.tone}>{transformError || status.label}</InlineMessage>
          </div>

          {showResults ? (
            <section className="machkit-panel flex min-h-0 flex-col">
              <header className="flex h-11 shrink-0 items-center border-b border-border px-4 text-xs font-medium text-secondary">
                {text.results}
              </header>
              <div className="min-h-0 flex-1 space-y-3 overflow-auto p-3">
                {pathQuery.matches.map((match) => {
                  const valueText = stringifyValue(match.value);
                  return (
                    <article key={match.path} className="rounded-control border border-border bg-field px-3 py-2.5">
                      <div className="mb-2 flex items-start gap-2">
                        <code className="min-w-0 flex-1 truncate font-mono text-[11px] text-accent">{match.path}</code>
                        <button
                          type="button"
                          className="shrink-0 text-[10px] text-secondary hover:text-foreground"
                          onClick={() => machkit.copy(match.path)}
                        >
                          {text.copyPath}
                        </button>
                      </div>
                      <div className="flex items-start gap-2">
                        <pre className="max-h-36 min-w-0 flex-1 overflow-auto font-mono text-[12px] leading-relaxed break-all whitespace-pre-wrap text-foreground">
                          {valueText}
                        </pre>
                        <button
                          type="button"
                          className="shrink-0 text-[10px] text-secondary hover:text-foreground"
                          onClick={() => machkit.copy(valueText)}
                        >
                          {text.copyValue}
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
            </section>
          ) : null}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<JsonFormatter />, { name: "JSON Formatter" });
