import React, { useState } from "react";
import { Eraser, Play } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Input,
  SegmentedControl,
  ToolContent,
  ToolInfoButton,
  ToolPage,
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
        <div className="machkit-toolbar gap-2">
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
          <Button variant="secondary" size="sm" disabled={running} onClick={runTrace}>
            <Play size={15} />
            {text.run}
          </Button>
          <Button variant="ghost" size="sm" disabled={running} onClick={clearAll}>
            <Eraser size={15} />
            {text.clear}
          </Button>
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-[11px] text-tertiary">
          <span>{text.examples}</span>
          {EXAMPLES.map((example) => (
            <button
              key={example}
              type="button"
              className="font-mono text-secondary hover:text-accent"
              onClick={() => setTarget(example)}
            >
              {example}
            </button>
          ))}
          {timings ? (
            <>
              <span className="text-border">·</span>
              <TimingChip label="DNS" value={timings.dnsMs} />
              <TimingChip label="TCP" value={timings.tcpMs} />
              <TimingChip label="TLS" value={timings.tlsMs} />
              <TimingChip label="TTFB" value={timings.ttfbMs} />
              <TimingChip label="Σ" value={timings.totalMs} />
            </>
          ) : null}
        </div>

        {status ? <InlineMessage tone={status.tone}>{status.label}</InlineMessage> : null}

        {result ? (
          <pre className="machkit-panel max-h-[520px] overflow-auto px-3 py-2.5 font-mono text-[11.5px] leading-[1.45] whitespace-pre-wrap break-all text-foreground">
            {verbose.length
              ? verbose.join("\n")
              : `* ${result.message || errorLabel(text, result.error)}`}
          </pre>
        ) : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<ConnectionTraceTool />, { name: "Connection Trace" });
