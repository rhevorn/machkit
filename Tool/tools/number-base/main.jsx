import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  Input,
  SelectControl,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
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

function FormatRow({ label, value, copyLabel }) {
  return (
    <div className="flex min-w-0 items-center gap-2 border-b border-border px-3 py-2 last:border-b-0">
      <span className="w-24 shrink-0 text-[12px] text-secondary">{label}</span>
      <code className="min-w-0 flex-1 truncate font-mono text-[12px]">{value}</code>
      <Button variant="ghost" size="sm" className="shrink-0" onClick={() => machkit.copy(value)}>
        <CopySimple size={15} />
        {copyLabel}
      </Button>
    </div>
  );
}

function NumberBaseTool() {
  const text = useToolMessages(messages);
  const [category, setCategory] = useState("bases");
  const [input, setInput] = useState("255");
  const [unit, setUnit] = useState(defaultUnits.bytes);
  const [unitByCategory, setUnitByCategory] = useState(() => ({ ...defaultUnits }));

  const categoryOptions = useMemo(
    () =>
      unitCategories.map((id) => ({
        value: id,
        label: text[`tab_${id}`] || id,
      })),
    [text],
  );

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

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : !result.ok
      ? {
          tone: "danger",
          label: result.error === "too-large" ? text.tooLarge : text.invalid,
        }
      : {
          tone: "info",
          label:
            category === "bases"
              ? result.formats.dec
              : category === "bytes"
                ? `${result.formats.B} B`
                : result.rows?.[0]
                  ? `${result.rows[0].value} ${result.rows[0].label}`
                  : text.empty,
        };

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
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
          <SelectControl
            value={category}
            onChange={onCategoryChange}
            label={text.category}
            className="w-[140px] flex-none"
            options={categoryOptions}
          />
          <div className="ml-auto flex items-center gap-1">
            <Button variant="ghost" size="sm" onClick={() => setInput("")}>
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <label htmlFor="unit-input" className="machkit-control-label whitespace-nowrap">
            {text.input}
          </label>
          <Input
            id="unit-input"
            className="min-w-0 flex-1 font-mono"
            value={input}
            onChange={(event) => setInput(event.target.value)}
            placeholder={
              category === "bases"
                ? text.placeholder
                : category === "bytes"
                  ? text.bytesPlaceholder
                  : text.valuePlaceholder
            }
            spellCheck={false}
          />
          {category !== "bases" ? (
            <SelectControl
              value={unit}
              onChange={onUnitChange}
              label={text.unit}
              className="w-[110px] flex-none"
              options={unitOptions}
            />
          ) : null}
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="machkit-panel">
          {rows.length ? (
            rows.map((row) => (
              <FormatRow key={row.id} label={row.label} value={row.value} copyLabel={text.copy} />
            ))
          ) : (
            <p className="px-3 py-8 text-center text-xs text-tertiary">{text.empty}</p>
          )}
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<NumberBaseTool />, { name: "Unit Converter" });
