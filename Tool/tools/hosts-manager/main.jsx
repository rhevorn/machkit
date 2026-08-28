import React, { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import CodeMirror from "@uiw/react-codemirror";
import { Desktop, HardDrives, Link, Plus } from "@phosphor-icons/react";
import { Button, Input, RadioDot, SidebarNavItem, StatusStrip, ToolPage, ToolSidebar } from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useMachKitEditorTheme } from "@/ui/codemirror-theme.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.jsx";

import { labels } from "./messages.js";
import { createOperationQueue } from "./operation-queue.js";

const SIDEBAR_ITEM_CLASS = "h-12 min-h-12 shrink-0 py-2";

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
    ...drafts.map((environment) => ({ id: environment.id, name: environmentName(environment), hint: "", icon: HardDrives })),
  ];

  return (
    <ToolPage title={text.title}>
      <div className="flex min-h-0 flex-1 bg-surface">
        <ToolSidebar width={220} className="bg-surface py-3 pl-3 pr-1">
          <div className="machkit-sidebar-label px-2 pt-1 pb-1.5">{text.system}</div>
          {rows.slice(0, 1).map((row) => (
            <SidebarNavItem
              key={row.id}
              icon={row.icon}
              label={row.name}
              hint={row.hint}
              active={selection === row.id}
              onClick={() => setSelection(row.id)}
              className={SIDEBAR_ITEM_CLASS}
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
              className={SIDEBAR_ITEM_CLASS}
            />
          ))}
          <div className="mt-3 flex h-9 shrink-0 items-center pl-2 pr-1.5">
            <span className="machkit-sidebar-label min-w-0 flex-1">{text.environments}</span>
            <Button variant="ghost" size="icon" className="size-5" onClick={addEnvironment} aria-label={text.add}><Plus size={14} /></Button>
          </div>
          <div className="space-y-1.5 overflow-auto">
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
              {rows.find((row) => row.id === selection)?.hint ? (
                <div className="truncate px-1 text-xs text-secondary">
                  {rows.find((row) => row.id === selection)?.hint}
                </div>
              ) : null}
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
  const [menu, setMenu] = useState(null);
  const canDelete = !active && !busy;
  const Icon = row.icon;

  useEffect(() => {
    if (!menu) return undefined;
    const close = () => setMenu(null);
    const onKeyDown = (event) => {
      if (event.key === "Escape") close();
    };
    window.addEventListener("mousedown", close);
    window.addEventListener("scroll", close, true);
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("mousedown", close);
      window.removeEventListener("scroll", close, true);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [menu]);

  return (
    <div
      className={cn(
        "relative flex h-12 w-full shrink-0 items-center rounded-control pr-1.5 transition-colors",
        selected ? "bg-accent-soft text-accent" : "text-secondary hover:bg-foreground/[0.04] hover:text-foreground",
      )}
      onContextMenu={(event) => {
        event.preventDefault();
        if (!canDelete) return;
        setMenu({ x: event.clientX, y: event.clientY });
      }}
    >
      {selected ? (
        <span
          className="absolute top-1.5 bottom-1.5 left-0 w-0.5 rounded-full bg-accent"
          aria-hidden="true"
        />
      ) : null}
      <button
        type="button"
        onClick={() => onSelect(row.id)}
        aria-current={selected ? "page" : undefined}
        className="flex min-h-12 min-w-0 flex-1 items-center gap-2 px-2 text-left outline-none focus-visible:ring-2 focus-visible:ring-accent/35"
      >
        {Icon ? <Icon size={16} className={cn("shrink-0", selected ? "text-accent" : "text-secondary")} /> : null}
        <span className={cn("min-w-0 flex-1 truncate text-[12.5px]", selected && "font-medium")}>{row.name}</span>
      </button>
      <RadioDot
        checked={active}
        disabled={active || busy}
        label={`${text.activate} ${row.name}`}
        onClick={() => onActivate(row.id)}
      />
      {menu
        ? createPortal(
          <div
            role="menu"
            className="fixed z-50 min-w-[132px] rounded-control border border-border bg-surface py-1 shadow-md"
            style={{ left: menu.x, top: menu.y }}
            onMouseDown={(event) => event.stopPropagation()}
          >
            <button
              type="button"
              role="menuitem"
              className="flex w-full items-center px-3 py-1.5 text-left text-xs text-danger outline-none hover:bg-danger/10"
              onClick={() => {
                setMenu(null);
                onDelete(row.id);
              }}
            >
              {text.delete}
            </button>
          </div>,
          document.body,
        )
        : null}
    </div>
  );
}

mountTool(<HostsManager />, { name: "Hosts Manager" });
