import { cn } from "@/lib/utils.js";

export function Textarea({ className, invalid = false, ...props }) {
  return (
    <textarea
      className={cn(
        "min-h-28 w-full resize-y rounded-control border border-border bg-field px-3.5 py-3 font-mono text-[13px] leading-[1.65] text-foreground outline-none transition-[border-color,box-shadow] placeholder:text-tertiary focus:border-accent focus:ring-3 focus:ring-accent-soft",
        invalid && "border-danger focus:border-danger focus:ring-danger/10",
        className,
      )}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
}
