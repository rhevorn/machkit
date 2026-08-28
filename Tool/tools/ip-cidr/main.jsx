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
import { ipInCIDR, parseCIDR } from "./cidr.js";
import { messages } from "./messages.js";

const EXAMPLES = ["192.168.1.10", "2001:db8::1", "192.168.1.10/24", "10.0.0.0/8"];

function Detail({ label, value, copyLabel }) {
  if (value === undefined || value === null || value === "") return null;
  const display = String(value);
  return (
    <div className="flex min-w-0 items-center gap-2 border-b border-border/70 py-2 last:border-b-0">
      <span className="w-[7.5rem] shrink-0 text-[12px] text-secondary">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono text-[12px] tabular-nums text-foreground select-text">
        {display}
      </code>
      <Button
        variant="ghost"
        size="sm"
        className="h-7 shrink-0 px-2 text-secondary"
        aria-label={`${copyLabel}: ${label}`}
        title={`${copyLabel}: ${label}`}
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

function IpCidrTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("192.168.1.10");
  const [checkIP, setCheckIP] = useState("192.168.1.20");
  const isCIDR = input.includes("/");

  const cidrResult = useMemo(() => (isCIDR ? parseCIDR(input) : null), [input, isCIDR]);
  const ipResult = useMemo(() => (!isCIDR ? inspectIP(input) : null), [input, isCIDR]);
  const membership = useMemo(() => {
    if (!checkIP.trim() || !cidrResult?.ok) return null;
    return ipInCIDR(checkIP, cidrResult.cidr);
  }, [checkIP, cidrResult]);

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : isCIDR && !cidrResult?.ok
      ? {
          tone: "danger",
          label: cidrResult?.error === "invalid-prefix" ? text.invalidPrefix : text.invalidIP,
        }
      : !isCIDR && !ipResult?.ok
        ? { tone: "danger", label: text.invalid }
        : isCIDR
          ? { tone: "info", label: cidrResult.cidr }
          : { tone: "info", label: `IPv${ipResult.version} · ${kindLabel(text, ipResult.kind)}` };

  const summary = isCIDR && cidrResult?.ok
    ? [
        ["address", cidrResult.address],
        ["cidr", cidrResult.cidr],
        ["network", cidrResult.network],
        ["broadcast", cidrResult.broadcast],
        ["netmask", cidrResult.netmask],
        ["wildcard", cidrResult.wildcard],
        ["firstHost", cidrResult.firstHost],
        ["lastHost", cidrResult.lastHost],
        ["hostCount", String(cidrResult.hostCount)],
      ]
    : ipResult?.ok
      ? [
          ["version", `IPv${ipResult.version}`],
          ["address", ipResult.address],
          ["kind", kindLabel(text, ipResult.kind)],
          ...(ipResult.version === 4
            ? [
                ["className", ipResult.class],
                ["integer", ipResult.integer],
                ["hex", ipResult.hex],
                ["binary", ipResult.binary],
              ]
            : [
                ["compressed", ipResult.compressed],
                ["expanded", ipResult.expanded],
                ["mapped", ipResult.mappedIPv4],
                ["zone", ipResult.zone],
              ]),
          ["reverse", ipResult.reverse],
        ]
      : [];

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="cidr-input" className="machkit-control-label whitespace-nowrap">
              {text.input}
            </label>
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
            <Button
              key={example}
              variant="ghost"
              size="sm"
              className="h-6 px-1.5 font-mono text-[11px] text-secondary"
              onClick={() => setInput(example)}
            >
              {example}
            </Button>
          ))}
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className={isCIDR ? "grid gap-3 lg:grid-cols-2" : "grid gap-3"}>
          <section className="machkit-panel px-4">
            {summary.length ? (
              summary.map(([key, value]) => (
                <Detail key={key} label={text[key]} value={value} copyLabel={text.copy} />
              ))
            ) : (
              <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
            )}
          </section>

          {isCIDR ? (
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-2">
                <label htmlFor="cidr-check" className="machkit-control-label whitespace-nowrap">
                  {text.checkIP}
                </label>
                <Input
                  id="cidr-check"
                  className="min-w-0 flex-1 font-mono"
                  value={checkIP}
                  onChange={(event) => setCheckIP(event.target.value)}
                  placeholder={text.checkPlaceholder}
                  spellCheck={false}
                />
              </div>
              <InlineMessage
                tone={membership?.ok ? (membership.inside ? "info" : "neutral") : "neutral"}
              >
                {!checkIP.trim() || !cidrResult?.ok
                  ? text.membership
                  : !membership?.ok
                    ? text.invalidIP
                    : membership.inside
                      ? text.inside
                      : text.outside}
              </InlineMessage>
            </div>
          ) : null}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<IpCidrTool />, { name: "IP / CIDR" });
