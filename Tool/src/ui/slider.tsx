import type { ChangeEvent, ComponentPropsWithoutRef, ReactNode } from "react";
import { cn } from "@/lib/utils.js";

export type SliderMark = {
  value: number | string;
  label: ReactNode;
};

/**
 * Shared range slider. Prefer this over raw `<input type="range">`.
 * Pass `marks` for discrete stops with labels under the track.
 */
export type SliderProps = Omit<ComponentPropsWithoutRef<"input">, "onChange" | "type" | "value"> & {
  label?: ReactNode;
  value: number | string;
  displayValue?: ReactNode;
  marks?: SliderMark[];
  onChange?: (value: number, event: ChangeEvent<HTMLInputElement>) => void;
};

export function Slider({
  id,
  label,
  value,
  displayValue,
  min = 0,
  max = 100,
  step = 1,
  marks,
  onChange,
  className,
  disabled = false,
  ...props
}: SliderProps) {
  const hasMarks = Array.isArray(marks) && marks.length > 0;

  return (
    <label className={cn("flex min-w-0 flex-col gap-1.5", className)}>
      {label ? (
        <span className="machkit-control-label flex items-center justify-between gap-2">
          <span>{label}</span>
          <span className="font-mono text-foreground tabular-nums">{displayValue ?? value}</span>
        </span>
      ) : null}
      <div className={cn("relative", hasMarks && "pb-4")}>
        <input
          id={id}
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          disabled={disabled}
          aria-label={typeof label === "string" ? label : props["aria-label"]}
          aria-valuetext={displayValue != null ? String(displayValue) : undefined}
          onChange={(event) => onChange?.(Number(event.target.value), event)}
          className="machkit-slider h-7 w-full cursor-default disabled:opacity-45"
          {...props}
        />
        {hasMarks ? (
          <div className="pointer-events-none absolute inset-x-[7px] top-[22px] flex justify-between">
            {marks.map((mark) => {
              const active = Number(mark.value) === Number(value);
              return (
                <span
                  key={String(mark.value)}
                  className={cn(
                    "flex w-0 flex-col items-center text-[10px] leading-tight tabular-nums",
                    active ? "font-medium text-foreground" : "text-tertiary",
                  )}
                >
                  <span className="mb-1 size-1 rounded-full bg-current opacity-70" aria-hidden />
                  <span>{mark.label}</span>
                </span>
              );
            })}
          </div>
        ) : null}
      </div>
    </label>
  );
}
