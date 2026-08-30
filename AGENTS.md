# MachKit Repository Guidelines

## Scope and precedence

This file applies to the whole repository.

- A nested `AGENTS.md` extends or overrides these rules for its subtree. Changes under `Tool/` must also follow `Tool/AGENTS.md`.
- Use `README.md` for supported environments and contributor commands, and `SECURITY.md` for vulnerability reporting.
- Higher-priority user and system instructions override repository guidance.
- Treat existing uncommitted changes as user-owned. Preserve unrelated work.

## Product invariants

MachKit is a privacy-first, local-first macOS utility.

- Do not add analytics, telemetry, tracking, advertising, cloud storage, remote runtime assets, or implicit network requests.
- Network operations and broad system scans must follow an explicit user action. Long-running work needs useful progress, cancellation, bounded timeouts, and actionable errors.
- Use least privilege. Keep administrator operations narrow, explicit, auditable, and separate from ordinary app logic.
- Prefer reversible changes. Move user data to Trash when practical; label and intentionally confirm permanent deletion.
- Safety and privacy take precedence over polish, convenience, and compatibility shortcuts.

## Repository boundaries

- `App/`: SwiftUI UI, app orchestration, preferences, system adapters, WebView hosting, and screenshot sessions.
- `Sources/MachKitCore/`: reusable, deterministic business logic, policies, parsers, scanners, command boundaries, and geometry.
- `Tests/MachKitCoreTests/`: unit, safety, and regression tests for the core module.
- `Tool/`: bundled React/TypeScript/Vite utilities. Its nested `AGENTS.md` is authoritative for H5 architecture and UI.
- `Website/`: React/TypeScript/Vite website with SSR and prerender verification.
- `Resources/`: app assets and localization catalogs.
- `Scripts/`: build, verification, localization, packaging, and release automation.

Put platform-independent logic in `MachKitCore`, not in SwiftUI views or app lifecycle objects. Keep AppKit and SwiftUI out of the core module unless an existing boundary deliberately requires them.

## Change discipline

- Keep changes focused. Avoid unrelated rewrites, formatting, renames, dependency churn, or parallel architecture.
- Search every consumer before changing public APIs, persistent keys, localization keys, tool IDs, bridge messages, capabilities, or resource paths.
- Preserve compatibility or provide an explicit migration for persisted data and public contracts.
- Fix root causes and add focused regression coverage when behavior is testable.
- Comments should explain non-obvious constraints or decisions, not restate code.
- Do not manually edit generated output or caches: `.build/`, `build/`, `Tool/dist/`, `Website/dist/`, `Resources/WebTools/`, or `node_modules/`.

## Swift and concurrency

- Keep the deployment targets and language versions declared by the project unless the task explicitly changes them.
- Prefer small `Sendable` protocols and dependency injection for system services.
- Keep UI state on the main actor. Filesystem walks, hashing, parsing, process execution, and network work must not block it.
- Use structured concurrency, propagate cancellation, and clean up tasks, observers, processes, temporary resources, and sessions on every exit path.
- Bound arbitrary inputs, batches, buffers, and results to keep memory and CPU use predictable.
- Prefer typed errors and explicit partial-failure results. Do not swallow recoverable failures or rely on force unwraps.
- Use `URL` and `FileManager` for paths. Invoke fixed executables with argument arrays through the established command runner; never interpolate untrusted text into a shell command.

## Filesystem and privilege safety

- Canonicalize paths before policy checks and account for symlinks, aliases, relative components, mount boundaries, and case behavior.
- Use the central safety policy and containment checks; do not create local allowlists for destructive operations.
- Revalidate the exact object immediately before mutation to reduce time-of-check/time-of-use risk.
- Never accept empty, root, home, workspace-root, or similarly broad recursive deletion targets.
- Return per-item outcomes for batch mutations and preserve unaffected items when one operation fails.
- Validate and normalize inputs on both sides of a privilege boundary. Authorization prompts must correspond to a clear, immediate action.
- Never log secrets, credentials, sensitive contents, or unnecessary personal paths.
- Changes to deletion, path validation, symlink handling, risk classification, or privilege boundaries require regression tests.

## WebView and embedded-tool boundary

- The native host owns capabilities. Register each tool explicitly and grant only what it needs.
- Validate the main frame, tool identity, protocol version, message shape, request ID, and capability before native work.
- Use versioned request/reply messages with bounded timeouts and structured errors. Do not expose generic filesystem, process, or network execution to web content.
- Cancel outstanding work when a tool closes or navigates away.
- Bundle runtime content locally; do not load remote scripts, fonts, trackers, or executable assets.
- Keep tool IDs, catalog metadata, native registry entries, capabilities, and bundled paths synchronized.
- H5 controls must use the repository-owned shadcn/ui layer and shared semantic tokens. Do not add HeroUI or another general-purpose UI system; follow `Tool/AGENTS.md` for details.

## UI, accessibility, and localization

- Native UI should follow macOS conventions and prefer SwiftUI controls, semantic colors, materials, typography, and spacing.
- Keep view bodies declarative; move non-trivial state transitions and side effects into a model or service.
- Every interactive control needs a clear accessible name, visible focus behavior where applicable, and logical keyboard interaction.
- Design loading, empty, success, partial, permission-denied, cancelled, and error states intentionally.
- Verify light and dark appearances. Do not hardcode colors that lose contrast.
- English is the source language. Put native strings in `Resources/Localizable.xcstrings` and keep every supported locale complete. Preserve placeholders, plurals, punctuation, and formatting tokens.
- Keep matching product names and concepts consistent across the native app, embedded tools, website, and READMEs.

## Website, screenshots, dependencies, and releases

- Keep `Website/` compatible with client build and SSR/prerender. Guard browser-only globals, maintain semantic responsive UI and SEO metadata, and use only bundled runtime assets.
- Keep screenshot coordinate and scale math pure. Test high-DPI and multi-display cases, and clean up overlays, event monitors, and capture state on all exits.
- Prefer platform APIs and existing packages. New dependencies require maintenance, security, privacy, license, bundle-size, and memory justification; update manifests and lockfiles together.
- Do not casually change tag parsing, signing, notarization, packaging, update feeds, or release workflows. Verify release changes against the actual automation.

## Verification and completion

Run the narrowest relevant checks while iterating. Before handoff, run the affected portions of the canonical suite:

```bash
./Scripts/verify.sh
```

For embedded-tool UI changes, install Chromium once and include Playwright:

```bash
MACHKIT_RUN_UI_TESTS=1 ./Scripts/verify.sh
```

- Inspect visual changes in the running implementation, not only in source. Check light/dark appearance, accessibility, and representative compact and wide layouts.
- Run focused tests for parsers, policies, bridges, geometry, and safety behavior before the full affected suite.
- Report every skipped or failed check with the exact command and reason.
- A change is complete only when requested behavior works, privacy and safety invariants hold, relevant checks pass, localization and documentation are synchronized, and unrelated or generated changes are excluded.
