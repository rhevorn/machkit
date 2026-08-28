import React from "react";
import { CalendarBlank } from "@phosphor-icons/react";
import { format } from "date-fns";
import * as Popover from "@radix-ui/react-popover";
import { cn } from "@/lib/utils.js";
import { Calendar } from "./calendar.jsx";

const VALUE_RE = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})$/;

function pad2(value) {
  return String(value).padStart(2, "0");
}

function parseValue(value) {
  if (!value) return null;
  const match = VALUE_RE.exec(String(value).trim());
  if (!match) return null;
  const date = new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    Number(match[4]),
    Number(match[5]),
    Number(match[6]),
  );
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatValue(date) {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}T${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(date.getSeconds())}`;
}

function formatDisplay(date) {
  return format(date, "yyyy-MM-dd HH:mm:ss");
}

function toDisplayText(value) {
  const date = parseValue(value);
  if (date) return formatDisplay(date);
  if (!value) return "";
  return String(value).replace("T", " ");
}

function clampPart(raw, max) {
  const value = Number.parseInt(String(raw).replace(/\D/g, ""), 10);
  if (!Number.isFinite(value)) return null;
  return Math.min(max, Math.max(0, value));
}

function TimePartsEditor({ date, onCommit }) {
  const hour = date?.getHours() ?? 0;
  const minute = date?.getMinutes() ?? 0;
  const second = date?.getSeconds() ?? 0;

  const update = (patch) => {
    const next = date ? new Date(date.getTime()) : new Date();
    if (patch.hour != null) next.setHours(patch.hour);
    if (patch.minute != null) next.setMinutes(patch.minute);
    if (patch.second != null) next.setSeconds(patch.second);
    onCommit(next);
  };

  const fieldClass =
    "h-8 w-12 rounded-control border border-border bg-field text-center font-sans text-[13px] tabular-nums text-foreground outline-none focus:border-accent focus:ring-3 focus:ring-accent-soft";

  return (
    <div className="mt-3 border-t border-border bg-popover pt-3">
      <div className="flex items-center justify-center gap-1.5">
        <input
          className={fieldClass}
          inputMode="numeric"
          aria-label="Hour"
          value={pad2(hour)}
          onFocus={(event) => event.target.select()}
          onChange={(event) => {
            const next = clampPart(event.target.value, 23);
            if (next == null) return;
            update({ hour: next });
          }}
        />
        <span className="text-secondary">:</span>
        <input
          className={fieldClass}
          inputMode="numeric"
          aria-label="Minute"
          value={pad2(minute)}
          onFocus={(event) => event.target.select()}
          onChange={(event) => {
            const next = clampPart(event.target.value, 59);
            if (next == null) return;
            update({ minute: next });
          }}
        />
        <span className="text-secondary">:</span>
        <input
          className={fieldClass}
          inputMode="numeric"
          aria-label="Second"
          value={pad2(second)}
          onFocus={(event) => event.target.select()}
          onChange={(event) => {
            const next = clampPart(event.target.value, 59);
            if (next == null) return;
            update({ second: next });
          }}
        />
      </div>
    </div>
  );
}

export function DateTimePicker({ value, onChange, label, className }) {
  const selected = parseValue(value);
  const [draft, setDraft] = React.useState(() => toDisplayText(value));
  const [open, setOpen] = React.useState(false);
  const [month, setMonth] = React.useState(() => selected ?? new Date());
  const focusedRef = React.useRef(false);

  React.useEffect(() => {
    if (focusedRef.current) return;
    setDraft(toDisplayText(value));
  }, [value]);

  React.useEffect(() => {
    if (selected) setMonth(selected);
  }, [value]);

  const commit = (next) => {
    onChange(next ? formatValue(next) : "");
  };

  const onSelectDay = (day) => {
    if (!day) return;
    const next = new Date(day.getTime());
    next.setHours(selected?.getHours() ?? 0, selected?.getMinutes() ?? 0, selected?.getSeconds() ?? 0, 0);
    setMonth(next);
    commit(next);
  };

  const onDraftChange = (text) => {
    setDraft(text);
    const parsed = parseValue(text);
    if (parsed) {
      setMonth(parsed);
      onChange(formatValue(parsed));
      return;
    }
    if (!text.trim()) onChange("");
  };

  const onDraftBlur = () => {
    focusedRef.current = false;
    const parsed = parseValue(draft);
    if (parsed) {
      setDraft(formatDisplay(parsed));
      onChange(formatValue(parsed));
      return;
    }
    setDraft(toDisplayText(value));
  };

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <div
        className={cn(
          "machkit-datetime-field flex h-9.5 w-full items-center overflow-hidden rounded-control border border-border bg-field outline-none transition-[border-color,box-shadow]",
          "focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft",
          open && "border-accent ring-3 ring-accent-soft",
          className,
        )}
      >
        <input
          type="text"
          spellCheck={false}
          autoComplete="off"
          aria-label={label}
          placeholder="yyyy-MM-dd HH:mm:ss"
          value={draft}
          onFocus={() => {
            focusedRef.current = true;
          }}
          onChange={(event) => onDraftChange(event.target.value)}
          onBlur={onDraftBlur}
          className="min-w-0 flex-1 border-0 bg-transparent px-3 font-mono text-[13px] tabular-nums text-foreground outline-none placeholder:font-sans placeholder:text-tertiary"
        />
        <Popover.Trigger asChild>
          <button
            type="button"
            aria-label={label ? `${label} calendar` : "Open calendar"}
            className="mr-1 grid size-7 shrink-0 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35"
          >
            <CalendarBlank size={16} />
          </button>
        </Popover.Trigger>
      </div>
      <Popover.Portal>
        <Popover.Content
          align="start"
          sideOffset={8}
          collisionPadding={12}
          onOpenAutoFocus={(event) => event.preventDefault()}
          className="z-[300] w-auto rounded-panel border border-border bg-popover p-3 text-popover-foreground shadow-popover outline-none data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
        >
          <Calendar
            mode="single"
            selected={selected ?? undefined}
            onSelect={onSelectDay}
            month={month}
            onMonthChange={setMonth}
          />
          <TimePartsEditor date={selected} onCommit={commit} />
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
