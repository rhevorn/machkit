import React, { useEffect, useMemo, useState } from "react";
import { ArrowsLeftRight, CopySimple, Minus, Pause, Play, Plus, Trash } from "@phosphor-icons/react";
import { useLocale, useToolMessages } from "../../src/i18n.js";
import {
  ActionGroup,
  Button,
  DateTimePicker,
  Field,
  Input,
  SegmentedControl,
  SelectControl,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { machkit } from "../../src/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { messages } from "./messages.js";
import {
  applyRelativeSteps,
  formatISO8601,
  formatLocalDateTime,
  formatReadableDate,
  formatRFC2822,
  formatRFC3339,
  localDateTimeValue,
  millisecondsFromLocalDateTime,
  millisecondsFromTimestamp,
  relativeUnits,
  timestampFromMilliseconds,
  timeZoneLabel,
  type RelativeOperator,
  type RelativeUnit,
  type TimestampUnit,
} from "./timestamp.js";

type TimestampMessages = (typeof messages)["en"];

type CalcStep = {
  id: string;
  operator: RelativeOperator;
  amount: string;
  unit: RelativeUnit;
};

const fallbackTimeZones = [
  "UTC",
  "Asia/Shanghai",
  "Asia/Tokyo",
  "Asia/Singapore",
  "Europe/London",
  "Europe/Paris",
  "America/New_York",
  "America/Los_Angeles",
  "Australia/Sydney",
];

function supportedTimeZones(): string[] {
  try {
    return Intl.supportedValuesOf("timeZone");
  } catch {
    return fallbackTimeZones;
  }
}

function createCalcStep(
  operator: RelativeOperator = "add",
  amount = "1",
  unit: RelativeUnit = "days",
): CalcStep {
  return {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    operator,
    amount,
    unit,
  };
}

function FormatRow({
  label,
  value,
  copyLabel,
  placeholder,
}: {
  label: string;
  value: string;
  copyLabel: string;
  placeholder?: string;
}) {
  const hasValue = Boolean(value);
  return (
    <div className="flex min-w-0 items-baseline gap-2 border-b border-border/70 py-2 last:border-b-0">
      <span className="w-[7.5rem] shrink-0 text-[12px] text-secondary">{label}</span>
      <code
        className={`min-w-0 flex-1 truncate font-mono text-[13px] tabular-nums select-text ${
          hasValue ? "text-foreground" : "font-sans text-tertiary"
        }`}
      >
        {hasValue ? value : placeholder || "—"}
      </code>
      {hasValue ? (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 shrink-0 px-2 text-secondary"
          aria-label={copyLabel}
          title={copyLabel}
          onClick={() => machkit.copy(value)}
        >
          <CopySimple size={15} />
        </Button>
      ) : null}
    </div>
  );
}

function FormatGrid({
  items,
  text,
}: {
  items: [string, string][];
  text: TimestampMessages;
}) {
  return (
    <div>
      {items.map(([label, value]) => (
        <FormatRow
          key={label}
          label={label}
          value={value}
          placeholder={text.invalid}
          copyLabel={text.copy}
        />
      ))}
    </div>
  );
}

function resultFormatItems(
  milliseconds: number | null,
  timeZone: string,
  locale: string,
  text: TimestampMessages,
  unitLabel: string,
  unit: TimestampUnit,
): [string, string][] {
  if (milliseconds === null) {
    return [
      [`${text.timestamp} · ${unitLabel}`, ""],
      [text.formatNormal, ""],
      [text.formatReadable, ""],
      ["ISO 8601 · UTC", ""],
      ["RFC 3339", ""],
      ["RFC 2822", ""],
    ];
  }
  return [
    [`${text.timestamp} · ${unitLabel}`, timestampFromMilliseconds(milliseconds, unit)],
    [text.formatNormal, formatLocalDateTime(milliseconds, timeZone)],
    [text.formatReadable, formatReadableDate(milliseconds, timeZone, locale)],
    ["ISO 8601 · UTC", formatISO8601(milliseconds)],
    ["RFC 3339", formatRFC3339(milliseconds, timeZone)],
    ["RFC 2822", formatRFC2822(milliseconds, timeZone)],
  ];
}

function AmountStepper({
  id,
  value,
  label,
  subtractLabel,
  addLabel,
  onChange,
  onNudge,
}: {
  id: string;
  value: string;
  label: string;
  subtractLabel: string;
  addLabel: string;
  onChange: (value: string) => void;
  onNudge: (delta: number) => void;
}) {
  return (
    <div className="flex h-[var(--machkit-size-control)] min-w-0 items-stretch overflow-hidden rounded-control border border-border bg-field focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft">
      <Button
        variant="ghost"
        size="icon"
        className="size-[var(--machkit-size-control)] shrink-0 rounded-none border-0 text-secondary"
        aria-label={subtractLabel}
        onClick={() => onNudge(-1)}
      >
        <Minus size={14} weight="bold" />
      </Button>
      <Input
        id={id}
        inputMode="numeric"
        aria-label={label}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-auto min-w-0 flex-1 rounded-none border-0 border-x border-border bg-transparent px-2 text-center font-sans text-[13px] tabular-nums shadow-none focus:border-border focus:ring-0"
      />
      <Button
        variant="ghost"
        size="icon"
        className="size-[var(--machkit-size-control)] shrink-0 rounded-none border-0 text-secondary"
        aria-label={addLabel}
        onClick={() => onNudge(1)}
      >
        <Plus size={14} weight="bold" />
      </Button>
    </div>
  );
}

function TimestampTool() {
  const text = useToolMessages(messages);
  const locale = useLocale();
  const systemZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  const zones = useMemo(() => [...new Set([systemZone, "UTC", ...supportedTimeZones()])], [systemZone]);
  const zoneOptions = useMemo(
    () => zones.map((zone) => ({ value: zone, label: timeZoneLabel(zone, locale) })),
    [locale, zones],
  );

  const [tab, setTab] = useState("convert");
  const [unit, setUnit] = useState<TimestampUnit>("seconds");
  const [timeZone, setTimeZone] = useState(systemZone);
  const [milliseconds, setMilliseconds] = useState(() => Date.now());
  const [timestampInput, setTimestampInput] = useState(() => timestampFromMilliseconds(Date.now(), "seconds"));
  const [currentMilliseconds, setCurrentMilliseconds] = useState(Date.now());
  const [paused, setPaused] = useState(false);

  const [calcBase, setCalcBase] = useState(() => localDateTimeValue(Date.now(), systemZone));
  const [calcZone, setCalcZone] = useState(systemZone);
  const [calcSteps, setCalcSteps] = useState<CalcStep[]>(() => [createCalcStep("add", "30", "days")]);

  useEffect(() => {
    if (paused) return undefined;
    const timer = window.setInterval(() => setCurrentMilliseconds(Date.now()), 100);
    return () => window.clearInterval(timer);
  }, [paused]);

  const selectedDate = localDateTimeValue(milliseconds, timeZone);
  const unitLabel = unit === "nanoseconds" ? text.ns : unit === "seconds" ? text.s : text.ms;
  const parsedMilliseconds = millisecondsFromTimestamp(timestampInput, unit);
  const invalidTimestamp = Boolean(timestampInput.trim()) && parsedMilliseconds === null;
  const currentTimestamp = timestampFromMilliseconds(currentMilliseconds, unit);
  const relativeUnitOptions = useMemo(
    () => relativeUnits.map((id) => ({ value: id, label: (text as Record<string, string>)[id] || id })),
    [text],
  );

  const calcBaseMilliseconds = millisecondsFromLocalDateTime(calcBase, calcZone);
  const calcResultMilliseconds = useMemo(() => {
    if (calcBaseMilliseconds === null) return null;
    return applyRelativeSteps(calcBaseMilliseconds, calcSteps, calcZone);
  }, [calcBaseMilliseconds, calcSteps, calcZone]);

  const applyMoment = (nextMilliseconds: number | null) => {
    if (nextMilliseconds === null || !Number.isFinite(nextMilliseconds)) return;
    setMilliseconds(nextMilliseconds);
    setTimestampInput(timestampFromMilliseconds(nextMilliseconds, unit));
  };

  const changeUnit = (nextUnit: string) => {
    const typed = nextUnit as TimestampUnit;
    setUnit(typed);
    setTimestampInput(timestampFromMilliseconds(milliseconds, typed));
  };

  const onTimestampChange = (raw: string) => {
    setTimestampInput(raw);
    const next = millisecondsFromTimestamp(raw, unit);
    if (next !== null) setMilliseconds(next);
  };

  const onDateChange = (value: string | null | undefined) => {
    if (!value) return;
    const next = millisecondsFromLocalDateTime(value, timeZone);
    if (next === null) return;
    setMilliseconds(next);
    setTimestampInput(timestampFromMilliseconds(next, unit));
  };

  const updateCalcStep = (id: string, patch: Partial<CalcStep>) => {
    setCalcSteps((steps) => steps.map((step) => (step.id === id ? { ...step, ...patch } : step)));
  };

  const nudgeCalcAmount = (id: string, delta: number) => {
    setCalcSteps((steps) =>
      steps.map((step) => {
        if (step.id !== id) return step;
        const current = Number.parseInt(String(step.amount).trim(), 10);
        const base = Number.isFinite(current) ? current : 0;
        return { ...step, amount: String(Math.max(0, base + delta)) };
      }),
    );
  };

  const removeCalcStep = (id: string) => {
    setCalcSteps((steps) => (steps.length <= 1 ? steps : steps.filter((step) => step.id !== id)));
  };

  return (
    <ToolPage title={text.title} adaptiveHeight>
      <ToolContent className="flex flex-col pt-4 pb-6">
        <ToolToolbar className="gap-2">
          <SegmentedControl
            value={tab}
            onChange={setTab}
            label={text.title}
            className="max-w-[360px]"
            options={[
              { value: "convert", label: text.tabConvert },
              { value: "calculate", label: text.tabCalculate },
            ]}
          />
          <ActionGroup>
          </ActionGroup>
        </ToolToolbar>

        {tab === "convert" ? (
          <>
            <div className="mt-3 grid gap-3 min-[620px]:grid-cols-[minmax(250px,0.9fr)_minmax(280px,1.1fr)]">
              <Field label={text.unit}>
                <SegmentedControl
                  value={unit}
                  onChange={changeUnit}
                  label={text.unit}
                  options={[
                    { value: "nanoseconds", label: text.ns },
                    { value: "milliseconds", label: text.ms },
                    { value: "seconds", label: text.s },
                  ]}
                />
              </Field>
              <Field label={text.zone}>
                <SelectControl
                  value={timeZone}
                  options={zoneOptions}
                  onChange={setTimeZone}
                  label={text.zone}
                />
              </Field>
            </div>

            <section className="mt-4">
              <div className="mb-1.5 flex items-center gap-2">
                <span className="machkit-control-label">{text.current}</span>
                <span className="min-w-0 truncate text-[12px] text-tertiary">
                  {timeZoneLabel(timeZone, locale, currentMilliseconds)}
                </span>
                <ActionGroup className="shrink-0 gap-0.5">
                  <Button variant="ghost" size="sm" className="h-7 px-2" onClick={() => applyMoment(Date.now())}>
                    {text.useNow}
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-7"
                    aria-label={paused ? text.resume : text.pause}
                    title={paused ? text.resume : text.pause}
                    onClick={() => setPaused((value) => !value)}
                  >
                    {paused ? <Play size={14} weight="fill" /> : <Pause size={14} weight="fill" />}
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-7"
                    aria-label={text.copy}
                    title={text.copy}
                    onClick={() => machkit.copy(currentTimestamp)}
                  >
                    <CopySimple size={14} />
                  </Button>
                </ActionGroup>
              </div>
              <output className="block min-w-0 overflow-hidden font-mono text-[clamp(22px,3.2vw,30px)] leading-none font-medium tracking-[0.03em] text-ellipsis whitespace-nowrap tabular-nums select-text">
                {currentTimestamp}
              </output>
              <div className="mt-1.5 font-mono text-[14px] tabular-nums text-secondary select-text">
                {formatLocalDateTime(currentMilliseconds, timeZone)}
              </div>
            </section>

            <section className="mt-5 overflow-visible rounded-panel border border-border bg-surface px-6 py-6">
              <div className="flex flex-wrap items-end gap-4">
                <Field label={text.dateTime} className="w-[292px] shrink-0">
                  <DateTimePicker
                    value={selectedDate}
                    onChange={onDateChange}
                    label={text.dateTime}
                  />
                </Field>

                <div className="mb-2 flex h-[var(--machkit-size-control)] shrink-0 items-center px-1 text-accent" aria-hidden>
                  <ArrowsLeftRight size={18} weight="bold" />
                </div>

                <Field label={`${text.timestamp} · ${unitLabel}`} htmlFor="timestamp-input" className="w-[168px] shrink-0">
                  <Input
                    id="timestamp-input"
                    inputMode="numeric"
                    placeholder={text.enter}
                    value={timestampInput}
                    onChange={(event) => onTimestampChange(event.target.value)}
                    invalid={invalidTimestamp}
                    className="font-mono tabular-nums"
                  />
                </Field>
              </div>

              {invalidTimestamp ? (
                <div className="mt-4 text-[12px] text-danger">{text.invalid}</div>
              ) : null}
            </section>

            <section className="mt-6">
              <FormatGrid
                items={resultFormatItems(
                  invalidTimestamp ? null : milliseconds,
                  timeZone,
                  locale,
                  text,
                  unitLabel,
                  unit,
                )}
                text={text}
              />
            </section>
          </>
        ) : (
          <>
            <div className="mt-4 grid gap-4 min-[620px]:grid-cols-[minmax(250px,1fr)_minmax(250px,1fr)_auto]">
              <Field label={text.dateTime}>
                <DateTimePicker
                  value={calcBase}
                  onChange={(value) => {
                    if (value) setCalcBase(value);
                  }}
                  label={text.dateTime}
                />
              </Field>
              <Field label={text.zone}>
                <SelectControl
                  value={calcZone}
                  options={zoneOptions}
                  onChange={setCalcZone}
                  label={text.zone}
                />
              </Field>
              <div className="flex items-end">
                <Button
                  variant="ghost"
                  size="sm"
                  className="w-full min-[620px]:w-auto"
                  onClick={() => setCalcBase(localDateTimeValue(Date.now(), calcZone))}
                >
                  {text.useNow}
                </Button>
              </div>
            </div>

            <section className="mt-5">
              <div className="mb-2 flex items-center gap-2">
                <div className="text-xs font-semibold text-secondary">{text.formula}</div>
                <Button
                  variant="ghost"
                  size="sm"
                  className="ml-auto h-7 px-2"
                  onClick={() => setCalcSteps((steps) => [...steps, createCalcStep()])}
                >
                  <Plus size={14} weight="bold" />
                  {text.addStep}
                </Button>
              </div>
              <div className="space-y-2">
                {calcSteps.map((step) => (
                  <div
                    key={step.id}
                    className="grid grid-cols-[96px_minmax(120px,0.7fr)_minmax(120px,1fr)_28px] items-center gap-2"
                  >
                    <SegmentedControl
                      value={step.operator}
                      onChange={(operator) => updateCalcStep(step.id, { operator: operator as RelativeOperator })}
                      label={text.operator}
                      options={[
                        { value: "add", label: text.add },
                        { value: "subtract", label: text.subtract },
                      ]}
                    />
                    <AmountStepper
                      id={`calc-amount-${step.id}`}
                      value={step.amount}
                      label={text.amount}
                      subtractLabel={`${text.subtract} ${text.amount}`}
                      addLabel={`${text.add} ${text.amount}`}
                      onChange={(amount: string) => updateCalcStep(step.id, { amount })}
                      onNudge={(delta: number) => nudgeCalcAmount(step.id, delta)}
                    />
                    <SelectControl
                      value={step.unit}
                      options={relativeUnitOptions}
                      onChange={(nextUnit) => updateCalcStep(step.id, { unit: nextUnit as RelativeUnit })}
                      label={text.durationUnit}
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-7"
                      aria-label={text.removeStep}
                      title={text.removeStep}
                      disabled={calcSteps.length <= 1}
                      onClick={() => removeCalcStep(step.id)}
                    >
                      <Trash size={14} />
                    </Button>
                  </div>
                ))}
              </div>
            </section>

            <section className="mt-5">
              <FormatGrid
                items={resultFormatItems(
                  calcResultMilliseconds,
                  calcZone,
                  locale,
                  text,
                  unitLabel,
                  unit,
                )}
                text={text}
              />
            </section>
          </>
        )}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<TimestampTool />, { name: "Timestamp Converter" });
