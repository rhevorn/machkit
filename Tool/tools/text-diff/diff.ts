export const maxDiffInput = 400_000;
export const maxDiffLines = 4_000;
/** Cap Myers edit distance to bound memory (compact traces still grow with D²). */
export const maxEditDistance = 4_000;

export type DiffOptions = {
  ignoreWhitespace?: boolean;
};

export type DiffRow = {
  type: "equal" | "delete" | "insert";
  leftLine: number | null;
  rightLine: number | null;
  leftText: string;
  rightText: string;
};

export type DiffStats = {
  equal: number;
  removed: number;
  added: number;
  leftLines: number;
  rightLines: number;
};

export type DiffResult = {
  ok: boolean;
  error: string | null;
  rows: DiffRow[];
  stats: DiffStats;
};

type Edit =
  | { type: "equal"; left: number; right: number }
  | { type: "delete"; left: number; right?: undefined }
  | { type: "insert"; right: number; left?: undefined };

function splitLines(text: unknown): string[] {
  const source = String(text ?? "");
  if (!source) return [];
  const lines = source.split("\n");
  if (source.endsWith("\n")) lines.pop();
  return lines;
}

function normalizeLine(line: string, { ignoreWhitespace = false }: DiffOptions = {}): string {
  return ignoreWhitespace ? line.replace(/\s+/g, " ").trim() : line;
}

/** Myers O(ND) line diff. Returns rows for a side-by-side view. */
export function diffLines(leftText: unknown, rightText: unknown, options: DiffOptions = {}): DiffResult {
  const leftRaw = String(leftText ?? "");
  const rightRaw = String(rightText ?? "");
  if (leftRaw.length > maxDiffInput || rightRaw.length > maxDiffInput) {
    return { ok: false as const, error: "input-too-large", rows: [], stats: emptyStats() };
  }

  const left = splitLines(leftRaw);
  const right = splitLines(rightRaw);
  if (left.length > maxDiffLines || right.length > maxDiffLines) {
    return { ok: false as const, error: "too-many-lines", rows: [], stats: emptyStats() };
  }

  const leftKeys = left.map((line) => normalizeLine(line, options));
  const rightKeys = right.map((line) => normalizeLine(line, options));
  const edits = myers(leftKeys, rightKeys);
  if (!edits) {
    return { ok: false as const, error: "too-complex", rows: [], stats: emptyStats() };
  }

  const rows: DiffRow[] = [];
  let leftLine = 1;
  let rightLine = 1;
  let equal = 0;
  let removed = 0;
  let added = 0;

  for (const edit of edits) {
    if (edit.type === "equal") {
      rows.push({
        type: "equal",
        leftLine: leftLine++,
        rightLine: rightLine++,
        leftText: left[edit.left] ?? "",
        rightText: right[edit.right] ?? "",
      });
      equal += 1;
      continue;
    }
    if (edit.type === "delete") {
      rows.push({
        type: "delete",
        leftLine: leftLine++,
        rightLine: null,
        leftText: left[edit.left] ?? "",
        rightText: "",
      });
      removed += 1;
      continue;
    }
    rows.push({
      type: "insert",
      leftLine: null,
      rightLine: rightLine++,
      leftText: "",
      rightText: right[edit.right] ?? "",
    });
    added += 1;
  }

  return {
    ok: true as const,
    error: null,
    rows,
    stats: { equal, removed, added, leftLines: left.length, rightLines: right.length },
  };
}

function emptyStats(): DiffStats {
  return { equal: 0, removed: 0, added: 0, leftLines: 0, rightLines: 0 };
}

/**
 * Myers O(ND) with compact per-depth frontiers (length 2d+1) instead of full
 * v.slice() copies of size O(N+M) every step.
 */
function myers(a: string[], b: string[]): Edit[] | null {
  const n = a.length;
  const m = b.length;
  if (n === 0 && m === 0) return [];
  const max = n + m;
  const maxD = Math.min(max, maxEditDistance);
  const offset = max;
  const v = new Int32Array(2 * max + 1);
  // Sentinel used on the first iteration (d = 0, k = 0 reads v[1]).
  v[offset + 1] = 0;
  const trace: Int32Array[] = [];

  for (let d = 0; d <= maxD; d += 1) {
    const snapshot = new Int32Array(2 * d + 1);
    for (let k = -d; k <= d; k += 1) {
      snapshot[k + d] = v[k + offset]!;
    }
    trace.push(snapshot);

    for (let k = -d; k <= d; k += 2) {
      let x: number;
      if (k === -d || (k !== d && v[k - 1 + offset]! < v[k + 1 + offset]!)) {
        x = v[k + 1 + offset]!;
      } else {
        x = v[k - 1 + offset]! + 1;
      }
      let y = x - k;
      while (x < n && y < m && a[x] === b[y]) {
        x += 1;
        y += 1;
      }
      v[k + offset] = x;
      if (x >= n && y >= m) return backtrack(trace, a, b);
    }
  }
  return null;
}

function backtrack(trace: Int32Array[], a: string[], b: string[]): Edit[] {
  const edits: Edit[] = [];
  let x = a.length;
  let y = b.length;

  for (let d = trace.length - 1; d >= 0; d -= 1) {
    // Compact frontiers omit the d=0 sentinel at k=1; remaining work is equals only.
    if (d === 0) {
      while (x > 0 && y > 0) {
        edits.push({ type: "equal", left: x - 1, right: y - 1 });
        x -= 1;
        y -= 1;
      }
      break;
    }

    const frontier = trace[d]!;
    const k = x - y;
    let prevK: number;
    if (k === -d || (k !== d && frontier[k - 1 + d]! < frontier[k + 1 + d]!)) {
      prevK = k + 1;
    } else {
      prevK = k - 1;
    }
    const prevX = frontier[prevK + d]!;
    const prevY = prevX - prevK;

    while (x > prevX && y > prevY) {
      edits.push({ type: "equal", left: x - 1, right: y - 1 });
      x -= 1;
      y -= 1;
    }

    if (x === prevX) {
      edits.push({ type: "insert", right: y - 1 });
      y -= 1;
    } else {
      edits.push({ type: "delete", left: x - 1 });
      x -= 1;
    }
  }

  edits.reverse();
  return edits;
}
