import React from "react";
import { Button } from "./button.jsx";
import { cn } from "@/lib/utils.js";

/**
 * Compact example / preset actions. Use instead of raw clickable chips.
 */
export function ExampleChips({
  label,
  options = [],
  onSelect,
  className,
  size = "sm",
}) {
  if (!options.length) return null;

  return (
    <div className={cn("flex min-w-0 flex-wrap items-center gap-1.5", className)}>
      {label ? <span className="machkit-control-label mr-0.5">{label}</span> : null}
      {options.map((option) => {
        const value = typeof option === "string" ? option : option.value;
        const chipLabel = typeof option === "string" ? option : option.label;
        const key = typeof option === "string" ? option : option.id || option.value;
        return (
          <Button
            key={key}
            type="button"
            variant="secondary"
            size={size}
            className="h-7 max-w-full px-2.5 font-mono text-[11px] font-normal"
            onClick={() => onSelect?.(value, option)}
          >
            <span className="truncate">{chipLabel}</span>
          </Button>
        );
      })}
    </div>
  );
}
