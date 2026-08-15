import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, Eraser, Plus, Trash } from "@phosphor-icons/react";
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
import { buildURL, parseURL } from "./url.js";
import { messages } from "./messages.js";

const FIELD_KEYS = ["protocol", "username", "password", "hostname", "port", "pathname", "hash"];

function UrlLabTool() {
  const text = useToolMessages(messages);
  const [raw, setRaw] = useState("https://example.com/path?lang=zh&ref=docs#install");
  const [parts, setParts] = useState(() => parseURL("https://example.com/path?lang=zh&ref=docs#install").parts);
  const [query, setQuery] = useState(() => parseURL("https://example.com/path?lang=zh&ref=docs#install").query);

  useEffect(() => {
    const parsed = parseURL(raw);
    if (!parsed.ok) return;
    setParts(parsed.parts);
    setQuery(parsed.query.length ? parsed.query : [{ key: "", value: "" }]);
  }, [raw]);

  const built = useMemo(() => buildURL(parts, query), [parts, query]);

  const status = !raw.trim()
    ? { tone: "neutral", label: text.empty }
    : !parseURL(raw).ok && !built.ok
      ? {
          tone: "danger",
          label:
            built.error === "missing-host"
              ? text.missingHost
              : parseURL(raw).error === "too-large"
                ? text.tooLarge
                : text.invalid,
        }
      : built.ok
        ? { tone: "info", label: built.href }
        : {
            tone: "danger",
            label: built.error === "missing-host" ? text.missingHost : text.invalid,
          };

  function updatePart(key, value) {
    setParts((prev) => ({ ...prev, [key]: value }));
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="url-raw" className="machkit-control-label whitespace-nowrap">{text.input}</label>
            <Input
              id="url-raw"
              className="min-w-0 flex-1 font-mono"
              value={raw}
              onChange={(event) => setRaw(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>
          <Button
            variant="ghost"
            size="sm"
            disabled={!built.ok}
            onClick={() => machkit.copy(built.href)}
          >
            <CopySimple size={15} />
            {text.copy}
          </Button>
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
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-2 sm:grid-cols-2">
          {FIELD_KEYS.map((key) => (
            <div key={key} className="flex items-center gap-2">
              <label className="machkit-control-label w-20 shrink-0">{text[key]}</label>
              <Input
                className="min-w-0 flex-1 font-mono"
                value={parts[key] || ""}
                onChange={(event) => updatePart(key, event.target.value)}
                spellCheck={false}
              />
            </div>
          ))}
        </div>

        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="machkit-control-label">{text.query}</span>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setQuery((prev) => [...prev, { key: "", value: "" }])}
            >
              <Plus size={15} />
              {text.addRow}
            </Button>
          </div>
          <div className="machkit-panel">
            {query.map((row, index) => (
              <div key={index} className="flex items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
                <Input
                  className="min-w-0 flex-1 font-mono"
                  value={row.key}
                  placeholder={text.key}
                  onChange={(event) => {
                    const value = event.target.value;
                    setQuery((prev) => prev.map((item, i) => (i === index ? { ...item, key: value } : item)));
                  }}
                  spellCheck={false}
                />
                <Input
                  className="min-w-0 flex-1 font-mono"
                  value={row.value}
                  placeholder={text.value}
                  onChange={(event) => {
                    const value = event.target.value;
                    setQuery((prev) => prev.map((item, i) => (i === index ? { ...item, value } : item)));
                  }}
                  spellCheck={false}
                />
                <Button
                  variant="ghost"
                  size="sm"
                  className="shrink-0"
                  onClick={() => setQuery((prev) => prev.filter((_, i) => i !== index))}
                >
                  <Trash size={15} />
                </Button>
              </div>
            ))}
          </div>
        </div>

        {built.ok ? (
          <div className="machkit-panel px-3 py-2">
            <div className="text-[11px] text-secondary">{text.result}</div>
            <code className="mt-1 block break-all font-mono text-[12px]">{built.href}</code>
          </div>
        ) : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<UrlLabTool />, { name: "URL Lab" });
