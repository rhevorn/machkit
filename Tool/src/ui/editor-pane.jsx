import { cn } from "@/lib/utils.js";

/**
 * Simple left/right (or stacked) workspace for editor / transform tools.
 */
export function SplitWorkspace({ className, children, ...props }) {
  return (
    <div
      className={cn("grid min-h-0 min-w-0 flex-1 gap-3 lg:grid-cols-2", className)}
      {...props}
    >
      {children}
    </div>
  );
}

/**
 * Pane chrome around an editor or large text surface.
 */
export function EditorPane({
  title,
  actions,
  className,
  bodyClassName,
  children,
  ...props
}) {
  return (
    <section className={cn("machkit-panel flex min-h-0 min-w-0 flex-col overflow-hidden", className)} {...props}>
      {title || actions ? (
        <header className="flex h-11 shrink-0 items-center gap-2 border-b border-border px-3">
          {title ? <span className="min-w-0 flex-1 truncate text-xs font-medium text-secondary">{title}</span> : <span className="flex-1" />}
          {actions ? <div className="flex shrink-0 items-center gap-1">{actions}</div> : null}
        </header>
      ) : null}
      <div className={cn("min-h-0 min-w-0 flex-1", bodyClassName)}>{children}</div>
    </section>
  );
}
