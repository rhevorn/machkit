import React, { useEffect, useMemo, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { json } from "@codemirror/lang-json";
import { ViewPlugin } from "@codemirror/view";
import { BracketsCurly, CopySimple, Eraser, MagnifyingGlass, Quotes, TextAa, TreeStructure } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  EditorPane,
  Input,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { useMachKitEditorTheme } from "@/ui/codemirror-theme.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  byteSize,
  escapeJSONText,
  formatJSON,
  minifyJSON,
  parseJSON,
  queryPath,
  sortKeysDeep,
  stringifyValue,
  unescapeJSONText,
  pathAtOffset,
} from "./json.js";
import { JsonHighlight } from "./json-highlight.jsx";

import { messages } from "./messages.js";

const jsonLanguage = json();

/** Stop trackpad rubber-banding at the editor scroll edges. */
const disableScrollerOverscroll = ViewPlugin.fromClass(
  class {
    constructor(view) {
      this.scroller = view.scrollDOM;
      this.onWheel = (event) => {
        const {
          scrollTop,
          scrollHeight,
          clientHeight,
          scrollLeft,
          scrollWidth,
          clientWidth,
        } = this.scroller;
        const { deltaX, deltaY } = event;
        const atTop = scrollTop <= 0;
        const atBottom = scrollTop + clientHeight >= scrollHeight - 1;
        const atLeft = scrollLeft <= 0;
        const atRight = scrollLeft + clientWidth >= scrollWidth - 1;
        const vertical = Math.abs(deltaY) >= Math.abs(deltaX);
        if (vertical && ((deltaY < 0 && atTop) || (deltaY > 0 && atBottom))) {
          event.preventDefault();
          return;
        }
        if (!vertical && ((deltaX < 0 && atLeft) || (deltaX > 0 && atRight))) {
          event.preventDefault();
        }
      };
      this.scroller.addEventListener("wheel", this.onWheel, { passive: false });
    }

    destroy() {
      this.scroller.removeEventListener("wheel", this.onWheel);
    }
  },
);

/** Reserve horizontal scroll for long lines without leaving an empty-state scrollbar. */
const syncContentMinWidth = ViewPlugin.fromClass(
  class {
    constructor(view) {
      this.apply(view);
    }

    update(update) {
      if (update.docChanged || update.geometryChanged) this.apply(update.view);
    }

    apply(view) {
      const { doc } = view.state;
      let maxLen = 0;
      const lineCount = doc.lines;
      const step = lineCount > 40_000 ? Math.ceil(lineCount / 40_000) : 1;
      for (let line = 1; line <= lineCount; line += step) {
        const length = doc.line(line).length;
        if (length > maxLen) maxLen = length;
      }

      const content = view.contentDOM;
      const scroller = view.scrollDOM;
      if (maxLen <= 0 || !doc.length) {
        content.style.minWidth = "";
        scroller.style.setProperty("overflow-x", "hidden", "important");
        return;
      }

      content.style.minWidth = `${maxLen}ch`;
      // Defer so minWidth is laid out before measuring overflow.
      requestAnimationFrame(() => {
        if (view.isDestroyed) return;
        const needsX = scroller.scrollWidth > scroller.clientWidth + 1;
        scroller.style.setProperty("overflow-x", needsX ? "auto" : "hidden", "important");
      });
    }
  },
);

function formatBytes(size) {
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(size < 10_240 ? 1 : 0)} KB`;
  return `${(size / (1024 * 1024)).toFixed(2)} MB`;
}

function JsonFormatter() {
  const text = useToolMessages(messages);
  const editorTheme = useMachKitEditorTheme();
  const editorExtensions = useMemo(
    () => [jsonLanguage, disableScrollerOverscroll, syncContentMinWidth, ...editorTheme],
    [editorTheme],
  );
  const [source, setSource] = useState("");
  const [path, setPath] = useState("");
  const [cursorPath, setCursorPath] = useState("");
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
  const cursorPathTimerRef = useRef(0);

  const updateCursorPath = React.useCallback((docText, offset) => {
    window.clearTimeout(cursorPathTimerRef.current);
    cursorPathTimerRef.current = window.setTimeout(() => {
      const result = pathAtOffset(docText, offset);
      setCursorPath(result.ok ? result.path : "");
    }, 80);
  }, []);

  useEffect(() => () => window.clearTimeout(cursorPathTimerRef.current), []);

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
    };
    return () => {
      worker.terminate();
      workerRef.current = null;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const clipboard = await machkit.readClipboard();
      if (cancelled || !clipboard.trim()) return;
      if (byteSize(clipboard) > 5_000_000) return;
      // Clipboard import may unwrap escaped JSON once on open.
      const parsed = parseJSON(clipboard);
      if (!parsed.ok || parsed.data === null || typeof parsed.data !== "object") return;
      try {
        setSource(formatJSON(parsed.data));
      } catch {
        // Ignore format failures; leave the editor empty.
      }
    })();
    return () => {
      cancelled = true;
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
      const nextParsed = parseJSON(source, { unwrap: false });
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

  const escapeSource = () => {
    if (!source) return;
    setTransformError("");
    try {
      setSource(escapeJSONText(source));
    } catch (error) {
      setTransformError(error instanceof Error ? error.message : "Unable to escape");
    }
  };

  const unescapeSource = () => {
    if (!source.trim()) return;
    setTransformError("");
    try {
      let next = unescapeJSONText(source);
      const nextParsed = parseJSON(next);
      if (nextParsed.ok && nextParsed.data !== null && typeof nextParsed.data === "object") {
        next = formatJSON(nextParsed.data);
      }
      setSource(next);
    } catch (error) {
      setTransformError(error instanceof Error ? error.message : "Unable to unescape");
    }
  };

  const showResults = Boolean(path.trim()) && parsed.ok && pathQuery.ok && pathQuery.matches.length > 0;

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex min-h-0 min-w-0 flex-1 flex-col overflow-x-hidden pt-4">
        <ToolToolbar className="flex-wrap pb-1.5">
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
          <Button variant="secondary" size="sm" disabled={!source} onClick={escapeSource}>
            <Quotes size={15} />
            {text.escape}
          </Button>
          <Button variant="secondary" size="sm" disabled={!source.trim()} onClick={unescapeSource}>
            <Quotes size={15} weight="duotone" />
            {text.unescape}
          </Button>
          <ActionGroup className="gap-2">
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
                setCursorPath("");
              }}
            >
              <Eraser size={16} />
              <span className="max-[560px]:hidden">{text.clear}</span>
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <ToolToolbar className="min-w-0 gap-2">
          <MagnifyingGlass size={15} className="shrink-0 text-secondary" />
          <span className="machkit-control-label">{text.path}</span>
          <Input
            value={path}
            onChange={(event) => setPath(event.target.value)}
            placeholder={text.pathPlaceholder}
            aria-label={text.path}
            invalid={Boolean(path.trim()) && parsed.ok && !pathQuery.ok}
            className="min-w-0"
          />
          {pathStatus ? (
            <span className={`shrink-0 text-xs ${pathStatus.tone === "danger" ? "text-danger" : "text-secondary"}`}>
              {pathStatus.label}
            </span>
          ) : null}
        </ToolToolbar>

        <div className={`grid min-h-0 min-w-0 flex-1 items-stretch gap-4 py-4 ${showResults ? "min-[900px]:grid-cols-[minmax(0,1.35fr)_minmax(0,0.9fr)]" : ""}`}>
          <div className="json-code-editor machkit-panel min-h-[360px] min-w-0 overflow-hidden">
            <CodeMirror
              value={source}
              height="100%"
              extensions={editorExtensions}
              basicSetup={{
                lineNumbers: true,
                highlightActiveLine: true,
                highlightActiveLineGutter: true,
                foldGutter: true,
                dropCursor: false,
                allowMultipleSelections: false,
                indentOnInput: true,
              }}
              onChange={(value, viewUpdate) => {
                setSource(value);
                updateCursorPath(value, viewUpdate.state.selection.main.head);
              }}
              onUpdate={(viewUpdate) => {
                if (!viewUpdate.selectionSet) return;
                updateCursorPath(viewUpdate.state.doc.toString(), viewUpdate.state.selection.main.head);
              }}
              className="h-full min-h-[360px] min-w-0"
            />
          </div>

          {showResults ? (
            <EditorPane
              title={text.results}
              className="min-h-[360px]"
              bodyClassName="space-y-3 overflow-y-auto p-3"
            >
              {pathQuery.matches.map((match) => {
                const valueText = stringifyValue(match.value);
                const fillHeight = pathQuery.matches.length === 1;
                return (
                  <article
                    key={match.path}
                    className={
                      fillHeight
                        ? "flex h-full min-h-0 min-w-0 flex-col overflow-hidden rounded-control border border-border bg-field px-3 py-2.5"
                        : "flex max-h-64 min-w-0 shrink-0 flex-col overflow-hidden rounded-control border border-border bg-field px-3 py-2.5"
                    }
                  >
                    <div className="mb-2 flex shrink-0 items-start gap-2">
                      <code className="min-w-0 flex-1 truncate font-mono text-[11px] text-accent">{match.path}</code>
                      <Button
                        type="button"
                        variant="ghost"
                        size="compact"
                        className="h-auto shrink-0 px-1.5 py-0.5 text-[10px] font-normal"
                        onClick={() => machkit.copy(match.path)}
                      >
                        {text.copyPath}
                      </Button>
                    </div>
                    <div className="flex min-h-0 min-w-0 flex-1 items-stretch gap-2 overflow-hidden">
                      <JsonHighlight value={match.value} />
                      <Button
                        type="button"
                        variant="ghost"
                        size="compact"
                        className="h-auto shrink-0 self-start px-1.5 py-0.5 text-[10px] font-normal"
                        onClick={() => machkit.copy(valueText)}
                      >
                        {text.copyValue}
                      </Button>
                    </div>
                  </article>
                );
              })}
            </EditorPane>
          ) : null}
        </div>

        <div className="flex min-h-8 items-center justify-between gap-3">
          {transformError || status.tone === "danger" ? (
            <StatusStrip tone="danger" className="min-w-0 flex-1">
              {transformError || status.label}
            </StatusStrip>
          ) : (
            <p className="min-w-0 flex-1 truncate text-xs text-secondary">{status.label}</p>
          )}
          {cursorPath ? (
            <Button
              type="button"
              variant="ghost"
              size="compact"
              className="machkit-control-label inline-flex h-auto max-w-[55%] items-center gap-1.5 truncate px-1.5 py-0.5 text-left font-normal"
              title={text.copyPath}
              onClick={() => machkit.copy(cursorPath)}
            >
              <span className="shrink-0">{text.location}</span>
              <code className="min-w-0 truncate font-mono text-[11px] text-accent">{cursorPath}</code>
            </Button>
          ) : null}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<JsonFormatter />, { name: "JSON Formatter" });
