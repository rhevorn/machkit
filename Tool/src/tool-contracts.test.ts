import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";
import ts from "typescript";

const toolsDirectory = fileURLToPath(new URL("../tools/", import.meta.url));

function toolDirectories(): string[] {
  return readdirSync(toolsDirectory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("_"))
    .map((entry) => entry.name)
    .sort();
}

function hasAttribute(node: ts.JsxOpeningLikeElement, name: string): boolean {
  return node.attributes.properties.some(
    (attribute) => ts.isJsxAttribute(attribute) && attribute.name.getText() === name,
  );
}

function containsAccessibleText(children: ts.NodeArray<ts.JsxChild>): boolean {
  return children.some((child) => {
    if (ts.isJsxText(child)) return Boolean(child.text.trim());
    if (ts.isJsxExpression(child)) return child.expression !== undefined;
    if (ts.isJsxElement(child)) return containsAccessibleText(child.children);
    return false;
  });
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
    const source = ts.createSourceFile(path, sourceText, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);

    const visit = (node: ts.Node) => {
      if (ts.isJsxElement(node)) {
        const opening = node.openingElement;
        const tagName = opening.tagName.getText();
        if (
          (tagName === "Button" || tagName === "button")
          && !hasAttribute(opening, "aria-label")
          && !hasAttribute(opening, "aria-labelledby")
          && !containsAccessibleText(node.children)
        ) {
          const position = source.getLineAndCharacterOfPosition(opening.getStart(source));
          issues.push(`${toolID}/main.tsx:${position.line + 1}`);
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }

  assert.deepEqual(issues, [], `Add aria-label to icon-only buttons:\n${issues.join("\n")}`);
});
