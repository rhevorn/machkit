import { cn } from "@/lib/utils.js";

export function InlineMessage({ children, tone = "neutral", className }) {
  return (
    <div
      className={cn(
        "rounded-control px-3.5 py-2.5 text-xs leading-relaxed",
        tone === "neutral" && "border border-border bg-transparent text-secondary",
        tone === "info" && "bg-accent-soft text-accent",
        tone === "danger" && "bg-danger/10 text-danger",
        className,
      )}
    >
      {children}
    </div>
  );
}
