import React from "react";
import { cn } from "@/lib/utils.js";

export const Input = React.forwardRef(function Input({ className, invalid = false, ...props }, ref) {
  return (
    <input
      ref={ref}
      className={cn(
        "h-9.5 w-full rounded-control border border-border bg-field px-3.5 font-sans text-[13px] text-foreground outline-none transition-[border-color,box-shadow] placeholder:text-tertiary focus:border-accent focus:ring-3 focus:ring-accent-soft",
        invalid && "border-danger focus:border-danger focus:ring-danger/10",
        className,
      )}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
});
