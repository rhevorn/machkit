import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ExampleChips,
  Input,
  ResultPanel,
  SplitWorkspace,
  StatusStrip,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ToolToolbar,
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
        <ToolToolbar className="gap-2">
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
          <ActionGroup>
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
          </ActionGroup>
        </ToolToolbar>

        <ExampleChips
          label={text.presets}
          options={cronPresets.map((preset) => ({
            id: preset.id,
            value: preset.expression,
            label: text[PRESET_LABELS[preset.id]] || preset.id,
          }))}
          onSelect={setExpression}
        />

        <StatusStrip tone={status.tone}>{status.label}</StatusStrip>

        <SplitWorkspace>
          <div className="flex flex-col gap-1.5">
            <span className="machkit-control-label">{text.fields}</span>
            <ResultPanel>
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
            </ResultPanel>
          </div>

          <div className="flex flex-col gap-1.5">
            <span className="machkit-control-label">{text.nextRuns}</span>
            <ResultPanel className="max-h-[260px] overflow-auto">
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
            </ResultPanel>
          </div>
        </SplitWorkspace>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CronTool />, { name: "Cron Expression" });
