import { CaretDown, Check } from "@phosphor-icons/react";
import * as Select from "@radix-ui/react-select";
import { cn } from "@/lib/utils.js";

export function SelectControl({ value, options, onChange, label, className }) {
  return (
    <Select.Root value={value} onValueChange={onChange}>
      <Select.Trigger
        aria-label={label}
        className={cn(
          "flex h-[var(--machkit-size-control)] min-w-0 flex-1 items-center justify-between gap-2 rounded-control border border-border bg-field px-3 text-xs text-foreground outline-none hover:bg-muted focus:border-accent focus:ring-3 focus:ring-accent-soft",
          className,
        )}
      >
        <Select.Value />
        <Select.Icon className="shrink-0 text-secondary"><CaretDown size={14} /></Select.Icon>
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
                  <Check size={14} weight="bold" />
                </Select.ItemIndicator>
              </Select.Item>
            ))}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  );
}
