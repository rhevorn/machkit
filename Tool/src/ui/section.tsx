import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { cn } from "@/lib/utils.js";

export type SectionProps = ComponentPropsWithoutRef<"section"> & {
  title?: ReactNode;
};

export function Section({ title, className, children, ...props }: SectionProps) {
  return (
    <section className={cn("border-b border-border py-4 last:border-b-0", className)} {...props}>
      {title ? <h2 className="mb-2.5 text-sm leading-tight font-semibold tracking-[-0.012em]">{title}</h2> : null}
      {children}
    </section>
  );
}

export function EmptyToolState({ children }: { children?: ReactNode }) {
  return <div className="grid min-h-[360px] place-items-center text-sm text-secondary">{children}</div>;
}

export type ToolContentProps = ComponentPropsWithoutRef<"div">;

/**
 * Sole page-edge inset for every tool. Do not override `p` / `pt` / `pb` / `px`
 * on this wrapper — inner spacing must come from `gap` and section spacing only.
 * `overflow-hidden` keeps flex children from painting over the padding inset.
 */
export function ToolContent({ className, ...props }: ToolContentProps) {
  return (
    <div
      data-machkit-tool-content
      className={cn(
        "box-border h-full min-h-0 w-full overflow-hidden",
        "px-[var(--machkit-layout-content-padding)] pb-[var(--machkit-layout-content-padding)] pt-[var(--machkit-layout-content-padding-top)]",
        className,
      )}
      {...props}
    />
  );
}
