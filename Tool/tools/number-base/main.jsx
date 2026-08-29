import React, { useMemo, useState } from "react";
import { Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Field,
  PropertyList,
  PropertyRow,
  SidebarNavItem,
  ToolPage,
  ToolSidebar,
  ValueUnitField,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  convertCategory,
  defaultUnits,
  unitCategories,
  unitsForCategory,
} from "./number.js";
import { messages } from "./messages.js";

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
        <ToolSidebar width={136} className="px-2 py-3">
          <div className="machkit-sidebar-label px-2.5 pb-2">{text.category}</div>
          <nav className="flex min-h-0 flex-1 flex-col gap-0.5 overflow-auto" aria-label={text.category}>
            {unitCategories.map((id) => (
              <SidebarNavItem
                key={id}
                active={category === id}
                label={text[`tab_${id}`] || id}
                onClick={() => onCategoryChange(id)}
              />
            ))}
          </nav>
        </ToolSidebar>

        <section className="flex min-w-0 flex-1 flex-col border-l border-border/60">
          <header className="flex h-[var(--machkit-size-toolbar)] shrink-0 items-center gap-2 px-5">
            <span className="truncate text-sm font-semibold">
              {text[`tab_${category}`] || category}
            </span>
            <ActionGroup>
              <Button variant="ghost" size="sm" onClick={() => setInput("")}>
                <Eraser size={15} />
                {text.clear}
              </Button>
            </ActionGroup>
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

            <PropertyList className="mt-5 min-h-0 flex-1 overflow-auto">
              {rows.length ? (
                rows.map((row) => (
                  <PropertyRow
                    key={row.id}
                    label={row.label}
                    value={row.value}
                    copyLabel={text.copy}
                    labelClassName="w-[5.5rem]"
                    className="px-0"
                  />
                ))
              ) : (
                <p className="py-10 text-center text-xs text-tertiary">{text.empty}</p>
              )}
            </PropertyList>
          </div>
        </section>
      </div>
    </ToolPage>
  );
}

mountTool(<NumberBaseTool />, { name: "Unit Converter" });
