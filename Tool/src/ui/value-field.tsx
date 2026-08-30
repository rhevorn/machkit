import { CopySimpleIcon } from "@phosphor-icons/react";
import { cn } from "@/lib/utils.js";
import { Button } from "./button.js";

export type ValueFieldProps = {
  value?: string | null;
  placeholder?: string;
  copyLabel?: string;
  onCopy: (value: string) => void;
  invalid?: boolean;
  showCopyLabel?: boolean;
  className?: string;
};

export function ValueField({
  value,
  placeholder,
  copyLabel,
  onCopy,
  invalid = false,
  showCopyLabel = true,
  className,
}: ValueFieldProps) {
  const hasValue = Boolean(value);

  return (
    <div
      className={cn(
        "flex h-[var(--machkit-size-control)] w-full items-center overflow-hidden rounded-control border border-border bg-field",
        invalid && "border-danger",
        className,
      )}
    >
      <output
        aria-live="polite"
        className={cn(
          "min-w-0 flex-1 overflow-hidden px-3 font-mono text-[13px] tabular-nums text-ellipsis whitespace-nowrap text-foreground select-text",
          !hasValue && "font-sans text-tertiary",
          invalid && "text-danger",
        )}
      >
        {value || placeholder || "—"}
      </output>
      {hasValue ? (
        <Button
          variant="ghost"
          className="h-full rounded-none border-l border-border px-3 text-secondary"
          onClick={() => onCopy(value as string)}
          aria-label={copyLabel}
          title={copyLabel}
        >
          <CopySimpleIcon size={17} />
          {showCopyLabel ? <span className="max-[500px]:hidden">{copyLabel}</span> : null}
        </Button>
      ) : null}
    </div>
  );
}
