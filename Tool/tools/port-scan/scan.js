export const minimumPort = 1;
export const maximumPort = 65_535;

export const presets = Object.freeze({
  common: "20-23,25,53,67-69,80,110,123,135,137-139,143,161,389,443,445,465,514,587,631,636,873,993,995,1080,1433,1521,1883,2049,2375-2376,3000,3306,3389,4000,4200,5000,5432,5672,5900,5984,6379,6443,8000,8080,8443,8888,9000,9090,9200,11211,27017",
  web: "80,443,3000,4000,4200,5000,5173,8000,8080,8081,8443,8888,9000",
  dev: "22,2375-2376,3000-3010,3306,4000-4010,4200,5000-5010,5173,5432,5672,6379,8000-8010,8080-8090,8443,8888,9000-9010,9090,9200,11211,27017",
  database: "1433,1521,3306,5432,5984,6379,7474,8529,9042,9200,11211,27017",
  all: "1-65535",
});

export function normalizeHost(value) {
  return String(value ?? "").trim();
}

export function inspectPortExpression(value) {
  const input = String(value ?? "").replaceAll("，", ",").trim();
  if (!input) return { ok: false, error: "empty-ports", count: 0 };

  const selected = new Uint8Array(maximumPort + 1);
  let count = 0;
  for (const rawPart of input.split(",")) {
    const part = rawPart.trim();
    if (!part) return { ok: false, error: "invalid-port", count: 0 };

    if (part.includes("-")) {
      const bounds = part.split("-");
      if (bounds.length !== 2) return { ok: false, error: "invalid-range", count: 0 };
      const lower = Number(bounds[0].trim());
      const upper = Number(bounds[1].trim());
      if (!Number.isInteger(lower) || !Number.isInteger(upper)
        || lower < minimumPort || upper > maximumPort || lower > upper) {
        return { ok: false, error: "invalid-range", count: 0 };
      }
      for (let port = lower; port <= upper; port += 1) {
        if (!selected[port]) {
          selected[port] = 1;
          count += 1;
        }
      }
    } else {
      const port = Number(part);
      if (!Number.isInteger(port) || port < minimumPort || port > maximumPort) {
        return { ok: false, error: "invalid-port", count: 0 };
      }
      if (!selected[port]) {
        selected[port] = 1;
        count += 1;
      }
    }
  }
  return { ok: count > 0, error: count > 0 ? null : "empty-ports", count };
}

export function progressPercent(completed, total) {
  const safeTotal = Number(total);
  if (!Number.isFinite(safeTotal) || safeTotal <= 0) return 0;
  return Math.min(100, Math.max(0, Math.round((Number(completed) / safeTotal) * 100)));
}

export function formatDuration(value) {
  const ms = Number(value);
  if (!Number.isFinite(ms) || ms < 0) return "—";
  if (ms < 1_000) return `${Math.round(ms)} ms`;
  if (ms < 60_000) return `${(ms / 1_000).toFixed(1)} s`;
  return `${Math.floor(ms / 60_000)}m ${Math.round((ms % 60_000) / 1_000)}s`;
}

export function isTerminalState(state) {
  return ["completed", "cancelled", "failed"].includes(state);
}
