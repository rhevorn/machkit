import { cpSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = fileURLToPath(new URL("..", import.meta.url));
const toolID = process.argv[2]?.trim();

if (!toolID || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(toolID)) {
  console.error("Usage: npm run new -- <kebab-case-tool-id>");
  process.exit(1);
}

const template = resolve(projectRoot, "tools/_template");
const destination = resolve(projectRoot, `tools/${toolID}`);

if (existsSync(destination)) {
  console.error(`Tool already exists: ${toolID}`);
  process.exit(1);
}

cpSync(template, destination, { recursive: true });

const title = toolID
  .split("-")
  .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
  .join(" ");
const indexPath = resolve(destination, "index.html");
const mainPath = resolve(destination, "main.tsx");

writeFileSync(indexPath, readFileSync(indexPath, "utf8").replace("MachKit Tool", title));
writeFileSync(
  mainPath,
  readFileSync(mainPath, "utf8").replace(
    "Replace this template with the tool UI.",
    `${title} is ready for implementation.`,
  ),
);

console.log(`Created tools/${toolID}`);
