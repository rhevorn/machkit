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
import { ipInCIDR, parseCIDR } from "./cidr.js";
import { messages } from "./messages.js";

const EXAMPLES = ["192.168.1.10/24", "10.0.0.0/8", "172.16.0.0/12", "127.0.0.1"];

function Detail({ label, value }) {
  return (
    <div className="flex min-w-0 items-baseline justify-between gap-3 border-b border-border px-3 py-2 last:border-b-0">
      <span className="shrink-0 text-[12px] text-secondary">{label}</span>
      <span className="min-w-0 truncate font-mono text-[12px] text-foreground">{value}</span>
    </div>
  );
}

function IpCidrTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("192.168.1.10/24");
  const [checkIP, setCheckIP] = useState("192.168.1.20");

  const result = useMemo(() => parseCIDR(input), [input]);
  const membership = useMemo(() => {
    if (!checkIP.trim() || !result.ok) return null;
    return ipInCIDR(checkIP, result.cidr);
  }, [checkIP, result]);

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "invalid-prefix" ? text.invalidPrefix : text.invalidIP,
        }
      : { tone: "info", label: result.cidr };

  const summary = result.ok
    ? [
        ["address", result.address],
        ["cidr", result.cidr],
        ["network", result.network],
        ["broadcast", result.broadcast],
        ["netmask", result.netmask],
        ["wildcard", result.wildcard],
        ["firstHost", result.firstHost],
        ["lastHost", result.lastHost],
        ["hostCount", String(result.hostCount)],
      ]
    : [];

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="cidr-input" className="machkit-control-label whitespace-nowrap">{text.input}</label>
            <Input
              id="cidr-input"
              className="min-w-0 flex-1 font-mono"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>
          <Button variant="ghost" size="sm" onClick={() => { setInput(""); setCheckIP(""); }}>
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

        <div className="grid gap-3 lg:grid-cols-2">
          <div className="machkit-panel">
            {summary.length ? summary.map(([key, value]) => (
              <Detail key={key} label={text[key]} value={value} />
            )) : (
              <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-2">
              <label htmlFor="cidr-check" className="machkit-control-label whitespace-nowrap">{text.checkIP}</label>
              <Input
                id="cidr-check"
                className="min-w-0 flex-1 font-mono"
                value={checkIP}
                onChange={(event) => setCheckIP(event.target.value)}
                placeholder={text.checkPlaceholder}
                spellCheck={false}
              />
              {result.ok ? (
                <Button variant="ghost" size="sm" onClick={() => machkit.copy(result.cidr)}>
                  <CopySimple size={15} />
                  {text.copy}
                </Button>
              ) : null}
            </div>
            <InlineMessage tone={membership?.ok ? (membership.inside ? "info" : "neutral") : "neutral"}>
              {!checkIP.trim() || !result.ok
                ? text.membership
                : !membership?.ok
                  ? text.invalidIP
                  : membership.inside
                    ? text.inside
                    : text.outside}
            </InlineMessage>
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<IpCidrTool />, { name: "IP / CIDR Calculator" });
