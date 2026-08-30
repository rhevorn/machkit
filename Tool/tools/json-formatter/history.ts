/** JSON paste history helpers (pure). */

export const HISTORY_STORAGE_KEY = "json-history-v1";
export const HISTORY_MAX_ENTRIES = 100;
/** Skip individual pastes larger than this (UTF-8 byte estimate via string length proxy in callers). */
export const HISTORY_MAX_ENTRY_CHARS = 200_000;
/** Soft cap on serialized payload size so native storage stays bounded. */
export const HISTORY_MAX_TOTAL_CHARS = 1_500_000;

export type HistoryEntry = {
  id: string;
  savedAt: number;
  preview: string;
  source: string;
};

export type PushHistoryOptions = {
  now?: number;
  idFactory?: () => string;
};

export function makePreview(source: unknown, maxLength = 72): string {
  const compact = String(source ?? "").replace(/\s+/g, " ").trim();
  if (compact.length <= maxLength) return compact;
  return `${compact.slice(0, Math.max(0, maxLength - 1))}…`;
}

export function normalizeHistory(raw: unknown): HistoryEntry[] {
  if (!Array.isArray(raw)) return [];
  const out: HistoryEntry[] = [];
  const seen = new Set<string>();
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const record = item as Record<string, unknown>;
    const source = typeof record.source === "string" ? record.source : "";
    if (!source || source.length > HISTORY_MAX_ENTRY_CHARS) continue;
    const id = typeof record.id === "string" && record.id ? record.id : `h-${out.length}`;
    if (seen.has(id)) continue;
    seen.add(id);
    const savedAt = Number.isFinite(record.savedAt) ? Number(record.savedAt) : Date.now();
    const preview = typeof record.preview === "string" && record.preview
      ? record.preview
      : makePreview(source);
    out.push({ id, savedAt, preview, source });
    if (out.length >= HISTORY_MAX_ENTRIES) break;
  }
  return out;
}

export function parseHistoryPayload(raw: unknown): HistoryEntry[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(String(raw));
    return normalizeHistory(parsed);
  } catch {
    return [];
  }
}

export function serializeHistory(entries: unknown): string {
  return JSON.stringify(normalizeHistory(entries));
}

function estimateSerializedLength(entries: unknown): number {
  return serializeHistory(entries).length;
}

/**
 * Prepend a paste. Dedupes identical source to the front. Enforces count and size caps.
 */
export function pushHistoryEntry(
  entries: unknown,
  source: unknown,
  options: PushHistoryOptions = {},
): { entries: HistoryEntry[]; changed: boolean } {
  const text = String(source ?? "");
  if (!text || text.length > HISTORY_MAX_ENTRY_CHARS) {
    return { entries: normalizeHistory(entries), changed: false };
  }

  const now = Number.isFinite(options.now) ? Number(options.now) : Date.now();
  const idFactory = typeof options.idFactory === "function"
    ? options.idFactory
    : () => `h-${now}-${Math.random().toString(36).slice(2, 10)}`;

  let next = normalizeHistory(entries).filter((item) => item.source !== text);
  next.unshift({
    id: idFactory(),
    savedAt: now,
    preview: makePreview(text),
    source: text,
  });

  while (next.length > HISTORY_MAX_ENTRIES) next.pop();
  while (next.length > 1 && estimateSerializedLength(next) > HISTORY_MAX_TOTAL_CHARS) {
    next.pop();
  }
  if (estimateSerializedLength(next) > HISTORY_MAX_TOTAL_CHARS) {
    return { entries: normalizeHistory(entries), changed: false };
  }

  return { entries: next, changed: true };
}

export function removeHistoryEntry(entries: unknown, id: unknown): HistoryEntry[] {
  return normalizeHistory(entries).filter((item) => item.id !== id);
}
