import React, { useMemo, useState } from "react";
import { Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ExampleChips,
  Input,
  PropertyList,
  PropertyRow,
  ResultPanel,
  StatusStrip,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { parseColor } from "./color.js";
import { messages } from "./messages.js";

const EXAMPLES = ["#0A84FF", "rgb(255, 149, 0)", "hsl(280, 60%, 45%)", "#34C759"];

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
        <ToolToolbar className="gap-2">
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
          <ActionGroup>
            <Button variant="ghost" size="sm" onClick={() => setInput("")}>
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </ActionGroup>
        </ToolToolbar>

        <ExampleChips label={text.examples} options={EXAMPLES} onSelect={setInput} />

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        <div className="grid gap-3 lg:grid-cols-[220px_minmax(0,1fr)]">
          <ResultPanel className="flex flex-col p-0" bodyClassName="flex min-h-0 flex-1 flex-col">
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
          </ResultPanel>

          <div className="flex flex-col gap-3">
            <ResultPanel>
              {result.ok ? (
                <PropertyList>
                  <PropertyRow label={text.hex} value={result.formats.hex} copyLabel={text.copy} labelClassName="w-10" />
                  <PropertyRow label={text.rgb} value={result.formats.rgb} copyLabel={text.copy} labelClassName="w-10" />
                  <PropertyRow label={text.hsl} value={result.formats.hsl} copyLabel={text.copy} labelClassName="w-10" />
                  <PropertyRow label={text.hsv} value={result.formats.hsv} copyLabel={text.copy} labelClassName="w-10" />
                </PropertyList>
              ) : (
                <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
              )}
            </ResultPanel>

            {result.ok ? (
              <ResultPanel>
                <PropertyList>
                  <PropertyRow label={text.onWhite} value={`${result.contrast.onWhite}:1`} />
                  <PropertyRow label={text.onBlack} value={`${result.contrast.onBlack}:1`} />
                </PropertyList>
              </ResultPanel>
            ) : null}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ColorLabTool />, { name: "Color Lab" });
