export type HostsEnvironment = {
  id: string;
  name: string;
  content: string;
};

export type HostsDraftBackup = {
  environments: HostsEnvironment[];
  sharedContent: string;
  activeEnvironmentID: string | null;
};

export type HostsSnapshot = {
  systemContent: string;
  sharedContent: string;
  environments: HostsEnvironment[];
  activeEnvironmentID: string | null;
  revision: number;
  needsApply: boolean;
};

export type HostsDraftPayload = {
  environments: HostsEnvironment[];
  sharedContent: string;
  revision?: number;
  environmentID?: string;
};

export type HostsStorageLike = {
  getItem: (key: string) => string | null;
  setItem: (key: string, value: string) => void;
  removeItem: (key: string) => void;
};

type PresetNameText = {
  development?: string;
  testing?: string;
  production?: string;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isHostsEnvironment(value: unknown): value is HostsEnvironment {
  if (!isRecord(value)) return false;
  return (
    typeof value.id === "string" &&
    typeof value.name === "string" &&
    typeof value.content === "string"
  );
}

/** Narrow `machkit.hosts(...)` Promise<unknown> results to the bridge snapshot shape. */
export function isHostsSnapshot(value: unknown): value is HostsSnapshot {
  if (!isRecord(value)) return false;
  if (typeof value.systemContent !== "string") return false;
  if (typeof value.sharedContent !== "string") return false;
  if (typeof value.revision !== "number") return false;
  if (typeof value.needsApply !== "boolean") return false;
  if (!Array.isArray(value.environments) || !value.environments.every(isHostsEnvironment)) {
    return false;
  }
  const active = value.activeEnvironmentID;
  if (!(active === null || typeof active === "string")) return false;
  return true;
}

export function assertHostsSnapshot(value: unknown): HostsSnapshot {
  if (!isHostsSnapshot(value)) {
    throw new Error("Invalid hosts snapshot from MachKit.");
  }
  return value;
}

/** Environment IDs from the native bridge may differ only by UUID letter case. */
export function sameEnvironmentID(left: unknown, right: unknown): boolean {
  if (left == null || right == null || left === "" || right === "") return false;
  return String(left).toLowerCase() === String(right).toLowerCase();
}

/**
 * Prefer the canonical environment ID from a snapshot when the current selection
 * matches case-insensitively (e.g. after save/apply round-trips).
 */
export function normalizeEnvironmentSelection(
  selection: string,
  environments: ReadonlyArray<Pick<HostsEnvironment, "id">> | null | undefined,
): string {
  if (selection === "system" || selection === "shared") return selection;
  const match = (environments ?? []).find((environment) =>
    sameEnvironmentID(environment.id, selection),
  );
  return match?.id ?? selection;
}

/**
 * Localize built-in hosts environment display names without rewriting stored IDs.
 * Preset UUIDs end with 0001 / 0002 / 0003 and ship with English default names.
 */
export function localizePresetEnvironmentName(
  environment: Pick<HostsEnvironment, "id" | "name"> | null | undefined,
  text: PresetNameText,
): string {
  if (!environment) return "";
  const name = String(environment.name ?? "");
  const id = String(environment.id ?? "");
  if (id.endsWith("0001") && name === "Development") return text.development ?? name;
  if (id.endsWith("0002") && name === "Testing") return text.testing ?? name;
  if (id.endsWith("0003") && name === "Production") return text.production ?? name;
  return name;
}

/** Keep local drafts when the user edited while a save was in flight. */
export function shouldKeepLocalDrafts(editRevision: number, savedRevision: number): boolean {
  return editRevision !== savedRevision;
}

export const HOSTS_DRAFT_BACKUP_KEY = "machkit.hosts-manager.draft";

/** Sync browser backup so closing the WebView cannot drop unsaved keystrokes. */
export function writeDraftBackup(
  storage: HostsStorageLike | null | undefined,
  draft: HostsDraftBackup | null | undefined,
): void {
  if (!storage || !draft) return;
  const environments = draft.environments ?? [];
  // Never persist an empty environment list — that can wipe presets on restore.
  if (!Array.isArray(environments) || environments.length === 0) return;
  storage.setItem(
    HOSTS_DRAFT_BACKUP_KEY,
    JSON.stringify({
      environments,
      sharedContent: draft.sharedContent ?? "",
      activeEnvironmentID: draft.activeEnvironmentID ?? null,
    }),
  );
}

export function readDraftBackup(storage: HostsStorageLike | null | undefined): HostsDraftBackup | null {
  if (!storage) return null;
  try {
    const raw = storage.getItem(HOSTS_DRAFT_BACKUP_KEY);
    if (!raw) return null;
    const parsed: unknown = JSON.parse(raw);
    if (!isRecord(parsed) || !Array.isArray(parsed.environments) || parsed.environments.length === 0) {
      return null;
    }
    if (!parsed.environments.every(isHostsEnvironment)) return null;
    return {
      environments: parsed.environments,
      sharedContent: typeof parsed.sharedContent === "string" ? parsed.sharedContent : "",
      activeEnvironmentID:
        typeof parsed.activeEnvironmentID === "string" ? parsed.activeEnvironmentID : null,
    };
  } catch {
    return null;
  }
}

export function clearDraftBackup(storage: HostsStorageLike | null | undefined): void {
  storage?.removeItem(HOSTS_DRAFT_BACKUP_KEY);
}

export function draftBackupDiffers(
  backup: HostsDraftBackup | null | undefined,
  data: Pick<HostsSnapshot, "environments" | "sharedContent" | "activeEnvironmentID"> | null | undefined,
): boolean {
  if (!backup || !data) return false;
  if (!Array.isArray(backup.environments) || backup.environments.length === 0) return false;
  if ((backup.sharedContent ?? "") !== (data.sharedContent ?? "")) return true;
  if ((backup.activeEnvironmentID ?? null) !== (data.activeEnvironmentID ?? null)) return true;
  return JSON.stringify(backup.environments ?? []) !== JSON.stringify(data.environments ?? []);
}
