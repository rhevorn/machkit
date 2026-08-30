/**
 * Localize built-in hosts environment display names without rewriting stored IDs.
 * Preset UUIDs end with 0001 / 0002 / 0003 and ship with English default names.
 */
export function localizePresetEnvironmentName(environment, text) {
  if (!environment) return "";
  const name = String(environment.name ?? "");
  const id = String(environment.id ?? "");
  if (id.endsWith("0001") && name === "Development") return text.development ?? name;
  if (id.endsWith("0002") && name === "Testing") return text.testing ?? name;
  if (id.endsWith("0003") && name === "Production") return text.production ?? name;
  return name;
}

/** Keep local drafts when the user edited while a save was in flight. */
export function shouldKeepLocalDrafts(editRevision, savedRevision) {
  return editRevision !== savedRevision;
}

export const HOSTS_DRAFT_BACKUP_KEY = "machkit.hosts-manager.draft";

/** Sync browser backup so closing the WebView cannot drop unsaved keystrokes. */
export function writeDraftBackup(storage, draft) {
  if (!storage || !draft) return;
  const environments = draft.environments ?? [];
  // Never persist an empty environment list — that can wipe presets on restore.
  if (!Array.isArray(environments) || environments.length === 0) return;
  storage.setItem(HOSTS_DRAFT_BACKUP_KEY, JSON.stringify({
    environments,
    sharedContent: draft.sharedContent ?? "",
    activeEnvironmentID: draft.activeEnvironmentID ?? null,
  }));
}

export function readDraftBackup(storage) {
  if (!storage) return null;
  try {
    const raw = storage.getItem(HOSTS_DRAFT_BACKUP_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.environments) || parsed.environments.length === 0) {
      return null;
    }
    return {
      environments: parsed.environments,
      sharedContent: typeof parsed.sharedContent === "string" ? parsed.sharedContent : "",
      activeEnvironmentID: typeof parsed.activeEnvironmentID === "string"
        ? parsed.activeEnvironmentID
        : null,
    };
  } catch {
    return null;
  }
}

export function clearDraftBackup(storage) {
  storage?.removeItem(HOSTS_DRAFT_BACKUP_KEY);
}

export function draftBackupDiffers(backup, data) {
  if (!backup || !data) return false;
  if (!Array.isArray(backup.environments) || backup.environments.length === 0) return false;
  if ((backup.sharedContent ?? "") !== (data.sharedContent ?? "")) return true;
  if ((backup.activeEnvironmentID ?? null) !== (data.activeEnvironmentID ?? null)) return true;
  return JSON.stringify(backup.environments ?? []) !== JSON.stringify(data.environments ?? []);
}
