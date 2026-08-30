import type { ReactNode } from "react";
import * as ToggleGroup from "@radix-ui/react-toggle-group";
import { cn } from "@/lib/utils.js";

export type SegmentedOption = {
  value: string;
  label: ReactNode;
};

export type SegmentedControlProps = {
  value: string;
  options: SegmentedOption[];
  onChange: (value: string) => void;
  label?: string;
  className?: string;
  size?: "default" | "compact";
};

export function SegmentedControl({
  value,
  options,
  onChange,
  label,
  className,
  size = "default",
}: SegmentedControlProps) {
  const compact = size === "compact";

  return (
    <ToggleGroup.Root
      type="single"
      value={value}
      onValueChange={(nextValue) => nextValue && onChange(nextValue)}
      aria-label={label}
      className={cn(
        "grid h-[var(--machkit-size-control)] flex-1 auto-cols-fr grid-flow-col gap-0.5 rounded-control bg-muted p-0.5",
        className,
      )}
    >
      {options.map((option) => (
        <ToggleGroup.Item
          value={option.value}
          key={option.value}
          className={cn(
            "relative min-w-0 overflow-hidden rounded-[5px] text-ellipsis whitespace-nowrap text-xs font-medium text-secondary outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35 data-[state=on]:bg-surface data-[state=on]:text-accent data-[state=on]:shadow-segment",
            "before:absolute before:inset-y-1 before:left-0 before:w-px before:bg-border first:before:hidden data-[state=on]:before:hidden [[data-state=on]+&]:before:hidden",
            compact ? "px-1" : "px-2",
          )}
        >
          {option.label}
        </ToggleGroup.Item>
      ))}
    </ToggleGroup.Root>
  );
}
