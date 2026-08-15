export const modes = Object.freeze(["dns", "full"]);

export function normalizeTarget(value) {
  return String(value ?? "").trim();
}

export function formatMs(value) {
  if (value == null || Number.isNaN(Number(value))) return "—";
  const ms = Number(value);
  if (ms < 1) return `${ms.toFixed(2)} ms`;
  if (ms < 10) return `${ms.toFixed(1)} ms`;
  return `${Math.round(ms)} ms`;
}

export function summarizeResult(result) {
  if (!result || typeof result !== "object") return { ok: false, error: "failed" };
  return result;
}

export function stepTone(step) {
  if (!step) return "neutral";
  if (step.ok) return "ok";
  return "danger";
}
