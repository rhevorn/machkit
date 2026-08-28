import React, { useMemo, useState } from "react";
import { CaretDown, Check, CopySimple, Eraser } from "@phosphor-icons/react";
import * as Select from "@radix-ui/react-select";
import {
  Button,
  Field,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  convertCategory,
  defaultUnits,
  unitCategories,
  unitsForCategory,
} from "./number.js";
import { messages } from "./messages.js";

function ResultRow({ label, value, copyLabel }) {
  const display = String(value ?? "");
  const hasValue = display.length > 0;
  return (
    <div className="flex min-w-0 items-baseline gap-2 border-b border-border/70 py-2 last:border-b-0">
      <span className="w-[5.5rem] shrink-0 text-[12px] text-secondary">{label}</span>
      <code
        className={cn(
          "min-w-0 flex-1 truncate font-mono text-[13px] tabular-nums select-text",
          hasValue ? "text-foreground" : "font-sans text-tertiary",
        )}
      >
        {hasValue ? display : "—"}
      </code>
      {hasValue ? (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 shrink-0 px-2 text-secondary"
          aria-label={copyLabel}
          title={copyLabel}
          onClick={() => machkit.copy(display)}
        >
          <CopySimple size={15} />
        </Button>
      ) : null}
    </div>
  );
}

function CategoryButton({ active, label, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex h-8.5 w-full items-center rounded-control px-2.5 text-left text-[13px] transition-colors",
        active
          ? "bg-foreground/[0.075] font-medium text-foreground"
          : "text-secondary hover:bg-foreground/[0.045] hover:text-foreground",
      )}
    >
      {label}
    </button>
  );
}

/** Combined value + optional unit control in one field shell. */
function ValueUnitField({
  id,
  value,
  onChange,
  placeholder,
  invalid = false,
  unit,
  unitLabel,
  unitOptions = [],
  onUnitChange,
}) {
  const showUnit = unitOptions.length > 0;

  return (
    <div
      className={cn(
        "flex h-10 min-w-0 items-stretch overflow-hidden rounded-control border bg-field transition-[border-color,box-shadow]",
        invalid
          ? "border-danger focus-within:border-danger focus-within:ring-3 focus-within:ring-danger/10"
          : "border-border focus-within:border-accent focus-within:ring-3 focus-within:ring-accent-soft",
      )}
    >
      <input
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        spellCheck={false}
        aria-invalid={invalid || undefined}
        className="min-w-0 flex-1 border-0 bg-transparent px-3.5 font-mono text-[15px] tabular-nums text-foreground outline-none placeholder:text-tertiary"
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
      ) : null}
    </div>
  );
}

function NumberBaseTool() {
  const text = useToolMessages(messages);
  const [category, setCategory] = useState("bases");
  const [input, setInput] = useState("255");
  const [unit, setUnit] = useState(defaultUnits.bytes);
  const [unitByCategory, setUnitByCategory] = useState(() => ({ ...defaultUnits }));

  const unitOptions = useMemo(() => {
    if (category === "bases") return [];
    return unitsForCategory(category).map((item) => ({
      value: item.id,
      label: item.label,
    }));
  }, [category]);

  const result = useMemo(
    () => convertCategory(category, input, unit),
    [category, input, unit],
  );

  const statusError = Boolean(input.trim()) && !result.ok;
  const errorLabel = !result.ok
    ? result.error === "too-large"
      ? text.tooLarge
      : text.invalid
    : null;

  function onCategoryChange(next) {
    setCategory(next);
    if (next === "bases") {
      setInput((prev) => prev || "255");
      return;
    }
    const nextUnit = unitByCategory[next] || defaultUnits[next];
    setUnit(nextUnit);
    if (next === "bytes" && !input.trim()) setInput("1");
    if (next === "temperature" && !input.trim()) setInput("25");
    if (next === "time" && !input.trim()) setInput("1000");
  }

  function onUnitChange(next) {
    setUnit(next);
    setUnitByCategory((prev) => ({ ...prev, [category]: next }));
  }

  const rows = useMemo(() => {
    if (!result.ok) return [];
    if (category === "bases") {
      return [
        { id: "bin", label: text.bin, value: result.formats.bin },
        { id: "oct", label: text.oct, value: result.formats.oct },
        { id: "dec", label: text.dec, value: result.formats.dec },
        { id: "hex", label: text.hex, value: result.formats.hex },
      ];
    }
    if (category === "bytes") {
      return unitsForCategory("bytes").map((item) => ({
        id: item.id,
        label: item.label,
        value: result.formats[item.id],
      }));
    }
    return result.rows || [];
  }, [category, result, text]);

  return (
    <ToolPage title={text.title}>
      <div className="flex min-h-0 flex-1 bg-surface">
        <aside className="flex w-[136px] shrink-0 flex-col px-2 py-3">
          <div className="machkit-sidebar-label px-2.5 pb-2">{text.category}</div>
          <nav className="flex min-h-0 flex-1 flex-col gap-0.5 overflow-auto" aria-label={text.category}>
            {unitCategories.map((id) => (
              <CategoryButton
                key={id}
                active={category === id}
                label={text[`tab_${id}`] || id}
                onClick={() => onCategoryChange(id)}
              />
            ))}
          </nav>
        </aside>

        <section className="flex min-w-0 flex-1 flex-col border-l border-border/60">
          <header className="flex h-12 shrink-0 items-center gap-2 px-5">
            <span className="truncate text-sm font-semibold">
              {text[`tab_${category}`] || category}
            </span>
            <div className="ml-auto flex items-center gap-1">
              <Button variant="ghost" size="sm" onClick={() => setInput("")}>
                <Eraser size={15} />
                {text.clear}
              </Button>
              <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
            </div>
          </header>

          <div className="flex min-h-0 flex-1 flex-col px-5 pb-5">
            <Field label={text.input} htmlFor="unit-input">
              <ValueUnitField
                id="unit-input"
                value={input}
                onChange={setInput}
                placeholder={
                  category === "bases"
                    ? text.placeholder
                    : category === "bytes"
                      ? text.bytesPlaceholder
                      : text.valuePlaceholder
                }
                invalid={statusError}
                unit={unit}
                unitLabel={text.unit}
                unitOptions={unitOptions}
                onUnitChange={onUnitChange}
              />
              {statusError ? (
                <p className="mt-2 text-[12px] text-danger">{errorLabel}</p>
              ) : null}
            </Field>

            <section className="mt-5 min-h-0 flex-1 overflow-auto">
              {rows.length ? (
                rows.map((row) => (
                  <ResultRow
                    key={row.id}
                    label={row.label}
                    value={row.value}
                    copyLabel={text.copy}
                  />
                ))
              ) : (
                <p className="py-10 text-center text-xs text-tertiary">{text.empty}</p>
              )}
            </section>
          </div>
        </section>
      </div>
    </ToolPage>
  );
}

mountTool(<NumberBaseTool />, { name: "Unit Converter" });
