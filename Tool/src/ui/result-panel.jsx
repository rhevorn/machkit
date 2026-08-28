import { cn } from "@/lib/utils.js";

/**
 * Standard bordered result panel shell.
 * Optional header with title + actions; body holds property lists or free content.
 */
export function ResultPanel({ title, actions, className, children, bodyClassName, ...props }) {
  return (
    <div className={cn("machkit-panel overflow-hidden", className)} {...props}>
      {title || actions ? (
        <header className="flex flex-wrap items-center justify-between gap-2 border-b border-border px-3 py-2">
          {title ? <div className="min-w-0 text-[12px] font-medium text-foreground">{title}</div> : <span />}
          {actions ? <div className="flex shrink-0 items-center gap-1">{actions}</div> : null}
        </header>
      ) : null}
      <div className={cn(bodyClassName)}>{children}</div>
    </div>
  );
}
