import React, { useEffect, useMemo, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { json } from "@codemirror/lang-json";
import { EditorView, ViewPlugin } from "@codemirror/view";
import * as Popover from "@radix-ui/react-popover";
import {
  BracketsCurly,
  ClockCounterClockwise,
  CopySimple,
  MagnifyingGlass,
  Quotes,
  TextAa,
  Trash,
  TreeStructure,
} from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  IconButton,
  Input,
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
import {
  HISTORY_STORAGE_KEY,
  parseHistoryPayload,
  pushHistoryEntry,
  serializeHistory,
} from "./history.js";
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

/** Click anywhere on a line to fill the path from that line's leading token. */
function fillPathOnLineClick(onFill) {
  return EditorView.domEventHandlers({
    click(event, view) {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) {
        return false;
      }
      if (event.target?.closest?.(".cm-gutters")) return false;
      const pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
      if (pos == null) return false;
      const line = view.state.doc.lineAt(pos);
      let offset = line.from;
      while (offset < line.to && /\s/.test(line.text[offset - line.from])) offset += 1;
      if (offset >= line.to) offset = pos;
      const result = pathAtOffset(view.state.doc.toString(), offset);
      if (!result.ok || !result.path) return false;
      onFill(result.path);
      return false;
    },
  });
}

/** Remember valid JSON pasted into the editor. */
function rememberPasteOnPaste(onPasteText) {
  return EditorView.domEventHandlers({
    paste(event) {
      const text = event.clipboardData?.getData("text");
      if (text) onPasteText(text);
      return false;
    },
  });
}

function formatHistoryTime(savedAt) {
  try {
    return new Intl.DateTimeFormat(undefined, { dateStyle: "short", timeStyle: "short" }).format(savedAt);
  } catch {
    return "";
  }
}

function prepareHistorySource(raw) {
  const parsed = parseJSON(raw);
  if (!parsed.ok || parsed.data === null || typeof parsed.data !== "object") return null;
  try {
    return formatJSON(parsed.data);
  } catch {
    return String(raw ?? "");
  }
}

const SPLIT_STORAGE_KEY = "machkit.json-formatter.leftRatio.v2";
const DEFAULT_LEFT_RATIO = 0.75;
const MIN_LEFT_RATIO = 0.28;
const MAX_LEFT_RATIO = 0.78;

function clampLeftRatio(value) {
  return Math.min(MAX_LEFT_RATIO, Math.max(MIN_LEFT_RATIO, value));
}

function readLeftRatio() {
  try {
    const value = Number(window.localStorage.getItem(SPLIT_STORAGE_KEY));
    if (Number.isFinite(value) && value >= MIN_LEFT_RATIO && value <= MAX_LEFT_RATIO) return value;
  } catch {
    // ignore
  }
  return DEFAULT_LEFT_RATIO;
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
    <div ref={containerRef} className="flex min-h-0 min-w-0 flex-1 overflow-hidden">
      <div
        className="flex min-h-0 min-w-0 flex-col overflow-hidden"
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
      <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden">{right}</div>
    </div>
  );
}

function JsonFormatter() {
  const text = useToolMessages(messages);
  const editorTheme = useMachKitEditorTheme();
  const [source, setSource] = useState("");
  const [path, setPath] = useState("");
  const [transformError, setTransformError] = useState("");
  const [history, setHistory] = useState([]);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [analysis, setAnalysis] = useState(() => ({
    source: "",
    path: "",
    parsed: parseJSON(""),
    pathQuery: { ok: true, error: null, matches: [] },
  }));
  const workerRef = useRef(null);
  const analysisIDRef = useRef(0);
  const transformIDRef = useRef(0);
  const applyPathRef = useRef((nextPath) => {});
  const rememberPasteRef = useRef((raw) => {});
  applyPathRef.current = (nextPath) => {
    if (nextPath) setPath(nextPath);
  };
  const editorExtensions = useMemo(
    () => [
      jsonLanguage,
      disableScrollerOverscroll,
      syncContentMinWidth,
      fillPathOnLineClick((nextPath) => applyPathRef.current(nextPath)),
      rememberPasteOnPaste((raw) => rememberPasteRef.current(raw)),
      ...editorTheme,
    ],
    [editorTheme],
  );

  const persistHistory = React.useCallback((entries) => {
    setHistory(entries);
    machkit.setItem(HISTORY_STORAGE_KEY, serializeHistory(entries)).catch(() => {});
  }, []);

  const rememberPaste = React.useCallback((raw) => {
    const prepared = prepareHistorySource(raw);
    if (!prepared) return;
    setHistory((current) => {
      const { entries, changed } = pushHistoryEntry(current, prepared);
      if (!changed) return current;
      machkit.setItem(HISTORY_STORAGE_KEY, serializeHistory(entries)).catch(() => {});
      return entries;
    });
  }, []);
  rememberPasteRef.current = rememberPaste;

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const raw = await machkit.getItem(HISTORY_STORAGE_KEY);
      if (cancelled) return;
      setHistory(parseHistoryPayload(raw));
    })();
    return () => {
      cancelled = true;
    };
  }, []);

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
      const prepared = prepareHistorySource(clipboard);
      if (!prepared) return;
      setSource(prepared);
      rememberPaste(prepared);
    })();
    return () => {
      cancelled = true;
    };
  }, [rememberPaste]);

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

  // Keep last parse while source is re-analyzing; path queries update sync so the
  // split pane does not collapse/remount on every line click.
  const isSourceAnalyzing = analysis.source !== source;
  const parsed = analysis.parsed;
  const pathQuery = useMemo(() => {
    if (!path.trim()) return { ok: true, error: null, matches: [] };
    if (analysis.source !== source) return analysis.pathQuery;
    if (!analysis.parsed.ok) return { ok: true, error: null, matches: [] };
    return queryPath(analysis.parsed.data, path);
  }, [analysis, source, path]);

  const pathStatus = (() => {
    if (transformError) return transformError;
    if (!isSourceAnalyzing && source.trim() && !parsed.ok) {
      return parsed.error === "input-too-large"
        ? (text.tooLarge || "Input is too large (5 MB maximum)")
        : `${text.invalid}: ${parsed.error}`;
    }
    if (!path.trim() || !parsed.ok) return null;
    if (!pathQuery.ok) return `${text.pathError}: ${pathQuery.error}`;
    return null;
  })();

  const mutate = (operation) => {
    if (!parsed.ok || isSourceAnalyzing) return;
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

  const copySource = () => {
    if (!source) return;
    machkit.copy(source);
  };

  const copyResults = () => {
    if (!pathQuery.matches.length) return;
    machkit.copy(pathQuery.matches.map((match) => stringifyValue(match.value)).join("\n\n"));
  };

  const editorPane = (
    <div
      className={`json-pane json-code-editor relative min-h-[360px] min-w-0 overflow-hidden ${showResults ? "h-full" : "flex-1"}`}
    >
      <div className="json-cm-host h-full min-h-[360px] min-w-0">
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
          onChange={(value) => {
            setSource(value);
            if (!value.trim()) setPath("");
          }}
          className="h-full min-h-[360px] min-w-0"
        />
      </div>
      <div className="pointer-events-none absolute top-2 right-2 z-20">
        <IconButton
          label={text.copy}
          disabled={!source}
          className="pointer-events-auto size-7 bg-surface/90 text-secondary shadow-sm backdrop-blur-sm hover:bg-muted hover:text-foreground"
          onClick={copySource}
        >
          <CopySimple size={15} />
        </IconButton>
      </div>
    </div>
  );

  const resultsPane = (
    <div className="json-pane relative flex h-full min-h-[360px] min-w-0 flex-col overflow-hidden">
      <div className="pointer-events-none absolute top-2 right-2 z-20">
        <IconButton
          label={text.copy}
          disabled={!pathQuery.matches.length}
          className="pointer-events-auto size-7 bg-surface/90 text-secondary shadow-sm backdrop-blur-sm hover:bg-muted hover:text-foreground"
          onClick={copyResults}
        >
          <CopySimple size={15} />
        </IconButton>
      </div>
      <div className="min-h-0 min-w-0 flex-1 space-y-4 overflow-y-auto px-3 py-2.5 pr-11">
        {pathQuery.matches.map((match) => {
          const fillHeight = pathQuery.matches.length === 1;
          return (
            <article
              key={match.path}
              className={
                fillHeight
                  ? "json-result-surface flex h-full min-h-0 min-w-0 flex-col overflow-hidden"
                  : "json-result-surface flex max-h-64 min-w-0 shrink-0 flex-col overflow-hidden"
              }
            >
              <button
                type="button"
                className="mb-1.5 min-w-0 shrink-0 truncate text-left font-mono text-[11px] text-accent hover:underline"
                title={text.usePath}
                onClick={() => setPath(match.path)}
              >
                {match.path}
              </button>
              <div className="min-h-0 min-w-0 flex-1 overflow-hidden">
                <JsonHighlight value={match.value} />
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex min-h-0 min-w-0 flex-1 flex-col gap-2 overflow-x-hidden pt-3">
        <div className="flex flex-col rounded-panel border border-border/80 bg-muted/55">
        <ToolToolbar className="min-h-[var(--machkit-size-control-compact)] flex-wrap gap-0.5 border-b-0 px-1.5 py-0.5">
          <Button
            variant="ghost"
            size="compact"
            disabled={!parsed.ok || isSourceAnalyzing}
            onClick={() => mutate("format")}
          >
            <BracketsCurly size={14} />
            {text.format}
          </Button>
          <Button
            variant="ghost"
            size="compact"
            disabled={!parsed.ok || isSourceAnalyzing}
            onClick={() => mutate("minify")}
          >
            <TextAa size={14} />
            {text.minify}
          </Button>
          <Button
            variant="ghost"
            size="compact"
            disabled={!parsed.ok || isSourceAnalyzing}
            onClick={() => mutate("sort")}
          >
            <TreeStructure size={14} />
            {text.sort}
          </Button>
          <span className="mx-1 hidden h-3.5 w-px shrink-0 self-center bg-border sm:block" aria-hidden />
          <Button variant="ghost" size="compact" disabled={!source} onClick={escapeSource}>
            <Quotes size={14} />
            {text.escape}
          </Button>
          <Button variant="ghost" size="compact" disabled={!source.trim()} onClick={unescapeSource}>
            <Quotes size={14} weight="duotone" />
            {text.unescape}
          </Button>
          <ActionGroup>
            <Popover.Root open={historyOpen} onOpenChange={setHistoryOpen}>
              <Popover.Trigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-[var(--machkit-size-control-compact)]"
                  aria-label={text.history}
                  title={text.history}
                >
                  <ClockCounterClockwise size={15} />
                </Button>
              </Popover.Trigger>
              <Popover.Portal>
                <Popover.Content
                  side="bottom"
                  align="end"
                  sideOffset={6}
                  className="z-50 w-[min(420px,calc(100vw-32px))] overflow-hidden rounded-panel border border-border bg-popover text-popover-foreground shadow-popover"
                >
                  <div className="flex items-center justify-between gap-2 border-b border-border px-3 py-2">
                    <span className="text-xs font-medium text-secondary">{text.history}</span>
                    <Button
                      type="button"
                      variant="ghost"
                      size="compact"
                      className="h-auto px-1.5 py-0.5 text-[11px] font-normal"
                      disabled={!history.length}
                      onClick={() => persistHistory([])}
                    >
                      <Trash size={13} />
                      {text.clearHistory}
                    </Button>
                  </div>
                  {history.length === 0 ? (
                    <p className="px-3 py-6 text-center text-xs text-secondary">{text.historyEmpty}</p>
                  ) : (
                    <ul className="max-h-72 overflow-y-auto py-1">
                      {history.map((entry) => (
                        <li key={entry.id}>
                          <button
                            type="button"
                            className="flex w-full flex-col gap-0.5 px-3 py-2 text-left hover:bg-accent-soft"
                            onClick={() => {
                              setSource(entry.source);
                              setHistoryOpen(false);
                            }}
                          >
                            <span className="line-clamp-2 font-mono text-[11px] text-foreground">{entry.preview}</span>
                            <span className="text-[10px] text-tertiary">{formatHistoryTime(entry.savedAt)}</span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                </Popover.Content>
              </Popover.Portal>
            </Popover.Root>
          </ActionGroup>
        </ToolToolbar>

        <ToolToolbar className="min-h-[var(--machkit-size-control)] min-w-0 gap-2 border-b-0 px-2.5 pt-0.5 pb-1.5">
          <div className="relative min-w-0 flex-1">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute top-1/2 left-2.5 z-10 -translate-y-1/2 text-secondary"
              aria-hidden
            />
            <Input
              value={path}
              onChange={(event) => setPath(event.target.value)}
              placeholder={text.pathPlaceholder}
              aria-label={text.path}
              invalid={Boolean(path.trim()) && parsed.ok && !pathQuery.ok}
              className="min-w-0 pl-8"
            />
          </div>
          {pathStatus ? (
            <span className="shrink-0 text-xs text-danger">
              {pathStatus}
            </span>
          ) : null}
        </ToolToolbar>
        </div>

        <div className="json-workspace machkit-panel flex min-h-0 min-w-0 flex-1 overflow-hidden">
          {showResults ? (
            <HorizontalSplit label={text.splitResize} left={editorPane} right={resultsPane} />
          ) : (
            editorPane
          )}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<JsonFormatter />, { name: "JSON Formatter" });
