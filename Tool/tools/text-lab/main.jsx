import React, { useMemo, useState } from "react";
import { ArrowLeft, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { textActionGroups, textStats, transformText } from "./text.js";
import { messages } from "./messages.js";

function formatStats(text, stats) {
  if (!stats) return "";
  return `${stats.chars} ${text.chars} · ${stats.lines} ${text.lines} · ${stats.nonEmpty} ${text.nonEmpty} · ${stats.words} ${text.words}`;
}

function actionLabel(text, action) {
  if (action === "title") return text.titleCase;
  return text[action] || action;
}

function TextLabTool() {
  const text = useToolMessages(messages);
  const [input, setInput] = useState("");
  const [output, setOutput] = useState("");
  const [error, setError] = useState(null);

  const inputStats = useMemo(() => textStats(input), [input]);
  const outputStats = useMemo(() => textStats(output), [output]);
  const hasInput = Boolean(input);
  const hasOutput = Boolean(output);

  const status = error
    ? {
        tone: "danger",
        label: error === "too-large" ? text.tooLarge : error === "too-many-lines" ? text.tooManyLines : error,
      }
    : input.trim()
      ? { tone: "info", label: formatStats(text, inputStats) }
      : null;

  function applyAction(action) {
    const result = transformText(input, action);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setError(null);
    setOutput(result.text);
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <span className="machkit-control-label shrink-0">{text.title}</span>
          <div className="mx-1 h-5 w-px shrink-0 bg-border" aria-hidden="true" />
          <Button
            variant="ghost"
            size="sm"
            disabled={!hasInput && !hasOutput}
            onClick={() => machkit.copy(hasOutput ? output : input)}
          >
            <CopySimple size={15} />
            {text.copy}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            disabled={!hasOutput}
            onClick={() => {
              setInput(output);
              setError(null);
            }}
          >
            <ArrowLeft size={15} />
            {text.replaceInput}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            disabled={!hasInput && !hasOutput}
            onClick={() => {
              setInput("");
              setOutput("");
              setError(null);
            }}
          >
            <Eraser size={15} />
            {text.clear}
          </Button>
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        {status ? <InlineMessage tone={status.tone}>{status.label}</InlineMessage> : null}

        <div className="machkit-panel grid gap-3 px-3 py-3 sm:grid-cols-2 lg:grid-cols-4">
          {textActionGroups.map((group) => (
            <div key={group.id} className="flex min-w-0 flex-col gap-2">
              <span className="text-[11px] text-secondary">{text[`group_${group.id}`]}</span>
              <div className="flex flex-wrap gap-1.5">
                {group.actions.map((action) => (
                  <Button
                    key={action}
                    variant="secondary"
                    size="sm"
                    disabled={!input.trim()}
                    onClick={() => applyAction(action)}
                  >
                    {actionLabel(text, action)}
                  </Button>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="grid min-h-0 flex-1 gap-3 lg:grid-cols-2">
          <div className="flex min-w-0 flex-col gap-1.5">
            <div className="flex items-center justify-between gap-2">
              <span className="machkit-control-label">{text.input}</span>
              {hasInput ? (
                <Button variant="ghost" size="sm" onClick={() => machkit.copy(input)}>
                  <CopySimple size={15} />
                  {text.copy}
                </Button>
              ) : null}
            </div>
            <Textarea
              className="min-h-[220px] flex-1 font-mono text-[12px]"
              value={input}
              onChange={(event) => {
                setInput(event.target.value);
                setError(null);
              }}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>

          <div className="flex min-w-0 flex-col gap-1.5">
            <div className="flex items-center justify-between gap-2">
              <span className="machkit-control-label">{text.output}</span>
              {hasOutput ? (
                <Button variant="ghost" size="sm" onClick={() => machkit.copy(output)}>
                  <CopySimple size={15} />
                  {text.copy}
                </Button>
              ) : null}
            </div>
            <Textarea
              className="min-h-[220px] flex-1 font-mono text-[12px]"
              value={output}
              readOnly
              placeholder={text.output}
              spellCheck={false}
            />
            {hasOutput ? (
              <p className="text-[11px] text-tertiary">{formatStats(text, outputStats)}</p>
            ) : null}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<TextLabTool />, { name: "Text Lab" });
