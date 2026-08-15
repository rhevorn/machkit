import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  Input,
  SegmentedControl,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
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

  const status = !pattern
    ? text.emptyPattern
    : !matchResult.ok
      ? (matchResult.error === "input-too-large"
        ? text.tooLarge
        : matchResult.error === "empty-pattern"
          ? text.emptyPattern
          : `${text.invalid}: ${matchResult.error}`)
      : !input
        ? text.emptyInput
        : matchResult.matches.length
          ? `${matchResult.matches.length} ${text.matchCount}${matchResult.truncated ? ` · ${text.truncated}` : ""}`
          : text.noMatches;

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar gap-2">
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
          <div className="ml-auto flex items-center gap-1">
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
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        <div className="flex flex-col gap-1.5">
          <label htmlFor="regex-pattern" className="machkit-control-label">
            {text.pattern}
          </label>
          <div className="flex items-center gap-2">
            <Input
              id="regex-pattern"
              className="min-w-0 flex-1 font-mono"
              value={pattern}
              onChange={(event) => setPattern(event.target.value)}
              placeholder={text.emptyPattern}
              spellCheck={false}
            />
            <div
              className="flex h-9.5 shrink-0 items-center gap-0.5 rounded-control bg-muted p-0.5"
              role="group"
              aria-label={text.flags}
            >
              {FLAG_OPTIONS.map((flag) => {
                const active = flags.includes(flag.key);
                return (
                  <button
                    key={flag.key}
                    type="button"
                    title={text[flag.labelKey]}
                    aria-pressed={active}
                    className={
                      active
                        ? "h-full min-w-7 rounded-[6px] bg-surface px-2 font-mono text-xs font-semibold text-accent shadow-segment"
                        : "h-full min-w-7 rounded-[6px] px-2 font-mono text-xs font-medium text-secondary hover:text-foreground"
                    }
                    onClick={() => setFlags(toggleFlag(flags, flag.key, !active))}
                  >
                    {flag.key}
                  </button>
                );
              })}
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] leading-4 text-tertiary">
            <span>{text.presets}</span>
            {regexPresets.map((preset) => (
              <button
                key={preset.id}
                type="button"
                className="text-secondary hover:text-accent"
                onClick={() => applyPreset(preset)}
              >
                {text[PRESET_LABELS[preset.id]] || preset.id}
              </button>
            ))}
          </div>
        </div>

        {mode === "test" ? (
          <>
            <div className="grid min-h-0 gap-2.5 lg:grid-cols-2">
              <label className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.test}</span>
                <Textarea
                  value={input}
                  onChange={(event) => setInput(event.target.value)}
                  placeholder={text.emptyInput}
                  className="h-[150px] min-h-[150px] w-full resize-y font-mono text-[12px]"
                  spellCheck={false}
                />
              </label>

              <div className="flex min-w-0 flex-col gap-1.5">
                <div className="flex items-center gap-2">
                  <span className="machkit-control-label">{text.preview}</span>
                  <span className="truncate text-[11px] text-tertiary">{status}</span>
                </div>
                <div className="machkit-panel h-[150px] min-h-[150px] overflow-auto whitespace-pre-wrap break-words p-2.5 font-mono text-[12px] leading-5">
                  {segments.map((segment, index) => (
                    segment.type === "match" ? (
                      <mark key={`${segment.matchIndex}-${index}`} className="regex-match-mark rounded-[3px] px-0.5">
                        {segment.value}
                      </mark>
                    ) : (
                      <span key={`text-${index}`}>{segment.value}</span>
                    )
                  ))}
                </div>
              </div>
            </div>

            <div className="flex min-h-0 flex-col gap-1.5">
              <span className="machkit-control-label">{text.matches}</span>
              <div className="machkit-panel max-h-[160px] overflow-auto">
                {matchResult.ok && matchResult.matches.length ? (
                  <ul className="divide-y divide-border">
                    {matchResult.matches.map((match, index) => (
                      <li key={`${match.index}-${index}`} className="px-3 py-1.5 font-mono text-[12px]">
                        <div className="flex flex-wrap items-baseline gap-x-3 gap-y-0.5">
                          <span className="text-tertiary">#{index + 1}</span>
                          <span className="text-accent">{match.text}</span>
                          <span className="text-tertiary">@{match.index}</span>
                          {match.groups.length ? (
                            <span className="text-secondary">
                              {match.groups.map((group) => (
                                <span key={group.index} className="mr-2">
                                  ${group.index}={JSON.stringify(group.value)}
                                </span>
                              ))}
                            </span>
                          ) : null}
                          {Object.keys(match.named).length ? (
                            <span className="text-secondary">
                              {Object.entries(match.named).map(([name, value]) => (
                                <span key={name} className="mr-2">
                                  {`<${name}>`}={JSON.stringify(value)}
                                </span>
                              ))}
                            </span>
                          ) : null}
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="px-3 py-4 text-center text-xs text-tertiary">{text.noMatches}</p>
                )}
              </div>
            </div>
          </>
        ) : (
          <>
            <div className="machkit-toolbar gap-2">
              <div className="flex min-w-0 flex-1 items-center gap-2">
                <label htmlFor="regex-replace" className="machkit-control-label whitespace-nowrap">
                  {text.replace}
                </label>
                <Input
                  id="regex-replace"
                  className="min-w-0 flex-1 font-mono"
                  value={replacement}
                  onChange={(event) => setReplacement(event.target.value)}
                  spellCheck={false}
                />
              </div>
              <Button
                variant="ghost"
                size="sm"
                disabled={!replaceResult.ok || !replaceResult.value}
                onClick={() => machkit.copy(replaceResult.value)}
              >
                <CopySimple size={15} />
                {text.copy}
              </Button>
            </div>

            <div className="grid min-h-0 gap-2.5 lg:grid-cols-2">
              <label className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.test}</span>
                <Textarea
                  value={input}
                  onChange={(event) => setInput(event.target.value)}
                  placeholder={text.emptyInput}
                  className="h-[220px] min-h-[220px] w-full resize-y font-mono text-[12px]"
                  spellCheck={false}
                />
              </label>
              <div className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.result}</span>
                <Textarea
                  readOnly
                  value={replaceResult.ok ? replaceResult.value : ""}
                  className="h-[220px] min-h-[220px] w-full resize-y font-mono text-[12px] bg-field"
                />
              </div>
            </div>
          </>
        )}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<RegexLab />, { name: "Regex Lab" });
