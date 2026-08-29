import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  ExampleChips,
  Input,
  ResultPanel,
  SegmentedControl,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  findMatches,
  highlightSegments,
  normalizeFlags,
  regexPresets,
  replaceMatches,
} from "./regex.js";
import { messages } from "./messages.js";

const FLAG_OPTIONS = [
  { key: "g", labelKey: "flagGlobal" },
  { key: "i", labelKey: "flagIgnoreCase" },
  { key: "m", labelKey: "flagMultiline" },
  { key: "s", labelKey: "flagDotAll" },
  { key: "u", labelKey: "flagUnicode" },
];

const PRESET_LABELS = {
  email: "presetEmail",
  url: "presetUrl",
  ipv4: "presetIpv4",
  uuid: "presetUuid",
  hexColor: "presetHexColor",
  whitespace: "presetWhitespace",
  numbers: "presetNumbers",
  quoted: "presetQuoted",
};

function toggleFlag(flags, key, enabled) {
  const set = new Set(normalizeFlags(flags));
  if (enabled) set.add(key);
  else set.delete(key);
  return normalizeFlags([...set].join(""));
}

function Seg({ children }) {
  return (
    <span className="shrink-0 select-none font-mono text-[13px] text-tertiary" aria-hidden="true">
      {children}
    </span>
  );
}

function FlagChip({ active, label, title, onClick }) {
  return (
    <Button
      type="button"
      title={title}
      aria-pressed={active}
      variant={active ? "secondary" : "ghost"}
      size="compact"
      className={cn(
        "h-7 min-w-7 px-2 font-mono text-xs",
        active && "border-transparent bg-accent-soft font-semibold text-accent hover:bg-accent-soft",
      )}
      onClick={onClick}
    >
      {label}
    </Button>
  );
}

function RegexLab() {
  const text = useToolMessages(messages);
  const [mode, setMode] = useState("test");
  const [pattern, setPattern] = useState(String.raw`(\w+)@(\w+\.\w+)`);
  const [flags, setFlags] = useState("gi");
  const [input, setInput] = useState("hello@example.com\nteam@machkit.app\nnot-an-email");
  const [replacement, setReplacement] = useState("$1 at $2");

  const matchResult = useMemo(
    () => findMatches(pattern, flags, input),
    [pattern, flags, input],
  );
  const replaceResult = useMemo(
    () => replaceMatches(pattern, flags, input, replacement),
    [pattern, flags, input, replacement],
  );
  const segments = useMemo(
    () => (matchResult.ok ? highlightSegments(input, matchResult.matches) : [{ type: "text", value: input }]),
    [input, matchResult],
  );

  const applyPreset = (preset) => {
    setPattern(preset.pattern);
    setFlags(normalizeFlags(preset.flags || "g"));
    setReplacement(preset.replacement ?? "");
  };

  const patternInvalid = Boolean(pattern) && !matchResult.ok;
  const statusLabel = !pattern
    ? text.emptyPattern
    : !matchResult.ok
      ? matchResult.error === "input-too-large"
        ? text.tooLarge
        : matchResult.error === "empty-pattern"
          ? text.emptyPattern
          : `${text.invalid}: ${matchResult.error}`
      : !input
        ? text.emptyInput
        : matchResult.matches.length
          ? `${matchResult.matches.length} ${text.matchCount}${matchResult.truncated ? ` · ${text.truncated}` : ""}`
          : text.noMatches;

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-4 pt-4 pb-6">
        <ToolToolbar className="gap-2">
          <SegmentedControl
            value={mode}
            onChange={setMode}
            label={text.title}
            size="compact"
            className="w-[200px] flex-none"
            options={[
              { value: "test", label: text.tabTest },
              { value: "replace", label: text.tabReplace },
            ]}
          />
          <ActionGroup>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setPattern("");
                setFlags("g");
                setInput("");
                setReplacement("");
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        <div className="flex flex-col gap-2">
          <span className="machkit-sidebar-label">{text.pattern}</span>
          <div
            className={cn(
              "flex items-center gap-1 rounded-panel border bg-surface px-2.5 py-1.5",
              patternInvalid ? "border-danger/40" : "border-border",
            )}
          >
            <Seg>/</Seg>
            <Input
              id="regex-pattern"
              className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-1.5 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-2 focus:ring-accent/25"
              value={pattern}
              onChange={(event) => setPattern(event.target.value)}
              placeholder={text.emptyPattern}
              spellCheck={false}
              aria-label={text.pattern}
              invalid={patternInvalid}
            />
            <Seg>/</Seg>
            <div
              className="ml-0.5 flex shrink-0 items-center gap-0.5"
              role="group"
              aria-label={text.flags}
            >
              {FLAG_OPTIONS.map((flag) => (
                <FlagChip
                  key={flag.key}
                  active={flags.includes(flag.key)}
                  label={flag.key}
                  title={text[flag.labelKey]}
                  onClick={() => setFlags(toggleFlag(flags, flag.key, !flags.includes(flag.key)))}
                />
              ))}
            </div>
          </div>
          <ExampleChips
            label={text.presets}
            options={regexPresets.map((preset) => ({
              id: preset.id,
              value: preset.id,
              label: text[PRESET_LABELS[preset.id]] || preset.id,
            }))}
            onSelect={(id) => {
              const preset = regexPresets.find((item) => item.id === id);
              if (preset) applyPreset(preset);
            }}
          />
        </div>

        {patternInvalid ? (
          <StatusStrip tone="danger">{statusLabel}</StatusStrip>
        ) : (
          <StatusStrip tone="info">{statusLabel}</StatusStrip>
        )}

        {mode === "replace" ? (
          <div className="flex flex-col gap-2">
            <span className="machkit-sidebar-label">{text.replace}</span>
            <div className="flex items-center gap-1 rounded-panel border border-border bg-surface px-2.5 py-1.5">
              <Input
                id="regex-replace"
                className="h-8 min-w-0 flex-1 border-transparent bg-transparent px-1.5 font-mono shadow-none focus:border-accent focus:bg-field focus:ring-2 focus:ring-accent/25"
                value={replacement}
                onChange={(event) => setReplacement(event.target.value)}
                spellCheck={false}
                aria-label={text.replace}
                placeholder="$1"
              />
              <Button
                variant="ghost"
                size="sm"
                className="h-7 shrink-0 px-2 text-secondary"
                disabled={!replaceResult.ok || !replaceResult.value}
                aria-label={text.copy}
                title={text.copy}
                onClick={() => machkit.copy(replaceResult.value)}
              >
                <CopySimple size={15} />
                <span className="max-[520px]:hidden">{text.copy}</span>
              </Button>
            </div>
          </div>
        ) : null}

        <div className="grid min-w-0 gap-3 sm:grid-cols-2">
          <div className="flex min-w-0 flex-col gap-2">
            <span className="machkit-sidebar-label">{text.test}</span>
            <Textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.emptyInput}
              className="h-[150px] min-h-[150px] w-full resize-y font-mono text-[12px]"
              spellCheck={false}
            />
          </div>

          {mode === "test" ? (
            <div className="flex min-w-0 flex-col gap-2">
              <span className="machkit-sidebar-label">{text.preview}</span>
              <ResultPanel
                className="h-[150px] min-h-[150px] bg-surface"
                bodyClassName="h-full overflow-auto px-3 py-2.5 font-mono text-[12px] leading-5 whitespace-pre-wrap break-words"
              >
                {input ? (
                  segments.map((segment, index) =>
                    segment.type === "match" ? (
                      <mark
                        key={`${segment.matchIndex}-${index}`}
                        className="regex-match-mark rounded-[3px] px-0.5"
                      >
                        {segment.value}
                      </mark>
                    ) : (
                      <span key={`text-${index}`}>{segment.value}</span>
                    ),
                  )
                ) : (
                  <span className="text-tertiary">{text.emptyInput}</span>
                )}
              </ResultPanel>
            </div>
          ) : (
            <div className="flex min-w-0 flex-col gap-2">
              <span className="machkit-sidebar-label">{text.result}</span>
              <Textarea
                readOnly
                value={replaceResult.ok ? replaceResult.value : ""}
                placeholder={text.result}
                className="h-[150px] min-h-[150px] w-full resize-y bg-accent-soft/40 font-mono text-[12px]"
              />
            </div>
          )}
        </div>

        {mode === "test" ? (
          <div className="flex flex-col gap-2">
            <span className="machkit-sidebar-label">{text.matches}</span>
            <ResultPanel className="max-h-[180px] overflow-auto bg-surface">
              {matchResult.ok && matchResult.matches.length ? (
                <ul>
                  {matchResult.matches.map((match, index) => (
                    <li
                      key={`${match.index}-${index}`}
                      className="flex min-w-0 items-baseline gap-2 border-b border-border/60 px-3.5 py-2 last:border-b-0"
                    >
                      <span className="w-7 shrink-0 text-[11px] tabular-nums text-tertiary">
                        #{index + 1}
                      </span>
                      <div className="min-w-0 flex-1 font-mono text-[12px]">
                        <div className="truncate text-accent">{match.text}</div>
                        <div className="mt-0.5 flex flex-wrap gap-x-2 gap-y-0.5 text-[11px] text-secondary">
                          <span className="text-tertiary">@{match.index}</span>
                          {match.groups.map((group) => (
                            <span key={group.index}>
                              ${group.index}={JSON.stringify(group.value)}
                            </span>
                          ))}
                          {Object.entries(match.named).map(([name, value]) => (
                            <span key={name}>
                              {`<${name}>`}={JSON.stringify(value)}
                            </span>
                          ))}
                        </div>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-7 shrink-0 px-2 text-secondary"
                        aria-label={text.copy}
                        title={text.copy}
                        onClick={() => machkit.copy(match.text)}
                      >
                        <CopySimple size={14} />
                      </Button>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="px-3 py-6 text-center text-xs text-tertiary">{text.noMatches}</p>
              )}
            </ResultPanel>
          </div>
        ) : null}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<RegexLab />, { name: "Regex Lab" });
