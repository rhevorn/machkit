import React, { useState } from "react";
import { Eraser, Play } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ExampleChips,
  Input,
  ResultPanel,
  SegmentedControl,
  StatusStrip,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { formatMs, modes, normalizeTarget, summarizeResult } from "./trace.js";
import { messages } from "./messages.js";

const EXAMPLES = ["example.com", "https://example.com", "1.1.1.1"];

function errorLabel(text, code) {
  if (!code) return text.failed;
  const key = `err_${String(code).replace(/-/g, "_")}`;
  return text[key] || text.failed;
}

function TimingChip({ label, value }) {
  if (value == null) return null;
  return (
    <span className="font-mono text-[11px] tabular-nums text-secondary">
      <span className="text-tertiary">{label}</span> {formatMs(value)}
    </span>
  );
}

function ConnectionTraceTool() {
  const text = useToolMessages(messages);
  const [target, setTarget] = useState("example.com");
  const [mode, setMode] = useState("full");
  const [result, setResult] = useState(null);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState(null);

  const status = running
    ? { tone: "info", label: text.running }
    : error && !result
      ? { tone: "danger", label: error }
      : null;

  async function runTrace() {
    const value = normalizeTarget(target);
    if (!value) {
      setError(text.empty);
      setResult(null);
      return;
    }
    if (!machkit.isEmbedded) {
      setError(text.needApp);
      setResult(null);
      return;
    }

    setRunning(true);
    setError(null);
    try {
      const payload = summarizeResult(
        await machkit.connectionTrace("probe", { target: value, mode }, { timeout: 20_000 }),
      );
      setResult(payload);
      if (!payload.ok) {
        setError(payload.message || errorLabel(text, payload.error));
      }
    } catch (caught) {
      setResult(null);
      setError(caught instanceof Error ? caught.message : text.failed);
    } finally {
      setRunning(false);
    }
  }

  function clearAll() {
    setTarget("");
    setResult(null);
    setError(null);
  }

  const verbose = Array.isArray(result?.verbose) ? result.verbose : [];
  const timings = result?.timings;

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-2.5 pt-3 pb-4">
        <ToolToolbar className="gap-2">
          <SegmentedControl
            value={modes.includes(mode) ? mode : "full"}
            onChange={setMode}
            label={text.mode}
            size="compact"
            className="w-[188px] flex-none"
            options={[
              { value: "dns", label: text.modeDns },
              { value: "full", label: text.modeFull },
            ]}
          />
          <Input
            className="min-w-0 flex-1 font-mono text-[12px]"
            value={target}
            onChange={(event) => setTarget(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.preventDefault();
                runTrace();
              }
            }}
            placeholder={text.placeholder}
            spellCheck={false}
          />
          <ActionGroup>
            <Button variant="default" size="sm" disabled={running} onClick={runTrace}>
              <Play size={15} />
              {text.run}
            </Button>
            <Button variant="ghost" size="sm" disabled={running} onClick={clearAll}>
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </ActionGroup>
        </ToolToolbar>

        <div className="flex flex-wrap items-center gap-x-2 gap-y-1.5">
          <ExampleChips label={text.examples} options={EXAMPLES} onSelect={setTarget} />
          {timings ? (
            <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-[11px] text-tertiary">
              <span className="text-border">·</span>
              <TimingChip label="DNS" value={timings.dnsMs} />
              <TimingChip label="TCP" value={timings.tcpMs} />
              <TimingChip label="TLS" value={timings.tlsMs} />
              <TimingChip label="TTFB" value={timings.ttfbMs} />
              <TimingChip label="Σ" value={timings.totalMs} />
            </div>
          ) : null}
        </div>

        {status ? <StatusStrip tone={status.tone}>{status.label}</StatusStrip> : null}

        {result ? (
          <ResultPanel
            className="max-h-[520px]"
            bodyClassName="overflow-auto px-3 py-2.5 font-mono text-[11.5px] leading-[1.45] whitespace-pre-wrap break-all text-foreground"
          >
            <pre className="m-0 font-inherit whitespace-pre-wrap break-all">
              {verbose.length
                ? verbose.join("\n")
                : `* ${result.message || errorLabel(text, result.error)}`}
            </pre>
          </ResultPanel>
        ) : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ConnectionTraceTool />, { name: "Connection Trace" });
