import React, { useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  InlineMessage,
  SegmentedControl,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { formatXML, minifyXML, plistToJSON } from "./xml.js";
import { messages } from "./messages.js";

const SAMPLE_XML = `<note>
  <to>MachKit</to>
  <from>Local</from>
  <body>Hello</body>
</note>
`;

const SAMPLE_PLIST = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>machkit</string>
  <key>enabled</key>
  <true/>
</dict>
</plist>
`;

function XmlPlistTool() {
  const text = useToolMessages(messages);
  const [tab, setTab] = useState("xml");
  const [input, setInput] = useState(SAMPLE_XML);

  const xmlFormatted = useMemo(() => formatXML(input), [input]);
  const xmlMinified = useMemo(() => minifyXML(input), [input]);
  const plist = useMemo(() => plistToJSON(input), [input]);

  const output = tab === "xml" ? (xmlFormatted.ok ? xmlFormatted.text : "") : (plist.ok ? plist.text : "");

  const status = !input.trim()
    ? { tone: "neutral", label: text.empty }
    : tab === "xml"
      ? !xmlFormatted.ok
        ? { tone: "danger", label: xmlFormatted.error === "too-large" ? text.tooLarge : text.empty }
        : { tone: "info", label: text.format }
      : !plist.ok
        ? {
            tone: "danger",
            label:
              plist.error === "too-large"
                ? text.tooLarge
                : plist.error === "not-plist"
                  ? text.notPlist
                  : text.parseFailed,
          }
        : { tone: "info", label: "JSON" };

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <div className="machkit-toolbar flex-wrap gap-x-3 gap-y-2">
          <SegmentedControl
            value={tab}
            onChange={(value) => {
              setTab(value);
              setInput(value === "plist" ? SAMPLE_PLIST : SAMPLE_XML);
            }}
            label={text.title}
            size="compact"
            className="w-[180px] flex-none"
            options={[
              { value: "xml", label: text.tabXML },
              { value: "plist", label: text.tabPlist },
            ]}
          />
          <div className="ml-auto flex items-center gap-1">
            {tab === "xml" ? (
              <>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={!xmlFormatted.ok}
                  onClick={() => setInput(xmlFormatted.text)}
                >
                  {text.format}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={!xmlMinified.ok}
                  onClick={() => setInput(xmlMinified.text)}
                >
                  {text.minify}
                </Button>
              </>
            ) : null}
            <Button variant="ghost" size="sm" disabled={!output} onClick={() => machkit.copy(output)}>
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button variant="ghost" size="sm" onClick={() => setInput("")}>
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </div>
        </div>

        <InlineMessage tone={status.tone}>{status.label}</InlineMessage>

        <div className="grid gap-3 lg:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <label className="machkit-control-label">{text.input}</label>
            <Textarea
              className="min-h-[260px] font-mono text-[12px]"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              spellCheck={false}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="machkit-control-label">{text.output}</label>
            <Textarea
              className="min-h-[260px] font-mono text-[12px]"
              value={output}
              readOnly
              spellCheck={false}
            />
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<XmlPlistTool />, { name: "XML / Plist" });
