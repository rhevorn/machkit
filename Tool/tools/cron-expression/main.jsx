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
import { cronPresets, nextCronRuns } from "./cron.js";
import { messages } from "./messages.js";

const PRESET_LABELS = {
  everyMinute: "presetEveryMinute",
  hourly: "presetHourly",
  daily: "presetDaily",
  weekdays: "presetWeekdays",
  weekly: "presetWeekly",
  monthly: "presetMonthly",
};

const FIELD_KEYS = ["minute", "hour", "dayOfMonth", "month", "dayOfWeek"];

function formatRun(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function CronTool() {
  const text = useToolMessages(messages);
  const [expression, setExpression] = useState("0 9 * * 1-5");

  const result = useMemo(() => nextCronRuns(expression, { count: 8 }), [expression]);

  const status = !expression.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "field-count" ? text.fieldCount : text.invalid,
        }
      : { tone: "info", label: expression.trim() };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <div className="flex min-w-0 flex-1 items-center gap-2">
            <label htmlFor="cron-expression" className="machkit-control-label whitespace-nowrap">
              {text.expression}
            </label>
            <Input
              id="cron-expression"
              className="min-w-0 flex-1 font-mono"
              value={expression}
              onChange={(event) => setExpression(event.target.value)}
              placeholder={text.placeholder}
              spellCheck={false}
            />
          </div>
          <Button
            variant="ghost"
            size="sm"
            disabled={!expression.trim()}
            onClick={() => machkit.copy(expression.trim())}
          >
            <CopySimple size={15} />
            {text.copy}
          </Button>
          <Button variant="ghost" size="sm" onClick={() => setExpression("")}>
            <Eraser size={15} />
            {text.clear}
          </Button>
          <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
        </div>

        <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] text-tertiary">
          <span>{text.presets}</span>
          {cronPresets.map((preset) => (
            <button
              key={preset.id}
              type="button"
              className="text-secondary hover:text-accent"
              onClick={() => setExpression(preset.expression)}
            >
              {text[PRESET_LABELS[preset.id]] || preset.id}
            </button>
          ))}
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-3 lg:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <span className="machkit-control-label">{text.fields}</span>
            <div className="machkit-panel">
              {result.ok ? FIELD_KEYS.map((key) => (
                <div key={key} className="flex items-baseline justify-between gap-3 border-b border-border px-3 py-2 last:border-b-0">
                  <span className="text-[12px] text-secondary">{text[key]}</span>
                  <span className="min-w-0 truncate font-mono text-[12px]">
                    {result.fields[key].length > 12
                      ? `${result.fields[key].slice(0, 12).join(",")}…`
                      : result.fields[key].join(",")}
                  </span>
                </div>
              )) : (
                <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
              )}
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <span className="machkit-control-label">{text.nextRuns}</span>
            <div className="machkit-panel max-h-[260px] overflow-auto">
              {result.ok && result.runs.length ? (
                <ul className="divide-y divide-border">
                  {result.runs.map((run) => (
                    <li key={run.toISOString()} className="px-3 py-2 font-mono text-[12px]">
                      {formatRun(run)}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="px-3 py-8 text-center text-xs text-tertiary">
                  {result.ok ? text.noRuns : text.empty}
                </p>
              )}
            </div>
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CronTool />, { name: "Cron Expression" });
