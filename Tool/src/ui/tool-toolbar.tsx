import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils.js";

/** Shared 54px toolbar shell. Put fields left, actions right. */
export type ToolToolbarProps = ComponentPropsWithoutRef<"div">;

export function ToolToolbar({ className, children, ...props }: ToolToolbarProps) {
  return (
    <div className={cn("machkit-toolbar", className)} {...props}>
      {children}
    </div>
  );
}

/** Groups primary / secondary / utility actions with consistent gap. */
export type ActionGroupProps = ComponentPropsWithoutRef<"div">;

export function ActionGroup({ className, children, ...props }: ActionGroupProps) {
  return (
    <div className={cn("ml-auto flex shrink-0 items-center gap-1", className)} {...props}>
      {children}
    </div>
  );
}
