import React, { useEffect, useRef, useState } from "react";
import { ArrowsLeftRight, CopySimple, Eraser } from "@phosphor-icons/react";
import {
  Button,
  CheckboxField,
  IconButton,
  InlineMessage,
  SegmentedControl,
  SelectControl,
  Textarea,
  ToolContent,
  ToolPage,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { sift } from "@/runtime/sift.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import { convertCodec, hashAlgorithms } from "./codec.js";

import { messages } from "./messages.js";

function CodecTool() {
  const text = useToolMessages(messages);
  const [tab, setTab] = useState("base64");
  const [direction, setDirection] = useState("encode");
  const [input, setInput] = useState("");
  const [output, setOutput] = useState("");
  const [error, setError] = useState(null);
  const [algorithm, setAlgorithm] = useState("SHA-256");
  const [urlMode, setUrlMode] = useState("component");
  const [base64URL, setBase64URL] = useState(false);
  const workerRef = useRef(null);
  const conversionIDRef = useRef(0);

  useEffect(() => {
    if (typeof Worker === "undefined") return undefined;
    const worker = new Worker(new URL("./codec.worker.js", import.meta.url), { type: "module" });
    workerRef.current = worker;
    worker.onmessage = ({ data }) => {
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
    const parameters = { tab, direction: tab === "hash" ? "encode" : direction, input, urlMode, base64URL, algorithm };
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
      convertCodec(parameters).then((result) => {
        if (cancelled || id !== conversionIDRef.current) return;
        setOutput(result.value);
        setError(result.ok ? null : result.error);
      }).catch(() => {
        if (!cancelled) setError("unsupported");
      });
    }, 80);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [tab, direction, input, urlMode, base64URL, algorithm]);

  const changeTab = (nextTab) => {
    setTab(nextTab);
    if (nextTab === "hash") setDirection("encode");
    setError(null);
  };

  const swap = () => {
    if (tab === "hash" || !output || error) return;
    setInput(output);
    setDirection((value) => (value === "encode" ? "decode" : "encode"));
  };

  const introKey = {
    base64: "introBase64",
    base32: "introBase32",
    base62: "introBase62",
    hex: "introHex",
    url: "introUrl",
    html: "introHtml",
    unicode: "introUnicode",
    escape: "introEscape",
    hash: "introHash",
  }[tab];

  return (
    <ToolPage title={text.title} adaptiveHeight>
      <ToolContent className="flex flex-col pt-4 pb-5">
        <div className="sift-toolbar gap-2">
          <SegmentedControl
            value={tab}
            onChange={changeTab}
            label={text.title}
            size="compact"
            className="min-w-0 w-full"
            options={[
              { value: "base64", label: text.base64 },
              { value: "base32", label: text.base32 },
              { value: "base62", label: text.base62 },
              { value: "hex", label: text.hex },
              { value: "url", label: text.url },
              { value: "html", label: text.html },
              { value: "unicode", label: text.unicode },
              { value: "escape", label: text.escape },
              { value: "hash", label: text.hash },
            ]}
          />
        </div>

        <aside className="sift-callout">
          {text[introKey]}
        </aside>

        <div className="sift-toolbar flex-wrap gap-4">
          {tab === "hash" ? (
            <div className="flex min-w-0 flex-1 items-center gap-3">
              <span className="sift-control-label">{text.algorithm}</span>
              <SelectControl
                value={algorithm}
                onChange={setAlgorithm}
                label={text.algorithm}
                className="max-w-[220px]"
                options={hashAlgorithms.map((value) => ({ value, label: value }))}
              />
            </div>
          ) : (
            <div className="flex items-center gap-2.5">
              <SegmentedControl
                value={direction}
                onChange={setDirection}
                label={text.direction}
                className="w-[168px] flex-none"
                options={[
                  { value: "encode", label: tab === "escape" ? text.escapeAction : text.encode },
                  { value: "decode", label: tab === "escape" ? text.unescapeAction : text.decode },
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
            <div className="ml-auto">
              <CheckboxField
                checked={base64URL}
                onCheckedChange={(checked) => setBase64URL(checked === true)}
                label={text.base64URL}
              />
            </div>
          ) : null}

          {tab === "url" ? (
            <div className="ml-auto flex min-w-0 items-center gap-3">
              <span className="sift-control-label">{text.urlMode}</span>
              <SelectControl
                value={urlMode}
                onChange={setUrlMode}
                label={text.urlMode}
                className="max-w-[220px]"
                options={[
                  { value: "component", label: text.component },
                  { value: "uri", label: text.uri },
                ]}
              />
            </div>
          ) : null}
        </div>

        <div className="flex w-full flex-col gap-4 pt-4">
          <label className="flex w-full flex-col gap-2">
            <div className="flex items-center gap-2">
              <span className="sift-control-label">{text.input}</span>
              <div className="ml-auto">
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
                  <Eraser size={16} />
                  {text.clear}
                </Button>
              </div>
            </div>
            <Textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              className="h-[170px] min-h-[170px] w-full resize-y"
            />
          </label>

          <div className="flex w-full flex-col gap-2">
            <div className="flex items-center gap-2">
              <span className="sift-control-label">{text.output}</span>
              <div className="ml-auto">
                <Button variant="ghost" size="sm" disabled={!output} onClick={() => sift.copy(output)}>
                  <CopySimple size={16} />
                  {text.copy}
                </Button>
              </div>
            </div>
            <Textarea
              value={output}
              readOnly
              placeholder={text.empty}
              invalid={Boolean(error)}
              className="h-[170px] min-h-[170px] w-full resize-y bg-field"
            />
            {error ? <InlineMessage tone="danger">{text[error] || (error === "input-too-large" ? "Input is too large (2 MB maximum)" : error)}</InlineMessage> : null}
          </div>
        </div>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CodecTool />, { name: "Codec" });
