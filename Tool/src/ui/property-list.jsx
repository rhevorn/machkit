import React from "react";
import { CopySimple } from "@phosphor-icons/react";
import { Button } from "./button.jsx";
import { cn } from "@/lib/utils.js";
import { machkit } from "@/runtime/machkit.js";

/**
 * Label / value row for technical results.
 * Copies via machkit.copy when copyLabel is provided and value is non-empty.
 */
export function PropertyRow({
  label,
  value,
  copyLabel,
  mono = true,
  empty = "—",
  hideEmpty = false,
  labelClassName,
  className,
}) {
  const hasValue = value !== undefined && value !== null && String(value).length > 0;
  if (hideEmpty && !hasValue) return null;

  const display = hasValue ? String(value) : empty;

  return (
    <div
      className={cn(
        "flex min-w-0 items-start gap-2 border-b border-border/70 px-3 py-2 last:border-b-0",
        className,
      )}
    >
      <span className={cn("w-24 shrink-0 pt-0.5 text-[12px] text-secondary", labelClassName)}>
        {label}
      </span>
      <code
        className={cn(
          "min-w-0 flex-1 break-all text-[12px] leading-relaxed select-text",
          mono ? "font-mono tabular-nums" : "font-sans",
          hasValue ? "text-foreground" : "font-sans text-tertiary",
        )}
      >
        {display}
      </code>
      {hasValue && copyLabel ? (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 shrink-0 px-2 text-secondary"
          aria-label={`${copyLabel}: ${label}`}
          title={`${copyLabel}: ${label}`}
          onClick={() => machkit.copy(display)}
        >
          <CopySimple size={15} />
        </Button>
      ) : null}
    </div>
  );
}

export function PropertyList({ children, className, ...props }) {
  return (
    <div className={cn("min-w-0", className)} {...props}>
      {children}
    </div>
  );
}
