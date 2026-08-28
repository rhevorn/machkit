import { CopySimple } from "@phosphor-icons/react";
import { cn } from "@/lib/utils.js";
import { Button } from "./button.jsx";

export function ValueField({
  value,
  placeholder,
  copyLabel,
  onCopy,
  invalid = false,
  showCopyLabel = true,
  className,
}) {
  const hasValue = Boolean(value);

  return (
    <div
      className={cn(
        "flex h-9.5 w-full items-center overflow-hidden rounded-control border border-border bg-field",
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
          onClick={() => onCopy(value)}
          aria-label={copyLabel}
          title={copyLabel}
        >
          <CopySimple size={17} />
          {showCopyLabel ? <span className="max-[500px]:hidden">{copyLabel}</span> : null}
        </Button>
      ) : null}
    </div>
  );
}
