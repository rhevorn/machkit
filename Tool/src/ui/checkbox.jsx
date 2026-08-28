import { Check } from "@phosphor-icons/react";
import * as Checkbox from "@radix-ui/react-checkbox";

export function CheckboxField({ checked, onCheckedChange, label, description, disabled = false }) {
  return (
    <label className="flex items-start gap-3 text-[13px] text-foreground">
      <Checkbox.Root
        checked={checked}
        onCheckedChange={onCheckedChange}
        disabled={disabled}
        className="mt-0.5 grid size-4.5 shrink-0 place-items-center rounded-[4px] border border-border bg-field text-white outline-none transition-colors hover:border-accent focus-visible:ring-2 focus-visible:ring-accent/35 data-[state=checked]:border-accent data-[state=checked]:bg-accent disabled:opacity-45"
      >
        <Checkbox.Indicator><Check size={12} weight="bold" /></Checkbox.Indicator>
      </Checkbox.Root>
      <span className="min-w-0">
        <span className="block font-medium">{label}</span>
        {description ? <span className="mt-0.5 block text-xs leading-relaxed text-secondary">{description}</span> : null}
      </span>
    </label>
  );
}
