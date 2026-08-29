import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  Input,
  ResultPanel,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { describeMode, inspectPermission, toggleBit, toggleSpecial } from "./chmod.js";
import { messages } from "./messages.js";

function ChmodLabTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("755");
  const [mode, setMode] = useState(0o755);

  const parsed = useMemo(() => inspectPermission(input), [input]);
  const view = useMemo(() => (parsed.ok ? parsed : describeMode(mode)), [parsed, mode]);

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !parsed.ok
      ? { tone: "danger", label: text.invalid }
      : { tone: "info", label: `${view.octal} · ${view.symbolic}` };

  function applyMode(next) {
    setMode(next.mode);
    setInput(next.octal);
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="gap-2">
          <label htmlFor="chmod-input" className="machkit-control-label whitespace-nowrap">
            {text.input}
          </label>
          <Input
            id="chmod-input"
            className="min-w-0 flex-1 font-mono"
            value={input}
            onChange={(event) => {
              setInput(event.target.value);
              const next = inspectPermission(event.target.value);
              if (next.ok) setMode(next.mode);
            }}
            placeholder={text.placeholder}
            spellCheck={false}
          />
          <ActionGroup>
            <Button variant="ghost" size="sm" onClick={() => machkit.copy(view.chmod)}>
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setInput("");
                setMode(0);
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        <div className="grid gap-3 sm:grid-cols-3">
          {[
            ["octal", view.octal],
            ["symbolic", view.symbolic],
            ["command", view.chmod],
          ].map(([key, value]) => (
            <ResultPanel
              key={key}
              className="flex items-center justify-between gap-2 px-3 py-2.5"
              bodyClassName="contents"
            >
              <div className="flex min-w-0 flex-1 items-center justify-between gap-2">
                <div className="min-w-0">
                  <div className="text-[11px] text-secondary">{text[key]}</div>
                  <code className="font-mono text-[13px]">{value}</code>
                </div>
                <Button variant="ghost" size="sm" onClick={() => machkit.copy(value)}>
                  <CopySimple size={15} />
                </Button>
              </div>
            </ResultPanel>
          ))}
        </div>

        <ResultPanel>
          <div className="grid grid-cols-[7rem_repeat(3,minmax(0,1fr))] border-b border-border px-3 py-2 text-[11px] text-secondary">
            <span />
            <span>{text.read}</span>
            <span>{text.write}</span>
            <span>{text.execute}</span>
          </div>
          {["owner", "group", "other"].map((who) => (
            <div
              key={who}
              className="grid grid-cols-[7rem_repeat(3,minmax(0,1fr))] items-center border-b border-border px-3 py-2 last:border-b-0"
            >
              <span className="text-[12px] text-secondary">{text[who]}</span>
              {["r", "w", "x"].map((perm) => (
                <CheckboxField
                  key={perm}
                  checked={view.bits[who][perm]}
                  onCheckedChange={() => applyMode(toggleBit(view.mode, who, perm))}
                  label={perm}
                />
              ))}
            </div>
          ))}
        </ResultPanel>

        <ResultPanel bodyClassName="flex flex-col gap-2 px-3 py-3">
          <div className="flex flex-wrap items-center gap-4">
            <span className="text-[12px] text-secondary">{text.special}</span>
            {["setuid", "setgid", "sticky"].map((flag) => (
              <CheckboxField
                key={flag}
                checked={view.bits[flag]}
                onCheckedChange={() => applyMode(toggleSpecial(view.mode, flag))}
                label={text[flag]}
              />
            ))}
          </div>
          <p className="text-[11px] leading-relaxed text-tertiary">{text.specialHint}</p>
        </ResultPanel>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ChmodLabTool />, { name: "chmod Lab" });
