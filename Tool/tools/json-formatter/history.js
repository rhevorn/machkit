/** JSON paste history helpers (pure). */

export const HISTORY_STORAGE_KEY = "json-history-v1";
export const HISTORY_MAX_ENTRIES = 100;
/** Skip individual pastes larger than this (UTF-8 byte estimate via string length proxy in callers). */
export const HISTORY_MAX_ENTRY_CHARS = 200_000;
/** Soft cap on serialized payload size so native storage stays bounded. */
export const HISTORY_MAX_TOTAL_CHARS = 1_500_000;

/**
 * @typedef {{ id: string, savedAt: number, preview: string, source: string }} HistoryEntry
 */

export function makePreview(source, maxLength = 72) {
  const compact = String(source ?? "").replace(/\s+/g, " ").trim();
  if (compact.length <= maxLength) return compact;
  return `${compact.slice(0, Math.max(0, maxLength - 1))}…`;
}

export function normalizeHistory(raw) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  const seen = new Set();
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const source = typeof item.source === "string" ? item.source : "";
    if (!source || source.length > HISTORY_MAX_ENTRY_CHARS) continue;
    const id = typeof item.id === "string" && item.id ? item.id : `h-${out.length}`;
    if (seen.has(id)) continue;
    seen.add(id);
    const savedAt = Number.isFinite(item.savedAt) ? Number(item.savedAt) : Date.now();
    const preview = typeof item.preview === "string" && item.preview
      ? item.preview
      : makePreview(source);
    out.push({ id, savedAt, preview, source });
    if (out.length >= HISTORY_MAX_ENTRIES) break;
  }
  return out;
}

export function parseHistoryPayload(raw) {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return normalizeHistory(parsed);
  } catch {
    return [];
  }
}

export function serializeHistory(entries) {
  return JSON.stringify(normalizeHistory(entries));
}

function estimateSerializedLength(entries) {
  return serializeHistory(entries).length;
}

/**
 * Prepend a paste. Dedupes identical source to the front. Enforces count and size caps.
 * @returns {{ entries: HistoryEntry[], changed: boolean }}
 */
export function pushHistoryEntry(entries, source, options = {}) {
  const text = String(source ?? "");
  if (!text || text.length > HISTORY_MAX_ENTRY_CHARS) {
    return { entries: normalizeHistory(entries), changed: false };
  }

  const now = Number.isFinite(options.now) ? options.now : Date.now();
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

export function removeHistoryEntry(entries, id) {
  return normalizeHistory(entries).filter((item) => item.id !== id);
}
