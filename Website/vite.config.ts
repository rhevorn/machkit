import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Connect, Plugin } from "vite";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { renderFeatureDocument } from "./scripts/site-renderer.js";
import { findFeaturePage } from "./src/seo-pages.js";

const root = path.dirname(fileURLToPath(import.meta.url));

function featurePageDevPlugin(): Plugin {
  return {
    name: "machkit-feature-pages",
    configureServer(server) {
      server.middlewares.use((request: Connect.IncomingMessage, response, next) => {
        const pathname = new URL(request.url || "/", "http://localhost").pathname;
        const match = findFeaturePage(pathname);
        if (!match) return next();
        response.statusCode = 200;
        response.setHeader("Content-Type", "text/html; charset=utf-8");
        response.end(renderFeatureDocument({
          ...match,
          stylesheetHref: "/src/styles.css",
          scriptHref: "/src/static-page.ts",
        }));
      });
    },
  };
}

export default defineConfig({
  base: "/",
  build: {
    target: "safari17",
    manifest: true,
    outDir: "dist/client",
    rollupOptions: {
      input: {
        main: path.resolve(root, "index.html"),
        chinese: path.resolve(root, "zh-CN/index.html"),
        staticPage: path.resolve(root, "src/static-page.ts"),
      },
    },
  },
  optimizeDeps: {
    include: ["react", "react-dom/client"],
  },
  server: {
    host: "0.0.0.0",
    allowedHosts: ["terminal.local"],
    warmup: {
      clientFiles: ["./src/main.tsx"],
    },
  },
  plugins: [featurePageDevPlugin(), react()],
});
