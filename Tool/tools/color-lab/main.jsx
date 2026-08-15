import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Input,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { parseColor } from "./color.js";
import { messages } from "./messages.js";

const EXAMPLES = ["#0A84FF", "rgb(255, 149, 0)", "hsl(280, 60%, 45%)", "#34C759"];

function FormatRow({ label, value, copyLabel }) {
  return (
    <div className="flex min-w-0 items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
      <span className="w-10 shrink-0 text-[12px] text-secondary">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono text-[12px] text-foreground">{value}</code>
      <Button variant="ghost" size="sm" className="shrink-0" onClick={() => machkit.copy(value)}>
        <CopySimple size={15} />
        {copyLabel}
      </Button>
    </div>
  );
}

function ColorLabTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("#0A84FF");

  const result = useMemo(() => parseColor(input), [input]);
  const pickerValue = result.ok ? result.hex.slice(0, 7) : "#000000";

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "too-large" ? text.tooLarge : text.invalid,
        }
      : { tone: "info", label: result.hex };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="color-input" className="machkit-control-label whitespace-nowrap">
              {text.input}
            </label>
            <Input
              id="color-input"
              className="min-w-0 flex-1 font-mono"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
            <label
              className="relative inline-flex size-8.5 shrink-0 cursor-pointer items-center justify-center overflow-hidden rounded-md border border-border bg-field"
              title={text.picker}
            >
              <span
                className="absolute inset-0"
                style={{ background: result.ok ? result.formats.rgb : "transparent" }}
              />
              <input
                type="color"
                className="absolute inset-0 cursor-pointer opacity-0"
                value={pickerValue}
                aria-label={text.picker}
                onChange={(event) => setInput(event.target.value.toUpperCase())}
              />
            </label>
          </div>
          <Button variant="ghost" size="sm" onClick={() => setInput("")}>
            <Eraser size={15} />
            {text.clear}
          </Button>
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] text-tertiary">
          <span>{text.examples}</span>
          {EXAMPLES.map((example) => (
            <button
              key={example}
              type="button"
              className="font-mono text-secondary hover:text-accent"
              onClick={() => setInput(example)}
            >
              {example}
            </button>
          ))}
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-3 lg:grid-cols-[220px_minmax(0,1fr)]">
          <div className="machkit-panel flex flex-col overflow-hidden p-0">
            <div
              className="min-h-[140px] flex-1"
              style={{
                background: result.ok
                  ? `linear-gradient(0deg, ${result.formats.rgb}, ${result.formats.rgb}), repeating-conic-gradient(#ccc 0% 25%, #fff 0% 50%) 0 0 / 16px 16px`
                  : "var(--machkit-field, transparent)",
              }}
            />
            <div className="grid grid-cols-2 gap-px border-t border-border bg-border">
              <div
                className="flex h-14 items-end px-3 pb-2 text-[11px]"
                style={{ background: "#fff", color: result.ok ? result.hex.slice(0, 7) : "#111" }}
              >
                {text.onWhite}
              </div>
              <div
                className="flex h-14 items-end px-3 pb-2 text-[11px]"
                style={{ background: "#111", color: result.ok ? result.hex.slice(0, 7) : "#eee" }}
              >
                {text.onBlack}
              </div>
            </div>
          </div>

          <div className="flex flex-col gap-3">
            <div className="machkit-panel">
              {result.ok ? (
                <>
                  <FormatRow label={text.hex} value={result.formats.hex} copyLabel={text.copy} />
                  <FormatRow label={text.rgb} value={result.formats.rgb} copyLabel={text.copy} />
                  <FormatRow label={text.hsl} value={result.formats.hsl} copyLabel={text.copy} />
                  <FormatRow label={text.hsv} value={result.formats.hsv} copyLabel={text.copy} />
                </>
              ) : (
                <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
              )}
            </div>

            {result.ok ? (
              <div className="machkit-panel">
                <div className="flex items-baseline justify-between gap-3 border-b border-border px-3 py-2">
                  <span className="text-[12px] text-secondary">{text.onWhite}</span>
                  <span className="font-mono text-[12px]">{result.contrast.onWhite}:1</span>
                </div>
                <div className="flex items-baseline justify-between gap-3 px-3 py-2">
                  <span className="text-[12px] text-secondary">{text.onBlack}</span>
                  <span className="font-mono text-[12px]">{result.contrast.onBlack}:1</span>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ColorLabTool />, { name: "Color Lab" });
