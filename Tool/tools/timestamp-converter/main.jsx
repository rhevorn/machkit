import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  CaretDown,
  CopySimple,
  Info,
  Pause,
  Play,
} from "@phosphor-icons/react";
import { currentLocale, useMessages } from "../../src/i18n.js";
import { IconButton, SegmentedControl } from "../../src/ui/components.jsx";
import { sift } from "../../src/runtime/sift.js";
import {
  formatDate,
  localDateTimeValue,
  millisecondsFromLocalDateTime,
  millisecondsFromTimestamp,
  timestampFromMilliseconds,
  timeZoneLabel,
} from "./timestamp.js";

const timeZones = [
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

function CopyField({ value, placeholder, copyLabel, invalid = false }) {
  const hasValue = Boolean(value);

  return (
    <div className={`value-field${hasValue ? "" : " is-placeholder"}${invalid ? " is-invalid" : ""}`}>
      <output aria-live="polite">{value || placeholder || "—"}</output>
      {hasValue ? (
        <button
          className="copy-action"
          type="button"
          onClick={() => sift.copy(value)}
          aria-label={copyLabel}
          title={copyLabel}
        >
          <CopySimple size={17} aria-hidden="true" />
          <span>{copyLabel}</span>
        </button>
      ) : null}
    </div>
  );
}

function TimestampTool() {
  const text = useMessages();
  const locale = currentLocale();
  const systemZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  const zones = useMemo(() => [...new Set([systemZone, ...timeZones])], [systemZone]);
  const [unit, setUnit] = useState("milliseconds");
  const [timeZone, setTimeZone] = useState(systemZone);
  const [selectedDate, setSelectedDate] = useState(() => localDateTimeValue(Date.now(), systemZone));
  const [timestampInput, setTimestampInput] = useState(() => timestampFromMilliseconds(Date.now(), "milliseconds"));
  const [currentMilliseconds, setCurrentMilliseconds] = useState(Date.now());
  const [paused, setPaused] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

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

  return (
    <main className="tool-shell">
      <header className="tool-header">
        <div className="tool-title">
          <h1>{text.title}</h1>
          <p>{text.subtitle}</p>
        </div>
        <div className="tool-header-actions">
          <IconButton label={text.info} onClick={() => setShowInfo((value) => !value)} aria-expanded={showInfo}>
            <Info size={18} />
          </IconButton>
        </div>
        {showInfo ? <div className="popover" role="status">{text.info}</div> : null}
      </header>

      <div className="tool-content">
        <section className="live-inspector" aria-labelledby="current-timestamp-label">
          <div className="live-heading">
            <span id="current-timestamp-label">{text.current}</span>
          </div>
          <div className="live-value-row">
            <output className="live-value" aria-live="off">{currentTimestamp}</output>
            <div className="live-actions">
              <button className="quiet-button" type="button" onClick={() => setPaused((value) => !value)}>
                {paused ? <Play size={15} weight="fill" /> : <Pause size={15} weight="fill" />}
                <span>{paused ? text.resume : text.pause}</span>
              </button>
              <button className="quiet-button" type="button" onClick={() => sift.copy(currentTimestamp)}>
                <CopySimple size={17} />
                <span>{text.copy}</span>
              </button>
            </div>
          </div>

          <div className="inspector-controls">
            <div className="control-group unit-control">
              <span className="control-label">{text.unit}</span>
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
            </div>
            <div className="control-divider" aria-hidden="true" />
            <label className="control-group zone-control">
              <span className="control-label">{text.zone}</span>
              <span className="select-wrap">
                <select value={timeZone} onChange={(event) => changeZone(event.target.value)}>
                  {zones.map((zone) => <option value={zone} key={zone}>{timeZoneLabel(zone, locale)}</option>)}
                </select>
                <CaretDown size={14} aria-hidden="true" />
              </span>
            </label>
          </div>
        </section>

        <section className="conversion-section" aria-labelledby="date-to-heading">
          <h2 id="date-to-heading">{text.dateTo}</h2>
          <label className="field-label" htmlFor="date-input">{text.dateTime}</label>
          <input
            id="date-input"
            className="source-input date-input"
            type="datetime-local"
            value={selectedDate}
            onChange={(event) => setSelectedDate(event.target.value)}
          />
          <span className="result-label">{`${text.timestamp} · ${unitLabel}`}</span>
          <CopyField
            value={selectedMilliseconds === null ? "" : timestampFromMilliseconds(selectedMilliseconds, unit)}
            placeholder={text.selectDate}
            copyLabel={text.copy}
          />
        </section>

        <section className="conversion-section" aria-labelledby="timestamp-to-heading">
          <h2 id="timestamp-to-heading">{text.timestampTo}</h2>
          <label className="field-label" htmlFor="timestamp-input">{`${text.timestamp} · ${unitLabel}`}</label>
          <input
            id="timestamp-input"
            className={`source-input timestamp-input${timestampInput && parsedMilliseconds === null ? " is-invalid" : ""}`}
            inputMode="numeric"
            placeholder={text.enter}
            value={timestampInput}
            onChange={(event) => setTimestampInput(event.target.value)}
            aria-invalid={Boolean(timestampInput && parsedMilliseconds === null)}
          />
          <span className="result-label">{text.dateTime}</span>
          <CopyField
            value={parsedMilliseconds === null ? "" : formatDate(parsedMilliseconds, timeZone, locale)}
            placeholder={timestampInput ? text.invalid : text.enter}
            copyLabel={text.copy}
            invalid={Boolean(timestampInput && parsedMilliseconds === null)}
          />
        </section>
      </div>
    </main>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode><TimestampTool /></React.StrictMode>,
);
