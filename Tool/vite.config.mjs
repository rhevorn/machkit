import { existsSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const projectRoot = fileURLToPath(new URL(".", import.meta.url));

function discoverToolPages() {
  const toolsRoot = resolve(projectRoot, "tools");
  const inputs = { index: resolve(projectRoot, "index.html") };

  if (!existsSync(toolsRoot)) return inputs;

  for (const entry of readdirSync(toolsRoot, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith("_")) continue;
    const page = resolve(toolsRoot, entry.name, "index.html");
    if (existsSync(page)) inputs[`tools/${entry.name}`] = page;
  }

  return inputs;
}

export default defineConfig({
  base: "./",
  plugins: [react()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
    rollupOptions: {
      input: discoverToolPages(),
    },
  },
  server: {
    host: "127.0.0.1",
    port: 4174,
  },
});
