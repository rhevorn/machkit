import React, { useEffect, useMemo, useRef, useState, type ComponentType, type SVGProps } from "react";
import { createPortal } from "react-dom";
import CodeMirror from "@uiw/react-codemirror";
import { Desktop, HardDrives, Link, Plus } from "@phosphor-icons/react";
import { Button, Input, SidebarNavItem, StatusStrip, ToolPage, ToolSidebar } from "@/ui/index.js";
import { cn } from "@/lib/utils.js";
import { useMachKitEditorTheme } from "@/ui/codemirror-theme.js";
import { useToolMessages } from "@/i18n.js";
import { machkit } from "@/runtime/machkit.js";
import { mountTool } from "@/runtime/mount-tool.js";

import { labels } from "./messages.js";
import { createOperationQueue, type OperationQueue } from "./operation-queue.js";
import {
  assertHostsSnapshot,
  clearDraftBackup,
  draftBackupDiffers,
  localizePresetEnvironmentName,
  readDraftBackup,
  shouldKeepLocalDrafts,
  writeDraftBackup,
  type HostsDraftPayload,
  type HostsEnvironment,
  type HostsSnapshot,
} from "./hosts.js";

const SIDEBAR_ITEM_CLASS = "h-12 min-h-12 shrink-0 py-2";
const DRAFT_SAVE_DELAY_MS = 350;

type ToolText = ReturnType<typeof useToolMessages<typeof labels>>;
type Selection = "system" | "shared" | string;
type SidebarRow = {
  id: string;
  name: string;
  hint: string;
  icon: ComponentType<SVGProps<SVGSVGElement> & { size?: number | string }>;
};
type ContextMenuState = { x: number; y: number };

function HostsManager() {
  const text = useToolMessages(labels);
  const editorTheme = useMachKitEditorTheme();
  const [data, setData] = useState<HostsSnapshot | null>(null);
  const [selection, setSelection] = useState<Selection>("system");
  const [drafts, setDrafts] = useState<HostsEnvironment[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const dataRef = useRef<HostsSnapshot | null>(null);
  const draftsRef = useRef<HostsEnvironment[]>([]);
  const selectionRef = useRef<Selection>("system");
  const editRevisionRef = useRef(0);
  const dirtyRef = useRef(false);
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const saveRef = useRef<
    ((nextDrafts?: HostsEnvironment[], nextSharedContent?: string) => Promise<boolean>) | null
  >(null);
  const draftSavedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const operationQueueRef = useRef<OperationQueue | null>(null);
  if (!operationQueueRef.current) {
    operationQueueRef.current = createOperationQueue((pending) => setBusy(pending > 0));
  }
  selectionRef.current = selection;

  const sameEnvironmentID = (left: unknown, right: unknown): boolean => {
    if (left == null || right == null || left === "" || right === "") return false;
    return String(left).toLowerCase() === String(right).toLowerCase();
  };

  const replaceData = (nextData: HostsSnapshot, { replaceDrafts = true } = {}) => {
    dataRef.current = nextData;
    setData(nextData);
    if (replaceDrafts) {
      draftsRef.current = nextData.environments;
      setDrafts(nextData.environments);
    }
  };

  const setLocalDrafts = (
    updater: HostsEnvironment[] | ((current: HostsEnvironment[]) => HostsEnvironment[]),
  ): HostsEnvironment[] => {
    const nextDrafts = typeof updater === "function" ? updater(draftsRef.current) : updater;
    draftsRef.current = nextDrafts;
    setDrafts(nextDrafts);
    editRevisionRef.current += 1;
    return nextDrafts;
  };

  const selectedEnvironment = useMemo(
    () => drafts.find((environment) => sameEnvironmentID(environment.id, selection)),
    [drafts, selection],
  );
  const editorValue = selection === "system"
    ? data?.systemContent || ""
    : selection === "shared"
      ? data?.sharedContent || ""
      : selectedEnvironment?.content || "";
  const needsApply = Boolean(data?.needsApply);
  const canApply = selection !== "system" && (
    needsApply
    || Boolean(selectedEnvironment && !sameEnvironmentID(selection, data?.activeEnvironmentID))
  );

  const draftPayload = (
    nextDrafts: HostsEnvironment[] = draftsRef.current,
    nextSharedContent = dataRef.current?.sharedContent || "",
  ): HostsDraftPayload => ({
    environments: nextDrafts,
    sharedContent: nextSharedContent,
    revision: dataRef.current?.revision,
  });

  const stashBackup = () => {
    writeDraftBackup(window.localStorage, {
      environments: draftsRef.current,
      sharedContent: dataRef.current?.sharedContent ?? "",
      activeEnvironmentID: dataRef.current?.activeEnvironmentID ?? null,
    });
  };

  const scheduleSave = () => {
    dirtyRef.current = true;
    stashBackup();
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(() => {
      saveTimerRef.current = null;
      void saveRef.current?.();
    }, DRAFT_SAVE_DELAY_MS);
  };

  const flushSave = () => {
    if (saveTimerRef.current) {
      clearTimeout(saveTimerRef.current);
      saveTimerRef.current = null;
    }
    stashBackup();
    if (!dirtyRef.current || !dataRef.current) return undefined;
    return saveRef.current?.();
  };

  const markDraftSaved = () => {
    const baseTitle = text.title;
    const savedTitle = `${baseTitle}${text.draftSaved}`;
    void machkit.setWindowTitle(savedTitle);
    if (draftSavedTimerRef.current) clearTimeout(draftSavedTimerRef.current);
    draftSavedTimerRef.current = setTimeout(() => {
      draftSavedTimerRef.current = null;
      void machkit.setWindowTitle(baseTitle);
    }, 3000);
  };

  const save = async (
    nextDrafts: HostsEnvironment[] = draftsRef.current,
    nextSharedContent = dataRef.current?.sharedContent || "",
  ): Promise<boolean> => {
    if (!dataRef.current) return false;
    const queue = operationQueueRef.current;
    if (!queue) return false;
    const localEditRevision = editRevisionRef.current;
    setMessage("");
    try {
      const raw = await queue.run(() =>
        machkit.hosts("save", draftPayload(nextDrafts, nextSharedContent)),
      );
      const nextData = assertHostsSnapshot(raw);
      const hasNewerLocalEdits = shouldKeepLocalDrafts(editRevisionRef.current, localEditRevision);
      if (hasNewerLocalEdits) {
        dataRef.current = {
          ...nextData,
          sharedContent: dataRef.current.sharedContent,
          needsApply: true,
        };
        setData(dataRef.current);
        dirtyRef.current = true;
        stashBackup();
        scheduleSave();
      } else {
        dirtyRef.current = false;
        replaceData(nextData);
        clearDraftBackup(window.localStorage);
        markDraftSaved();
      }
      return true;
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
      return false;
    }
  };
  saveRef.current = save;

  useEffect(() => () => {
    if (draftSavedTimerRef.current) clearTimeout(draftSavedTimerRef.current);
    void machkit.setWindowTitle(text.title);
  }, [text.title]);

  useEffect(() => {
    machkit.hosts("load").then(async (raw) => {
      const nextData = assertHostsSnapshot(raw);
      const backup = readDraftBackup(window.localStorage);
      if (backup && draftBackupDiffers(backup, nextData)) {
        replaceData({
          ...nextData,
          environments: backup.environments,
          sharedContent: backup.sharedContent,
          needsApply: true,
        });
        draftsRef.current = backup.environments;
        setDrafts(backup.environments);
        dirtyRef.current = true;
        await save(backup.environments, backup.sharedContent);
        return;
      }
      replaceData(nextData);
      clearDraftBackup(window.localStorage);
    }).catch((error: unknown) => {
      setMessage(error instanceof Error ? error.message : String(error));
    });
  }, []);

  useEffect(() => {
    const persistDraft = () => {
      if (!dataRef.current || draftsRef.current.length === 0) return;
      stashBackup();
      void flushSave();
    };
    const onVisibility = () => {
      if (document.visibilityState === "hidden") persistDraft();
    };
    window.addEventListener("pagehide", persistDraft);
    window.addEventListener("beforeunload", persistDraft);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.removeEventListener("pagehide", persistDraft);
      window.removeEventListener("beforeunload", persistDraft);
      document.removeEventListener("visibilitychange", onVisibility);
      persistDraft();
    };
  }, []);

  const applyToSystem = async () => {
    const queue = operationQueueRef.current;
    if (!queue) return;
    const targetSelection = selectionRef.current;
    const targetEnvironmentID = targetSelection !== "system" && targetSelection !== "shared"
      ? targetSelection
      : null;
    if (dirtyRef.current) {
      const saved = await flushSave();
      if (saved === false) return;
    }
    setMessage("");
    try {
      const payload = draftPayload();
      if (targetEnvironmentID) {
        payload.environmentID = targetEnvironmentID;
      }
      const nextData = assertHostsSnapshot(await queue.run(() => machkit.hosts("apply", payload)));
      dirtyRef.current = false;
      replaceData(nextData);
      clearDraftBackup(window.localStorage);
      editRevisionRef.current += 1;
      if (targetEnvironmentID) {
        setSelection(targetEnvironmentID);
      }
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    }
  };

  const addEnvironment = () => {
    const environment: HostsEnvironment = {
      id: crypto.randomUUID(),
      name: `${text.environments} ${drafts.length + 1}`,
      content: "",
    };
    const nextDrafts = [...drafts, environment];
    setLocalDrafts(nextDrafts);
    setSelection(environment.id);
    dirtyRef.current = true;
    stashBackup();
    void save(nextDrafts);
  };

  const updateContent = (value: string) => {
    if (selection === "shared") {
      if (!dataRef.current) return;
      const nextData: HostsSnapshot = { ...dataRef.current, sharedContent: value, needsApply: true };
      dataRef.current = nextData;
      setData(nextData);
      editRevisionRef.current += 1;
      setMessage("");
      scheduleSave();
      return;
    }
    if (!selectedEnvironment) return;
    setLocalDrafts((current) =>
      current.map((environment) =>
        environment.id === selection ? { ...environment, content: value } : environment,
      ),
    );
    if (dataRef.current) {
      const nextData: HostsSnapshot = { ...dataRef.current, needsApply: true };
      dataRef.current = nextData;
      setData(nextData);
    }
    setMessage("");
    scheduleSave();
  };

  const updateName = (value: string) => {
    if (!selectedEnvironment) return;
    setLocalDrafts((current) =>
      current.map((environment) =>
        environment.id === selection ? { ...environment, name: value } : environment,
      ),
    );
    setMessage("");
    scheduleSave();
  };

  const removeEnvironment = async (id: string) => {
    if (!data || sameEnvironmentID(id, data.activeEnvironmentID)) return;
    const nextDrafts = drafts.filter((environment) => !sameEnvironmentID(environment.id, id));
    if (sameEnvironmentID(selection, id)) setSelection("shared");
    setLocalDrafts(nextDrafts);
    dirtyRef.current = true;
    stashBackup();
    await save(nextDrafts);
  };

  const environmentName = (environment: HostsEnvironment) =>
    localizePresetEnvironmentName(environment, text);

  if (!data) {
    return (
      <ToolPage title={text.title}>
        <div className="grid h-full place-items-center text-xs text-secondary">{message || "…"}</div>
      </ToolPage>
    );
  }

  const rows: SidebarRow[] = [
    { id: "system", name: text.systemHosts, hint: text.systemHint, icon: Desktop },
    { id: "shared", name: text.sharedName, hint: text.sharedHint, icon: Link },
    ...drafts.map((environment) => ({
      id: environment.id,
      name: environmentName(environment),
      hint: "",
      icon: HardDrives,
    })),
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
                active={sameEnvironmentID(row.id, data.activeEnvironmentID)}
                onSelect={setSelection}
                onDelete={removeEnvironment}
              />
            ))}
          </div>
        </ToolSidebar>

        <section className="flex min-w-0 flex-1 flex-col">
          <header className="flex min-h-[var(--machkit-size-toolbar)] shrink-0 items-center gap-3 px-5">
            <div className="min-w-0 flex-1">
              {selectedEnvironment ? (
                <Input
                  value={selectedEnvironment.name}
                  onChange={(event) => updateName(event.target.value)}
                  onBlur={() => flushSave()}
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
              ) : selectedEnvironment && sameEnvironmentID(selection, data.activeEnvironmentID) && !needsApply ? (
                <div className="truncate px-1 text-xs text-secondary">
                  {text.activeOnSystem}
                </div>
              ) : needsApply && selection !== "system" ? (
                <div className="truncate px-1 text-xs text-secondary">
                  {text.draftPending}
                </div>
              ) : selectedEnvironment ? (
                <div className="truncate px-1 text-xs text-secondary">
                  {text.applyThisEnvironment}
                </div>
              ) : null}
            </div>
            {selection !== "system" ? (
              <Button
                size="sm"
                disabled={busy || !canApply}
                onClick={applyToSystem}
              >
                {text.apply}
              </Button>
            ) : null}
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
              onBlur={() => selection !== "system" && flushSave()}
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

function EnvironmentRow({
  row,
  text,
  busy,
  selected,
  active,
  onSelect,
  onDelete,
}: {
  row: SidebarRow;
  text: ToolText;
  busy: boolean;
  selected: boolean;
  active: boolean;
  onSelect: (id: string) => void;
  onDelete: (id: string) => void | Promise<void>;
}) {
  const [menu, setMenu] = useState<ContextMenuState | null>(null);
  const canDelete = !active && !busy;
  const Icon = row.icon;

  useEffect(() => {
    if (!menu) return undefined;
    const close = () => setMenu(null);
    const onKeyDown = (event: KeyboardEvent) => {
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
        "relative flex h-12 w-full shrink-0 items-center rounded-control pr-2 transition-colors",
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
      <Button
        variant="ghost"
        onClick={() => onSelect(row.id)}
        aria-current={selected ? "page" : undefined}
        className={cn(
          "h-auto min-h-12 min-w-0 flex-1 justify-start gap-2 px-2 text-left font-normal",
          selected
            ? "bg-transparent text-accent hover:bg-transparent hover:text-accent"
            : "text-secondary hover:bg-transparent hover:text-foreground",
        )}
      >
        {Icon ? (
          <Icon size={16} className={cn("shrink-0", selected ? "text-accent" : "text-secondary")} />
        ) : null}
        <span className={cn("min-w-0 flex-1 truncate text-left text-[12.5px]", selected && "font-medium")}>
          {row.name}
        </span>
        <span
          className={cn(
            "size-2 shrink-0 rounded-full",
            active ? "bg-accent" : "bg-transparent",
          )}
          title={active ? text.active : undefined}
          aria-label={active ? `${row.name} · ${text.active}` : undefined}
          aria-hidden={!active}
        />
      </Button>
      {menu
        ? createPortal(
          <div
            role="menu"
            className="fixed z-50 min-w-[132px] rounded-control border border-border bg-surface py-1 shadow-md"
            style={{ left: menu.x, top: menu.y }}
            onMouseDown={(event) => event.stopPropagation()}
          >
            <Button
              variant="ghost"
              role="menuitem"
              className="h-auto w-full justify-start rounded-none px-3 py-1.5 text-xs font-normal text-danger hover:bg-danger/10 hover:text-danger"
              onClick={() => {
                setMenu(null);
                onDelete(row.id);
              }}
            >
              {text.delete}
            </Button>
          </div>,
          document.body,
        )
        : null}
    </div>
  );
}

mountTool(<HostsManager />, { name: "Hosts Manager" });
