import React, { useEffect, useMemo, useState } from "react";
import { ArrowsLeftRight, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  SegmentedControl,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { convertFormat } from "./format.js";
import { messages } from "./messages.js";

function placeholderFor(format, text) {
  if (format === "yaml") return text.placeholderYaml;
  if (format === "toml") return text.placeholderToml;
  return text.placeholderJson;
}

function DataFormatTool() {
  const text = useToolMessages(messages);
  const [fromFormat, setFromFormat] = useState("yaml");
  const [toFormat, setToFormat] = useState("json");
  const [input, setInput] = useState("name: machkit\nversion: 2\nfeatures:\n  - hosts\n  - cleanup\n");
  const [output, setOutput] = useState("");

  const formatOptions = useMemo(
    () => [
      { value: "json", label: "JSON" },
      { value: "yaml", label: "YAML" },
      { value: "toml", label: "TOML" },
    ],
    [],
  );

  const result = useMemo(
    () => convertFormat(input, fromFormat, toFormat),
    [input, fromFormat, toFormat],
  );

  useEffect(() => {
    setOutput(result.ok ? result.text : "");
  }, [result]);

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "input-too-large"
            ? text.tooLarge
            : result.error === "toml-root-object"
              ? text.tomlRoot
              : result.error === "unsupported"
                ? text.unsupported
                : result.error,
        }
      : { tone: "info", label: `${fromFormat.toUpperCase()} → ${toFormat.toUpperCase()}` };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar flex-wrap gap-x-3 gap-y-2">
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.from}</span>
            <SegmentedControl
              value={fromFormat}
              onChange={setFromFormat}
              label={text.from}
              size="compact"
              className="w-[210px] flex-none"
              options={formatOptions}
            />
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setFromFormat(toFormat);
              setToFormat(fromFormat);
              setInput(output || input);
            }}
          >
            <ArrowsLeftRight size={15} />
            {text.swap}
          </Button>
          <div className="flex items-center gap-2">
            <span className="machkit-control-label">{text.to}</span>
            <SegmentedControl
              value={toFormat}
              onChange={setToFormat}
              label={text.to}
              size="compact"
              className="w-[210px] flex-none"
              options={formatOptions}
            />
          </div>
          <div className="ml-auto flex items-center gap-1">
            <Button variant="ghost" size="sm" disabled={!output} onClick={() => machkit.copy(output)}>
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setInput("");
                setOutput("");
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-3 lg:grid-cols-2">
          <label className="flex min-w-0 flex-col gap-1.5">
            <span className="machkit-control-label">{text.input}</span>
            <Textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={placeholderFor(fromFormat, text)}
              className="h-[280px] min-h-[280px] w-full resize-y font-mono text-[12px]"
              spellCheck={false}
            />
          </label>
          <label className="flex min-w-0 flex-col gap-1.5">
            <span className="machkit-control-label">{text.output}</span>
            <Textarea
              readOnly
              value={output}
              placeholder={text.empty}
              className="h-[280px] min-h-[280px] w-full resize-y font-mono text-[12px] bg-field"
            />
          </label>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<DataFormatTool />, { name: "Data Format" });
