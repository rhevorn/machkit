import React, { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { CopySimpleIcon, EraserIcon, PlusIcon, TrashIcon } from "@phosphor-icons/react";
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
import { buildURL, parseURL, type QueryItem, type URLParts } from "./url.js";
import { messages } from "./messages.js";

const SAMPLE = "https://example.com/path?lang=zh&ref=docs#install";

function Seg({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <span
      className={cn("shrink-0 select-none font-mono text-[13px] text-tertiary", className)}
      aria-hidden="true"
    >
      {children}
    </span>
  );
}

function AtomInput({ className, ...props }: React.ComponentPropsWithoutRef<typeof Input>) {
  return (
    <Input
      spellCheck={false}
      className={cn(
        "h-8 min-w-0 border-transparent bg-transparent px-1.5 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-3 focus:ring-accent/25",
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
  /** Which side last drove the two-way sync. */
  const editSourceRef = useRef<"raw" | "parts">("raw");

  const parsedRaw = useMemo(() => parseURL(raw), [raw]);
  const built = useMemo(() => buildURL(parts, query), [parts, query]);

  // Raw → parts when the raw URL parses successfully.
  useEffect(() => {
    if (editSourceRef.current !== "raw") return;
    if (!parsedRaw.ok) return;
    setParts(parsedRaw.parts);
    setQuery(parsedRaw.query.length ? parsedRaw.query : [{ key: "", value: "" }]);
  }, [parsedRaw, raw]);

  // Parts → raw when structured edits build a valid URL.
  useEffect(() => {
    if (editSourceRef.current !== "parts") return;
    if (!built.ok) return;
    if (built.href !== raw) setRaw(built.href);
  }, [built, raw]);

  const rawParseFailed = Boolean(raw.trim()) && !parsedRaw.ok;
  const error = (() => {
    if (!raw.trim() && !parts.hostname) return null;
    if (rawParseFailed) {
      return parsedRaw.error === "too-large" ? text.tooLarge : text.invalid;
    }
    if (!built.ok) {
      return built.error === "missing-host" ? text.missingHost : text.invalid;
    }
    return null;
  })();

  // Do not present a stale successful build while the raw field is invalid.
  const showBuiltSuccess = built.ok && !rawParseFailed;

  function setRawFromUser(value: string) {
    editSourceRef.current = "raw";
    setRaw(value);
  }

  function updatePart(key: keyof URLParts, value: string) {
    editSourceRef.current = "parts";
    setParts((prev) => ({ ...prev, [key]: value }));
  }

  function updateQuery(index: number, patch: Partial<QueryItem>) {
    editSourceRef.current = "parts";
    setQuery((prev) => prev.map((item, i) => (i === index ? { ...item, ...patch } : item)));
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
              onChange={(event: React.ChangeEvent<HTMLInputElement>) => setRawFromUser(event.target.value)}
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
                editSourceRef.current = "raw";
                setRaw("");
                setParts(parseURL("").parts);
                setQuery([{ key: "", value: "" }]);
              }}
            >
              <EraserIcon size={15} />
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
                : showBuiltSuccess
                  ? "border-border bg-accent-soft/70"
                  : "border-border bg-surface",
            )}
          >
            <code
              className={cn(
                "min-w-0 flex-1 break-all font-mono text-[13px] leading-relaxed select-text",
                showBuiltSuccess ? "text-foreground" : "text-tertiary",
              )}
            >
              {showBuiltSuccess ? built.href : text.result}
            </code>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 shrink-0 px-2 text-secondary"
              disabled={!showBuiltSuccess}
              aria-label={text.copy}
              title={text.copy}
              onClick={() => {
                if (showBuiltSuccess) machkit.copy(built.href);
              }}
            >
              <CopySimpleIcon size={15} />
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
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("protocol", event.target.value)}
              />
              <Seg>://</Seg>
              <AtomInput
                aria-label={text.hostname}
                title={text.hostname}
                className="min-w-[10rem] flex-1"
                value={parts.hostname || ""}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("hostname", event.target.value)}
                placeholder="example.com"
              />
              <Seg>:</Seg>
              <AtomInput
                aria-label={text.port}
                title={text.port}
                className="w-[4.5rem]"
                value={parts.port || ""}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("port", event.target.value)}
                placeholder="443"
              />
            </div>

            <div className="mt-1 flex flex-wrap items-center gap-x-0.5 gap-y-1 border-t border-border/50 pt-1">
              <AtomInput
                aria-label={text.username}
                title={text.username}
                className="min-w-[6.5rem] flex-1"
                value={parts.username || ""}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("username", event.target.value)}
                placeholder={text.username}
              />
              <Seg>:</Seg>
              <AtomInput
                aria-label={text.password}
                title={text.password}
                className="min-w-[6.5rem] flex-1"
                value={parts.password || ""}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("password", event.target.value)}
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
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
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
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePart("hash", event.target.value.replace(/^#/, ""))}
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
              onClick={() => {
                editSourceRef.current = "parts";
                setQuery((prev) => [...prev, { key: "", value: "" }]);
              }}
            >
              <PlusIcon size={14} />
              {text.addRow}
            </Button>
          </div>
          <div className="flex flex-col gap-1.5">
            {query.map((row, index) => (
              <div
                key={index}
                className="flex items-center gap-1 rounded-control bg-surface px-1.5 py-0.5 ring-1 ring-border/65"
              >
                <Input
                  className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-2 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-3 focus:ring-accent/25"
                  value={row.key}
                  placeholder={text.key}
                  onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateQuery(index, { key: event.target.value })}
                  spellCheck={false}
                />
                <Seg>=</Seg>
                <Input
                  className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-2 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-3 focus:ring-accent/25"
                  value={row.value}
                  placeholder={text.value}
                  onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateQuery(index, { value: event.target.value })}
                  spellCheck={false}
                />
                <Button
                  variant="ghost"
                  size="sm"
                  className="size-8 shrink-0 px-0 text-secondary"
                  aria-label={text.removeRow}
                  title={text.removeRow}
                  onClick={() => {
                    editSourceRef.current = "parts";
                    setQuery((prev) => prev.filter((_, i) => i !== index));
                  }}
                >
                  <TrashIcon size={14} />
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
