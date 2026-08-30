import type { ReactNode } from "react";
import { Check } from "@phosphor-icons/react";
import * as Checkbox from "@radix-ui/react-checkbox";
import { cn } from "@/lib/utils.js";

export type CheckboxFieldProps = {
  checked?: boolean | "indeterminate";
  onCheckedChange?: (checked: boolean | "indeterminate") => void;
  label: ReactNode;
  description?: ReactNode;
  disabled?: boolean;
  className?: string;
};

export function CheckboxField({
  checked,
  onCheckedChange,
  label,
  description,
  disabled = false,
  className,
}: CheckboxFieldProps) {
  return (
    <label
      className={cn(
        "inline-flex max-w-full cursor-default items-center gap-2 text-[13px] text-foreground select-none",
        description && "items-start",
        disabled && "opacity-45",
        className,
      )}
    >
      <Checkbox.Root
        checked={checked}
        onCheckedChange={onCheckedChange}
        disabled={disabled}
        className={cn(
          "grid size-4 shrink-0 place-items-center rounded-[4px] border border-border bg-field text-white outline-none transition-colors",
          "hover:border-accent focus-visible:ring-2 focus-visible:ring-accent/35",
          "data-[state=checked]:border-accent data-[state=checked]:bg-accent",
          "data-[state=indeterminate]:border-accent data-[state=indeterminate]:bg-accent",
          "disabled:pointer-events-none",
          description && "mt-0.5",
        )}
      >
        <Checkbox.Indicator className="grid place-items-center text-white">
          <Check size={11} weight="bold" />
        </Checkbox.Indicator>
      </Checkbox.Root>
      <span className="min-w-0">
        <span className="block text-[12px] leading-none font-medium text-secondary">{label}</span>
        {description ? (
          <span className="mt-1 block text-xs leading-relaxed text-tertiary">{description}</span>
        ) : null}
      </span>
    </label>
  );
}
