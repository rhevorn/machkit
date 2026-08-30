import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ExampleChips,
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

function formatRun(date: any) {
  const pad = (value: any) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatFieldValues(values: any) {
  if (!values?.length) return "—";
  if (values.length > 14) return `${values.slice(0, 14).join(",")}…`;
  return values.join(",");
}

function CronTool() {
  const text = useToolMessages(messages) as any;
  const [expression, setExpression] = useState("0 9 * * 1-5");

  const result = useMemo(() => nextCronRuns(expression, { count: 100 }), [expression]);
  const tokens = result.ok ? result.expression!.split(" ") : [];

  const status = !expression.trim()
    ? null
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "field-count" ? text.fieldCount : text.invalid,
        }
      : null;

  return (
    <ToolPage title={text.title} adaptiveHeight={false}>
      <ToolContent className="flex h-full min-h-0 flex-1 flex-col gap-3 overflow-hidden pt-3 pb-4">
        <ToolToolbar className="min-h-[var(--machkit-size-control)] shrink-0 gap-2 border-b-0">
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
          </ActionGroup>
        </ToolToolbar>

        <ExampleChips
          className="shrink-0"
          label={text.presets}
          options={cronPresets.map((preset: any) => ({
            id: preset.id,
            value: preset.expression,
            label: (text as any)[(PRESET_LABELS as any)[preset.id]] || preset.id,
          }))}
          onSelect={setExpression}
        />

        {status ? <StatusStrip tone={status.tone as any as any}>{status.label}</StatusStrip> : null}

        {result.ok ? (
          <div className="grid min-h-0 flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)]">
            <section className="flex min-h-0 flex-col gap-2">
              <div className="machkit-sidebar-label shrink-0">{text.fields}</div>
              <div className="min-h-0 flex-1 overflow-auto">
                {FIELD_KEYS.map((key: any, index: any) => (
                  <div
                    key={key}
                    className={cn(
                      "flex items-start gap-3 border-b border-border/70 py-2.5 last:border-b-0",
                    )}
                  >
                    <span className="w-[4.5rem] shrink-0 pt-0.5 text-[12px] text-secondary">
                      {text[key]}
                    </span>
                    <span className="w-16 shrink-0 truncate font-mono text-[13px] font-semibold tracking-tight text-accent">
                      {tokens[index] ?? "—"}
                    </span>
                    <span className="min-w-0 flex-1 break-all font-mono text-[11px] leading-relaxed text-tertiary">
                      {formatFieldValues((result.fields as any)[key])}
                    </span>
                  </div>
                ))}
              </div>
            </section>

            <section className="flex min-h-0 flex-col gap-2 border-l border-border/70 pl-6 max-lg:border-l-0 max-lg:pl-0 max-lg:border-t max-lg:pt-4">
              <div className="machkit-sidebar-label shrink-0">{text.nextRuns}</div>
              {result.runs.length ? (
                <ol className="min-h-0 flex-1 space-y-0.5 overflow-auto">
                  {result.runs.map((run: any, index: any) => (
                    <li
                      key={run.toISOString()}
                      className="flex items-baseline gap-3 rounded-control px-1.5 py-1.5 font-mono text-[12.5px] tabular-nums hover:bg-muted/70"
                    >
                      <span className="w-5 shrink-0 text-right text-[11px] text-tertiary">
                        {index + 1}
                      </span>
                      <span className="text-foreground">{formatRun(run)}</span>
                    </li>
                  ))}
                </ol>
              ) : (
                <p className="py-4 text-xs text-tertiary">{text.noRuns}</p>
              )}
            </section>
          </div>
        ) : !status ? (
          <p className="grid flex-1 place-items-center text-xs text-tertiary">{text.empty}</p>
        ) : (
          <div className="flex-1" />
        )}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CronTool />, { name: "Cron Expression" });
