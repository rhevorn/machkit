import React from "react";
import { cva } from "class-variance-authority";
import { CaretDown, Check, CheckCircle, CopySimple, Info, WarningCircle } from "@phosphor-icons/react";
import * as Checkbox from "@radix-ui/react-checkbox";
import * as Label from "@radix-ui/react-label";
import * as Popover from "@radix-ui/react-popover";
import * as Select from "@radix-ui/react-select";
import * as ToggleGroup from "@radix-ui/react-toggle-group";
import { cn } from "@/lib/cn.js";
import { useLocale } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import "./ui.css";

const copiedLabels = {
  en: { success: "Copied", failure: "Copy failed" },
  "zh-Hans": { success: "已复制", failure: "复制失败" },
  "zh-Hant": { success: "已複製", failure: "複製失敗" },
  ja: { success: "コピーしました", failure: "コピーできませんでした" },
  ko: { success: "복사됨", failure: "복사 실패" },
  es: { success: "Copiado", failure: "Error al copiar" },
  fr: { success: "Copié", failure: "Échec de la copie" },
  de: { success: "Kopiert", failure: "Kopieren fehlgeschlagen" },
  "pt-BR": { success: "Copiado", failure: "Falha ao copiar" },
  ru: { success: "Скопировано", failure: "Не удалось скопировать" },
};

const buttonVariants = cva(
  "inline-flex shrink-0 cursor-default items-center justify-center gap-1.5 rounded-control font-sans text-xs font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/35 disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        default: "bg-accent text-white hover:bg-accent/90",
        secondary: "border border-border bg-surface text-foreground hover:bg-muted",
        ghost: "text-secondary hover:bg-muted hover:text-foreground",
        accentGhost: "text-accent hover:bg-accent-soft",
      },
      size: {
        default: "h-9 px-3.5",
        sm: "h-8.5 px-3",
        icon: "size-9 p-0",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export const Button = React.forwardRef(function Button(
  { className, variant, size, type = "button", ...props },
  ref,
) {
  return <button ref={ref} type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
});

export function IconButton({ label, children, className, ...props }) {
  return (
    <Button variant="ghost" size="icon" aria-label={label} title={label} className={className} {...props}>
      {children}
    </Button>
  );
}

export function ToolInfoButton({ info, className }) {
  if (!info) return null;

  return (
    <Popover.Root>
      <Popover.Trigger asChild>
        <IconButton label={info} className={cn("text-tertiary", className)}>
          <Info size={16} />
        </IconButton>
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Content
          align="end"
          sideOffset={8}
          className="z-50 w-[294px] rounded-panel border border-border bg-surface p-3.5 text-xs leading-relaxed text-secondary shadow-popover outline-none data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95"
        >
          {info}
          <Popover.Arrow className="fill-surface" />
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}

export function ToolPage({ title, info, adaptiveHeight = false, children }) {
  const pageRef = React.useRef(null);

  React.useEffect(() => {
    document.title = title;
  }, [title]);

  React.useEffect(() => {
    if (!adaptiveHeight || !machkit.isEmbedded || typeof ResizeObserver === "undefined") return undefined;

    const content = pageRef.current?.querySelector(":scope > [data-machkit-tool-content]");
    if (!content) return undefined;

    let animationFrame = 0;
    let lastHeight = 0;
    const measure = () => {
      window.cancelAnimationFrame(animationFrame);
      animationFrame = window.requestAnimationFrame(() => {
        const height = Math.ceil(Math.max(content.scrollHeight, content.getBoundingClientRect().height));
        if (Math.abs(height - lastHeight) < 2) return;
        lastHeight = height;
        machkit.fitContentHeight(height);
      });
    };

    const observer = new ResizeObserver(measure);
    observer.observe(content);
    measure();
    document.fonts?.ready.then(measure);

    return () => {
      observer.disconnect();
      window.cancelAnimationFrame(animationFrame);
    };
  }, [adaptiveHeight]);

  return (
    <main ref={pageRef} className="relative flex h-full min-h-full flex-col bg-surface font-sans text-[13px] text-foreground">
      {info ? (
        <div className="absolute top-2 right-5 z-20">
          <ToolInfoButton info={info} />
        </div>
      ) : null}
      {children}
      <CopyFeedbackToast />
    </main>
  );
}

function CopyFeedbackToast() {
  const locale = useLocale();
  const [toast, setToast] = React.useState(null);
  const timeoutRef = React.useRef(0);

  React.useEffect(() => {
    const showToast = (event) => {
      window.clearTimeout(timeoutRef.current);
      setToast({ id: Date.now(), ok: event.detail?.ok !== false });
      timeoutRef.current = window.setTimeout(() => setToast(null), 1800);
    };
    window.addEventListener("machkit:copy-result", showToast);
    return () => {
      window.removeEventListener("machkit:copy-result", showToast);
      window.clearTimeout(timeoutRef.current);
    };
  }, []);

  if (!toast) return null;
  const labels = copiedLabels[locale] || copiedLabels.en;

  return (
    <div
      key={toast.id}
      role="status"
      aria-live="polite"
      className={cn(
        "pointer-events-none fixed bottom-5 left-1/2 z-[100] inline-flex -translate-x-1/2 items-center gap-2 rounded-full border px-3.5 py-2 text-xs font-medium shadow-popover animate-in fade-in-0 slide-in-from-bottom-2 duration-150",
        toast.ok ? "border-border bg-foreground text-surface" : "border-danger/25 bg-danger text-white",
      )}
    >
      {toast.ok ? <CheckCircle size={16} weight="fill" /> : <WarningCircle size={16} weight="fill" />}
      {toast.ok ? labels.success : labels.failure}
    </div>
  );
}

export function ToolContent({ className, ...props }) {
  return <div data-machkit-tool-content className={cn("w-full px-7 pb-6 max-[680px]:px-6", className)} {...props} />;
}

export function Section({ title, className, children, ...props }) {
  return (
    <section className={cn("border-b border-border py-4 last:border-b-0", className)} {...props}>
      {title ? <h2 className="mb-2.5 text-sm leading-tight font-semibold tracking-[-0.012em]">{title}</h2> : null}
      {children}
    </section>
  );
}

export function Field({ label, htmlFor, className, children }) {
  return (
    <div className={className}>
      <Label.Root htmlFor={htmlFor} className="mb-2 block text-xs font-medium text-secondary">
        {label}
      </Label.Root>
      {children}
    </div>
  );
}

export const Input = React.forwardRef(function Input({ className, invalid = false, ...props }, ref) {
  return (
    <input
      ref={ref}
      className={cn(
        "h-9.5 w-full rounded-control border border-border bg-field px-3.5 font-sans text-[13px] text-foreground outline-none transition-[border-color,box-shadow] placeholder:text-tertiary focus:border-accent focus:ring-3 focus:ring-accent-soft",
        invalid && "border-danger focus:border-danger focus:ring-danger/10",
        className,
      )}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
});

export function SegmentedControl({ value, options, onChange, label, className, size = "default" }) {
  const compact = size === "compact";

  return (
    <ToggleGroup.Root
      type="single"
      value={value}
      onValueChange={(nextValue) => nextValue && onChange(nextValue)}
      aria-label={label}
      className={cn("grid h-9.5 flex-1 auto-cols-fr grid-flow-col gap-0.5 rounded-control bg-muted p-0.5", className)}
    >
      {options.map((option) => (
        <ToggleGroup.Item
          value={option.value}
          key={option.value}
          className={cn(
            "min-w-0 overflow-hidden rounded-[6px] text-ellipsis whitespace-nowrap text-xs font-medium text-secondary outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-accent/35 data-[state=on]:bg-surface data-[state=on]:text-accent data-[state=on]:shadow-segment",
            compact ? "px-1" : "px-2",
          )}
        >
          {option.label}
        </ToggleGroup.Item>
      ))}
    </ToggleGroup.Root>
  );
}

export function SelectControl({ value, options, onChange, label, className }) {
  return (
    <Select.Root value={value} onValueChange={onChange}>
      <Select.Trigger
        aria-label={label}
        className={cn(
          "flex h-9.5 min-w-0 flex-1 items-center justify-between gap-2 rounded-control border border-border bg-field px-3.5 text-xs text-foreground outline-none hover:bg-muted focus:border-accent focus:ring-3 focus:ring-accent-soft",
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
                className="relative flex h-9 cursor-default select-none items-center rounded-[6px] pr-8 pl-3 text-xs text-foreground outline-none data-[highlighted]:bg-accent-soft data-[highlighted]:text-accent"
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

export function EmptyToolState({ children }) {
  return <div className="grid min-h-[360px] place-items-center px-6 text-sm text-secondary">{children}</div>;
}

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

export function Textarea({ className, invalid = false, ...props }) {
  return (
    <textarea
      className={cn(
        "min-h-28 w-full resize-y rounded-control border border-border bg-field px-3.5 py-3 font-mono text-[13px] leading-[1.65] text-foreground outline-none transition-[border-color,box-shadow] placeholder:text-tertiary focus:border-accent focus:ring-3 focus:ring-accent-soft",
        invalid && "border-danger focus:border-danger focus:ring-danger/10",
        className,
      )}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
}

export function InlineMessage({ children, tone = "neutral", className }) {
  return (
    <div
      className={cn(
        "rounded-control px-3.5 py-2.5 text-xs leading-relaxed",
        tone === "neutral" && "border border-border bg-transparent text-secondary",
        tone === "info" && "bg-accent-soft text-accent",
        tone === "danger" && "bg-danger/10 text-danger",
        className,
      )}
    >
      {children}
    </div>
  );
}
