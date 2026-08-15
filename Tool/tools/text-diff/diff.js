export const maxDiffInput = 400_000;
export const maxDiffLines = 8_000;

function splitLines(text) {
  const source = String(text ?? "");
  if (!source) return [];
  const lines = source.split("\n");
  if (source.endsWith("\n")) lines.pop();
  return lines;
}

function normalizeLine(line, { ignoreWhitespace = false } = {}) {
  return ignoreWhitespace ? line.replace(/\s+/g, " ").trim() : line;
}

/** Myers O(ND) line diff. Returns rows for a side-by-side view. */
export function diffLines(leftText, rightText, options = {}) {
  const leftRaw = String(leftText ?? "");
  const rightRaw = String(rightText ?? "");
  if (leftRaw.length > maxDiffInput || rightRaw.length > maxDiffInput) {
    return { ok: false, error: "input-too-large", rows: [], stats: emptyStats() };
  }

  const left = splitLines(leftRaw);
  const right = splitLines(rightRaw);
  if (left.length > maxDiffLines || right.length > maxDiffLines) {
    return { ok: false, error: "too-many-lines", rows: [], stats: emptyStats() };
  }

  const leftKeys = left.map((line) => normalizeLine(line, options));
  const rightKeys = right.map((line) => normalizeLine(line, options));
  const edits = myers(leftKeys, rightKeys);
  const rows = [];
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
        leftText: left[edit.left],
        rightText: right[edit.right],
      });
      equal += 1;
      continue;
    }
    if (edit.type === "delete") {
      rows.push({
        type: "delete",
        leftLine: leftLine++,
        rightLine: null,
        leftText: left[edit.left],
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
      rightText: right[edit.right],
    });
    added += 1;
  }

  return {
    ok: true,
    error: null,
    rows,
    stats: { equal, removed, added, leftLines: left.length, rightLines: right.length },
  };
}

function emptyStats() {
  return { equal: 0, removed: 0, added: 0, leftLines: 0, rightLines: 0 };
}

function myers(a, b) {
  const n = a.length;
  const m = b.length;
  if (n === 0 && m === 0) return [];
  const max = n + m;
  const offset = max;
  const v = new Array(2 * max + 1).fill(0);
  const trace = [];

  for (let d = 0; d <= max; d += 1) {
    const snapshot = v.slice();
    trace.push(snapshot);
    for (let k = -d; k <= d; k += 2) {
      let x;
      if (k === -d || (k !== d && v[k - 1 + offset] < v[k + 1 + offset])) {
        x = v[k + 1 + offset];
      } else {
        x = v[k - 1 + offset] + 1;
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
  return backtrack(trace, a, b);
}

function backtrack(trace, a, b) {
  const edits = [];
  let x = a.length;
  let y = b.length;

  for (let d = trace.length - 1; d >= 0; d -= 1) {
    const v = trace[d];
    const offset = v.length >> 1;
    const k = x - y;
    let prevK;
    if (k === -d || (k !== d && v[k - 1 + offset] < v[k + 1 + offset])) {
      prevK = k + 1;
    } else {
      prevK = k - 1;
    }
    const prevX = v[prevK + offset];
    const prevY = prevX - prevK;

    while (x > prevX && y > prevY) {
      edits.push({ type: "equal", left: x - 1, right: y - 1 });
      x -= 1;
      y -= 1;
    }

    if (d === 0) break;

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
