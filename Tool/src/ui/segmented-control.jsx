import * as ToggleGroup from "@radix-ui/react-toggle-group";
import { cn } from "@/lib/utils.js";

export function SegmentedControl({ value, options, onChange, label, className, size = "default" }) {
  const compact = size === "compact";

  return (
    <ToggleGroup.Root
      type="single"
      value={value}
      onValueChange={(nextValue) => nextValue && onChange(nextValue)}
      aria-label={label}
      className={cn("grid h-9.5 flex-1 auto-cols-fr grid-flow-col gap-0.5 rounded-control bg-muted p-0.5", className)}
    >
      {options.map((option) => (
        <ToggleGroup.Item
          value={option.value}
          key={option.value}
          className={cn(
            "relative min-w-0 overflow-hidden rounded-[6px] text-ellipsis whitespace-nowrap text-xs font-medium text-secondary outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35 data-[state=on]:bg-surface data-[state=on]:text-accent data-[state=on]:shadow-segment",
            "before:absolute before:inset-y-1.5 before:left-0 before:w-px before:bg-border first:before:hidden data-[state=on]:before:hidden [[data-state=on]+&]:before:hidden",
            compact ? "px-1" : "px-2",
          )}
        >
          {option.label}
        </ToggleGroup.Item>
      ))}
    </ToggleGroup.Root>
  );
}
