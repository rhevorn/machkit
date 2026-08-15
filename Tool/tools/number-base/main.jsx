import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Input,
  SegmentedControl,
  SelectControl,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { byteUnits, convertBases, convertBytes } from "./number.js";
import { messages } from "./messages.js";

function FormatRow({ label, value, copyLabel }) {
  return (
    <div className="flex min-w-0 items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
      <span className="w-24 shrink-0 text-[12px] text-secondary">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono text-[12px]">{value}</code>
      <Button variant="ghost" size="sm" className="shrink-0" onClick={() => machkit.copy(value)}>
        <CopySimple size={15} />
        {copyLabel}
      </Button>
    </div>
  );
}

function NumberBaseTool() {
  const text = useToolMessages(messages);
  const [tab, setTab] = useState("bases");
  const [input, setInput] = useState("255");
  const [byteInput, setByteInput] = useState("1");
  const [unit, setUnit] = useState("MiB");

  const bases = useMemo(() => convertBases(input), [input]);
  const bytes = useMemo(() => convertBytes(byteInput, unit), [byteInput, unit]);

  const status =
    tab === "bases"
      ? !input.trim()
        ? { tone: "neutral", label: text.empty }
        : !bases.ok
          ? { tone: "danger", label: bases.error === "too-large" ? text.tooLarge : text.invalid }
          : { tone: "info", label: bases.formats.dec }
      : !byteInput.trim()
        ? { tone: "neutral", label: text.empty }
        : !bytes.ok
          ? { tone: "danger", label: text.invalid }
          : { tone: "info", label: `${bytes.formats.B} B` };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <SegmentedControl
            value={tab}
            onChange={setTab}
            label={text.title}
            size="compact"
            className="w-[180px] flex-none"
            options={[
              { value: "bases", label: text.tabBases },
              { value: "bytes", label: text.tabBytes },
            ]}
          />
          <div className="ml-auto flex items-center gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setInput("");
                setByteInput("");
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        {tab === "bases" ? (
          <div className="flex items-center gap-2">
            <label htmlFor="num-input" className="machkit-control-label whitespace-nowrap">{text.input}</label>
            <Input
              id="num-input"
              className="min-w-0 flex-1 font-mono"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <label htmlFor="byte-input" className="machkit-control-label whitespace-nowrap">{text.input}</label>
            <Input
              id="byte-input"
              className="min-w-0 flex-1 font-mono"
              value={byteInput}
              onChange={(event) => setByteInput(event.target.value)}
              placeholder={text.bytesPlaceholder}
              spellCheck={false}
            />
            <SelectControl
              value={unit}
              onChange={setUnit}
              label={text.unit}
              className="w-[100px] flex-none"
              options={byteUnits.map((id) => ({ value: id, label: id }))}
            />
          </div>
        )}

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="machkit-panel">
          {tab === "bases" && bases.ok ? (
            <>
              <FormatRow label={text.bin} value={bases.formats.bin} copyLabel={text.copy} />
              <FormatRow label={text.oct} value={bases.formats.oct} copyLabel={text.copy} />
              <FormatRow label={text.dec} value={bases.formats.dec} copyLabel={text.copy} />
              <FormatRow label={text.hex} value={bases.formats.hex} copyLabel={text.copy} />
            </>
          ) : null}
          {tab === "bytes" && bytes.ok
            ? byteUnits.map((id) => (
                <FormatRow key={id} label={id} value={bytes.formats[id]} copyLabel={text.copy} />
              ))
            : null}
          {((tab === "bases" && !bases.ok) || (tab === "bytes" && !bytes.ok)) && (
            <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
          )}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<NumberBaseTool />, { name: "Number Base" });
