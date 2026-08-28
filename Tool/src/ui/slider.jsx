import React from "react";
import { cn } from "@/lib/utils.js";

/**
 * Shared range slider. Prefer this over raw `<input type="range">`.
 */
export function Slider({
  id,
  label,
  value,
  min = 0,
  max = 100,
  step = 1,
  onChange,
  className,
  disabled = false,
  ...props
}) {
  return (
    <label className={cn("flex min-w-0 flex-col gap-1.5", className)}>
      {label ? (
        <span className="machkit-control-label flex items-center justify-between gap-2">
          <span>{label}</span>
          <span className="font-mono text-foreground tabular-nums">{value}</span>
        </span>
      ) : null}
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        disabled={disabled}
        aria-label={typeof label === "string" ? label : props["aria-label"]}
        onChange={(event) => onChange?.(Number(event.target.value), event)}
        className="h-7 w-full cursor-default accent-[var(--accent)] disabled:opacity-45"
        {...props}
      />
    </label>
  );
}
