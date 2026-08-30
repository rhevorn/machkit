import type { ReactNode } from "react";
import { cn } from "@/lib/utils.js";

export type InlineMessageTone = "neutral" | "info" | "success" | "warning" | "danger";

export type InlineMessageProps = {
  children?: ReactNode;
  tone?: InlineMessageTone;
  className?: string;
};

export function InlineMessage({ children, tone = "neutral", className }: InlineMessageProps) {
  return (
    <div
      className={cn(
        "rounded-control px-3.5 py-2.5 text-xs leading-relaxed",
        tone === "neutral" && "border border-border bg-transparent text-secondary",
        tone === "info" && "bg-info-soft text-info",
        tone === "success" && "bg-success-soft text-success",
        tone === "warning" && "bg-warning-soft text-warning",
        tone === "danger" && "bg-danger-soft text-danger",
        className,
      )}
    >
      {children}
    </div>
  );
}
