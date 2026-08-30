import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Connect, Plugin } from "vite";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import type { FeaturePage, SiteLocale } from "./src/seo-pages.js";

const root = path.dirname(fileURLToPath(import.meta.url));

type SSRRenderer = {
  findFeaturePage(pathname: string): { page: FeaturePage; locale: SiteLocale } | null;
  renderFeatureDocument(options: {
    page: FeaturePage;
    locale: SiteLocale;
    stylesheetHref?: string;
    scriptHref?: string;
  }): string;
  renderHome(options: { locale: string; assetBase: string }): string;
};

function replaceFallback(html: string, markup: string): string {
  const pattern = /<main class="seo-fallback">[\s\S]*?<\/main>/;
  if (!pattern.test(html)) throw new Error("Unable to find the homepage SEO fallback.");
  return html.replace(pattern, markup);
}

function staticSiteDevPlugin(): Plugin {
  return {
    name: "machkit-static-pages",
    configureServer(server) {
      server.middlewares.use(async (request: Connect.IncomingMessage, response, next) => {
        const pathname = new URL(request.url || "/", "http://localhost").pathname;
        const renderer = await server.ssrLoadModule("/src/entry-server.tsx") as SSRRenderer;
        const homeLocale = pathname === "/" ? "en" : pathname === "/zh-CN/" ? "zh-CN" : null;
        if (homeLocale) {
          try {
            const sourceFile = path.join(root, homeLocale === "en" ? "index.html" : "zh-CN/index.html");
            const source = await fs.readFile(sourceFile, "utf8");
            const transformed = await server.transformIndexHtml(pathname, source);
            response.statusCode = 200;
            response.setHeader("Content-Type", "text/html; charset=utf-8");
            response.end(replaceFallback(
              transformed,
              renderer.renderHome({ locale: homeLocale, assetBase: homeLocale === "en" ? "." : ".." }),
            ));
          } catch (error) {
            next(error as Error);
          }
          return;
        }

        const match = renderer.findFeaturePage(pathname);
        if (!match) return next();
        response.statusCode = 200;
        response.setHeader("Content-Type", "text/html; charset=utf-8");
        response.end(renderer.renderFeatureDocument({
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
    modulePreload: { polyfill: false },
    outDir: "dist/client",
    rollupOptions: {
      input: {
        main: path.resolve(root, "index.html"),
        chinese: path.resolve(root, "zh-CN/index.html"),
        staticPage: path.resolve(root, "src/static-page.ts"),
      },
    },
  },
  server: {
    host: "0.0.0.0",
    allowedHosts: ["terminal.local"],
  },
  plugins: [staticSiteDevPlugin(), react()],
});
