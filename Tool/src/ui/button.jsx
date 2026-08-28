import React from "react";
import { cva } from "class-variance-authority";
import { Info } from "@phosphor-icons/react";
import * as Popover from "@radix-ui/react-popover";
import { cn } from "@/lib/utils.js";

const buttonVariants = cva(
  "inline-flex shrink-0 cursor-default items-center justify-center gap-1.5 rounded-control font-sans text-xs font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/35 disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        default: "bg-accent text-white hover:bg-accent/90",
        secondary: "border border-border bg-surface text-foreground hover:bg-muted",
        ghost: "text-secondary hover:bg-muted hover:text-foreground",
        accentGhost: "text-accent hover:bg-accent-soft",
      },
      size: {
        default: "h-9 px-3.5",
        sm: "h-8.5 px-3",
        icon: "size-9 p-0",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export const Button = React.forwardRef(function Button(
  { className, variant, size, type = "button", ...props },
  ref,
) {
  return <button ref={ref} type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
});

export function IconButton({ label, children, className, ...props }) {
  return (
    <Button variant="ghost" size="icon" aria-label={label} title={label} className={className} {...props}>
      {children}
    </Button>
  );
}

export function ToolInfoButton({ info, className }) {
  if (!info) return null;

  return (
    <Popover.Root>
      <Popover.Trigger asChild>
        <IconButton label={info} className={cn("text-tertiary", className)}>
          <Info size={16} />
        </IconButton>
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Content
          align="end"
          sideOffset={8}
          className="z-50 w-[294px] rounded-panel border border-border bg-surface p-3.5 text-xs leading-relaxed text-secondary shadow-popover outline-none data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
        >
          {info}
          <Popover.Arrow className="fill-surface" />
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
