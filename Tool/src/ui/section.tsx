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
  return <div className="grid min-h-[360px] place-items-center px-6 text-sm text-secondary">{children}</div>;
}

export type ToolContentProps = ComponentPropsWithoutRef<"div">;

export function ToolContent({ className, ...props }: ToolContentProps) {
  return <div data-machkit-tool-content className={cn("w-full px-7 pb-6 max-[680px]:px-6", className)} {...props} />;
}
