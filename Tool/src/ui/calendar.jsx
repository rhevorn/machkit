import React from "react";
import { CaretLeft, CaretRight } from "@phosphor-icons/react";
import { DayPicker } from "react-day-picker";
import { cn } from "@/lib/utils.js";

function CalendarDayButton({ className, day, modifiers, ...props }) {
  const ref = React.useRef(null);

  React.useEffect(() => {
    if (modifiers.focused) ref.current?.focus();
  }, [modifiers.focused]);

  return (
    <button
      ref={ref}
      type="button"
      className={cn(
        "inline-flex size-8 items-center justify-center rounded-[6px] text-xs outline-none",
        "hover:bg-muted focus-visible:ring-2 focus-visible:ring-accent/35",
        modifiers.selected && "bg-accent font-semibold text-white hover:bg-accent",
        modifiers.today && !modifiers.selected && "font-semibold text-accent",
        modifiers.outside && !modifiers.selected && "text-tertiary",
        className,
      )}
      {...props}
    />
  );
}

export function Calendar({ className, classNames, showOutsideDays = true, ...props }) {
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn("machkit-calendar p-1", className)}
      classNames={{
        months: "relative flex flex-col",
        month: "flex w-full flex-col gap-2",
        month_caption: "relative z-10 flex h-8 items-center justify-center px-9",
        caption_label: "text-[13px] font-semibold text-foreground",
        nav: "absolute inset-x-0 top-0 z-20 flex h-8 items-center justify-between",
        button_previous:
          "grid size-8 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35",
        button_next:
          "grid size-8 place-items-center rounded-[6px] text-secondary outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35",
        month_grid: "w-[16rem] table-fixed border-collapse",
        weekdays: "",
        weekday: "h-8 w-8 p-0 text-center align-middle text-[11px] font-medium text-tertiary",
        week: "",
        day: "h-8 w-8 p-0 text-center align-middle",
        outside: "text-tertiary",
        disabled: "opacity-35",
        hidden: "invisible",
        ...classNames,
      }}
      components={{
        Chevron: ({ orientation, ...chevronProps }) => {
          const Icon = orientation === "left" ? CaretLeft : CaretRight;
          return <Icon size={14} weight="bold" {...chevronProps} />;
        },
        DayButton: CalendarDayButton,
      }}
      {...props}
    />
  );
}
