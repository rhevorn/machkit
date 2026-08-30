import { useMemo, useState } from "react";
import { EraserIcon } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ColorPicker,
  ExampleChips,
  Input,
  PropertyList,
  PropertyRow,
  ResultPanel,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { parseColor } from "./color.js";
import { messages } from "./messages.js";

type StatusTone = "neutral" | "info" | "success" | "warning" | "danger";

const EXAMPLES = ["#0A84FF", "rgb(255, 149, 0)", "hsl(280, 60%, 45%)", "#34C759"];

function ContrastSwatch({
  label,
  ratio,
  background,
  color,
}: {
  label: string;
  ratio: number | null;
  background: string;
  color: string;
}) {
  return (
    <div
      className="flex min-h-14 flex-col justify-end gap-0.5 px-3 py-2"
      style={{ background, color }}
    >
      <span className="text-[11px] leading-none opacity-80">{label}</span>
      <span className="font-mono text-[12px] leading-none tabular-nums">
        {ratio != null ? `${ratio}:1` : "—"}
      </span>
    </div>
  );
}

function ColorLabTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("#0A84FF");

  const result = useMemo(() => parseColor(input), [input]);
  const trimmed = input.trim();
  const status: { tone: StatusTone; label: string } | null = !trimmed
    ? null
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "too-large" ? text.tooLarge : text.invalid,
        }
      : null;

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
            <ColorPicker
              value={input}
              label={text.picker}
              onChange={(hex) => setInput(hex)}
            />
          </div>
          <ActionGroup>
            <Button variant="ghost" size="sm" onClick={() => setInput("")}>
              <EraserIcon size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <ExampleChips label={text.examples} options={EXAMPLES} onSelect={setInput} />

        {status ? <StatusStrip tone={status.tone}>{status.label}</StatusStrip> : null}

        <div className="grid gap-3 lg:grid-cols-[240px_minmax(0,1fr)]">
          <ResultPanel className="flex flex-col overflow-hidden p-0" bodyClassName="flex min-h-0 flex-1 flex-col p-0">
            <div
              className="min-h-[148px] flex-1"
              style={{
                background: result.ok
                  ? `linear-gradient(0deg, ${result.formats.rgb}, ${result.formats.rgb}), repeating-conic-gradient(#ccc 0% 25%, #fff 0% 50%) 0 0 / 16px 16px`
                  : "var(--machkit-field, transparent)",
              }}
            />
            <div className="grid grid-cols-2 gap-px border-t border-border bg-border">
              <ContrastSwatch
                label={text.onWhite}
                ratio={result.ok ? result.contrast.onWhite : null}
                background="#fff"
                color={result.ok ? result.hex.slice(0, 7) : "#111"}
              />
              <ContrastSwatch
                label={text.onBlack}
                ratio={result.ok ? result.contrast.onBlack : null}
                background="#111"
                color={result.ok ? result.hex.slice(0, 7) : "#eee"}
              />
            </div>
          </ResultPanel>

          <ResultPanel title={text.formats}>
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
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ColorLabTool />, { name: "Color Lab" });
