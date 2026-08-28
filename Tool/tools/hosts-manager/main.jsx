import React, { useEffect, useMemo, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { Check, Desktop, HardDrives, Link, Plus, Power, Trash } from "@phosphor-icons/react";
import * as ContextMenu from "@radix-ui/react-context-menu";
import { Button, InlineMessage, ToolPage } from "@/ui/index.js";
import { useMachKitEditorTheme } from "@/ui/codemirror-theme.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";

import { labels } from "./messages.js";
import { createOperationQueue } from "./operation-queue.js";

function HostsManager() {
  const text = useToolMessages(labels);
  const editorTheme = useMachKitEditorTheme();
  const [data, setData] = useState(null);
  const [selection, setSelection] = useState("system");
  const [drafts, setDrafts] = useState([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const dataRef = useRef(null);
  const draftsRef = useRef([]);
  const editRevisionRef = useRef(0);
  const operationQueueRef = useRef(null);
  if (!operationQueueRef.current) {
    operationQueueRef.current = createOperationQueue((pending) => setBusy(pending > 0));
  }

  const replaceData = (nextData, { replaceDrafts = true } = {}) => {
    dataRef.current = nextData;
    setData(nextData);
    if (replaceDrafts) {
      draftsRef.current = nextData.environments;
      setDrafts(nextData.environments);
    }
  };

  const setLocalDrafts = (updater) => {
    const nextDrafts = typeof updater === "function" ? updater(draftsRef.current) : updater;
    draftsRef.current = nextDrafts;
    setDrafts(nextDrafts);
    editRevisionRef.current += 1;
    return nextDrafts;
  };

  const selectedEnvironment = useMemo(
    () => drafts.find((environment) => environment.id === selection),
    [drafts, selection],
  );
  const editorValue = selection === "system"
    ? data?.systemContent || ""
    : selection === "shared"
      ? data?.sharedContent || ""
      : selectedEnvironment?.content || "";

  useEffect(() => {
    machkit.hosts("load").then((nextData) => {
      replaceData(nextData);
    }).catch((error) => setMessage(error.message));
  }, []);

  const save = async (
    nextDrafts = draftsRef.current,
    nextSharedContent = dataRef.current?.sharedContent || "",
  ) => {
    const localEditRevision = editRevisionRef.current;
    setMessage("");
    try {
      const nextData = await operationQueueRef.current.run(() => machkit.hosts("save", {
        environments: nextDrafts,
        sharedContent: nextSharedContent,
        revision: dataRef.current?.revision,
      }));
      const hasNewerLocalEdits = editRevisionRef.current !== localEditRevision;
      if (hasNewerLocalEdits) {
        dataRef.current = {
          ...nextData,
          sharedContent: dataRef.current.sharedContent,
        };
        setData(dataRef.current);
      } else {
        replaceData(nextData);
      }
      return true;
    } catch (error) {
      setMessage(error.message);
      return false;
    }
  };

  const activate = async (id) => {
    if (!await save()) return;
    setMessage("");
    try {
      const nextData = await operationQueueRef.current.run(() => machkit.hosts("activate", {
        id,
        revision: dataRef.current?.revision,
      }));
      replaceData(nextData);
    } catch (error) {
      setMessage(error.message);
    }
  };

  const addEnvironment = () => {
    const environment = { id: crypto.randomUUID(), name: `${text.environments} ${drafts.length + 1}`, content: "" };
    const nextDrafts = [...drafts, environment];
    setLocalDrafts(nextDrafts);
    setSelection(environment.id);
    save(nextDrafts);
  };

  const updateContent = (value) => {
    if (selection === "shared") {
      const nextData = { ...dataRef.current, sharedContent: value };
      dataRef.current = nextData;
      setData(nextData);
      editRevisionRef.current += 1;
      setMessage("");
      return;
    }
    if (!selectedEnvironment) return;
    setLocalDrafts((current) => current.map((environment) => environment.id === selection ? { ...environment, content: value } : environment));
    setMessage("");
  };

  const updateName = (value) => {
    if (!selectedEnvironment) return;
    setLocalDrafts((current) => current.map((environment) => environment.id === selection ? { ...environment, name: value } : environment));
    setMessage("");
  };

  const removeEnvironment = async (id) => {
    if (id === data.activeEnvironmentID) return;
    const nextDrafts = drafts.filter((environment) => environment.id !== id);
    if (selection === id) setSelection("shared");
    setLocalDrafts(nextDrafts);
    await save(nextDrafts);
  };

  const environmentName = (environment) => {
    if (environment.id.endsWith("0001") && environment.name === "Development") return text.development;
    if (environment.id.endsWith("0002") && environment.name === "Testing") return text.testing;
    if (environment.id.endsWith("0003") && environment.name === "Production") return text.production;
    return environment.name;
  };

  if (!data) return <ToolPage title="Hosts Manager"><div className="grid h-full place-items-center text-xs text-secondary">{message || "…"}</div></ToolPage>;

  const rows = [
    { id: "system", name: text.systemHosts, hint: text.systemHint, icon: Desktop },
    { id: "shared", name: text.sharedName, hint: text.sharedHint, icon: Link },
    ...drafts.map((environment) => ({ id: environment.id, name: environmentName(environment), hint: environment.id === data.activeEnvironmentID ? text.active : "", icon: HardDrives })),
  ];

  return (
    <ToolPage title="Hosts Manager">
      <div className="flex min-h-0 flex-1 bg-surface">
        <aside className="w-[220px] shrink-0 bg-surface p-3">
          <div className="machkit-sidebar-label px-2 pt-1 pb-1.5">{text.system}</div>
          {rows.slice(0, 1).map((row) => <HostRow key={row.id} row={row} selected={selection === row.id} active={false} onSelect={setSelection} />)}
          <div className="machkit-sidebar-label px-2 pt-3 pb-1.5">{text.shared}</div>
          {rows.slice(1, 2).map((row) => <HostRow key={row.id} row={row} selected={selection === row.id} active={false} onSelect={setSelection} />)}
          <div className="mt-3 flex items-center justify-between px-2.5 py-2">
            <span className="machkit-sidebar-label">{text.environments}</span>
            <Button variant="ghost" size="icon" className="size-7" onClick={addEnvironment} aria-label={text.add}><Plus size={14} /></Button>
          </div>
          <div className="space-y-1 overflow-auto">
            {rows.slice(2).map((row) => (
              <EnvironmentRow
                key={row.id}
                row={row}
                text={text}
                busy={busy}
                selected={selection === row.id}
                active={row.id === data.activeEnvironmentID}
                onSelect={setSelection}
                onActivate={activate}
                onDelete={removeEnvironment}
              />
            ))}
          </div>
        </aside>

        <section className="flex min-w-0 flex-1 flex-col">
          <header className="flex h-[62px] shrink-0 items-center px-5">
            <div className="min-w-0 flex-1">
              {selectedEnvironment ? (
                <input
                  value={selectedEnvironment.name}
                  onChange={(event) => updateName(event.target.value)}
                  onBlur={() => save()}
                  aria-label={selectedEnvironment.name}
                  className="h-7 w-full rounded-[6px] bg-transparent px-1 text-sm font-semibold outline-none hover:bg-muted focus:bg-muted"
                />
              ) : <div className="truncate px-1 text-sm font-semibold">{rows.find((row) => row.id === selection)?.name}</div>}
              <div className="truncate px-1 text-xs text-secondary">{rows.find((row) => row.id === selection)?.hint}</div>
            </div>
          </header>
          <div className="min-h-0 flex-1 px-5 pb-5">
            <CodeMirror
              value={editorValue}
              height="100%"
              extensions={editorTheme}
              readOnly={selection === "system"}
              editable={selection !== "system"}
              basicSetup={{
                lineNumbers: true,
                highlightActiveLine: selection !== "system",
                highlightActiveLineGutter: selection !== "system",
                foldGutter: false,
                dropCursor: false,
                allowMultipleSelections: false,
                indentOnInput: false,
              }}
              onChange={updateContent}
              onBlur={() => selection !== "system" && save()}
              placeholder={`# ${text.empty}\n127.0.0.1    api.example.local`}
              className="hosts-code-editor machkit-panel h-full min-h-0"
            />
          </div>
          {message ? <div className="px-3 pb-3"><InlineMessage tone="danger">{message}</InlineMessage></div> : null}
        </section>
      </div>
    </ToolPage>
  );
}

function HostRow({ row, selected, active, onSelect }) {
  const Icon = row.icon;
  return (
    <button type="button" onClick={() => onSelect(row.id)} className={`flex h-12 w-full items-center gap-3 rounded-control px-2.5 text-left ${selected ? "bg-foreground/[0.075] text-foreground" : "text-foreground hover:bg-foreground/[0.045]"}`}>
      <Icon size={16} className="shrink-0" />
      <span className="min-w-0 flex-1"><span className="block truncate text-xs font-medium">{row.name}</span>{row.hint ? <span className="mt-0.5 block truncate text-[11px] text-secondary">{row.hint}</span> : null}</span>
      {active ? <span className="size-1.5 rounded-full bg-green-500" /> : null}
    </button>
  );
}

function EnvironmentRow({ row, text, busy, selected, active, onSelect, onActivate, onDelete }) {
  const Icon = row.icon;
  return (
    <ContextMenu.Root>
      <ContextMenu.Trigger asChild>
        <div className={`group flex h-12 w-full items-center rounded-control pr-2.5 ${selected ? "bg-foreground/[0.075]" : "hover:bg-foreground/[0.045]"}`}>
          <button type="button" onClick={() => onSelect(row.id)} className="flex min-w-0 flex-1 items-center gap-3 self-stretch px-2.5 text-left text-foreground">
            <Icon size={16} className="shrink-0 text-secondary" />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-xs font-medium">{row.name}</span>
              {active ? <span className="mt-0.5 block truncate text-[11px] text-secondary">{text.active}</span> : null}
            </span>
          </button>
          <button
            type="button"
            role="radio"
            aria-checked={active}
            aria-label={`${text.activate} ${row.name}`}
            disabled={active || busy}
            onClick={() => onActivate(row.id)}
            className={`grid size-[15px] shrink-0 place-items-center rounded-full border outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/30 ${active ? "border-accent bg-accent" : "border-tertiary hover:border-accent"}`}
          >
            {active ? <span className="size-[5px] rounded-full bg-white" /> : null}
          </button>
        </div>
      </ContextMenu.Trigger>
      <ContextMenu.Portal>
        <ContextMenu.Content className="z-50 min-w-36 rounded-panel border border-border bg-surface p-1 shadow-popover outline-none">
          <ContextMenu.Item disabled={active || busy} onSelect={() => onActivate(row.id)} className="flex h-8 cursor-default items-center gap-2 rounded-[6px] px-2.5 text-xs outline-none data-[highlighted]:bg-muted data-[disabled]:opacity-40">
            {active ? <Check size={14} /> : <Power size={14} />}{active ? text.active : text.activate}
          </ContextMenu.Item>
          <ContextMenu.Item disabled={active || busy} onSelect={() => onDelete(row.id)} className="flex h-8 cursor-default items-center gap-2 rounded-[6px] px-2.5 text-xs text-danger outline-none data-[highlighted]:bg-danger/10 data-[disabled]:opacity-40">
            <Trash size={14} />{text.delete}
          </ContextMenu.Item>
        </ContextMenu.Content>
      </ContextMenu.Portal>
    </ContextMenu.Root>
  );
}

mountTool(<HostsManager />, { name: "Hosts Manager" });
