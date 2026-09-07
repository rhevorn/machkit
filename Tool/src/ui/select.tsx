import type { ReactNode } from "react";
import { CaretDownIcon, CheckIcon } from "@phosphor-icons/react";
import * as Select from "@radix-ui/react-select";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils.js";

export type SelectOption = {
  value: string;
  label: ReactNode;
};

const selectTriggerVariants = cva(
  "flex min-w-0 shrink-0 items-center justify-between gap-1.5 rounded-control text-[13px] leading-none outline-none",
  {
    variants: {
      variant: {
        default:
          "h-[var(--machkit-size-control)] min-h-[var(--machkit-size-control)] w-full gap-2 border border-border bg-field px-3 text-foreground hover:bg-muted focus:border-accent focus:ring-3 focus:ring-accent-soft",
        ghost:
          "h-6 w-auto border-0 bg-transparent px-1 text-[11px] text-tertiary hover:bg-muted hover:text-secondary focus-visible:ring-3 focus-visible:ring-accent/35 data-[state=open]:bg-muted data-[state=open]:text-secondary",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export type SelectControlProps = {
  value: string;
  options: SelectOption[];
  onChange: (value: string) => void;
  label?: string;
  className?: string;
} & VariantProps<typeof selectTriggerVariants>;

export function SelectControl({
  value,
  options,
  onChange,
  label,
  className,
  variant = "default",
}: SelectControlProps) {
  return (
    <Select.Root value={value} onValueChange={onChange}>
      <Select.Trigger aria-label={label} className={cn(selectTriggerVariants({ variant }), className)}>
        <Select.Value className="min-w-0 truncate" />
        <Select.Icon className={cn("shrink-0", variant === "ghost" ? "text-tertiary" : "text-secondary")}>
          <CaretDownIcon size={variant === "ghost" ? 11 : 14} />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content
          position="popper"
          sideOffset={5}
          className="z-50 max-h-[300px] min-w-[var(--radix-select-trigger-width)] overflow-hidden rounded-panel border border-border bg-surface p-1 shadow-popover data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
        >
          <Select.Viewport>
            {options.map((option) => (
              <Select.Item
                value={option.value}
                key={option.value}
                className="relative flex h-[var(--machkit-size-control)] cursor-default select-none items-center rounded-sm pr-8 pl-3 text-xs text-foreground outline-none data-[highlighted]:bg-accent-soft data-[highlighted]:text-accent"
              >
                <Select.ItemText>{option.label}</Select.ItemText>
                <Select.ItemIndicator className="absolute right-2 inline-flex items-center text-accent">
                  <CheckIcon size={14} weight="bold" />
                </Select.ItemIndicator>
              </Select.Item>
            ))}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  );
}
