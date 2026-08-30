# MachKit H5 UI Migration Plan

## Status

Design system: **complete for current tools**.

| Layer | State |
| --- | --- |
| Brand + token contract | Landed in `src/ui/ui.css` |
| Shared primitives | Control heights, tones, focus, and disabled opacity wired |
| Product patterns | `ToolToolbar`, `ActionGroup`, `ExampleChips`, `PropertyList`/`PropertyRow`, `StatusStrip`, `ResultPanel`, `ToolSidebar`, `SidebarNavItem`, `ValueUnitField`, `EditorPane`, `SplitWorkspace`, `RadioDot`, `Slider` |
| Page templates | Reference layouts in place; further micro-polish is product taste, not migration debt |
| Per-tool migration | All registered tools consume shared patterns |

**Approved leftovers (not debt):**

- CodeMirror hosts / JSON surfaces may keep `machkit-panel` on the editor root for CSS hooks.
- `<input type="color">` for Color Lab.
- QR preview `bg-white` for scannable contrast.
- Curl options dialog shell may keep `machkit-panel` + popover elevation.

## Objective

Make every embedded H5 tool feel like **one premium MachKit product**: calm,
precise, compact, and native to macOS — without changing tool behavior,
capability boundaries, or inventing a second visual language per page.

Unify four layers in order:

1. Foundation tokens in `src/ui/ui.css` (the brand contract).
2. Repository-owned shadcn/ui primitives in `src/ui`.
3. Reusable MachKit product patterns (toolbar, sidebar rail, property list, …).
4. Tool pages, migrated in small template-based waves.

This is a **consistency migration onto the decided system**, not a redesign of
every workflow and not a hunt for another component library.

## Non-goals

- Do not add HeroUI, Mantine, or another general-purpose component library.
- Do not change parsing, conversion, scanning, networking, clipboard, or native
  bridge behavior while migrating UI.
- Do not reorganize a tool's workflow unless the chosen template requires a
  layout change that preserves the same task, or a separate product request
  asks for it.
- Do not change tool identifiers, registry capabilities, localization coverage,
  or persistent keys as part of visual cleanup.
- Window `widthClass` **may** change when a tool adopts a standard template
  (for example compact for form/rail tools). Record the change in the native
  registry in the same commit as the layout migration.
- Do not edit `Tool/dist/` or `Resources/WebTools/` manually.
- Do not perform one repository-wide JSX rewrite in a single change.
- Do not restore removed tools (`text-lab`, `data-format`, `xml-plist`, …)
  from older drafts of this plan.

## Design system (source of truth)

Everything below is approved. Migration work **implements** it; it does not
re-litigate palette, density, or component ownership mid-wave.

### Stack

- Controls: repository-owned shadcn/ui in `src/ui` (Radix + Tailwind + CVA).
- Import path: `@/ui/index.js` only for user-facing controls.
- Icons: Phosphor only.
- Themes: exactly two resolved appearances — light and dark — via
  `data-appearance` from the native shell.
- Specialized surfaces (CodeMirror, canvas, charts, image editors) may keep
  purpose-built libraries; surrounding chrome still uses `@/ui`.

### Brand contract

MachKit should feel **calm, precise, compact, local, and native to macOS** —
closer to a refined system utility than to a marketing site or admin dashboard.

- Blue is reserved for primary actions, selection, focus, and useful results.
- Neutral surfaces and **1px borders** provide ordinary structure.
- Shadows are reserved for transient overlays and selected segmented controls.
- Data values use the shared monospace stack; labels and explanations use the
  system UI font.
- A page has at most one visually primary action.
- Tool titles stay in the native title bar and are not repeated inside the page.
- Light and dark themes share identical hierarchy and geometry.
- Prefer quiet density over decorative chrome: no gradients, glass, tinted
  canvases, or ornamental card stacks on tool pages.
- “Premium” means restraint and alignment — shared metrics, stable focus rings,
  predictable spacing — not extra visual effects.

### Token contract

Land this complete contract in `src/ui/ui.css` before migrating more pages.
If a partial patch is absent (for example after an unrelated revert), restore
the full contract in an isolated change first.

Semantic design tokens define:

- semantic light and dark colors;
- a 4px spacing scale;
- compact, small, and regular control sizes;
- typography roles;
- semantic radii;
- borders, focus rings, and elevations; and
- disabled opacity and interaction timing.

Use this scale without retuning it during migration waves:

- spacing: `0`, `4`, `8`, `12`, `16`, `24`, `32px`;
- radii: `4px` tiny, `6px` internal, `8px` controls, `10px` panels, `12px`
  overlays; pill radius only when semantics require a pill;
- control heights: `28px` compact chips, `34px` default fields / selects / segmented / toolbar buttons;
- toolbar height: `54px`;
- icon sizes: `14`, `16`, and `18px`;
- typography: `11px` caption, `12px` label, `13px` body, `14px` title;
- content padding: `28px` normal and `24px` compact;
- border width: `1px`;
- focus ring width: `3px`;
- disabled opacity: `0.45`;
- motion: `120ms` fast, `180ms` normal, `240ms` slow, with
  `cubic-bezier(0.2, 0, 0, 1)`.

Semantic color roles (no tool-specific palettes):

- background/canvas;
- surface, muted surface, and elevated surface;
- field;
- primary, secondary, and tertiary text;
- subtle, normal, and strong borders;
- accent and accent-soft;
- info, success, warning, and danger, each with a soft surface role;
- focus ring.

Keep the existing MachKit blue and current neutral light/dark surfaces for the
first pass. Token work is **normalization**, not a palette redesign.

Do not retune values mid-wave. First make primitives and pages consume the
contract; evaluate the rendered system as a whole after a full wave.

## Phase 0: Land the token contract

**Goal:** `src/ui/ui.css` exposes the full contract above (MachKit aliases +
shadcn variables + light/dark mappings).

- Isolated commit; no tool JSX in the same change.
- Verify light and dark on at least one compact form tool and one editor tool.
- After this lands, treat token names and values as frozen for migration waves.

## Phase 1: Wire primitives to the contract

Only change files under `Tool/src/ui/` (and `ui.css` if a gap remains).
Do not migrate tool pages yet.

Primitives that must consume semantic tokens:

- `Button` and `IconButton`
- `Input` and `Textarea`
- `Field`
- `SelectControl`
- `CheckboxField`
- `SegmentedControl`
- `InlineMessage`
- `ToolInfoButton`
- `Section`, `ToolContent`, and `EmptyToolState`
- `ValueField`
- date and calendar controls

Required outcomes:

- Controls use the defined heights, radii, border width, focus ring, disabled
  opacity, and motion timing.
- Button variants stay hierarchical: primary, secondary, ghost, accent-ghost,
  and destructive where required.
- Text inputs, textareas, selects, and value fields share field surface, label
  relationship, focus, and invalid treatment.
- Popovers are the only ordinary surfaces using overlay radius and elevation.
- Shared components expose standard DOM/Radix props without tool-specific
  branching.
- Existing exports remain compatible unless every consumer updates in the same
  focused change.

Verification:

```bash
cd Tool
npm test
npm run build
git diff --check
```

Inspect at least one compact form tool, one editor, one sidebar/workbench tool,
and one dark-theme view before merging.

## Phase 2: Extract MachKit product patterns

Add patterns under `Tool/src/ui/` and export them from `src/ui/index.ts`.
Prefer extracting from already-polished tools rather than designing in the
abstract. Keep APIs small.

### Priority A

1. `ToolToolbar` — shared `54px` toolbar geometry; main control region, action
   region, info action; consistent narrow wrapping / label collapse.
2. `ExampleChips` — compact example actions; keyboard accessible; buttons, not
   raw clickable text.
3. `PropertyList` / `PropertyRow` — label/value alignment for technical results;
   optional `machkit.copy()`; truncate visually, keep full value copyable;
   empty values without broken separators.
4. `StatusStrip` — neutral / info / success / warning / danger; text + icon;
   stable height when results appear.
5. `ResultPanel` — panel shell for result, empty, loading, and property content;
   no tool-specific layout lock-in.

### Priority B

6. `SplitWorkspace` — left/right editor or input/result geometry; stacks cleanly
   when narrow.
7. `ToolSidebar` — category / mode rail for workbench tools; selected, hover,
   focus, and optional code badge (extract from `codec` / `number-base`).
8. `EditorPane` — header, actions, border, empty state, CodeMirror container.
9. `ActionGroup` — primary / secondary / utility ordering and narrow behavior.
10. `AnatomyBar` (optional) — protocol- or URL-style segmented field row
    (extract from `url-lab` / `regex-lab` only if a third consumer appears).

Do not create a shared component that only hides one tool's Tailwind string.
A pattern needs two known consumers or membership in a selected page template.

## Phase 3: Lock reference templates

Migrate (or formally adopt) one reference tool per layout family. Later waves
copy these; they do not invent a fifth visual system.

### Template A — editor / transform workspace

Reference: `json-formatter`

Shared pieces: `ToolToolbar`, `ActionGroup`, `EditorPane`, `StatusStrip`,
`SplitWorkspace` when input and output are both visible.

Preserve JSON workflow, CodeMirror, worker, query, keyboard, and clipboard
behavior.

### Template B — form / structured result

Reference: `ip-cidr` (after Phase 1 polish if needed)

Shared pieces: `ToolToolbar`, `ExampleChips`, `StatusStrip`, `ResultPanel`,
`PropertyList` / `PropertyRow`.

Preserve IP-versus-CIDR detection, IPv4/IPv6 inspection, membership, and copy.

### Template C — sidebar workbench

Reference: **`codec`** (primary), with `number-base` as the second consumer

Shared pieces: `ToolSidebar`, field groups or `EditorPane`, `ActionGroup`,
`StatusStrip`.

Preserve category ordering, selection, inputs, and conversion logic. Prefer
`widthClass: .compact` unless the work surface truly needs wide.

### Template D — anatomy / literal editor

Reference: **`url-lab`**, second consumer `regex-lab`

Shared pieces: `ToolToolbar`, `StatusStrip`, anatomy-style field composition,
result region without duplicating the same output twice.

Preserve parse/rebuild semantics. Prefer compact windows.

### Template E — task / progress workflow

Reference: `port-scan`

Shared pieces: `ToolToolbar`, field groups, `StatusStrip`, `ResultPanel`,
standard progress treatment.

Preserve explicit-run, cancellation, progress, bounds, capability checks, and
errors.

Each reference adoption is its own reviewable change. Do not start the next
template until the previous one passes visual and functional QA.

## Phase 4: Migrate remaining tools in waves

Before each wave, rebuild the list from `DeveloperToolRegistry`,
`src/tools-catalog.ts`, and `tools/*/index.html`. Do not revive deleted tools
from this document.

### Current inventory (as of this revision)

`json-formatter`, `timestamp-converter`, `codec`, `string-generator`,
`hosts-manager`, `url-lab`, `regex-lab`, `text-diff`, `number-base`,
`cron-expression`, `ip-cidr`, `color-lab`, `image-process`, `qr-code`,
`jwt-lab`, `chmod-lab`, `cert-lab`, `curl-lab`,
`port-scan`.

### Wave 0 — foundation (blocking)

1. Phase 0 token contract in `ui.css`.
2. Phase 1 primitive wiring.
3. Extract Priority A patterns used by the next wave.
4. Confirm Templates A–E references (adopt existing polish where it already
   matches).

### Wave 1 — form and structured-result tools

Template B (and D where anatomy fits):

- `timestamp-converter`
- `cron-expression`
- `chmod-lab`
- `jwt-lab`
- `cert-lab`
- `color-lab`
- `qr-code`
- `string-generator` (unless it clearly needs Template C)

Goals: toolbars, fields, examples, status strips, property rows, copy actions.

### Wave 2 — transform and editor tools

Templates A / D:

- `text-diff`
- `hosts-manager`
- `regex-lab` / `url-lab` if not already locked as Template D references

Goals: editor headers, split geometry, actions, empty/error states, CodeMirror
consistency.

### Wave 3 — generators and richer workspaces

Templates C / A:

- `image-process`
- `curl-lab`
- `number-base` / `codec` if any remaining local chrome is not yet extracted
  into `ToolSidebar`

Goals: sidebar/group structure, batch/file/progress states, conditional result
stability.

### Wave 4 — native-bridge network workflows

Template E:

- `port-scan` if not already the Template E reference

Goals: explicit execution, progress, cancellation, partial results, timeouts,
errors, and capability boundaries.

## Per-tool migration procedure

1. Read JSX, messages, pure logic, tests, and native registry entry.
2. Record workflow, control order, defaults, conditional states, `widthClass`,
   minimum size, and capabilities.
3. Select one locked page template (A–E).
4. Replace visible controls with shared primitives and product patterns.
5. Remove tool-local styles only when the replacement is complete.
6. Keep specialized visualization CSS when tokens cannot express data meaning.
7. Keep all user-visible strings in `messages.ts` with every locale complete.
8. Run focused tests, then `npm test` and `npm run build` under `Tool/`.
9. Inspect success, empty, invalid, disabled, and conditional states in both
   themes at narrow and normal widths.
10. Check nearby tools if a shared component or token changed.

## Rules for JSX and styling

- Import user-facing controls through `@/ui/index.js`.
- Do not add raw `<button>`, `<input>`, `<select>`, or `<textarea>` when a
  shared component exists.
- Do not invent arbitrary colors, radii, shadows, control heights, or spacing.
- Use semantic roles: `surface`, `field`, `border`, `secondary`, `accent`,
  `success`, `warning`, `danger`.
- Phosphor remains the only H5 icon set.
- Icon-only actions need an accessible name and tooltip/title.
- Use `machkit.copy()` for copy actions.
- Do not globally override a shared component from a tool stylesheet.
- Tool-specific CSS is only for specialized editors, charts, canvases,
  previews, and protocol syntax.

## Review checklist

### Product behavior

- No logic, default, ordering, capability, or bridge behavior changed unless
  the template migration explicitly documents a preserved-equivalent layout
  change (including intentional `widthClass` updates).
- A real successful workflow still works.
- Long values, paths, URLs, localized copy, and errors do not break layout.

### Visual system / brand

- Shared toolbar and control metrics match the token contract.
- Panel and property-row treatments match the reference template.
- At most one primary action.
- Light and dark share hierarchy; page feels calm and precise, not decorative.
- No leftover second button/field/card system on the same page.

### Accessibility

- Labels are associated with controls.
- Icon-only actions have accessible names.
- Keyboard order, focus visibility, Escape, and disabled behavior work.
- Status meaning is available as text, not color alone.

### Engineering

- No new general UI or icon library.
- No generated output edited by hand.
- Registry / catalog metadata stay synchronized when width or presentation
  changes.
- Localization catalogs remain complete.
- Unrelated worktree changes are excluded.

## Verification commands

```bash
cd Tool
npm test
npm run build
cd ..
swift test
xcodebuild -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath build/XcodeDerivedData \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
```

If only shared H5 code changed, still run the macOS App build before accepting
the final wave so bundled WebView integration is verified.

## Commit strategy

Small commits, one responsibility:

1. Land token contract.
2. Wire shared primitives to tokens.
3. Add Priority A product patterns (optionally extracted from reference tools).
4. Lock one reference template per commit.
5. Migrate one coherent tool wave in reviewable groups.
6. Remove legacy classes only after their last consumer is migrated.

Do not mix parsing changes, feature work, catalog cleanup, dependency upgrades,
or unrelated formatting into UI migration commits.

## Completion criteria

Migration is complete when:

- every current tool uses one of Templates A–E;
- visible controls come from the repository-owned shadcn/ui layer;
- arbitrary colors, radii, shadows, and control sizes are absent outside
  approved specialized visualizations;
- shared empty, loading, status, result, copy, and error patterns are used;
- light/dark and narrow/normal visual QA passes for every tool;
- Tool tests, production build, Swift tests, and macOS App build pass; and
- removed legacy CSS and duplicate local chrome have no remaining consumers.
