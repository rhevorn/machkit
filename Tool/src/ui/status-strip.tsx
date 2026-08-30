import { cn } from "@/lib/utils.js";
import { InlineMessage, type InlineMessageProps } from "./inline-message.js";

/**
 * Stable status / feedback strip. Wraps InlineMessage with a consistent floor height
 * so conditional results do not jump the page.
 */
export type StatusStripProps = InlineMessageProps;

export function StatusStrip({ tone = "neutral", className, children, ...props }: StatusStripProps) {
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
