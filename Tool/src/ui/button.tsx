import React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils.js";

const buttonVariants = cva(
  "inline-flex shrink-0 cursor-default items-center justify-center gap-1.5 rounded-control font-sans text-xs font-medium outline-none transition-colors focus-visible:ring-3 focus-visible:ring-accent/35 disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        default: "bg-accent text-white hover:bg-accent/90",
        secondary: "border border-border bg-surface text-foreground hover:bg-muted",
        ghost: "text-secondary hover:bg-muted hover:text-foreground",
        accentGhost: "text-accent hover:bg-accent-soft",
        destructive: "bg-danger text-white hover:bg-danger/90",
      },
      size: {
        default: "h-[var(--machkit-size-control)] px-3.5",
        /* Match field / select / segmented height in compact toolbars */
        sm: "h-[var(--machkit-size-control)] px-3",
        compact: "h-[var(--machkit-size-control-compact)] px-2.5",
        icon: "size-[var(--machkit-size-control)] p-0",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export type ButtonProps = React.ComponentPropsWithoutRef<"button"> & VariantProps<typeof buttonVariants>;

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { className, variant, size, type = "button", ...props },
  ref,
) {
  return <button ref={ref} type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
});

export type IconButtonProps = Omit<ButtonProps, "aria-label" | "children"> & {
  label: string;
  children?: React.ReactNode;
};

export function IconButton({ label, children, className, ...props }: IconButtonProps) {
  return (
    <Button variant="ghost" size="icon" aria-label={label} title={label} className={className} {...props}>
      {children}
    </Button>
  );
}
