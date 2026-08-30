import React, { useEffect, useRef, useState } from "react";
import { ArrowsLeftRight, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  CheckboxField,
  IconButton,
  SegmentedControl,
  SelectControl,
  SidebarNavItem,
  StatusStrip,
  Textarea,
  ToolPage,
  ToolSidebar,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import { convertCodec, hashAlgorithms, type ConvertCodecResult } from "./codec.js";
import { messages } from "./messages.js";

type CodecMessages = (typeof messages)["en"];

const CODEC_GROUPS = [
  {
    id: "binary" as const,
    items: [
      { id: "base64", code: "64" },
      { id: "base32", code: "32" },
      { id: "base62", code: "62" },
      { id: "hex", code: "Hx" },
    ],
  },
  {
    id: "text" as const,
    items: [
      { id: "url", code: "%" },
      { id: "html", code: "<>" },
      { id: "unicode", code: "\\u" },
      { id: "escape", code: "\\n" },
    ],
  },
  {
    id: "digest" as const,
    items: [{ id: "hash", code: "#" }],
  },
];

type WorkerReply = {
  id: number;
  result: ConvertCodecResult;
};

function messageFor(text: CodecMessages, key: string): string {
  return (text as Record<string, string>)[key] || key;
}

function CodecTool() {
  const text = useToolMessages(messages);
  const [tab, setTab] = useState("base64");
  const [direction, setDirection] = useState("encode");
  const [input, setInput] = useState("");
  const [output, setOutput] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [algorithm, setAlgorithm] = useState("SHA-256");
  const [urlMode, setUrlMode] = useState("component");
  const [base64URL, setBase64URL] = useState(false);
  const workerRef = useRef<Worker | null>(null);
  const conversionIDRef = useRef(0);

  useEffect(() => {
    if (typeof Worker === "undefined") return undefined;
    const worker = new Worker(new URL("./codec.worker.ts", import.meta.url), { type: "module" });
    workerRef.current = worker;
    worker.onmessage = ({ data }: MessageEvent<WorkerReply>) => {
      if (data.id !== conversionIDRef.current) return;
      setOutput(data.result.value);
      setError(data.result.ok ? null : data.result.error);
    };
    return () => {
      worker.terminate();
      workerRef.current = null;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const id = conversionIDRef.current + 1;
    conversionIDRef.current = id;
    const parameters = {
      tab,
      direction: tab === "hash" ? "encode" : direction,
      input,
      urlMode,
      base64URL,
      algorithm,
    };
    const timer = window.setTimeout(() => {
      if (input.length > 2_000_000) {
        setOutput("");
        setError("input-too-large");
        return;
      }
      if (workerRef.current) {
        workerRef.current.postMessage({ id, parameters });
        return;
      }
      convertCodec(parameters)
        .then((result) => {
          if (cancelled || id !== conversionIDRef.current) return;
          setOutput(result.value);
          setError(result.ok ? null : result.error);
        })
        .catch(() => {
          if (!cancelled) setError("unsupported");
        });
    }, 80);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [tab, direction, input, urlMode, base64URL, algorithm]);

  const changeTab = (nextTab: string) => {
    setTab(nextTab);
    if (nextTab === "hash") setDirection("encode");
    setError(null);
  };

  const swap = () => {
    if (tab === "hash" || !output || error) return;
    setInput(output);
    setDirection((value) => (value === "encode" ? "decode" : "encode"));
  };

  const tabLabel = messageFor(text, tab);
  const groupLabels: Record<(typeof CODEC_GROUPS)[number]["id"], string> = {
    binary: text.groupBinary,
    text: text.groupText,
    digest: text.groupDigest,
  };

  return (
    <ToolPage title={text.title}>
      <div className="flex min-h-0 flex-1 bg-surface">
        <ToolSidebar width={148} className="p-2.5" muted>
            {CODEC_GROUPS.map((group) => (
              <div key={group.id}>
                <div className="machkit-sidebar-label px-2 pb-1.5">{groupLabels[group.id]}</div>
                <nav className="flex flex-col gap-0.5" aria-label={groupLabels[group.id]}>
                  {group.items.map((item) => (
                    <SidebarNavItem
                      key={item.id}
                      active={tab === item.id}
                      code={item.code}
                      label={messageFor(text, item.id)}
                      onClick={() => changeTab(item.id)}
                    />
                  ))}
                </nav>
              </div>
            ))}
        </ToolSidebar>

        <section className="flex min-w-0 flex-1 flex-col">
          <header className="flex h-11 shrink-0 items-center gap-2 px-4">
            <span className="truncate text-sm font-semibold">{tabLabel}</span>
            <ActionGroup>
              <Button
                variant="ghost"
                size="sm"
                disabled={!input && !output}
                onClick={() => {
                  setInput("");
                  setOutput("");
                  setError(null);
                }}
              >
                <Eraser size={15} />
                {text.clear}
              </Button>
            </ActionGroup>
          </header>

          <div className="flex min-h-0 flex-1 flex-col gap-2.5 px-4 pb-4">
            <ToolToolbar className="flex-wrap gap-2">
              {tab === "hash" ? (
                <div className="flex min-w-0 flex-1 items-center gap-2">
                  <span className="machkit-control-label whitespace-nowrap">{text.algorithm}</span>
                  <SelectControl
                    value={algorithm}
                    onChange={setAlgorithm}
                    label={text.algorithm}
                    className="max-w-[200px]"
                    options={hashAlgorithms.map((value) => ({ value, label: value }))}
                  />
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <SegmentedControl
                    value={direction}
                    onChange={setDirection}
                    label={text.direction}
                    size="compact"
                    className="w-[168px] flex-none"
                    options={[
                      {
                        value: "encode",
                        label: tab === "escape" ? text.escapeAction : text.encode,
                      },
                      {
                        value: "decode",
                        label: tab === "escape" ? text.unescapeAction : text.decode,
                      },
                    ]}
                  />
                  <IconButton
                    label={text.swap}
                    disabled={!output || Boolean(error)}
                    onClick={swap}
                    className="size-8.5"
                  >
                    <ArrowsLeftRight size={15} />
                  </IconButton>
                </div>
              )}

              {tab === "base64" ? (
                <ActionGroup>
                  <CheckboxField
                    checked={base64URL}
                    onCheckedChange={(checked) => setBase64URL(checked === true)}
                    label={text.base64URL}
                  />
                </ActionGroup>
              ) : null}

              {tab === "url" ? (
                <ActionGroup className="min-w-0 gap-2">
                  <span className="machkit-control-label whitespace-nowrap">{text.urlMode}</span>
                  <SelectControl
                    value={urlMode}
                    onChange={setUrlMode}
                    label={text.urlMode}
                    className="max-w-[200px]"
                    options={[
                      { value: "component", label: text.component },
                      { value: "uri", label: text.uri },
                    ]}
                  />
                </ActionGroup>
              ) : null}
            </ToolToolbar>

            <div className="flex min-h-0 flex-1 flex-col gap-2.5">
              <label className="flex min-h-0 min-w-0 flex-1 flex-col gap-1.5">
                <span className="machkit-control-label">{text.input}</span>
                <Textarea
                  value={input}
                  onChange={(event) => setInput(event.target.value)}
                  placeholder={text.placeholder}
                  className="min-h-[120px] w-full flex-1 resize-y"
                />
              </label>

              <div className="flex min-h-0 min-w-0 flex-1 flex-col gap-1.5">
                <div className="flex items-center gap-2">
                  <span className="machkit-control-label">{text.output}</span>
                  <ActionGroup>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={!output}
                      onClick={() => machkit.copy(output)}
                    >
                      <CopySimple size={15} />
                      {text.copy}
                    </Button>
                  </ActionGroup>
                </div>
                <Textarea
                  value={output}
                  readOnly
                  placeholder={text.empty}
                  invalid={Boolean(error)}
                  className="min-h-[120px] w-full flex-1 resize-y bg-field"
                />
                {error ? (
                  <StatusStrip tone="danger">
                    {messageFor(text, error) ||
                      (error === "input-too-large" ? "Input is too large (2 MB maximum)" : error)}
                  </StatusStrip>
                ) : null}
              </div>
            </div>
          </div>
        </section>
      </div>
    </ToolPage>
  );
}

mountTool(<CodecTool />, { name: "Codec" });
