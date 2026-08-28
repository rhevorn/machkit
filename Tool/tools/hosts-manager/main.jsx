import React, { useEffect, useMemo, useRef, useState } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { Desktop, HardDrives, Link, Plus, Trash } from "@phosphor-icons/react";
import { Button, IconButton, Input, RadioDot, SidebarNavItem, StatusStrip, ToolPage, ToolSidebar } from "@/ui/index.js";
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

  if (!data) {
    return (
      <ToolPage title={text.title}>
        <div className="grid h-full place-items-center text-xs text-secondary">{message || "…"}</div>
      </ToolPage>
    );
  }

  const rows = [
    { id: "system", name: text.systemHosts, hint: text.systemHint, icon: Desktop },
    { id: "shared", name: text.sharedName, hint: text.sharedHint, icon: Link },
    ...drafts.map((environment) => ({ id: environment.id, name: environmentName(environment), hint: environment.id === data.activeEnvironmentID ? text.active : "", icon: HardDrives })),
  ];

  return (
    <ToolPage title={text.title}>
      <div className="flex min-h-0 flex-1 bg-surface">
        <ToolSidebar width={220} className="bg-surface p-3">
          <div className="machkit-sidebar-label px-2 pt-1 pb-1.5">{text.system}</div>
          {rows.slice(0, 1).map((row) => (
            <SidebarNavItem
              key={row.id}
              icon={row.icon}
              label={row.name}
              hint={row.hint}
              active={selection === row.id}
              onClick={() => setSelection(row.id)}
            />
          ))}
          <div className="machkit-sidebar-label px-2 pt-3 pb-1.5">{text.shared}</div>
          {rows.slice(1, 2).map((row) => (
            <SidebarNavItem
              key={row.id}
              icon={row.icon}
              label={row.name}
              hint={row.hint}
              active={selection === row.id}
              onClick={() => setSelection(row.id)}
            />
          ))}
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
        </ToolSidebar>

        <section className="flex min-w-0 flex-1 flex-col">
          <header className="flex min-h-[var(--machkit-size-toolbar)] shrink-0 items-center px-5">
            <div className="min-w-0 flex-1">
              {selectedEnvironment ? (
                <Input
                  value={environmentName(selectedEnvironment)}
                  onChange={(event) => updateName(event.target.value)}
                  onBlur={() => save()}
                  aria-label={environmentName(selectedEnvironment)}
                  className="h-7 border-transparent bg-transparent px-1 text-sm font-semibold shadow-none hover:bg-muted focus:border-transparent focus:bg-muted focus:ring-0"
                />
              ) : (
                <div className="truncate px-1 text-sm font-semibold">
                  {rows.find((row) => row.id === selection)?.name}
                </div>
              )}
              <div className="truncate px-1 text-xs text-secondary">
                {rows.find((row) => row.id === selection)?.hint}
              </div>
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
          {message ? <div className="px-3 pb-3"><StatusStrip tone="danger">{message}</StatusStrip></div> : null}
        </section>
      </div>
    </ToolPage>
  );
}

function EnvironmentRow({ row, text, busy, selected, active, onSelect, onActivate, onDelete }) {
  return (
    <div className="group flex w-full items-center gap-0.5">
      <SidebarNavItem
        icon={row.icon}
        label={row.name}
        hint={active ? text.active : undefined}
        active={selected}
        onClick={() => onSelect(row.id)}
        className="min-w-0 flex-1"
      />
      <IconButton
        label={`${text.delete} ${row.name}`}
        disabled={active || busy}
        onClick={() => onDelete(row.id)}
        className="size-7 shrink-0 text-secondary opacity-0 transition-opacity group-hover:opacity-100 hover:bg-danger/10 hover:text-danger focus-visible:opacity-100 disabled:pointer-events-none disabled:opacity-0"
      >
        <Trash size={14} />
      </IconButton>
      <RadioDot
        checked={active}
        disabled={active || busy}
        label={`${text.activate} ${row.name}`}
        onClick={() => onActivate(row.id)}
        className="mr-1"
      />
    </div>
  );
}

mountTool(<HostsManager />, { name: "Hosts Manager" });
