export const maxTextInput = 500_000;
export const maxLines = 50_000;

export const textActions = Object.freeze([
  "trim",
  "dedupe",
  "dedupeIgnoreCase",
  "sortAsc",
  "sortDesc",
  "reverse",
  "lower",
  "upper",
  "title",
  "removeBlank",
  "collapseSpace",
  "lineNumbers",
  "shuffle",
]);

/** @type {ReadonlyArray<{ id: string, actions: ReadonlyArray<string> }>} */
export const textActionGroups = Object.freeze([
  { id: "whitespace", actions: Object.freeze(["trim", "removeBlank", "collapseSpace"]) },
  { id: "lines", actions: Object.freeze(["dedupe", "dedupeIgnoreCase", "lineNumbers"]) },
  { id: "order", actions: Object.freeze(["sortAsc", "sortDesc", "reverse", "shuffle"]) },
  { id: "case", actions: Object.freeze(["lower", "upper", "title"]) },
]);

function splitLines(text) {
  return String(text ?? "").replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
}

function joinLines(lines) {
  return lines.join("\n");
}

export function textStats(input) {
  const text = String(input ?? "");
  const lines = splitLines(text);
  const nonEmpty = lines.filter((line) => line.trim().length > 0);
  return {
    chars: text.length,
    lines: lines.length,
    nonEmpty: nonEmpty.length,
    words: text.trim() ? text.trim().split(/\s+/).length : 0,
  };
}

export function transformText(input, action) {
  const text = String(input ?? "");
  if (text.length > maxTextInput) return { ok: false, error: "too-large", text: null, stats: null };
  const lines = splitLines(text);
  if (lines.length > maxLines) return { ok: false, error: "too-many-lines", text: null, stats: null };

  let next = lines;
  switch (action) {
    case "trim":
      next = lines.map((line) => line.trimEnd());
      while (next.length && next[0].trim() === "") next.shift();
      while (next.length && next[next.length - 1].trim() === "") next.pop();
      break;
    case "dedupe": {
      const seen = new Set();
      next = lines.filter((line) => {
        if (seen.has(line)) return false;
        seen.add(line);
        return true;
      });
      break;
    }
    case "dedupeIgnoreCase": {
      const seen = new Set();
      next = lines.filter((line) => {
        const key = line.toLowerCase();
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
      break;
    }
    case "sortAsc":
      next = [...lines].sort((a, b) => a.localeCompare(b));
      break;
    case "sortDesc":
      next = [...lines].sort((a, b) => b.localeCompare(a));
      break;
    case "reverse":
      next = [...lines].reverse();
      break;
    case "lower":
      next = lines.map((line) => line.toLowerCase());
      break;
    case "upper":
      next = lines.map((line) => line.toUpperCase());
      break;
    case "title":
      next = lines.map((line) =>
        line.replace(/\w\S*/g, (word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()),
      );
      break;
    case "removeBlank":
      next = lines.filter((line) => line.trim().length > 0);
      break;
    case "collapseSpace":
      next = lines.map((line) => line.replace(/[ \t]+/g, " ").trim());
      break;
    case "lineNumbers":
      next = lines.map((line, index) => `${String(index + 1).padStart(String(lines.length).length, " ")}  ${line}`);
      break;
    case "shuffle": {
      next = [...lines];
      for (let i = next.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        [next[i], next[j]] = [next[j], next[i]];
      }
      break;
    }
    default:
      return { ok: false, error: "unknown-action", text: null, stats: null };
  }

  const output = joinLines(next);
  return { ok: true, error: null, text: output, stats: textStats(output) };
}
