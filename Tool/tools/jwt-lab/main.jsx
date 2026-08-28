import React, { useEffect, useMemo, useState } from "react";
import { CopySimple, Eraser } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  ResultPanel,
  SegmentedControl,
  SelectControl,
  SplitWorkspace,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolInfoButton,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";
import {
  createJwt,
  defaultGeneratePayload,
  inspectJwt,
  signAlgorithms,
} from "./jwt.js";
import { messages } from "./messages.js";

const SAMPLE =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtYWNoa2l0IiwibmFtZSI6Ik1hY2hLaXQiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6NDkwMDAwMDAwMH0.signature";

function ClaimRow({ label, claim, none }) {
  if (!claim) {
    return (
      <div className="flex items-center justify-between gap-2 border-b border-border px-3 py-2 text-[12px] last:border-b-0">
        <span className="text-secondary">{label}</span>
        <span className="text-tertiary">{none}</span>
      </div>
    );
  }
  return (
    <div className="flex flex-col gap-0.5 border-b border-border px-3 py-2 text-[12px] last:border-b-0">
      <div className="flex items-center justify-between gap-2">
        <span className="text-secondary">{label}</span>
        <span className={claim.expired ? "text-danger" : "text-foreground"}>{claim.iso}</span>
      </div>
      <span className="font-mono text-[11px] text-tertiary">{claim.local}</span>
    </div>
  );
}

function JwtLabTool() {
  const text = useToolMessages(messages);
  const [mode, setMode] = useState("decode");
  const [token, setToken] = useState(SAMPLE);
  const [headerText, setHeaderText] = useState(JSON.stringify({ alg: "HS256", typ: "JWT" }, null, 2));
  const [payloadText, setPayloadText] = useState(() => JSON.stringify(defaultGeneratePayload(), null, 2));
  const [algorithm, setAlgorithm] = useState("HS256");
  const [secret, setSecret] = useState("machkit-secret");
  const [generateError, setGenerateError] = useState(null);
  const [busy, setBusy] = useState(false);

  const decoded = useMemo(() => inspectJwt(token), [token]);

  // Shared algorithm + JSON follow the shared token while decoding.
  useEffect(() => {
    if (mode !== "decode" || !decoded.ok) return;
    if (signAlgorithms.includes(decoded.algorithm) && decoded.algorithm !== algorithm) {
      setAlgorithm(decoded.algorithm);
    }
    setHeaderText(decoded.headerJson);
    setPayloadText(decoded.payloadJson);
  }, [mode, decoded.ok, decoded.algorithm, decoded.headerJson, decoded.payloadJson, algorithm]);

  const decodeStatus = !token.trim()
    ? { tone: "neutral", label: text.empty }
    : !decoded.ok
      ? {
          tone: "danger",
          label:
            decoded.error === "too-large"
              ? text.tooLarge
              : decoded.error === "invalid-json"
                ? text.invalidJson
                : text.invalidFormat,
        }
      : {
          tone: decoded.status === "expired" ? "danger" : "info",
          label:
            decoded.status === "expired"
              ? text.statusExpired
              : decoded.status === "not-before"
                ? text.statusNotBefore
                : `${text.statusOk} · ${algorithm || text.none}`,
        };

  const generateStatus = generateError
    ? {
        tone: "danger",
        label:
          generateError === "missing-secret"
            ? text.missingSecret
            : generateError === "invalid-object"
              ? text.invalidObject
              : generateError === "invalid-json" || generateError === "empty"
                ? text.generateEmpty
                : text.invalidJson,
      }
    : token.trim()
      ? { tone: "info", label: `${text.generated} · ${algorithm}` }
      : { tone: "neutral", label: text.generateEmpty };

  useEffect(() => {
    if (mode !== "generate") return;
    let cancelled = false;
    setBusy(true);
    createJwt({ headerText, payloadText, secret, algorithm }).then((result) => {
      if (cancelled) return;
      setBusy(false);
      if (result.ok) {
        setToken(result.token);
        setGenerateError(null);
      } else {
        setGenerateError(result.error);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [mode, headerText, payloadText, secret, algorithm]);

  function onAlgorithmChange(next) {
    setAlgorithm(next);
    // Keep header.alg aligned with the shared algorithm control.
    try {
      const header = JSON.parse(headerText);
      if (header && typeof header === "object" && !Array.isArray(header)) {
        setHeaderText(JSON.stringify({ ...header, alg: next, typ: header.typ || "JWT" }, null, 2));
      }
    } catch {
      setHeaderText(JSON.stringify({ alg: next, typ: "JWT" }, null, 2));
    }
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="flex-wrap gap-y-2">
          <SegmentedControl
            value={mode}
            onChange={setMode}
            label={text.title}
            size="compact"
            className="w-[180px] flex-none"
            options={[
              { value: "decode", label: text.tabDecode },
              { value: "generate", label: text.tabGenerate },
            ]}
          />

          <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />

          <div className="flex items-center gap-2">
            <span className="machkit-control-label shrink-0">{text.algorithm}</span>
            <SelectControl
              value={algorithm}
              onChange={onAlgorithmChange}
              label={text.algorithm}
              className="w-[84px] flex-none"
              options={signAlgorithms.map((value) => ({ value, label: value }))}
            />
          </div>

          <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />

          <div className="flex min-w-0 flex-1 items-center gap-2">
            <span className="machkit-control-label shrink-0">{text.secret}</span>
            <Input
              className="min-w-0 flex-1 font-mono"
              value={secret}
              onChange={(event) => setSecret(event.target.value)}
              placeholder={text.secretPlaceholder}
              spellCheck={false}
              disabled={algorithm === "none"}
            />
          </div>

          <div className="mx-3 h-5 w-px shrink-0 bg-border" aria-hidden="true" />

          <ActionGroup>
            <Button
              variant="ghost"
              size="sm"
              disabled={!token.trim()}
              onClick={() => machkit.copy(token.trim())}
            >
              <CopySimple size={15} />
              {text.copy}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setToken("");
                setHeaderText(JSON.stringify({ alg: algorithm, typ: "JWT" }, null, 2));
                setPayloadText(JSON.stringify(defaultGeneratePayload(), null, 2));
                setGenerateError(null);
              }}
            >
              <Eraser size={15} />
              {text.clear}
            </Button>
            <ToolInfoButton info={text.info} className="size-8.5 shrink-0" />
          </ActionGroup>
        </ToolToolbar>

        <div className="flex min-w-0 flex-col gap-1.5">
          <span className="machkit-control-label">{text.token}</span>
          <Textarea
            className="min-h-[96px] font-mono text-[12px]"
            value={token}
            onChange={(event) => {
              if (mode === "generate") return;
              setToken(event.target.value);
            }}
            readOnly={mode === "generate"}
            placeholder={text.placeholder}
            spellCheck={false}
          />
        </div>

        {mode === "decode" ? (
          <>
            <StatusStrip tone={decodeStatus.tone}>{decodeStatus.label}</StatusStrip>
            {decoded.ok ? <p className="text-[11px] text-tertiary">{text.unverified}</p> : null}

            {decoded.ok ? (
              <div className="grid gap-3 lg:grid-cols-2">
                <ResultPanel
                  title={text.header}
                  actions={
                    <Button variant="ghost" size="sm" onClick={() => machkit.copy(decoded.headerJson)}>
                      <CopySimple size={15} />
                      {text.copy}
                    </Button>
                  }
                >
                  <pre className="max-h-48 overflow-auto px-3 py-2 font-mono text-[12px] leading-relaxed">
                    {decoded.headerJson}
                  </pre>
                </ResultPanel>

                <ResultPanel
                  title={text.payload}
                  actions={
                    <Button variant="ghost" size="sm" onClick={() => machkit.copy(decoded.payloadJson)}>
                      <CopySimple size={15} />
                      {text.copy}
                    </Button>
                  }
                >
                  <pre className="max-h-48 overflow-auto px-3 py-2 font-mono text-[12px] leading-relaxed">
                    {decoded.payloadJson}
                  </pre>
                </ResultPanel>

                <ResultPanel title={text.claims} className="lg:col-span-2">
                  <ClaimRow label={text.exp} claim={decoded.exp} none={text.none} />
                  <ClaimRow label={text.iat} claim={decoded.iat} none={text.none} />
                  <ClaimRow label={text.nbf} claim={decoded.nbf} none={text.none} />
                  <div className="flex items-center justify-between gap-2 px-3 py-2 text-[12px]">
                    <span className="text-secondary">{text.signature}</span>
                    <code className="max-w-[70%] truncate font-mono text-[11px]">
                      {decoded.parts.signature || text.none}
                    </code>
                  </div>
                </ResultPanel>
              </div>
            ) : null}
          </>
        ) : (
          <>
            <SplitWorkspace>
              <div className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.header}</span>
                <Textarea
                  className="min-h-[160px] font-mono text-[12px]"
                  value={headerText}
                  onChange={(event) => setHeaderText(event.target.value)}
                  spellCheck={false}
                />
              </div>
              <div className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.payload}</span>
                <Textarea
                  className="min-h-[160px] font-mono text-[12px]"
                  value={payloadText}
                  onChange={(event) => setPayloadText(event.target.value)}
                  spellCheck={false}
                />
              </div>
            </SplitWorkspace>

            <StatusStrip tone={generateStatus.tone}>
              {busy ? text.generate : generateStatus.label}
            </StatusStrip>
          </>
        )}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<JwtLabTool />, { name: "JWT Lab" });
