import React from "react";
import { CalendarBlank, CaretLeft, CaretRight } from "@phosphor-icons/react";
import { parseDateTime } from "@internationalized/date";
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

export function DateTimePicker({ value, onChange, label, className }) {
  const [isOpen, setIsOpen] = React.useState(false);
  let dateValue = null;
  try {
    dateValue = value ? parseDateTime(value) : null;
  } catch {
    dateValue = null;
  }

  return (
    <DatePicker
      aria-label={label}
      value={dateValue}
      onChange={(nextValue) => onChange(nextValue?.toString() || "")}
      granularity="second"
      hourCycle={24}
      shouldCloseOnSelect={false}
      isOpen={isOpen}
      onOpenChange={setIsOpen}
      className={cn("relative", className)}
    >
      <Group
        className="flex h-9.5 w-full cursor-default items-center rounded-control border border-border bg-field px-3 outline-none transition-[border-color,box-shadow] hover:bg-muted focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft"
        onPointerDownCapture={(event) => {
          if (!event.target.closest("button")) setIsOpen(true);
        }}
      >
        <DateInput className="flex min-w-0 flex-1 items-center font-sans text-[13px] tabular-nums">
          {(segment) => (
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
          )}
        </DateInput>
        <AriaButton className="ml-2 grid size-7 shrink-0 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35">
          <CalendarBlank size={16} />
        </AriaButton>
      </Group>
      <AriaPopover placement="bottom start" offset={6} className="z-50 rounded-panel border border-border bg-surface p-3 shadow-popover outline-none entering:animate-in entering:fade-in-0 entering:zoom-in-95 exiting:animate-out exiting:fade-out-0 exiting:zoom-out-95">
        <Dialog className="outline-none">
          <Calendar className="w-[252px] text-xs">
            <header className="mb-2 flex items-center justify-between">
              <AriaButton slot="previous" className="grid size-7 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35"><CaretLeft size={14} weight="bold" /></AriaButton>
              <Heading className="text-[13px] font-semibold" />
              <AriaButton slot="next" className="grid size-7 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35"><CaretRight size={14} weight="bold" /></AriaButton>
            </header>
            <CalendarGrid className="w-full border-separate border-spacing-0.5">
              <CalendarGridHeader>{(day) => <CalendarHeaderCell className="h-7 font-medium text-tertiary">{day}</CalendarHeaderCell>}</CalendarGridHeader>
              <CalendarGridBody>{(date) => <CalendarCell date={date} className="grid size-8 cursor-default place-items-center rounded-[6px] outline-none hover:bg-muted data-[disabled]:opacity-35 data-[focused]:ring-2 data-[focused]:ring-accent/35 data-[outside-visible-range]:text-tertiary data-[selected]:bg-accent data-[selected]:font-semibold data-[selected]:text-white" />}</CalendarGridBody>
            </CalendarGrid>
          </Calendar>
        </Dialog>
      </AriaPopover>
    </DatePicker>
  );
}
