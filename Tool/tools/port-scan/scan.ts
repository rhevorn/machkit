export const minimumPort = 1;
export const maximumPort = 65_535;

export const presets = Object.freeze({
  common: "20-23,25,53,67-69,80,110,123,135,137-139,143,161,389,443,445,465,514,587,631,636,873,993,995,1080,1433,1521,1883,2049,2375-2376,3000,3306,3389,4000,4200,5000,5432,5672,5900,5984,6379,6443,8000,8080,8443,8888,9000,9090,9200,11211,27017",
  web: "80,443,3000,4000,4200,5000,5173,8000,8080,8081,8443,8888,9000",
  dev: "22,2375-2376,3000-3010,3306,4000-4010,4200,5000-5010,5173,5432,5672,6379,8000-8010,8080-8090,8443,8888,9000-9010,9090,9200,11211,27017",
  database: "1433,1521,3306,5432,5984,6379,7474,8529,9042,9200,11211,27017",
  all: "1-65535",
});

export type PortPreset = keyof typeof presets;

export type PortInspectResult =
  | { ok: true; error: null; count: number }
  | { ok: false; error: string; count: number };

export type ScanState = "idle" | "running" | "completed" | "cancelled" | "failed" | string;

export type OpenPort = {
  port: number;
  service?: string;
  latencyMs?: number | null;
};

export type ScanResult = {
  state?: string;
  scanID?: string;
  host?: string;
  total?: number;
  completed?: number;
  openPorts?: OpenPort[];
  closed?: number;
  timedOut?: number;
  durationMs?: number | null;
  error?: string | null;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function isScanResult(value: unknown): value is ScanResult {
  if (!isRecord(value)) return false;
  if (value.state !== undefined && typeof value.state !== "string") return false;
  if (value.scanID !== undefined && typeof value.scanID !== "string") return false;
  if (value.host !== undefined && typeof value.host !== "string") return false;
  if (value.total !== undefined && typeof value.total !== "number") return false;
  if (value.completed !== undefined && typeof value.completed !== "number") return false;
  if (value.closed !== undefined && typeof value.closed !== "number") return false;
  if (value.timedOut !== undefined && typeof value.timedOut !== "number") return false;
  if (value.durationMs !== undefined && value.durationMs !== null && typeof value.durationMs !== "number") {
    return false;
  }
  if (value.error !== undefined && value.error !== null && typeof value.error !== "string") return false;
  if (value.openPorts !== undefined) {
    if (!Array.isArray(value.openPorts)) return false;
    for (const entry of value.openPorts) {
      if (!isRecord(entry) || typeof entry.port !== "number") return false;
    }
  }
  return true;
}

export function assertScanResult(value: unknown): ScanResult {
  if (!isScanResult(value)) {
    throw new Error("Invalid port scan result from MachKit.");
  }
  return value;
}

export function normalizeHost(value: unknown): string {
  return String(value ?? "").trim();
}

export function inspectPortExpression(value: unknown): PortInspectResult {
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
      const lower = Number(bounds[0]!.trim());
      const upper = Number(bounds[1]!.trim());
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
  return { ok: count > 0 ? true : false, error: count > 0 ? null : "empty-ports", count } as PortInspectResult;
}

export function progressPercent(completed: unknown, total: unknown): number {
  const safeTotal = Number(total);
  if (!Number.isFinite(safeTotal) || safeTotal <= 0) return 0;
  return Math.min(100, Math.max(0, Math.round((Number(completed) / safeTotal) * 100)));
}

export function formatDuration(value: unknown): string {
  const ms = Number(value);
  if (!Number.isFinite(ms) || ms < 0) return "—";
  if (ms < 1_000) return `${Math.round(ms)} ms`;
  if (ms < 60_000) return `${(ms / 1_000).toFixed(1)} s`;
  return `${Math.floor(ms / 60_000)}m ${Math.round((ms % 60_000) / 1_000)}s`;
}

export function isTerminalState(state: unknown): boolean {
  return ["completed", "cancelled", "failed"].includes(String(state));
}
