import { Button, type ButtonProps } from "./button.js";
import { cn } from "@/lib/utils.js";

type ChipOption =
  | string
  | {
      value: string;
      label: string;
      id?: string;
    };

/**
 * Compact example / preset actions. Use instead of raw clickable chips.
 */
export type ExampleChipsProps = {
  label?: string;
  options?: ChipOption[];
  onSelect?: (value: string, option: ChipOption) => void;
  className?: string;
  size?: ButtonProps["size"];
};

export function ExampleChips({
  label,
  options = [],
  onSelect,
  className,
  size = "sm",
}: ExampleChipsProps) {
  if (!options.length) return null;

  return (
    <div className={cn("flex min-w-0 flex-wrap items-center gap-1.5", className)}>
      {label ? <span className="machkit-control-label mr-0.5">{label}</span> : null}
      {options.map((option) => {
        const value = typeof option === "string" ? option : option.value;
        const chipLabel = typeof option === "string" ? option : option.label;
        const key = typeof option === "string" ? option : option.id || option.value;
        return (
          <Button
            key={key}
            type="button"
            variant="secondary"
            size={size}
            className="h-7 max-w-full px-2.5 font-mono text-[11px] font-normal"
            onClick={() => onSelect?.(value, option)}
          >
            <span className="truncate">{chipLabel}</span>
          </Button>
        );
      })}
    </div>
  );
}
