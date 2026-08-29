import React from "react";
import { cn } from "@/lib/utils.js";

/**
 * Shared sidebar / mode-rail item for workbench tools.
 * Prefer this over raw `<button>` nav rows in tools.
 */
export function SidebarNavItem({
  active = false,
  label,
  hint,
  code,
  icon: Icon,
  onClick,
  className,
  trailing,
  ...props
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-current={active ? "page" : undefined}
      className={cn(
        "group relative flex w-full items-center gap-2 rounded-control px-2 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/35",
        hint || Icon ? "min-h-9 py-1.5" : "h-9",
        active
          ? "bg-accent-soft text-accent"
          : "text-secondary hover:bg-foreground/[0.04] hover:text-foreground",
        className,
      )}
      {...props}
    >
      {active ? (
        <span
          className="absolute top-1.5 bottom-1.5 left-0 w-0.5 rounded-full bg-accent"
          aria-hidden="true"
        />
      ) : null}
      {code ? (
        <span
          className={cn(
            "grid size-6 shrink-0 place-items-center rounded-xs font-mono text-[10px] leading-none tracking-tight",
            active ? "bg-accent/15 text-accent" : "bg-muted text-tertiary group-hover:text-secondary",
          )}
        >
          {code}
        </span>
      ) : null}
      {Icon ? <Icon size={16} className={cn("shrink-0", active ? "text-accent" : "text-secondary")} /> : null}
      <span className="min-w-0 flex-1">
        <span className={cn("block truncate text-[12.5px]", active && "font-medium")}>{label}</span>
        {hint ? <span className="mt-0.5 block truncate text-[11px] text-secondary">{hint}</span> : null}
      </span>
      {trailing}
    </button>
  );
}
