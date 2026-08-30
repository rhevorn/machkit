import { useMemo, useState } from "react";
import { EraserIcon } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  PropertyList,
  PropertyRow,
  ResultPanel,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import type { InlineMessageTone } from "@/ui/inline-message.js";
import { useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { inspectIP } from "./ip.js";
import { ipInCIDR, parseCIDR } from "./cidr.js";
import { messages } from "./messages.js";

const EXAMPLES = ["192.168.1.10", "2001:db8::1", "192.168.1.10/24", "10.0.0.0/8"];

type ToolText = (typeof messages)["en"];

function kindLabel(text: ToolText, kind: string | undefined): string {
  const key = `kind_${String(kind || "").replace(/-/g, "_")}` as keyof ToolText;
  const label = text[key];
  return typeof label === "string" ? label : String(kind || "");
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

  const status: { tone: InlineMessageTone; label: string } = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : isCIDR && !cidrResult?.ok
      ? {
          tone: "danger",
          label: cidrResult?.error === "invalid-prefix" ? text.invalidPrefix : text.invalidIP,
        }
      : !isCIDR && !ipResult?.ok
        ? { tone: "danger", label: text.invalid }
        : isCIDR && cidrResult?.ok
          ? { tone: "info", label: cidrResult.cidr }
          : ipResult?.ok
            ? { tone: "info", label: `IPv${ipResult.version} · ${kindLabel(text, ipResult.kind)}` }
            : { tone: "neutral", label: text.empty };

  const summary: Array<[keyof ToolText, string | undefined]> = isCIDR && cidrResult?.ok
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
            ? ([
                ["className", ipResult.class],
                ["integer", ipResult.integer],
                ["hex", ipResult.hex],
                ["binary", ipResult.binary],
              ] as Array<[keyof ToolText, string | undefined]>)
            : ([
                ["compressed", ipResult.compressed],
                ["expanded", ipResult.expanded],
                ["mapped", ipResult.mappedIPv4],
                ["zone", ipResult.zone],
              ] as Array<[keyof ToolText, string | undefined]>)),
          ["reverse", ipResult.reverse],
        ]
      : [];

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="gap-2">
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
          <ActionGroup>
            <Button variant="ghost" size="sm" onClick={() => { setInput(""); setCheckIP(""); }}>
              <EraserIcon size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

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

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        <div className={isCIDR ? "grid gap-3 lg:grid-cols-2" : "grid gap-3"}>
          <ResultPanel bodyClassName="px-4">
            {summary.length ? (
              <PropertyList>
                {summary.map(([key, value]) => (
                  <PropertyRow
                    key={String(key)}
                    label={String(text[key] ?? key)}
                    value={value}
                    copyLabel={text.copy}
                    hideEmpty
                    labelClassName="w-[7.5rem]"
                    className="items-center border-border/70 px-0"
                  />
                ))}
              </PropertyList>
            ) : (
              <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
            )}
          </ResultPanel>

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
              <StatusStrip
                tone={membership?.ok ? (membership.inside ? "info" : "neutral") : "neutral"}
              >
                {!checkIP.trim() || !cidrResult?.ok
                  ? text.membership
                  : !membership?.ok
                    ? text.invalidIP
                    : membership.inside
                      ? text.inside
                      : text.outside}
              </StatusStrip>
            </div>
          ) : null}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<IpCidrTool />, { name: "IP / CIDR" });
