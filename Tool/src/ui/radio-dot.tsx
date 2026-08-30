import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils.js";

/**
 * Compact radio / activate control used by workbench lists (e.g. Hosts).
 */
export type RadioDotProps = ComponentPropsWithoutRef<"button"> & {
  checked?: boolean;
  label?: string;
};

export function RadioDot({
  checked = false,
  disabled = false,
  label,
  onClick,
  className,
  ...props
}: RadioDotProps) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "grid size-[15px] shrink-0 place-items-center rounded-full border outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/30",
        checked ? "border-accent bg-accent" : "border-tertiary hover:border-accent",
        disabled && "pointer-events-none",
        disabled && !checked && "opacity-45",
        className,
      )}
      {...props}
    >
      {checked ? <span className="size-[5px] rounded-full bg-primary-foreground" aria-hidden="true" /> : null}
    </button>
  );
}
