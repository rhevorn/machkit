import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";

const toolsDirectory = fileURLToPath(new URL("../tools/", import.meta.url));

function toolDirectories(): string[] {
  return readdirSync(toolsDirectory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("_"))
    .map((entry) => entry.name)
    .sort();
}

/**
 * Approximate the previous TypeScript-AST check without the TS 7 compiler API:
 * flag `<Button>` / `<button>` that lack aria-label / aria-labelledby and have no
 * text or JSX expression children (expressions count as accessible content).
 */
function iconOnlyButtonsWithoutAccessibleName(sourceText: string): number[] {
  const lines: number[] = [];
  const pattern = /<(Button|button)(\s[^>]*?)?(\/>|>)/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(sourceText)) !== null) {
    const attrs = match[2] ?? "";
    const selfClosing = match[3] === "/>";
    if (/\baria-label\s*=/.test(attrs) || /\baria-labelledby\s*=/.test(attrs)) continue;

    let hasAccessibleContent = false;
    if (!selfClosing) {
      const start = match.index + match[0].length;
      const closeMatch = sourceText.slice(start).match(/<\/(Button|button)>/);
      if (closeMatch && closeMatch.index !== undefined) {
        const inner = sourceText.slice(start, start + closeMatch.index);
        // Plain text, or any JSX expression (same rule as the old AST walker).
        if (/\{[^}]+\}/.test(inner) || /[^\s<{]/.test(inner.replace(/<[^>]+>/g, ""))) {
          hasAccessibleContent = true;
        }
      }
    }
    if (hasAccessibleContent) continue;

    const line = sourceText.slice(0, match.index).split("\n").length;
    lines.push(line);
  }
  return lines;
}

test("every embedded tool follows the repository page contract", () => {
  const issues: string[] = [];
  for (const toolID of toolDirectories()) {
    const directory = `${toolsDirectory}/${toolID}`;
    for (const requiredFile of ["index.html", "main.tsx", "messages.ts"]) {
      try {
        readFileSync(`${directory}/${requiredFile}`);
      } catch {
        issues.push(`${toolID}: missing ${requiredFile}`);
      }
    }

    try {
      const main = readFileSync(`${directory}/main.tsx`, "utf8");
      if (!main.includes("mountTool(")) issues.push(`${toolID}: main.tsx must use mountTool`);
      if (!main.includes("<ToolPage")) issues.push(`${toolID}: main.tsx must use ToolPage`);
    } catch {
      // The missing-file issue above is more actionable.
    }
  }
  assert.deepEqual(issues, []);
});

test("icon-only embedded-tool buttons have an accessible name", () => {
  const issues: string[] = [];
  for (const toolID of toolDirectories()) {
    const path = `${toolsDirectory}/${toolID}/main.tsx`;
    const sourceText = readFileSync(path, "utf8");
    for (const line of iconOnlyButtonsWithoutAccessibleName(sourceText)) {
      issues.push(`${toolID}/main.tsx:${line}`);
    }
  }

  assert.deepEqual(issues, [], `Add aria-label to icon-only buttons:\n${issues.join("\n")}`);
});
