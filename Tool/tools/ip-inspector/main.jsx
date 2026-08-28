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
import { inspectIP } from "./ip.js";
import { messages } from "./messages.js";

const EXAMPLES = ["192.168.1.10", "127.0.0.1", "2001:db8::1", "::ffff:192.0.2.128"];

function DetailRow({ label, value, copyLabel }) {
  const hasValue = value || value === 0;
  if (!hasValue) return null;
  const display = String(value);
  return (
    <div className="flex min-w-0 items-baseline gap-2 border-b border-border/70 py-2 last:border-b-0">
      <span className="w-[7.5rem] shrink-0 text-[12px] text-secondary">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono text-[13px] tabular-nums text-foreground select-text">
        {display}
      </code>
      <Button
        variant="ghost"
        size="sm"
        className="h-7 shrink-0 px-2 text-secondary"
        aria-label={copyLabel}
        title={copyLabel}
        onClick={() => machkit.copy(display)}
      >
        <CopySimple size={15} />
      </Button>
    </div>
  );
}

function kindLabel(text, kind) {
  const key = `kind_${String(kind || "").replace(/-/g, "_")}`;
  return text[key] || kind;
}

function IpInspectorTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("192.168.1.10");
  const result = useMemo(() => inspectIP(input), [input]);

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? { tone: "danger", label: text.invalid }
      : { tone: "info", label: `IPv${result.version} · ${kindLabel(text, result.kind)}` };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-4 pb-6">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="ip-input" className="machkit-control-label whitespace-nowrap">
              {text.input}
            </label>
            <Input
              id="ip-input"
              className="min-w-0 flex-1 font-mono"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
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

        <section className="rounded-panel border border-border bg-surface px-5 py-2">
          {result.ok ? (
            <>
              <DetailRow label={text.version} value={`IPv${result.version}`} copyLabel={text.copy} />
              <DetailRow label={text.address} value={result.address} copyLabel={text.copy} />
              <DetailRow label={text.kind} value={kindLabel(text, result.kind)} copyLabel={text.copy} />
              {result.version === 4 ? (
                <>
                  <DetailRow label={text.className} value={result.class} copyLabel={text.copy} />
                  <DetailRow label={text.integer} value={result.integer} copyLabel={text.copy} />
                  <DetailRow label={text.hex} value={result.hex} copyLabel={text.copy} />
                  <DetailRow label={text.binary} value={result.binary} copyLabel={text.copy} />
                </>
              ) : (
                <>
                  <DetailRow label={text.compressed} value={result.compressed} copyLabel={text.copy} />
                  <DetailRow label={text.expanded} value={result.expanded} copyLabel={text.copy} />
                  <DetailRow label={text.mapped} value={result.mappedIPv4} copyLabel={text.copy} />
                  <DetailRow label={text.zone} value={result.zone} copyLabel={text.copy} />
                </>
              )}
              <DetailRow label={text.reverse} value={result.reverse} copyLabel={text.copy} />
            </>
          ) : (
            <p className="py-8 text-center text-xs text-tertiary">{text.empty}</p>
          )}
        </section>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<IpInspectorTool />, { name: "IP Inspector" });
