# Sift H5 Tools

This project contains web-based tools embedded in Sift with `WKWebView`. Native
Swift tools remain in `App/Sources`; only tools that benefit from web UI belong
here.

## Development

```bash
npm install
npm run dev
```

The development server runs at `http://127.0.0.1:4174`.

## Add a tool

1. Run `npm run new -- <tool-id>` (for example,
   `npm run new -- json-formatter`).
2. Keep one `index.html` entry per tool. Vite discovers these directories
   automatically; directories beginning with `_` are templates and are skipped.
3. Add the tool to `DeveloperToolRegistry` in
   `App/Sources/DeveloperTools.swift` with
   `.bundledWeb(entryFile: "WebTools/tools/<tool-id>/index.html")`.
4. Run `npm run build:app` to build all H5 tools into the app's
   `Resources/WebTools` directory. This directory is generated and ignored by
   Git. Xcode runs the same build automatically before compiling app resources.

Run `npm install` once after cloning the repository so Xcode can use the local,
locked frontend dependencies without downloading packages during every build.

## Runtime rules

- Use relative asset paths. The Vite base path is `./` because tools load from
  local files rather than an HTTP server.
- Shared macOS-like colors and dark mode behavior live in `src/styles.css`.
- `src/runtime/sift.js` is the single boundary for optional native messages.
  A message only works after its handler has been explicitly added to the native
  `WKWebView` configuration.
- Do not load remote scripts or place secrets in a web tool.
