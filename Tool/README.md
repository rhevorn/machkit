# MachKit H5 Tools

This project contains web-based tools embedded in MachKit with `WKWebView`. Native
Swift tools remain in `App/Sources`; only tools that benefit from web UI belong
here.

## Development

Run the local development server before opening a web tool from a Debug build:

```bash
npm run dev
```

Debug builds load tools from `http://127.0.0.1:4174` and update through Vite HMR
without rebuilding MachKit. If the server is not running, MachKit automatically falls
back to the bundled tool. Release builds always use bundled resources.

The development server runs at `http://127.0.0.1:4174`. The root page is a simple
index of every H5 tool under `tools/` (folders starting with `_` are skipped).

In the browser (not inside MachKit), each tool page shows a floating **Dev** bar for
locale and theme. Drag the `Dev` handle to move it, or press **Hide** to collapse it
into a small chip (click the chip to restore). You can also set them in the URL or
console:

```text
http://127.0.0.1:4174/tools/string-generator/?locale=zh-Hans&appearance=dark
```

```js
machkit.applyPreferences({ locale: "zh-Hans", appearance: "dark" })
```

Browser choices are remembered in `localStorage` and synced into the URL.

## Add a tool

1. Run `npm run new -- <tool-id>` (for example,
   `npm run new -- json-formatter`).
2. Keep one `index.html` entry per tool. Vite discovers these directories
   automatically; directories beginning with `_` are templates and are skipped.
3. Add the tool to `DeveloperToolRegistry` in
   `App/Sources/WebView/DeveloperTools.swift` with
   `.bundledWeb(entryFile: "WebTools/tools/<tool-id>/index.html")`, pick a
   `WebToolWidthClass` (`.compact` / `.regular` / `.wide`), and grant only the
   native capabilities the tool needs (`clipboard`, `hosts`, or `storage`).
   Each width class sets both default and minimum width/height; pages that
   enable adaptive height can still grow up to a screen cap.
4. Run `npm run build:app` to build all H5 tools into the app's
   `Resources/WebTools` directory. This directory is generated and ignored by
   Git. Xcode runs the same build automatically before compiling app resources.

Run `npm install` once after cloning the repository so Xcode can use the local,
locked frontend dependencies without downloading packages during every build.

## Shared UI

All tools use the shared component layer in `src/ui`. It follows the shadcn/ui
model: component source stays in this repository, Radix Primitives provide
accessible interaction behavior, Tailwind CSS provides layout and visual
states, and `class-variance-authority` defines reusable component variants.

- Import components from `@/ui/index.js`.
- Reuse `ToolPage`, `ToolContent`, `Section`, `Field`, `Input`, `Textarea`,
  `CheckboxField`, `Button`, `SelectControl`, `SegmentedControl`, `ValueField`,
  and `InlineMessage` before adding new UI.
- Keep MachKit theme tokens and light/dark colors in `src/ui/ui.css`.
- Use Phosphor icons so native and web tools keep one icon language.
- Add tool-specific CSS only for a layout or visualization that cannot be
  expressed cleanly with the shared components and Tailwind utilities.

The generated `_template` already imports this UI layer, so a new tool starts
with the MachKit shell and theme rather than a blank page.

Tool titles belong to the native compact macOS title bar. Do not repeat a title
or subtitle inside an H5 page. Put optional explanations behind the `info`
popover on `ToolPage`, and let the primary tool content start immediately.

## Runtime rules

- Use relative asset paths. The Vite base path is `./` because tools load from
  local files rather than an HTTP server.
- Shared macOS-like colors, controls, and dark mode behavior live in `src/ui`.
- `src/runtime/machkit.js` is the single boundary for optional native messages.
  Native calls use the versioned request/reply bridge and time out rather than
  leaving a tool pending forever. A method only works when its capability is
  explicitly granted in `DeveloperToolRegistry`.
- Mount tools with `mountTool()` so root validation and the shared error boundary
  are applied consistently.
- Keep each tool's translations in its own `messages.js`; use
  `catalogIssues()` in tests to keep locale keys complete.
- Move CPU-heavy transformations to a module worker and cap input or result size
  before adding a tool that accepts arbitrary text.
- Do not load remote scripts or place secrets in a web tool.
