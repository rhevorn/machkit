import { cn } from "@/lib/utils.js";
import { InlineMessage } from "./inline-message.jsx";

/**
 * Stable status / feedback strip. Wraps InlineMessage with a consistent floor height
 * so conditional results do not jump the page.
 */
export function StatusStrip({ tone = "neutral", className, children, ...props }) {
  return (
    <InlineMessage
      tone={tone}
  className={cn("min-h-[var(--machkit-size-control)]", className)}
      {...props}
    >
      {children}
    </InlineMessage>
  );
}
