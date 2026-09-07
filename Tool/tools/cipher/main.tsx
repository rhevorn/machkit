import { useEffect, useMemo, useState } from "react";
import { ArrowsLeftRightIcon, CopySimpleIcon, EraserIcon } from "@phosphor-icons/react";
import {
  ActionGroup,
  Button,
  IconButton,
  Input,
  SegmentedControl,
  SelectControl,
  SidebarNavItem,
  StatusStrip,
  Textarea,
  ToolContent,
  ToolPage,
  ToolSidebar,
} from "@/ui/index.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";
import {
  cipherAlgorithmGroups,
  generateRsaPrivateKeyPem,
  generateSm2PrivateKey,
  getAlgorithmMeta,
  publicKeyFromSm2PrivateKey,
  publicKeyPemFromRsaPrivateKey,
  runCipher,
  suggestedIV,
  suggestedKeyForMode,
  type CipherDirection,
  type CipherMode,
} from "./cipher.js";
import type { ByteEncoding, CipherPayloadEncoding } from "./cipher-bytes.js";
import { messages } from "./messages.js";

type ToolText = (typeof messages)["en"];
type MaterialFormat = "hex" | "base64";

function messageFor(text: ToolText, key: string | null): string {
  if (!key) return text.empty;
  return (text as Record<string, string>)[key] || key;
}

function groupLabel(text: ToolText, groupID: string): string {
  if (groupID === "aes") return text.groupAES;
  if (groupID === "chacha") return text.groupChaCha;
  if (groupID === "rsa") return text.groupRSA;
  if (groupID === "des") return text.groupDES;
  if (groupID === "sm") return text.groupSM;
  return groupID;
}

function ivPlaceholder(text: ToolText, mode: CipherMode): string {
  const meta = getAlgorithmMeta(mode);
  if (meta.ivLength === 24) return text.ivPlaceholderXchacha;
  if (meta.ivLength === 12) return text.ivPlaceholderGcm;
  if (meta.ivLength === 8) return text.ivPlaceholder8;
  if (mode === "AES-CTR") return text.ivPlaceholderCtr;
  return text.ivPlaceholderCbc;
}

function keyPlaceholder(text: ToolText, mode: CipherMode): string {
  if (mode === "DES-CBC") return text.keyPlaceholderDes;
  if (mode === "3DES-CBC") return text.keyPlaceholder3Des;
  if (mode === "ChaCha20-Poly1305" || mode === "XChaCha20-Poly1305") return text.keyPlaceholderChaCha;
  return text.keyPlaceholder;
}

function isByteEncoding(value: string): value is ByteEncoding {
  return value === "utf8" || value === "hex" || value === "base64";
}

function isPayloadEncoding(value: string): value is CipherPayloadEncoding {
  return value === "utf8" || value === "hex" || value === "base64";
}

function isMaterialFormat(value: string): value is MaterialFormat {
  return value === "hex" || value === "base64";
}

function CipherTool() {
  const text = useToolMessages(messages);
  const [mode, setMode] = useState<CipherMode>("AES-GCM");
  const [direction, setDirection] = useState<CipherDirection>("encrypt");
  const [input, setInput] = useState("");
  const [output, setOutput] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [keyFormat, setKeyFormat] = useState<ByteEncoding>("hex");
  const [ivFormat, setIVFormat] = useState<MaterialFormat>("hex");
  const [inputFormat, setInputFormat] = useState<CipherPayloadEncoding>("utf8");
  const [outputFormat, setOutputFormat] = useState<MaterialFormat>("hex");
  const [key, setKey] = useState(() => suggestedKeyForMode("AES-GCM", "hex"));
  const [iv, setIV] = useState(() => suggestedIV("AES-GCM", "hex"));
  const [publicKey, setPublicKey] = useState("");
  const [privateKey, setPrivateKey] = useState("");
  const [busyKeys, setBusyKeys] = useState(false);

  const meta = useMemo(() => getAlgorithmMeta(mode), [mode]);

  function changeMode(next: CipherMode) {
    if (next === mode) return;
    setMode(next);
    const nextMeta = getAlgorithmMeta(next);
    if (nextMeta.needsIV) setIV(suggestedIV(next, ivFormat));
    if (nextMeta.asymmetric) {
      setPublicKey("");
      setPrivateKey("");
    } else {
      const encoding = keyFormat === "utf8" ? "hex" : keyFormat;
      if (keyFormat === "utf8") setKeyFormat("hex");
      setKey(suggestedKeyForMode(next, encoding));
    }
  }

  function changeDirection(next: string) {
    if (next !== "encrypt" && next !== "decrypt") return;
    if (next === direction) return;
    setDirection(next);
    if (next === "encrypt") {
      setInputFormat("utf8");
    } else {
      setInputFormat(outputFormat);
    }
  }

  function changeKeyFormat(next: string) {
    if (!isByteEncoding(next) || next === keyFormat) return;
    setKeyFormat(next);
    if (next === "utf8") return;
    setKey(suggestedKeyForMode(mode, next));
  }

  function changeIVFormat(next: string) {
    if (!isMaterialFormat(next) || next === ivFormat) return;
    setIVFormat(next);
    setIV(suggestedIV(mode, next));
  }

  function changeInputFormat(next: string) {
    if (!isPayloadEncoding(next) || next === inputFormat) return;
    setInputFormat(next);
  }

  function changeOutputFormat(next: string) {
    if (!isMaterialFormat(next) || next === outputFormat) return;
    setOutputFormat(next);
  }

  useEffect(() => {
    let cancelled = false;
    if (!input.trim()) {
      setOutput("");
      setError(null);
      return;
    }

    runCipher({
      mode,
      direction,
      input,
      key,
      iv,
      publicKey,
      privateKey,
      keyEncoding: keyFormat,
      ivEncoding: ivFormat,
      inputEncoding: inputFormat,
      outputEncoding: outputFormat,
    }).then((result) => {
      if (cancelled) return;
      setOutput(result.value);
      setError(result.ok ? null : result.error);
    });

    return () => {
      cancelled = true;
    };
  }, [mode, direction, input, key, iv, publicKey, privateKey, keyFormat, ivFormat, inputFormat, outputFormat]);

  function regenerateKey() {
    const encoding = keyFormat === "utf8" ? "hex" : keyFormat;
    if (keyFormat === "utf8") setKeyFormat("hex");
    setKey(suggestedKeyForMode(mode, encoding));
  }

  function regenerateIV() {
    setIV(suggestedIV(mode, ivFormat));
  }

  function generatePrivateKey() {
    setBusyKeys(true);
    setError(null);
    try {
      if (mode === "SM2") {
        setPrivateKey(generateSm2PrivateKey());
      } else {
        setPrivateKey(generateRsaPrivateKeyPem(2048));
      }
      setPublicKey("");
    } finally {
      setBusyKeys(false);
    }
  }

  function generatePublicKey() {
    if (!privateKey.trim()) {
      setError("missing-private-key-for-public");
      return;
    }
    setBusyKeys(true);
    try {
      const derived =
        mode === "SM2"
          ? publicKeyFromSm2PrivateKey(privateKey)
          : publicKeyPemFromRsaPrivateKey(privateKey);
      if (!derived.ok) {
        setError(derived.error);
        return;
      }
      setPublicKey(derived.value);
      setError(null);
    } finally {
      setBusyKeys(false);
    }
  }

  function clearAll() {
    setInput("");
    setOutput("");
    setError(null);
  }

  function useOutputAsDecryptInput() {
    if (!output.trim() || error) return;
    setDirection("decrypt");
    setInputFormat(outputFormat);
    setInput(output);
  }

  const keyFormatOptions = [
    { value: "hex", label: text.hex },
    { value: "base64", label: text.base64 },
    { value: "utf8", label: text.utf8 },
  ];
  const payloadFormatOptions = [
    { value: "utf8", label: text.utf8 },
    { value: "hex", label: text.hex },
    { value: "base64", label: text.base64 },
  ];
  const materialFormatOptions = [
    { value: "hex", label: text.hex },
    { value: "base64", label: text.base64 },
  ];

  return (
    <ToolPage title={text.title}>
      <ToolContent className="flex min-h-0 flex-1 gap-[var(--machkit-layout-content-padding)] bg-surface">
        <ToolSidebar width={176} muted className="min-h-0 self-stretch">
          {cipherAlgorithmGroups.map((group) => (
            <div key={group.id} className="flex flex-col gap-[4px]">
              <div className="machkit-sidebar-label px-2 py-[4px]">{groupLabel(text, group.id)}</div>
              <nav className="flex flex-col gap-[4px]" aria-label={groupLabel(text, group.id)}>
                {group.items.map((item) => (
                  <SidebarNavItem
                    key={item.id}
                    active={mode === item.id}
                    code={item.code}
                    label={item.id}
                    onClick={() => changeMode(item.id)}
                  />
                ))}
              </nav>
            </div>
          ))}
        </ToolSidebar>

        <section className="flex min-h-0 min-w-0 flex-1 flex-col">
          <header className="flex h-11 shrink-0 items-center gap-2">
            <span className="truncate text-sm font-semibold">{mode}</span>
            <ActionGroup>
              <Button variant="ghost" size="sm" disabled={!input && !output} onClick={clearAll}>
                <EraserIcon size={15} />
                {text.clear}
              </Button>
            </ActionGroup>
          </header>

          <div className="flex min-h-0 flex-1 flex-col gap-2.5 overflow-hidden">
            <div className="flex shrink-0 items-center gap-2">
              <SegmentedControl
                value={direction}
                onChange={changeDirection}
                label={text.direction}
                size="compact"
                className="w-[168px] flex-none"
                options={[
                  { value: "encrypt", label: text.encrypt },
                  { value: "decrypt", label: text.decrypt },
                ]}
              />
              <IconButton
                label={text.swap}
                disabled={!output.trim() || Boolean(error) || direction === "decrypt"}
                onClick={useOutputAsDecryptInput}
                className="size-8.5"
              >
                <ArrowsLeftRightIcon size={15} />
              </IconButton>
            </div>

            {meta.asymmetric ? (
              <div className="flex min-w-0 shrink-0 flex-col gap-2">
                <div className="flex min-w-0 flex-col gap-1.5">
                  <div className="flex h-8 items-center gap-2">
                    <span className="machkit-control-label">{text.privateKey}</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={busyKeys}
                      onClick={generatePrivateKey}
                      className="h-6 px-1.5 text-[11px] text-tertiary hover:text-secondary"
                    >
                      {text.generatePrivateKey}
                    </Button>
                  </div>
                  <Textarea
                    className="min-h-[72px] font-mono text-[11px]"
                    value={privateKey}
                    onChange={(event) => setPrivateKey(event.target.value)}
                    placeholder={text.privateKeyPlaceholder}
                    aria-label={text.privateKey}
                    spellCheck={false}
                  />
                </div>
                <div className="flex min-w-0 flex-col gap-1.5">
                  <div className="flex h-8 items-center gap-2">
                    <span className="machkit-control-label">{text.publicKey}</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={busyKeys || !privateKey.trim()}
                      onClick={generatePublicKey}
                      className="h-6 px-1.5 text-[11px] text-tertiary hover:text-secondary"
                    >
                      {text.generatePublicKey}
                    </Button>
                  </div>
                  <Textarea
                    className="min-h-[72px] font-mono text-[11px]"
                    value={publicKey}
                    onChange={(event) => setPublicKey(event.target.value)}
                    placeholder={text.publicKeyPlaceholder}
                    aria-label={text.publicKey}
                    spellCheck={false}
                  />
                </div>
              </div>
            ) : (
              <div className="flex min-w-0 shrink-0 flex-col gap-2">
                <div className="flex min-w-0 flex-col gap-1.5">
                  <div className="flex h-8 items-center gap-2">
                    <span className="machkit-control-label">{text.key}</span>
                    <SelectControl
                      variant="ghost"
                      value={keyFormat}
                      onChange={changeKeyFormat}
                      label={text.keyEncoding}
                      className="flex-none"
                      options={keyFormatOptions}
                    />
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={regenerateKey}
                      className="h-6 px-1.5 text-[11px] text-tertiary hover:text-secondary"
                    >
                      {text.generateKey}
                    </Button>
                  </div>
                  <Input
                    className="w-full font-mono text-[12px]"
                    value={key}
                    onChange={(event) => setKey(event.target.value)}
                    placeholder={keyPlaceholder(text, mode)}
                    aria-label={text.key}
                    spellCheck={false}
                  />
                </div>

                {meta.needsIV ? (
                  <div className="flex min-w-0 flex-col gap-1.5">
                    <div className="flex h-8 items-center gap-2">
                      <span className="machkit-control-label">{text.iv}</span>
                      <SelectControl
                        variant="ghost"
                        value={ivFormat}
                        onChange={changeIVFormat}
                        label={text.ivEncoding}
                        className="flex-none"
                        options={materialFormatOptions}
                      />
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={regenerateIV}
                        className="h-6 px-1.5 text-[11px] text-tertiary hover:text-secondary"
                      >
                        {text.generateIV}
                      </Button>
                    </div>
                    <Input
                      className="w-full font-mono text-[12px]"
                      value={iv}
                      onChange={(event) => setIV(event.target.value)}
                      placeholder={ivPlaceholder(text, mode)}
                      aria-label={text.iv}
                      spellCheck={false}
                    />
                  </div>
                ) : null}
              </div>
            )}

            <div className="flex h-8 shrink-0 items-center gap-2">
              <span className="machkit-control-label">{text.input}</span>
              <SelectControl
                variant="ghost"
                value={inputFormat}
                onChange={changeInputFormat}
                label={text.inputEncoding}
                className="flex-none"
                options={payloadFormatOptions}
              />
            </div>
            <Textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={text.placeholder}
              aria-label={text.input}
              className="min-h-0 w-full flex-1 basis-0 resize-none font-mono text-[12px]"
            />

            <div className="flex h-8 shrink-0 items-center gap-2">
              <span className="machkit-control-label">{text.output}</span>
              <SelectControl
                variant="ghost"
                value={outputFormat}
                onChange={changeOutputFormat}
                label={text.outputEncoding}
                className="flex-none"
                options={materialFormatOptions}
              />
              <ActionGroup>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={!output.trim() || Boolean(error)}
                  onClick={() => machkit.copy(output)}
                >
                  <CopySimpleIcon size={15} />
                  {text.copy}
                </Button>
              </ActionGroup>
            </div>
            <Textarea
              value={output}
              readOnly
              placeholder={text.empty}
              invalid={Boolean(error)}
              aria-label={text.output}
              className="min-h-0 w-full flex-1 basis-0 resize-none bg-field font-mono text-[12px]"
            />
            {error ? (
              <StatusStrip tone="danger" className="shrink-0">
                {messageFor(text, error)}
              </StatusStrip>
            ) : !input.trim() ? (
              <p className="shrink-0 text-[11px] leading-relaxed text-tertiary">{text.empty}</p>
            ) : null}
          </div>
        </section>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<CipherTool />, { name: "Cipher" });
