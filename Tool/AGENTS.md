# MachKit H5 Tool Development Rules

This file applies to everything under `Tool/`. MachKit H5 tools run inside a
native macOS `WKWebView`; they must feel like one product with the SwiftUI shell,
not like unrelated web pages.

## Priorities

When requirements conflict, use this order:

1. Preserve correctness, user data, native capability boundaries, and accessibility.
2. Preserve the requested layout and behavior unless the task explicitly changes them.
3. Keep all tools visually consistent with MachKit and with each other.
4. Prefer shared components and semantic tokens over tool-specific styling.
5. Keep the bundled web payload and runtime work proportional to the tool.

## Architecture

- Use React, Vite, and Tailwind CSS as configured in this project.
- Mount every tool with `mountTool()`.
- Use `ToolPage` and `ToolContent` for the common page shell and content geometry.
- Keep one `index.html` entry per tool under `tools/<tool-id>/`.
- Keep pure transformation logic separate from React, normally in a sibling module
  such as `json.js`, and test it with Node's test runner.
- Use `@/runtime/machkit.js` as the only boundary for native operations.
- Use relative asset paths. Bundled tools are loaded from local files with Vite
  `base: "./"`.

## Component Library

The repository-owned shadcn/ui component layer in `src/ui` is the standard for
all user-facing H5 controls. Radix Primitives provide accessible behavior,
Tailwind CSS provides styling, and CVA defines shared variants.

- Import shared controls from `@/ui/index.js`.
- Reuse `ToolPage`, `ToolContent`, `Section`, `Field`, `Input`, `Textarea`,
  `CheckboxField`, `Button`, `SelectControl`, `SegmentedControl`, `ValueField`,
  `InlineMessage`, and the other shared exports before adding a component.
- Use standard DOM/shadcn props such as `onClick`, `disabled`, `aria-invalid`,
  and the component's documented Radix state props.
- Use Phosphor icons. Do not introduce a second general icon library.
- CodeMirror, canvas, charts, image editors, and other specialized workspaces may
  use purpose-built libraries when the shared layer has no equivalent. Their
  surrounding controls must still use the shared shadcn/ui layer.
- Do not create a local imitation of a shared control with raw `<button>`,
  `<input>`, or a large Tailwind class string.
- Semantic HTML used only for structure (`main`, `section`, `header`, `div`,
  `code`, `pre`) does not need a component wrapper.
- Do not add HeroUI, MUI, Ant Design, Chakra, Mantine, or another competing
  general-purpose component library.

### Legacy components

Some existing tools still contain ad-hoc raw controls or tool-specific component
styles. Treat those implementations as legacy:

- Do not add new ad-hoc control styles when a shared component exists.
- Do not perform an unrelated repository-wide migration while fixing one tool.
- When a task explicitly migrates a tool, migrate all visible controls in that
  tool so the page does not mix two button, field, card, or feedback systems.
- Move reusable variants and theme adaptations into `src/ui`, not into a tool
  folder.

### Imports and bundle size

- Import components through `@/ui/index.js`; avoid deep imports from individual
  UI files outside `src/ui`.
- Use `components.json` and the shadcn workflow when a missing primitive should
  be added. Adapt generated code to the repository's tokens, naming, and
  Phosphor icon language before use.
- Keep one source file per shared component and export it from `src/ui/index.js`.
- Before adding a dependency, confirm that the shared layer, Radix, the platform,
  or an existing dependency cannot already handle the requirement.
- Commit `package.json` and `package-lock.json` together.

## Themes

MachKit has exactly two resolved visual themes: light and dark.

- `appearance="system"` is a preference mode, not a third theme. It must resolve
  to the same light or dark tokens according to the operating system.
- The native shell and browser development dock set `data-appearance`. Do not add
  an independent per-tool theme state.
- `src/ui/ui.css` is the single source of truth for MachKit tokens, shadcn CSS
  variables, and light/dark mappings.
- Shared components must consume semantic roles such as background, surface,
  field, border, secondary text, accent, danger, and focus. Do not fork the
  palette for an individual tool.
- Use system UI fonts and the shared monospace stack.
- Use semantic color variables. Hard-coded colors are allowed only for data
  visualization or protocol-specific syntax, and must have an intentional dark
  theme value.

### Visual consistency

- Use a clean native surface for the page background. Do not add gradients,
  tinted canvases, glass effects, decorative blobs, or patterned backgrounds
  unless the product requirement explicitly calls for them.
- Do not add large shadows to ordinary panels. Use borders and subtle shared
  elevation tokens; dark mode generally uses borders instead of shadows.
- Controls, panels, popovers, and result cards must use the shared radius,
  border, focus, and spacing tokens.
- Do not globally restyle shared shadcn components from inside one tool. Shared
  design decisions go into `src/ui`; tool CSS is for unique layout and
  specialized visualization only.
- A page should have at most one visually primary action in a toolbar. Secondary
  transformations use secondary/outline emphasis; copy, clear, and help actions
  use ghost or icon-only emphasis.
- Disabled, hover, pressed, focus-visible, pending, invalid, success, and danger
  states must remain distinguishable in both themes.

## Layout and content

- Tool titles live in the native compact title bar. Do not repeat a large title
  or marketing subtitle inside the H5 page.
- Start with the task controls and working content. Put optional explanation in a
  shared `ToolInfoButton`/Popover opened from an accessible info button.
- Preserve the existing tool layout unless the user explicitly asks to change it.
  A visual refresh is not authorization to rearrange controls or workflows.
- Keep desktop tool density compact and macOS-like. Avoid mobile-sized controls,
  oversized cards, excessive rounding, and large empty decorative spacing.
- Use responsive rules for the actual minimum window size. Essential actions must
  remain available at narrow widths; labels may collapse before icons disappear.
- Long localized text, paths, JSON, URLs, and error messages must wrap or truncate
  deliberately without expanding the window unexpectedly.
- Results that appear conditionally must not cause avoidable layout jumps.

## Accessibility and interaction

- Every icon-only action needs an `aria-label` and a useful tooltip or popover when
  its meaning is not universal.
- Associate labels and descriptions with fields through the shared Field/Label
  components and Radix accessibility APIs.
- Preserve keyboard navigation, focus-visible rings, Escape behavior, and logical
  tab order.
- Never rely on color alone for validation or status. Use `InlineMessage`, text,
  and an icon/indicator as appropriate.
- Use `machkit.copy()` for copy actions so native acknowledgement and shared copy
  feedback continue to work.
- Do not read the clipboard on an incidental render. Read only on tool open when
  the behavior is expected, or after an explicit user action.
- Do not disable the browser context menu unless the native interaction design
  explicitly requires it.

## Localization

- Put all user-facing strings in the tool's `messages.js`.
- Do not hard-code fallback English in JSX when a message key can be provided.
- Keep every supported locale structurally complete and non-empty.
- Preserve punctuation and interpolation semantics across locales.
- Test at least one compact Latin locale and Simplified Chinese. For layout-sensitive
  changes, also inspect a locale likely to produce longer labels.

## Native bridge and security

- A tool may call only capabilities granted in `DeveloperToolRegistry`.
- Request the smallest native capability set needed by the tool.
- Do not call WebKit message handlers directly; go through `machkit` APIs so
  requests remain versioned, acknowledged, and time-bounded.
- Do not load remote scripts, fonts, trackers, or executable content.
- Do not place secrets, tokens, or privileged file paths in a web bundle.
- Treat pasted or opened content as untrusted. Escape output and avoid injecting
  user content with `dangerouslySetInnerHTML`.
- Enforce input, output, batch, and file-size caps before allocating large buffers.

## Performance

- Keep typing responsive. Debounce non-trivial analysis and cancel or ignore stale
  results.
- Move CPU-heavy parsing, formatting, encoding, diffing, and image work to a module
  worker when it can block the main thread.
- Avoid re-parsing the same large input during render.
- Revoke object URLs and terminate workers during cleanup.
- Prefer tree-shaken imports and selective component styles.

## Adding a tool

1. Run `npm run new -- <kebab-case-tool-id>`.
2. Implement the pure logic and tests before or alongside the UI.
3. Add localized messages for every supported locale.
4. Register the tool in `DeveloperToolRegistry` with the appropriate width class
   and minimum native capabilities.
5. Add or update catalog metadata and ordering only when required.
6. Use the shared shadcn/ui controls and MachKit theme from the first version.
7. Run the verification checklist below.

Do not manually edit generated `Resources/WebTools` output. `npm run build:app`
regenerates it when app integration needs to be tested.

## Verification

Before handing off a tool change:

1. Run `npm test` from `Tool/`.
2. Run `npm run build` from `Tool/`.
3. Run `git diff --check`.
4. Inspect the tool in light and dark appearances.
5. Inspect the minimum/narrow window and a normal desktop window.
6. Exercise a real successful workflow, not only the empty state.
7. Inspect disabled, focus, invalid/error, success, loading, and conditional-result
   states affected by the change.
8. Check keyboard navigation and icon-only accessible names.
9. Confirm unrelated tools did not change because of shared CSS or theme edits.

For visual changes, screenshots must be taken from the running implementation;
do not judge the result only from CSS or JSX. Browser-only screenshots include a
development dock that is not present in the embedded MachKit view.

## Definition of done

A tool change is done only when:

- behavior and layout match the request;
- visible controls use the designated component system consistently;
- both resolved themes align with MachKit;
- localization and accessibility are complete;
- heavy work and large inputs are bounded;
- tests and the production build pass; and
- the actual rendered result has been inspected in representative states.
