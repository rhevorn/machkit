import React from "react";
import { CalendarBlank, CaretLeft, CaretRight } from "@phosphor-icons/react";
import { CalendarDateTime, parseDateTime } from "@internationalized/date";
import {
  Button as AriaButton,
  Calendar,
  CalendarCell,
  CalendarGrid,
  CalendarGridBody,
  CalendarGridHeader,
  CalendarHeaderCell,
  DateInput,
  DatePicker,
  DateSegment,
  Dialog,
  Group,
  Heading,
  Popover as AriaPopover,
} from "react-aria-components";
import { cn } from "@/lib/utils.js";

function renderSegment(segment) {
  return (
    <DateSegment
      segment={segment}
      className={cn(
        "machkit-date-segment rounded-[4px] px-[1px] text-foreground outline-none data-[focused]:bg-accent data-[focused]:text-white data-[placeholder]:text-tertiary",
        `machkit-date-segment-${segment.type}`,
      )}
    >
      {segment.isPlaceholder || !["month", "day", "hour", "minute", "second"].includes(segment.type)
        ? segment.text
        : segment.text.padStart(2, "0")}
    </DateSegment>
  );
}

function toCalendarDateTime(value) {
  if (!value) return null;
  try {
    return parseDateTime(value);
  } catch {
    return null;
  }
}

function buildDateTime(parts) {
  return new CalendarDateTime(
    parts.year,
    parts.month,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
}

function pad2(value) {
  return String(value).padStart(2, "0");
}

function TimePartsEditor({ dateValue, onCommit }) {
  const year = dateValue?.year ?? new Date().getFullYear();
  const month = dateValue?.month ?? new Date().getMonth() + 1;
  const day = dateValue?.day ?? new Date().getDate();
  const hour = dateValue?.hour ?? 0;
  const minute = dateValue?.minute ?? 0;
  const second = dateValue?.second ?? 0;

  const update = (patch) => {
    onCommit(
      buildDateTime({
        year,
        month,
        day,
        hour,
        minute,
        second,
        ...patch,
      }),
    );
  };

  const fieldClass =
    "h-9 w-14 rounded-control border border-border bg-surface text-center font-sans text-[13px] tabular-nums text-foreground outline-none focus:border-accent focus:ring-3 focus:ring-accent-soft";

  return (
    <div className="relative z-10 mt-3 border-t border-border bg-popover pt-3">
      <div className="flex items-end justify-center gap-2">
        <label className="grid gap-1">
          <span className="text-center text-[11px] font-medium text-tertiary">时</span>
          <input
            className={fieldClass}
            inputMode="numeric"
            aria-label="Hour"
            value={pad2(hour)}
            onFocus={(event) => event.target.select()}
            onChange={(event) => {
              const raw = Number.parseInt(event.target.value.replace(/\D/g, ""), 10);
              if (!Number.isFinite(raw)) return;
              update({ hour: Math.min(23, Math.max(0, raw)) });
            }}
          />
        </label>
        <span className="mb-2 text-secondary">:</span>
        <label className="grid gap-1">
          <span className="text-center text-[11px] font-medium text-tertiary">分</span>
          <input
            className={fieldClass}
            inputMode="numeric"
            aria-label="Minute"
            value={pad2(minute)}
            onFocus={(event) => event.target.select()}
            onChange={(event) => {
              const raw = Number.parseInt(event.target.value.replace(/\D/g, ""), 10);
              if (!Number.isFinite(raw)) return;
              update({ minute: Math.min(59, Math.max(0, raw)) });
            }}
          />
        </label>
        <span className="mb-2 text-secondary">:</span>
        <label className="grid gap-1">
          <span className="text-center text-[11px] font-medium text-tertiary">秒</span>
          <input
            className={fieldClass}
            inputMode="numeric"
            aria-label="Second"
            value={pad2(second)}
            onFocus={(event) => event.target.select()}
            onChange={(event) => {
              const raw = Number.parseInt(event.target.value.replace(/\D/g, ""), 10);
              if (!Number.isFinite(raw)) return;
              update({ second: Math.min(59, Math.max(0, raw)) });
            }}
          />
        </label>
      </div>
    </div>
  );
}

export function DateTimePicker({ value, onChange, label, className }) {
  const [isOpen, setIsOpen] = React.useState(false);
  const dateValue = toCalendarDateTime(value);

  const commit = (next) => {
    onChange(next ? next.toString() : "");
  };

  return (
    <DatePicker
      aria-label={label}
      value={dateValue}
      onChange={(nextValue) => {
        if (!nextValue) {
          commit(null);
          return;
        }
        commit(
          buildDateTime({
            year: nextValue.year,
            month: nextValue.month,
            day: nextValue.day,
            hour: nextValue.hour ?? dateValue?.hour ?? 0,
            minute: nextValue.minute ?? dateValue?.minute ?? 0,
            second: nextValue.second ?? dateValue?.second ?? 0,
          }),
        );
      }}
      granularity="second"
      hourCycle={24}
      shouldCloseOnSelect={false}
      isOpen={isOpen}
      onOpenChange={setIsOpen}
      className={cn("relative z-0", className)}
    >
      <Group className="machkit-datetime-field flex h-9.5 w-full cursor-default items-center overflow-hidden rounded-control border border-border bg-field px-3 outline-none transition-[border-color,box-shadow] hover:bg-muted focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft">
        <DateInput className="flex min-w-0 flex-1 flex-nowrap items-center overflow-hidden font-sans text-[13px] tabular-nums">
          {renderSegment}
        </DateInput>
        <AriaButton className="ml-2 grid size-7 shrink-0 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35">
          <CalendarBlank size={16} />
        </AriaButton>
      </Group>
      <AriaPopover
        placement="bottom start"
        offset={8}
        containerPadding={12}
        className="z-[300] overflow-visible rounded-panel border border-border bg-popover p-3 text-popover-foreground shadow-popover outline-none entering:animate-in entering:fade-in-0 entering:zoom-in-95 exiting:animate-out exiting:fade-out-0 exiting:zoom-out-95"
      >
        <Dialog className="relative z-[301] w-[260px] bg-popover outline-none">
          <Calendar className="w-full bg-popover text-xs">
            <header className="mb-2 flex items-center justify-between">
              <AriaButton slot="previous" className="grid size-7 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35">
                <CaretLeft size={14} weight="bold" />
              </AriaButton>
              <Heading className="text-[13px] font-semibold" />
              <AriaButton slot="next" className="grid size-7 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35">
                <CaretRight size={14} weight="bold" />
              </AriaButton>
            </header>
            <CalendarGrid className="w-full border-separate border-spacing-0.5">
              <CalendarGridHeader>
                {(day) => <CalendarHeaderCell className="h-7 font-medium text-tertiary">{day}</CalendarHeaderCell>}
              </CalendarGridHeader>
              <CalendarGridBody>
                {(date) => (
                  <CalendarCell
                    date={date}
                    className="grid size-8 cursor-default place-items-center rounded-[6px] outline-none hover:bg-muted data-[disabled]:opacity-35 data-[focused]:ring-2 data-[focused]:ring-accent/35 data-[outside-visible-range]:text-tertiary data-[selected]:bg-accent data-[selected]:font-semibold data-[selected]:text-white"
                  />
                )}
              </CalendarGridBody>
            </CalendarGrid>
          </Calendar>

          <TimePartsEditor dateValue={dateValue} onCommit={commit} />
        </Dialog>
      </AriaPopover>
    </DatePicker>
  );
}
