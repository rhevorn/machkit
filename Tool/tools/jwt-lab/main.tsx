import React, { useEffect, useMemo, useState } from "react";
import { CopySimpleIcon, EraserIcon } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  Input,
  SegmentedControl,
  SelectControl,
  SplitWorkspace,
  StatusStrip,
  type InlineMessageTone,
  Textarea,
  ToolContent,
  ToolPage,
  ToolToolbar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import {
  createJwt,
  defaultGeneratePayload,
  inspectJwt,
  signAlgorithms,
  type UnixTimeInfo,
} from "./jwt.js";
import { messages } from "./messages.js";

type ToolText = (typeof messages)["en"];

const SAMPLE =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtYWNoa2l0IiwibmFtZSI6Ik1hY2hLaXQiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6NDkwMDAwMDAwMH0.signature";

function JsonBlock({
  label,
  value,
  copyLabel,
  onCopy,
}: {
  label: string;
  value: string;
  copyLabel: string;
  onCopy: () => void;
}) {
  return (
    <div className="flex min-w-0 flex-col gap-1.5">
      <div className="flex items-center justify-between gap-2">
        <span className="machkit-control-label">{label}</span>
        <Button variant="ghost" size="sm" onClick={onCopy}>
          <CopySimpleIcon size={15} />
          {copyLabel}
        </Button>
      </div>
      <pre className="max-h-[132px] overflow-auto whitespace-pre-wrap break-all rounded-control bg-muted px-3 py-2 font-mono text-[12px] leading-relaxed text-foreground select-text">
        {value}
      </pre>
    </div>
  );
}

function ClaimChip({
  label,
  claim,
  none,
}: {
  label: string;
  claim: UnixTimeInfo | null;
  none: string;
}) {
  return (
    <div className="min-w-0 flex-1 rounded-control bg-muted px-2.5 py-2">
      <div className="text-[11px] text-secondary">{label}</div>
      {claim ? (
        <>
          <div className={`mt-0.5 truncate text-[12px] ${claim.expired ? "text-danger" : "text-foreground"}`}>
            {claim.iso}
          </div>
          <div className="mt-0.5 truncate font-mono text-[10px] text-tertiary">{claim.local}</div>
        </>
      ) : (
        <div className="mt-0.5 text-[12px] text-tertiary">{none}</div>
      )}
    </div>
  );
}

function JwtLabTool() {
  const text: ToolText = useToolMessages(messages);
  const [mode, setMode] = useState("generate");
  const [token, setToken] = useState("");
  const [headerText, setHeaderText] = useState(JSON.stringify({ alg: "HS256", typ: "JWT" }, null, 2));
  const [payloadText, setPayloadText] = useState(() => JSON.stringify(defaultGeneratePayload(), null, 2));
  const [algorithm, setAlgorithm] = useState("HS256");
  const [secret, setSecret] = useState("machkit-secret");
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const decoded = useMemo(() => inspectJwt(token), [token]);

  // Shared algorithm + JSON follow the shared token while decoding.
  useEffect(() => {
    if (mode !== "decode" || !decoded.ok) return;
    if ((signAlgorithms as readonly string[]).includes(decoded.algorithm) && decoded.algorithm !== algorithm) {
      setAlgorithm(decoded.algorithm);
    }
    setHeaderText(decoded.headerJson);
    setPayloadText(decoded.payloadJson);
  }, [mode, decoded, algorithm]);

  const displayAlgorithm =
    decoded.ok && decoded.algorithm ? decoded.algorithm : algorithm;

  const decodeStatus: { tone: InlineMessageTone; label: string } = !token.trim()
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
                : `${text.statusOk} · ${displayAlgorithm || text.none}`,
        };

  const generateStatus: { tone: InlineMessageTone; label: string } | null = generateError
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
    : null;

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
        setToken("");
      }
    });
    return () => {
      cancelled = true;
    };
  }, [mode, headerText, payloadText, secret, algorithm]);

  function onAlgorithmChange(next: string) {
    setAlgorithm(next);
    // Keep header.alg aligned with the shared algorithm control.
    try {
      const header = JSON.parse(headerText) as unknown;
      if (header && typeof header === "object" && !Array.isArray(header)) {
        setHeaderText(JSON.stringify({ ...(header as Record<string, unknown>), alg: next, typ: (header as Record<string, unknown>).typ || "JWT" }, null, 2));
      }
    } catch {
      setHeaderText(JSON.stringify({ alg: next, typ: "JWT" }, null, 2));
    }
  }

  function switchMode(next: string) {
    if (next === mode) return;
    if (next === "decode") {
      setToken(SAMPLE);
    } else {
      setToken("");
      setGenerateError(null);
    }
    setMode(next);
  }

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex flex-col gap-3 pt-3 pb-4">
        <ToolToolbar className="flex-wrap gap-y-2">
          <SegmentedControl
            value={mode}
            onChange={switchMode}
            label={text.title}
            size="compact"
            className="w-[180px] flex-none"
            options={[
              { value: "generate", label: text.tabGenerate },
              { value: "decode", label: text.tabDecode },
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
              onChange={(event: React.ChangeEvent<HTMLInputElement>) => setSecret(event.target.value)}
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
              <CopySimpleIcon size={15} />
              {text.copy}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                if (mode === "decode") {
                  setToken("");
                } else {
                  setToken("");
                  setHeaderText(JSON.stringify({ alg: algorithm, typ: "JWT" }, null, 2));
                  setPayloadText(JSON.stringify(defaultGeneratePayload(), null, 2));
                  setGenerateError(null);
                }
              }}
            >
              <EraserIcon size={15} />
              {text.clear}
            </Button>
          </ActionGroup>
        </ToolToolbar>

        {mode === "decode" ? (
          <>
            <div className="flex min-w-0 flex-col gap-1.5">
              <span className="machkit-control-label">{text.token}</span>
              <Textarea
                className="min-h-[72px] font-mono text-[12px]"
                value={token}
                onChange={(event) => setToken(event.target.value)}
                placeholder={text.placeholder}
                spellCheck={false}
              />
            </div>

            <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
              <StatusStrip tone={decodeStatus.tone} className="min-w-0 flex-1">
                {decodeStatus.label}
              </StatusStrip>
              {decoded.ok ? <span className="text-[11px] text-tertiary">{text.unverified}</span> : null}
            </div>

            {decoded.ok ? (
              <div className="flex flex-col gap-3">
                <div className="grid gap-3 sm:grid-cols-2">
                  <JsonBlock
                    label={text.header}
                    value={decoded.headerJson}
                    copyLabel={text.copy}
                    onCopy={() => machkit.copy(decoded.headerJson)}
                  />
                  <JsonBlock
                    label={text.payload}
                    value={decoded.payloadJson}
                    copyLabel={text.copy}
                    onCopy={() => machkit.copy(decoded.payloadJson)}
                  />
                </div>

                <div className="flex flex-col gap-1.5">
                  <span className="machkit-control-label">{text.claims}</span>
                  <div className="grid grid-cols-3 gap-2">
                    <ClaimChip label={text.exp} claim={decoded.exp} none={text.none} />
                    <ClaimChip label={text.iat} claim={decoded.iat} none={text.none} />
                    <ClaimChip label={text.nbf} claim={decoded.nbf} none={text.none} />
                  </div>
                  <div className="rounded-control bg-muted px-2.5 py-2">
                    <div className="text-[11px] text-secondary">{text.signature}</div>
                    <code className="mt-0.5 block break-all font-mono text-[11px] leading-snug text-foreground">
                      {decoded.parts.signature || text.none}
                    </code>
                  </div>
                </div>
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
                  aria-label={text.header}
                  spellCheck={false}
                />
              </div>
              <div className="flex min-w-0 flex-col gap-1.5">
                <span className="machkit-control-label">{text.payload}</span>
                <Textarea
                  className="min-h-[160px] font-mono text-[12px]"
                  value={payloadText}
                  onChange={(event) => setPayloadText(event.target.value)}
                  aria-label={text.payload}
                  spellCheck={false}
                />
              </div>
            </SplitWorkspace>

            {generateError || busy ? (
              <StatusStrip tone={generateError ? generateStatus!.tone : "info"}>
                {busy ? text.generate : generateStatus!.label}
              </StatusStrip>
            ) : null}

            <div className="flex min-w-0 flex-col gap-1.5">
              <div className="flex items-center justify-between gap-2">
                <span className="machkit-control-label">{text.token}</span>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={!token.trim()}
                  onClick={() => machkit.copy(token.trim())}
                >
                  <CopySimpleIcon size={15} />
                  {text.copy}
                </Button>
              </div>
              <div className="rounded-control bg-muted px-3 py-2.5">
                {token.trim() ? (
                  <pre className="whitespace-pre-wrap break-all font-mono text-[12px] leading-relaxed select-text">
                    {token.trim().split(".").map((part, index, parts) => (
                      <span key={`${index}-${part.slice(0, 8)}`}>
                        <span
                          className={
                            index === 0
                              ? "text-accent"
                              : index === 1
                                ? "text-foreground"
                                : "text-secondary"
                          }
                        >
                          {part}
                        </span>
                        {index < parts.length - 1 ? (
                          <span className="text-tertiary">.</span>
                        ) : null}
                      </span>
                    ))}
                  </pre>
                ) : (
                  <p className="font-mono text-[12px] text-tertiary">{text.generateEmpty}</p>
                )}
              </div>
            </div>
          </>
        )}
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<JwtLabTool />, { name: "JWT Lab" });
