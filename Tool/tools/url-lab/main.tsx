import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, Eraser, Plus, Trash } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  StatusStrip,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { buildURL, parseURL } from "./url.js";
import { messages } from "./messages.js";

const SAMPLE = "https://example.com/path?lang=zh&ref=docs#install";

function Seg({ children, className }: Record<string, any>) {
  return (
    <span
      className={cn("shrink-0 select-none font-mono text-[13px] text-tertiary", className)}
      aria-hidden="true"
    >
      {children}
    </span>
  );
}

function AtomInput({ className, ...props }: Record<string, any>) {
  return (
    <Input
      spellCheck={false}
      className={cn(
        "h-8 min-w-0 border-transparent bg-transparent px-1.5 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-2 focus:ring-accent/25",
        className,
      )}
      {...props}
    />
  );
}

function UrlLabTool() {
  const text = useToolMessages(messages);
  const [raw, setRaw] = useState(SAMPLE);
  const [parts, setParts] = useState(() => parseURL(SAMPLE).parts);
  const [query, setQuery] = useState(() => parseURL(SAMPLE).query);

  useEffect(() => {
    const parsed = parseURL(raw);
    if (!parsed.ok) return;
    setParts(parsed.parts);
    setQuery(parsed.query.length ? parsed.query : [{ key: "", value: "" }]);
  }, [raw]);

  const built = useMemo(() => buildURL(parts, query), [parts, query]);
  const parsedRaw = useMemo(() => parseURL(raw), [raw]);

  const error =
    !raw.trim() && !parts.hostname
      ? null
      : !built.ok
        ? built.error === "missing-host"
          ? text.missingHost
          : parsedRaw.error === "too-large"
            ? text.tooLarge
            : text.invalid
        : null;

  function updatePart(key: any, value: any) {
    setParts((prev) => ({ ...prev, [key]: value }));
  }

  function updateQuery(index: any, patch: any) {
    setQuery((prev) => prev.map((item: any, i: any) => (i === index ? { ...item, ...patch } : item)));
  }

  const pathDisplay = (parts.pathname || "").replace(/^\//, "");

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-4 pt-4 pb-6">
        <ToolToolbar className="gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="url-raw" className="machkit-control-label whitespace-nowrap">
              {text.input}
            </label>
            <Input
              id="url-raw"
              className="min-w-0 flex-1 font-mono"
              value={raw}
              onChange={(event: any) => setRaw(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
              invalid={Boolean(error) && Boolean(raw.trim())}
            />
          </div>
          <ActionGroup>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setRaw("");
                setParts(parseURL("").parts);
                setQuery([{ key: "", value: "" }]);
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        {error ? <StatusStrip tone="danger">{error}</StatusStrip> : null}

        <div className="flex flex-col gap-2">
          <span className="machkit-sidebar-label">{text.result}</span>
          <div
            className={cn(
              "flex items-start gap-2 rounded-panel border px-3.5 py-3",
              error
                ? "border-danger/35 bg-danger/5"
                : "border-border bg-accent-soft/70",
            )}
          >
            <code
              className={cn(
                "min-w-0 flex-1 break-all font-mono text-[13px] leading-relaxed select-text",
                built.ok ? "text-foreground" : "text-tertiary",
              )}
            >
              {built.ok ? built.href : text.result}
            </code>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 shrink-0 px-2 text-secondary"
              disabled={!built.ok}
              aria-label={text.copy}
              title={text.copy}
              onClick={() => machkit.copy(built.href)}
            >
              <CopySimple size={15} />
              <span className="max-[520px]:hidden">{text.copy}</span>
            </Button>
          </div>
        </div>

        <div className="rounded-panel border border-border bg-surface px-3 py-2">
            <div className="flex flex-wrap items-center gap-x-0.5 gap-y-1">
              <AtomInput
                aria-label={text.protocol}
                title={text.protocol}
                className="w-[4.75rem]"
                value={parts.protocol || ""}
                onChange={(event: any) => updatePart("protocol", event.target.value)}
              />
              <Seg>://</Seg>
              <AtomInput
                aria-label={text.hostname}
                title={text.hostname}
                className="min-w-[10rem] flex-1"
                value={parts.hostname || ""}
                onChange={(event: any) => updatePart("hostname", event.target.value)}
                placeholder="example.com"
              />
              <Seg>:</Seg>
              <AtomInput
                aria-label={text.port}
                title={text.port}
                className="w-[4.5rem]"
                value={parts.port || ""}
                onChange={(event: any) => updatePart("port", event.target.value)}
                placeholder="443"
              />
            </div>

            <div className="mt-1 flex flex-wrap items-center gap-x-0.5 gap-y-1 border-t border-border/50 pt-1">
              <AtomInput
                aria-label={text.username}
                title={text.username}
                className="min-w-[6.5rem] flex-1"
                value={parts.username || ""}
                onChange={(event: any) => updatePart("username", event.target.value)}
                placeholder={text.username}
              />
              <Seg>:</Seg>
              <AtomInput
                aria-label={text.password}
                title={text.password}
                className="min-w-[6.5rem] flex-1"
                value={parts.password || ""}
                onChange={(event: any) => updatePart("password", event.target.value)}
                placeholder={text.password}
              />
              <Seg>@</Seg>
            </div>

            <div className="mt-1 flex flex-wrap items-center gap-x-0.5 gap-y-1 border-t border-border/50 pt-1">
              <Seg>/</Seg>
              <AtomInput
                aria-label={text.pathname}
                title={text.pathname}
                className="min-w-[8rem] flex-1"
                value={pathDisplay}
                onChange={(event: any) => {
                  const next = event.target.value;
                  updatePart("pathname", next ? (next.startsWith("/") ? next : `/${next}`) : "");
                }}
                placeholder="path"
              />
              <Seg>#</Seg>
              <AtomInput
                aria-label={text.hash}
                title={text.hash}
                className="min-w-[6rem] flex-[0.75]"
                value={parts.hash || ""}
                onChange={(event: any) => updatePart("hash", event.target.value.replace(/^#/, ""))}
                placeholder="hash"
              />
            </div>
        </div>

        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between gap-2">
            <span className="machkit-sidebar-label">{text.query}</span>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 px-2"
              onClick={() => setQuery((prev) => [...prev, { key: "", value: "" }])}
            >
              <Plus size={14} />
              {text.addRow}
            </Button>
          </div>
          <div className="flex flex-col gap-1.5">
            {query.map((row: any, index: any) => (
              <div
                key={index}
                className="flex items-center gap-1 rounded-control bg-surface px-1.5 py-0.5 ring-1 ring-border/65"
              >
                <Input
                  className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-2 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-2 focus:ring-accent/25"
                  value={row.key}
                  placeholder={text.key}
                  onChange={(event: any) => updateQuery(index, { key: event.target.value })}
                  spellCheck={false}
                />
                <Seg>=</Seg>
                <Input
                  className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-2 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-2 focus:ring-accent/25"
                  value={row.value}
                  placeholder={text.value}
                  onChange={(event: any) => updateQuery(index, { value: event.target.value })}
                  spellCheck={false}
                />
                <Button
                  variant="ghost"
                  size="sm"
                  className="size-8 shrink-0 px-0 text-secondary"
                  aria-label={text.removeRow}
                  title={text.removeRow}
                  onClick={() => setQuery((prev) => prev.filter((_: any, i: any) => i !== index))}
                >
                  <Trash size={14} />
                </Button>
              </div>
            ))}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<UrlLabTool />, { name: "URL Lab" });
