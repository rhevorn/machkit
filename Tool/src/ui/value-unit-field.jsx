import React from "react";
import { CaretDown, Check } from "@phosphor-icons/react";
import * as Select from "@radix-ui/react-select";
import { cn } from "@/lib/utils.js";

/**
 * Combined numeric value + optional unit select in one field shell.
 */
export function ValueUnitField({
  id,
  value,
  onChange,
  placeholder,
  invalid = false,
  unit,
  unitLabel,
  unitOptions = [],
  onUnitChange,
  className,
}) {
  const showUnit = unitOptions.length > 0;

  return (
    <div
      className={cn(
        "flex h-[var(--machkit-size-control)] min-w-0 items-stretch overflow-hidden rounded-control border bg-field transition-[border-color,box-shadow]",
        invalid
          ? "border-danger focus-within:border-danger focus-within:ring-3 focus-within:ring-danger/10"
          : "border-border focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft",
        className,
      )}
    >
      <input
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        spellCheck={false}
        aria-invalid={invalid || undefined}
        className="min-w-0 flex-1 border-0 bg-transparent px-3.5 font-mono text-[13px] tabular-nums text-foreground outline-none placeholder:text-tertiary"
      />
      {showUnit ? (
        <Select.Root value={unit} onValueChange={onUnitChange}>
          <Select.Trigger
            aria-label={unitLabel}
            className="inline-flex h-full w-[108px] shrink-0 items-center justify-between gap-1.5 border-l border-border bg-muted/45 px-3 text-[12px] text-foreground outline-none hover:bg-muted focus:bg-muted data-[state=open]:bg-muted"
          >
            <Select.Value />
            <Select.Icon className="shrink-0 text-secondary">
              <CaretDown size={13} />
            </Select.Icon>
          </Select.Trigger>
          <Select.Portal>
            <Select.Content
              position="popper"
              sideOffset={5}
              className="z-50 max-h-[300px] min-w-[var(--radix-select-trigger-width)] overflow-hidden rounded-panel border border-border bg-surface p-1 shadow-popover data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
            >
              <Select.Viewport>
                {unitOptions.map((option) => (
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
      ) : null}
    </div>
  );
}
