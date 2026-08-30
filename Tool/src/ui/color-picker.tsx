import React, { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import * as Popover from "@radix-ui/react-popover";
import { cn } from "@/lib/utils.js";
import { hsvToRgb, parseColor, rgbToHex } from "../../tools/color-lab/color.js";

type HsvState = { h: number; s: number; v: number; a: number };
type DragKind = "sv" | "hue";

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function hsvFromValue(value: string): HsvState {
  const parsed = parseColor(value) as
    | { ok: false }
    | { ok: true; hsv: { h: number; s: number; v: number }; rgb: { a?: number } };
  if (parsed.ok) return { ...parsed.hsv, a: parsed.rgb.a ?? 1 };
  return { h: 210, s: 100, v: 100, a: 1 };
}

function hexFromHsv(hsv: Pick<HsvState, "h" | "s" | "v">): string {
  return rgbToHex(hsvToRgb(hsv));
}

function readPoint(
  event: Pick<ReactPointerEvent, "clientX" | "clientY">,
  element: HTMLElement,
): { x: number; y: number } {
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return { x: 0, y: 0 };
  return {
    x: clamp((event.clientX - rect.left) / rect.width, 0, 1),
    y: clamp((event.clientY - rect.top) / rect.height, 0, 1),
  };
}

/**
 * Popover color picker anchored to a swatch trigger.
 * Replaces native `<input type="color">`, which mis-positions in WKWebView.
 */
export type ColorPickerProps = {
  value: string;
  onChange?: (hex: string) => void;
  label?: string;
  className?: string;
  side?: "top" | "right" | "bottom" | "left";
  align?: "start" | "center" | "end";
};

export function ColorPicker({
  value,
  onChange,
  label,
  className,
  side = "bottom",
  align = "end",
}: ColorPickerProps) {
  const [open, setOpen] = useState(false);
  const [hsv, setHsv] = useState<HsvState>(() => hsvFromValue(value));
  const svRef = useRef<HTMLDivElement>(null);
  const hueRef = useRef<HTMLDivElement>(null);
  const dragKindRef = useRef<DragKind | null>(null);

  useEffect(() => {
    if (open) return;
    setHsv(hsvFromValue(value));
  }, [value, open]);

  const commit = (next: Pick<HsvState, "h" | "s" | "v">) => {
    const clamped = {
      h: clamp(next.h, 0, 360),
      s: clamp(next.s, 0, 100),
      v: clamp(next.v, 0, 100),
    };
    setHsv((current) => ({ ...current, ...clamped }));
    onChange?.(hexFromHsv(clamped));
  };

  const onSvPointer = (event: ReactPointerEvent<HTMLDivElement>) => {
    const node = svRef.current;
    if (!node) return;
    const point = readPoint(event, node);
    commit({ ...hsv, s: point.x * 100, v: (1 - point.y) * 100 });
  };

  const onHuePointer = (event: ReactPointerEvent<HTMLDivElement>) => {
    const node = hueRef.current;
    if (!node) return;
    const point = readPoint(event, node);
    commit({ ...hsv, h: point.x * 360 });
  };

  const endDrag = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragKindRef.current) return;
    dragKindRef.current = null;
    try {
      event.currentTarget.releasePointerCapture(event.pointerId);
    } catch {
      // ignore
    }
  };

  const preview = hexFromHsv(hsv);
  const hueColor = rgbToHex(hsvToRgb({ h: hsv.h, s: 100, v: 100 }));

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger asChild>
        <button
          type="button"
          title={label}
          aria-label={label}
          className={cn(
            "relative size-[var(--machkit-size-control)] shrink-0 overflow-hidden rounded-control border border-border outline-none transition-colors",
            "focus-visible:ring-3 focus-visible:ring-accent/35",
            className,
          )}
        >
          <span
            className="absolute inset-0"
            style={{
              background: `linear-gradient(0deg, ${preview}, ${preview}), repeating-conic-gradient(#ccc 0% 25%, #fff 0% 50%) 0 0 / 8px 8px`,
            }}
          />
        </button>
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Content
          side={side}
          align={align}
          sideOffset={8}
          collisionPadding={16}
          avoidCollisions
          onOpenAutoFocus={(event) => event.preventDefault()}
          className="z-[300] w-[232px] rounded-panel border border-border bg-popover p-3 text-popover-foreground shadow-popover outline-none data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
        >
          <div
            ref={svRef}
            role="slider"
            tabIndex={0}
            aria-label="Saturation and brightness"
            aria-valuetext={`S ${Math.round(hsv.s)}%, V ${Math.round(hsv.v)}%`}
            className="relative h-[140px] w-full touch-none overflow-hidden rounded-control border border-border outline-none focus-visible:ring-3 focus-visible:ring-accent/35"
            style={{
              background: `
                linear-gradient(to top, #000, transparent),
                linear-gradient(to right, #fff, ${hueColor})
              `,
            }}
            onPointerDown={(event) => {
              if (event.button !== 0) return;
              dragKindRef.current = "sv";
              event.currentTarget.setPointerCapture(event.pointerId);
              onSvPointer(event);
            }}
            onPointerMove={(event) => {
              if (dragKindRef.current !== "sv") return;
              onSvPointer(event);
            }}
            onPointerUp={endDrag}
            onPointerCancel={endDrag}
          >
            <span
              className="pointer-events-none absolute size-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_0_0_1px_rgba(0,0,0,0.35)]"
              style={{
                left: `${hsv.s}%`,
                top: `${100 - hsv.v}%`,
                background: preview,
              }}
            />
          </div>

          <div
            ref={hueRef}
            role="slider"
            tabIndex={0}
            aria-label="Hue"
            aria-valuemin={0}
            aria-valuemax={360}
            aria-valuenow={Math.round(hsv.h)}
            className="relative mt-3 h-3 w-full touch-none rounded-full border border-border outline-none focus-visible:ring-3 focus-visible:ring-accent/35"
            style={{
              background:
                "linear-gradient(to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%)",
            }}
            onPointerDown={(event) => {
              if (event.button !== 0) return;
              dragKindRef.current = "hue";
              event.currentTarget.setPointerCapture(event.pointerId);
              onHuePointer(event);
            }}
            onPointerMove={(event) => {
              if (dragKindRef.current !== "hue") return;
              onHuePointer(event);
            }}
            onPointerUp={endDrag}
            onPointerCancel={endDrag}
          >
            <span
              className="pointer-events-none absolute top-1/2 size-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_0_0_1px_rgba(0,0,0,0.35)]"
              style={{
                left: `${(hsv.h / 360) * 100}%`,
                background: hueColor,
              }}
            />
          </div>

          <div className="mt-3 flex items-center gap-2">
            <span
              className="size-7 shrink-0 rounded-control border border-border"
              style={{ background: preview }}
              aria-hidden="true"
            />
            <span className="min-w-0 flex-1 truncate font-mono text-[12px] tabular-nums text-secondary">
              {preview}
            </span>
          </div>
          <Popover.Arrow className="fill-popover" />
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
