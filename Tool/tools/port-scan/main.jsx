import React, { useEffect, useMemo, useRef, useState } from "react";
import { CopySimple, Eraser, Play, X } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  ResultPanel,
  SegmentedControl,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  formatDuration,
  inspectPortExpression,
  isTerminalState,
  normalizeHost,
  presets,
  progressPercent,
} from "./scan.js";
import { messages } from "./messages.js";

const POLL_INTERVAL = 250;

function PortScanTool() {
  const text = useToolMessages(messages);
  const timerRef = useRef(null);
  const generationRef = useRef(0);
  const scanIDRef = useRef(null);
  const [host, setHost] = useState("localhost");
  const [preset, setPreset] = useState("common");
  const [ports, setPorts] = useState(presets.common);
  const [timeout, setTimeoutValue] = useState("300");
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [running, setRunning] = useState(false);

  const portInspection = useMemo(() => inspectPortExpression(ports), [ports]);
  const percent = progressPercent(result?.completed ?? 0, result?.total ?? portInspection.count);
  const openPorts = Array.isArray(result?.openPorts) ? result.openPorts : [];

  useEffect(() => () => {
    generationRef.current += 1;
    if (timerRef.current) clearTimeout(timerRef.current);
  }, []);

  function errorLabel(code) {
    const key = `err_${String(code || "failed").replace(/-/g, "_")}`;
    return text[key] || text.failed;
  }

  async function poll(scanID, generation) {
    if (generation !== generationRef.current) return;
    try {
      const next = await machkit.portScan("status", { scanID });
      if (generation !== generationRef.current) return;
      setResult(next);
      if (isTerminalState(next.state)) {
        setRunning(false);
        if (next.state === "failed") setError(errorLabel(next.error));
        return;
      }
      timerRef.current = setTimeout(() => poll(scanID, generation), POLL_INTERVAL);
    } catch (caught) {
      if (generation !== generationRef.current) return;
      setRunning(false);
      setError(caught instanceof Error ? caught.message : text.failed);
    }
  }

  async function startScan() {
    const target = normalizeHost(host);
    if (!target) {
      setError(text.err_empty_host);
      return;
    }
    if (!portInspection.ok) {
      setError(errorLabel(portInspection.error));
      return;
    }
    if (!machkit.isEmbedded) {
      setError(text.needApp);
      return;
    }

    generationRef.current += 1;
    const generation = generationRef.current;
    if (timerRef.current) clearTimeout(timerRef.current);
    setRunning(true);
    setError(null);
    setResult({ state: "running", total: portInspection.count, completed: 0, openPorts: [] });
    try {
      const started = await machkit.portScan("start", {
        host: target,
        ports,
        timeoutMs: Number(timeout),
      });
      scanIDRef.current = started.scanID;
      setResult({ ...started, state: "running", completed: 0, openPorts: [] });
      timerRef.current = setTimeout(() => poll(started.scanID, generation), 80);
    } catch (caught) {
      setRunning(false);
      setError(errorLabel(caught instanceof Error ? caught.message : "failed"));
    }
  }

  async function cancelScan() {
    const scanID = scanIDRef.current;
    if (!scanID) return;
    generationRef.current += 1;
    if (timerRef.current) clearTimeout(timerRef.current);
    try {
      const next = await machkit.portScan("cancel", { scanID });
      setResult(next);
    } catch {
      // The native task may already have completed between the last poll and cancel.
    }
    setRunning(false);
  }

  function selectPreset(next) {
    setPreset(next);
    if (next !== "custom") setPorts(presets[next]);
  }

  function clearAll() {
    setHost("");
    setPorts("");
    setPreset("custom");
    setResult(null);
    setError(null);
  }

  const status = running
    ? { tone: "info", label: `${text.scanning} ${result?.completed ?? 0} / ${result?.total ?? portInspection.count}` }
    : error
      ? { tone: "danger", label: error }
      : result?.state === "cancelled"
        ? { tone: "neutral", label: text.cancelled }
        : result?.state === "completed"
          ? { tone: "info", label: `${text.completed} · ${openPorts.length} ${text.open}` }
          : { tone: "neutral", label: text.ready };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="flex-wrap gap-2">
          <Input
            className="min-w-[180px] flex-1 font-mono text-[12px]"
            value={host}
            onChange={(event) => setHost(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !running) startScan();
            }}
            placeholder={text.hostPlaceholder}
            aria-label={text.host}
            spellCheck={false}
          />
          <SegmentedControl
            value={timeout}
            onChange={setTimeoutValue}
            label={text.timeout}
            size="compact"
            className="w-[212px] flex-none"
            options={[
              { value: "200", label: text.fast },
              { value: "300", label: text.balanced },
              { value: "1000", label: text.deep },
            ]}
          />
          <ActionGroup>
            {running ? (
              <Button variant="secondary" size="sm" onClick={cancelScan}>
                <X size={15} />
                {text.cancel}
              </Button>
            ) : (
              <Button variant="default" size="sm" onClick={startScan}>
                <Play size={15} />
                {text.scan}
              </Button>
            )}
            <Button variant="ghost" size="sm" onClick={clearAll} disabled={running}>
              <Eraser size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <div className="flex flex-wrap items-center gap-2">
          <span className="machkit-control-label">{text.preset}</span>
          <SegmentedControl
            value={preset}
            onChange={selectPreset}
            label={text.preset}
            size="compact"
            className="min-w-[430px] flex-1"
            options={[
              { value: "common", label: text.common },
              { value: "web", label: text.web },
              { value: "dev", label: text.development },
              { value: "database", label: text.database },
              { value: "all", label: text.all },
              { value: "custom", label: text.custom },
            ]}
          />
        </div>

        <div className="flex items-center gap-2">
          <label htmlFor="port-expression" className="machkit-control-label shrink-0">{text.ports}</label>
          <Input
            id="port-expression"
            className="min-w-0 flex-1 font-mono text-[12px]"
            value={ports}
            onChange={(event) => {
              setPorts(event.target.value);
              setPreset("custom");
            }}
            placeholder="22,80,443,8000-8010"
            spellCheck={false}
          />
          <span className="shrink-0 text-[11px] text-tertiary">
            {portInspection.ok ? `${portInspection.count} ${text.portsCount}` : text.invalidPorts}
          </span>
        </div>

        {preset === "all" ? <StatusStrip tone="neutral">{text.allHint}</StatusStrip> : null}
        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        {running || result ? (
          <ResultPanel bodyClassName="flex flex-col gap-2 px-3 py-3">
            <div className="flex items-center justify-between text-[11px] text-secondary">
              <span>{result?.completed ?? 0} / {result?.total ?? portInspection.count}</span>
              <span>{percent}%</span>
            </div>
            <div
              className="h-1.5 overflow-hidden rounded-full bg-border"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={percent}
            >
              <div className="h-full rounded-full bg-accent transition-[width] duration-200" style={{ width: `${percent}%` }} />
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-tertiary">
              <span>{text.open}: <strong className="text-foreground">{openPorts.length}</strong></span>
              <span>{text.closed}: {result?.closed ?? 0}</span>
              <span>{text.timedOut}: {result?.timedOut ?? 0}</span>
              {result?.durationMs != null ? <span>{text.duration}: {formatDuration(result.durationMs)}</span> : null}
            </div>
          </ResultPanel>
        ) : null}

        {openPorts.length ? (
          <ResultPanel>
            <div className="grid grid-cols-[7rem_minmax(0,1fr)_7rem] border-b border-border px-3 py-2 text-[11px] text-secondary">
              <span>{text.port}</span>
              <span>{text.service}</span>
              <span className="text-right">{text.latency}</span>
            </div>
            {openPorts.map((item) => (
              <div
                key={item.port}
                className="grid grid-cols-[7rem_minmax(0,1fr)_7rem] items-center border-b border-border px-3 py-2 last:border-b-0"
              >
                <code className="font-mono text-[13px] text-accent">{item.port}</code>
                <span className="text-[12px] text-secondary">{item.service || text.unknown}</span>
                <span className="text-right font-mono text-[11px] text-tertiary">
                  {item.latencyMs == null ? "—" : `${item.latencyMs} ms`}
                </span>
              </div>
            ))}
            <div className="flex justify-end border-t border-border px-2 py-1.5">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => machkit.copy(openPorts.map((item) => `${result.host}:${item.port}`).join("\n"))}
              >
                <CopySimple size={15} />
                {text.copy}
              </Button>
            </div>
          </ResultPanel>
        ) : result?.state === "completed" ? (
          <ResultPanel bodyClassName="px-3 py-5 text-center text-[12px] text-tertiary">
            {text.noOpen}
          </ResultPanel>
        ) : null}

        <p className="text-[11px] leading-relaxed text-tertiary">{text.authorizedOnly}</p>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<PortScanTool />, { name: "Port Scanner" });
