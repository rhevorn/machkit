import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowsLeftRight, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  EditorPane,
  IconButton,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { diffLines } from "./diff.js";
import { messages } from "./messages.js";

const LINE_HEIGHT_PX = 20;
const SPLIT_STORAGE_KEY = "machkit.text-diff.leftRatio";
const DEFAULT_LEFT_RATIO = 0.5;
const MIN_LEFT_RATIO = 0.24;
const MAX_LEFT_RATIO = 0.76;

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

function lineToneClass(type, side) {
  if (type === "delete" && side === "left") return "diff-row-delete";
  if (type === "insert" && side === "right") return "diff-row-insert";
  return "diff-row-equal";
}

function DiffSidePane({ title, value, onChange, side, lineTypes, placeholder, copyLabel }) {
  const backdropRef = useRef(null);
  const textareaRef = useRef(null);
  const lines = value.length ? value.split("\n") : [""];

  const syncScroll = () => {
    if (!backdropRef.current || !textareaRef.current) return;
    backdropRef.current.scrollTop = textareaRef.current.scrollTop;
    backdropRef.current.scrollLeft = textareaRef.current.scrollLeft;
  };

  useEffect(() => {
    syncScroll();
  }, [value, lineTypes]);

  return (
    <EditorPane
      title={title}
      className="min-h-0 flex-1"
      bodyClassName="min-h-0"
      actions={(
        <IconButton
          label={copyLabel}
          disabled={!value}
          className="size-7"
          onClick={() => machkit.copy(value)}
        >
          <CopySimple size={14} />
        </IconButton>
      )}
    >
      <div className="relative flex h-full min-h-[280px] min-w-0 overflow-hidden">
        <div
          ref={backdropRef}
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 overflow-hidden font-mono text-[12px]"
          style={{ lineHeight: `${LINE_HEIGHT_PX}px` }}
        >
          {lines.map((line, index) => {
            const lineNo = index + 1;
            return (
              <div
                key={`bg-${lineNo}`}
                className={cn("flex min-h-[20px]", lineToneClass(lineTypes.get(lineNo), side))}
                style={{ minHeight: LINE_HEIGHT_PX }}
              >
                <span className="w-10 shrink-0 select-none px-2 text-right text-tertiary">{lineNo}</span>
                <span className="min-w-0 flex-1 overflow-hidden px-2 whitespace-pre opacity-0">{line || " "}</span>
              </div>
            );
          })}
        </div>
        <div className="relative z-10 flex min-h-0 min-w-0 flex-1">
          <div className="w-10 shrink-0" aria-hidden="true" />
          <textarea
            ref={textareaRef}
            value={value}
            onChange={(event) => onChange(event.target.value)}
            onScroll={syncScroll}
            placeholder={placeholder}
            spellCheck={false}
            className="min-h-0 min-w-0 flex-1 resize-none border-0 bg-transparent px-2 py-0 font-mono text-[12px] text-foreground outline-none placeholder:text-tertiary"
            style={{ lineHeight: `${LINE_HEIGHT_PX}px` }}
          />
        </div>
      </div>
    </EditorPane>
  );
}

function TextDiff() {
  const text = useToolMessages(messages);
  const [left, setLeft] = useState('{\n  "name": "machkit",\n  "version": 1\n}\n');
  const [right, setRight] = useState('{\n  "name": "machkit",\n  "version": 2,\n  "stable": true\n}\n');
  const [ignoreWhitespace, setIgnoreWhitespace] = useState(false);

  const result = useMemo(
    () => diffLines(left, right, { ignoreWhitespace }),
    [left, right, ignoreWhitespace],
  );

  const leftLineTypes = useMemo(() => {
    const map = new Map();
    if (!result.ok) return map;
    for (const row of result.rows) {
      if (row.leftLine == null) continue;
      map.set(row.leftLine, row.type);
    }
    return map;
  }, [result]);

  const rightLineTypes = useMemo(() => {
    const map = new Map();
    if (!result.ok) return map;
    for (const row of result.rows) {
      if (row.rightLine == null) continue;
      map.set(row.rightLine, row.type);
    }
    return map;
  }, [result]);

  const status = !left && !right
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "too-many-lines" ? text.tooManyLines : text.tooLarge,
        }
      : result.stats.added === 0 && result.stats.removed === 0
        ? { tone: "info", label: text.identical }
        : {
            tone: "info",
            label: `${text.stats}: +${result.stats.added} ${text.added} · −${result.stats.removed} ${text.removed} · ${result.stats.equal} ${text.equal}`,
          };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex h-full min-h-0 flex-1 flex-col gap-2 overflow-hidden pt-3 pb-4">
        <ToolToolbar className="min-h-[var(--machkit-size-control)] gap-2 border-b-0">
          <CheckboxField
            checked={ignoreWhitespace}
            onCheckedChange={(checked) => setIgnoreWhitespace(checked === true)}
            label={text.ignoreWhitespace}
          />
          <ActionGroup>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setLeft(right);
                setRight(left);
              }}
            >
              <ArrowsLeftRight size={15} />
              {text.swap}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setLeft("");
                setRight("");
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        <HorizontalSplit
          label="Resize panels"
          left={(
            <DiffSidePane
              title={text.left}
              value={left}
              onChange={setLeft}
              side="left"
              lineTypes={leftLineTypes}
              placeholder={text.empty}
              copyLabel={`${text.copy} ${text.left}`}
            />
          )}
          right={(
            <DiffSidePane
              title={text.right}
              value={right}
              onChange={setRight}
              side="right"
              lineTypes={rightLineTypes}
              placeholder={text.empty}
              copyLabel={`${text.copy} ${text.right}`}
            />
          )}
        />
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<TextDiff />, { name: "Text Diff" });
