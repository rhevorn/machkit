import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, Pause, Play } from "@phosphor-icons/react";
import { I18nProvider } from "react-aria-components";
import { useLocale, useToolMessages } from "../../src/i18n.js";
import {
  Button,
  DateTimePicker,
  Field,
  Input,
  SegmentedControl,
  SelectControl,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ValueField,
} from "@/ui/index.js";
import { sift } from "../../src/runtime/sift.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { messages } from "./messages.js";
import {
  formatDate,
  formatISO8601,
  formatRFC2822,
  formatRFC3339,
  localDateTimeValue,
  millisecondsFromLocalDateTime,
  millisecondsFromTimestamp,
  timestampFromMilliseconds,
  timeZoneLabel,
} from "./timestamp.js";

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

function supportedTimeZones() {
  try {
    return Intl.supportedValuesOf("timeZone");
  } catch {
    return fallbackTimeZones;
  }
}

function StandardFormats({ milliseconds, timeZone, text }) {
  const formats = milliseconds === null ? [] : [
    ["ISO 8601 · UTC", formatISO8601(milliseconds)],
    ["RFC 3339", formatRFC3339(milliseconds, timeZone)],
    ["RFC 2822", formatRFC2822(milliseconds, timeZone)],
  ];

  return (
    <div className="mt-3 grid gap-3">
      {(formats.length ? formats : [["ISO 8601 · UTC", ""], ["RFC 3339", ""], ["RFC 2822", ""]]).map(([label, value]) => (
        <Field key={label} label={label}>
          <ValueField
            value={value}
            placeholder={text.invalid}
            copyLabel={text.copy}
            onCopy={(nextValue) => sift.copy(nextValue)}
            showCopyLabel={false}
          />
        </Field>
      ))}
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
  const [unit, setUnit] = useState("milliseconds");
  const [conversionMode, setConversionMode] = useState("dateToTimestamp");
  const [timeZone, setTimeZone] = useState(systemZone);
  const [selectedDate, setSelectedDate] = useState(() => localDateTimeValue(Date.now(), systemZone));
  const [timestampInput, setTimestampInput] = useState(() => timestampFromMilliseconds(Date.now(), "milliseconds"));
  const [currentMilliseconds, setCurrentMilliseconds] = useState(Date.now());
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused) return undefined;
    const timer = window.setInterval(() => setCurrentMilliseconds(Date.now()), 100);
    return () => window.clearInterval(timer);
  }, [paused]);

  const changeUnit = (nextUnit) => {
    const milliseconds = millisecondsFromTimestamp(timestampInput, unit);
    setUnit(nextUnit);
    if (milliseconds !== null) setTimestampInput(timestampFromMilliseconds(milliseconds, nextUnit));
  };

  const changeZone = (nextZone) => {
    const milliseconds = millisecondsFromLocalDateTime(selectedDate, timeZone);
    setTimeZone(nextZone);
    if (milliseconds !== null) setSelectedDate(localDateTimeValue(milliseconds, nextZone));
  };

  const selectedMilliseconds = millisecondsFromLocalDateTime(selectedDate, timeZone);
  const parsedMilliseconds = millisecondsFromTimestamp(timestampInput, unit);
  const currentTimestamp = timestampFromMilliseconds(currentMilliseconds, unit);
  const unitLabel = unit === "nanoseconds" ? text.ns : unit === "seconds" ? text.s : text.ms;
  const invalidTimestamp = Boolean(timestampInput && parsedMilliseconds === null);

  return (
    <ToolPage title={text.title} adaptiveHeight>
      <ToolContent className="flex flex-col pt-4 pb-6">
        <div className="sift-toolbar gap-2">
          <SegmentedControl
            value={conversionMode}
            onChange={setConversionMode}
            label={text.title}
            className="max-w-[420px]"
            options={[
              { value: "dateToTimestamp", label: text.dateTo },
              { value: "timestampToDate", label: text.timestampTo },
            ]}
          />
          <ToolInfoButton info={text.info} className="ml-auto size-8.5 shrink-0" />
        </div>

        <section className="mt-4 rounded-panel border border-border bg-surface p-5 shadow-[0_1px_2px_rgb(0_0_0/0.04)]">
          <header className="mb-3 flex items-center gap-3">
            <span className="sift-control-label">{text.current}</span>
            <div className="ml-auto flex shrink-0 gap-1">
              <Button variant="accentGhost" size="sm" onClick={() => setPaused((value) => !value)}>
                {paused ? <Play size={15} weight="fill" /> : <Pause size={15} weight="fill" />}
                <span className="max-[500px]:hidden">{paused ? text.resume : text.pause}</span>
              </Button>
              <Button variant="ghost" size="sm" onClick={() => sift.copy(currentTimestamp)}>
                <CopySimple size={17} />
                <span className="max-[500px]:hidden">{text.copy}</span>
              </Button>
            </div>
          </header>
          <output className="block min-w-0 overflow-hidden font-mono text-[clamp(26px,4vw,36px)] leading-none font-medium tracking-[0.035em] text-ellipsis whitespace-nowrap tabular-nums select-text">
            {currentTimestamp}
          </output>
        </section>

        <div className="grid gap-4 py-4 min-[620px]:grid-cols-[minmax(250px,0.9fr)_minmax(300px,1.1fr)]">
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
              onChange={changeZone}
              label={text.zone}
            />
          </Field>
        </div>

        <section className="sift-panel">
          <div className="grid gap-4 p-5 min-[620px]:grid-cols-2">
            {conversionMode === "dateToTimestamp" ? (
              <>
                <Field label={text.dateTime} htmlFor="date-input">
                  <DateTimePicker
                    value={selectedDate}
                    onChange={setSelectedDate}
                    label={text.dateTime}
                  />
                </Field>
                <Field label={`${text.timestamp} · ${unitLabel}`}>
                  <ValueField
                    value={selectedMilliseconds === null ? "" : timestampFromMilliseconds(selectedMilliseconds, unit)}
                    placeholder={text.selectDate}
                    copyLabel={text.copy}
                    onCopy={(value) => sift.copy(value)}
                    showCopyLabel={false}
                  />
                </Field>
              </>
            ) : (
              <>
                <Field label={`${text.timestamp} · ${unitLabel}`} htmlFor="timestamp-input">
                  <Input
                    id="timestamp-input"
                    inputMode="numeric"
                    placeholder={text.enter}
                    value={timestampInput}
                    onChange={(event) => setTimestampInput(event.target.value)}
                    invalid={invalidTimestamp}
                  />
                </Field>
                <Field label={text.dateTime}>
                  <ValueField
                    value={parsedMilliseconds === null ? "" : formatDate(parsedMilliseconds, timeZone, locale)}
                    placeholder={timestampInput ? text.invalid : text.enter}
                    copyLabel={text.copy}
                    onCopy={(value) => sift.copy(value)}
                    invalid={invalidTimestamp}
                    showCopyLabel={false}
                  />
                </Field>
              </>
            )}
          </div>

          <div className="border-t border-border p-5">
            <div className="text-xs font-semibold text-secondary">
              {text.standardFormats || "Standard Formats"}
            </div>
            <StandardFormats
              milliseconds={conversionMode === "dateToTimestamp" ? selectedMilliseconds : parsedMilliseconds}
              timeZone={timeZone}
              text={text}
            />
          </div>
        </section>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<TimestampApp />, { name: "Timestamp Converter" });

function TimestampApp() {
  const locale = useLocale().replaceAll("_", "-");
  return (
    <I18nProvider locale={locale}>
      <TimestampTool />
    </I18nProvider>
  );
}
