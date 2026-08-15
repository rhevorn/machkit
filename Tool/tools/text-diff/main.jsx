import React, { useMemo, useState } from "react";
import { ArrowsLeftRight, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  CheckboxField,
  InlineMessage,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { diffLines } from "./diff.js";
import { messages } from "./messages.js";

function rowClass(type, side) {
  if (type === "equal") return "diff-row-equal";
  if (type === "delete" && side === "left") return "diff-row-delete";
  if (type === "insert" && side === "right") return "diff-row-insert";
  if (type === "delete" && side === "right") return "diff-row-blank";
  if (type === "insert" && side === "left") return "diff-row-blank";
  return "diff-row-equal";
}

function TextDiff() {
  const text = useToolMessages(messages);
  const [left, setLeft] = useState('{\n  "name": "machkit",\n  "version": 1\n}\n');
  const [right, setRight] = useState('{\n  "name": "machkit",\n  "version": 2,\n  "stable": true\n}\n');
  const [ignoreWhitespace, setIgnoreWhitespace] = useState(false);

  const result = useMemo(
    () => diffLines(left, right, { ignoreWhitespace }),
    [left, right, ignoreWhitespace],
  );

  const status = !left && !right
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "too-many-lines" ? text.tooManyLines : text.tooLarge,
        }
      : result.stats.added === 0 && result.stats.removed === 0
        ? { tone: "info", label: text.identical }
        : {
            tone: "info",
            label: `${text.stats}: +${result.stats.added} ${text.added} · −${result.stats.removed} ${text.removed} · ${result.stats.equal} ${text.equal}`,
          };

  const unifiedPatch = useMemo(() => {
    if (!result.ok) return "";
    return result.rows
      .map((row) => {
        if (row.type === "equal") return `  ${row.leftText}`;
        if (row.type === "delete") return `- ${row.leftText}`;
        return `+ ${row.rightText}`;
      })
      .join("\n");
  }, [result]);

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-4 pb-5">
        <div className="machkit-toolbar flex-wrap gap-x-4 gap-y-2">
          <CheckboxField
            checked={ignoreWhitespace}
            onCheckedChange={(checked) => setIgnoreWhitespace(checked === true)}
            label={text.ignoreWhitespace}
          />
          <div className="ml-auto flex items-center gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setLeft(right);
                setRight(left);
              }}
            >
              <ArrowsLeftRight size={15} />
              {text.swap}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              disabled={!unifiedPatch}
              onClick={() => machkit.copy(unifiedPatch)}
            >
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setLeft("");
                setRight("");
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
          <label className="flex min-w-0 flex-col gap-2">
            <span className="machkit-control-label">{text.left}</span>
            <Textarea
              value={left}
              onChange={(event) => setLeft(event.target.value)}
              className="h-[160px] min-h-[160px] w-full resize-y font-mono text-[12px]"
              spellCheck={false}
            />
          </label>
          <label className="flex min-w-0 flex-col gap-2">
            <span className="machkit-control-label">{text.right}</span>
            <Textarea
              value={right}
              onChange={(event) => setRight(event.target.value)}
              className="h-[160px] min-h-[160px] w-full resize-y font-mono text-[12px]"
              spellCheck={false}
            />
          </label>
        </div>

        <div className="flex flex-col gap-2">
          <span className="machkit-control-label">{text.diff}</span>
          <div className="machkit-panel overflow-hidden">
            {result.ok && result.rows.length ? (
              <div className="grid max-h-[320px] grid-cols-2 overflow-auto font-mono text-[12px] leading-5">
                <div className="min-w-0 border-r border-border">
                  {result.rows.map((row, index) => (
                    <div key={`l-${index}`} className={`flex ${rowClass(row.type, "left")}`}>
                      <span className="w-10 shrink-0 select-none px-2 py-0.5 text-right text-tertiary">
                        {row.leftLine ?? ""}
                      </span>
                      <pre className="min-w-0 flex-1 overflow-x-auto px-2 py-0.5 whitespace-pre-wrap break-all">
                        {row.leftText}
                      </pre>
                    </div>
                  ))}
                </div>
                <div className="min-w-0">
                  {result.rows.map((row, index) => (
                    <div key={`r-${index}`} className={`flex ${rowClass(row.type, "right")}`}>
                      <span className="w-10 shrink-0 select-none px-2 py-0.5 text-right text-tertiary">
                        {row.rightLine ?? ""}
                      </span>
                      <pre className="min-w-0 flex-1 overflow-x-auto px-2 py-0.5 whitespace-pre-wrap break-all">
                        {row.rightText}
                      </pre>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
            )}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<TextDiff />, { name: "Text Diff" });
