import { cn } from "@/lib/utils.js";

/**
 * Left rail shell for workbench tools. Pair with SidebarNavItem.
 */
export function ToolSidebar({
  width = 148,
  className,
  children,
  muted = false,
  ...props
}) {
  return (
    <aside
      className={cn("flex shrink-0 flex-col", className)}
      style={{ width: typeof width === "number" ? `${width}px` : width }}
      {...props}
    >
      {muted ? (
        <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-auto rounded-panel bg-muted/70 px-1.5 py-2">
          {children}
        </div>
      ) : (
        children
      )}
    </aside>
  );
}
