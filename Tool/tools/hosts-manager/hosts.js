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
