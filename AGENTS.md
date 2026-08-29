# MachKit Repository Guidelines

## Scope and precedence

This file applies to the entire repository.

- Read this file before making changes anywhere in the project.
- A more deeply nested `AGENTS.md` extends or overrides these rules for files in its directory tree.
- Changes under `Tool/` must also follow `Tool/AGENTS.md`. In particular, embedded H5 tools use the repository-owned shadcn/ui component layer, not HeroUI.
- Follow `README.md`, `CONTRIBUTING.md`, and `SECURITY.md` when they provide more specific product, contribution, or security requirements.
- When instructions conflict, prefer the instruction closest to the file being changed, unless a higher-priority user or system instruction says otherwise.

## Product principles

MachKit is a privacy-first macOS utility. Preserve these properties in every change:

- Local-first by default. Do not add analytics, telemetry, tracking, advertising, cloud storage, remote scripts, or implicit network requests.
- Network access and system scans must be initiated by an explicit user action and must expose useful progress, cancellation, timeout, and error states.
- Use the least privilege required. Keep privileged operations small, explicit, auditable, and separated from ordinary app logic.
- Prefer reversible actions. Move user data to Trash where practical; permanent deletion must be clearly labeled and intentionally confirmed.
- Never trade safety or privacy for visual polish or implementation convenience.

## Repository layout

- `App/`: the macOS SwiftUI application, app-level orchestration, preferences, tool hosting, WebView bridges, and screenshot UI.
- `Sources/MachKitCore/`: reusable and testable core logic, including scanning, cleanup rules, hosts operations, inventory, and geometry.
- `Tests/MachKitCoreTests/`: unit and regression tests for `MachKitCore`.
- `Tool/`: embedded H5 utilities built with React and Vite. Follow `Tool/AGENTS.md` for its UI and tool-development contract.
- `Website/`: the React/Vite marketing website, including SSR/prerender and verification scripts.
- `Resources/`: app resources, the app icon, and `Localizable.xcstrings`.
- `Scripts/`: build, localization, packaging, and release automation.

Do not put platform-independent business logic in SwiftUI views or app lifecycle objects when it belongs in `MachKitCore`.

## Change discipline

- Keep changes focused on the requested outcome. Avoid unrelated rewrites, reformatting, renaming, or dependency churn.
- Treat existing uncommitted changes as user-owned. Inspect the worktree and preserve unrelated edits.
- Prefer extending existing architecture and components over introducing parallel systems.
- Search for all consumers before changing public APIs, persistent keys, localization keys, tool identifiers, bridge messages, or resource paths.
- Do not edit generated artifacts by hand. Update their source or generator instead.
- Comments should explain non-obvious constraints or reasoning, not restate the code.
- Fix the cause of a problem and add a focused regression test when the behavior is testable.

## Swift and MachKitCore

- Target the Swift and macOS versions declared by the project. Do not silently raise deployment targets or toolchain requirements.
- Put pure parsing, validation, policy, geometry, and filesystem decision logic in `MachKitCore` when possible.
- Keep AppKit and SwiftUI dependencies out of `MachKitCore` unless the module already establishes a deliberate boundary for them.
- Use small `Sendable` protocols and dependency injection for system services so behavior can be tested without touching the live machine.
- Respect actor isolation. UI state belongs on the main actor; long-running scans, filesystem walks, hashing, and network work must not block it.
- Support cancellation in asynchronous or potentially long-running work, and avoid detached tasks when structured concurrency can express ownership.
- Prefer typed errors and actionable user-facing failure states. Do not swallow failures or rely on force unwraps for recoverable conditions.
- Use `URL` and `FileManager` APIs for paths. Do not construct shell commands by interpolating untrusted strings.
- When invoking a process, pass the executable and argument array separately through the established command runner.
- Keep model and service behavior deterministic enough for unit tests.

## SwiftUI and native app UX

- Follow the existing macOS visual language and interaction patterns. Prefer native SwiftUI controls, semantic colors, materials, typography, and spacing.
- Isolate AppKit bridging to the smallest practical adapter instead of leaking it throughout views.
- Keep view bodies declarative. Put non-trivial state transitions, asynchronous work, and side effects in a view model or service.
- Preserve existing preference keys and migration behavior. A renamed key is a data migration, not a cosmetic refactor.
- Every interactive control must have a clear label, keyboard/focus behavior where appropriate, and an accessible description when the visible content is insufficient.
- Verify light and dark appearances. Do not hardcode colors that lose contrast in either theme.
- Make loading, empty, success, partial, permission-denied, cancelled, and error states intentional.
- Use localized strings for user-visible copy; do not assemble translated sentences from fragments.

## Filesystem and destructive operations

Filesystem changes are security-sensitive.

- Resolve and canonicalize paths before evaluating policy. Account for symlinks, aliases, relative components, mount boundaries, and path case behavior.
- Use the central safety policy and containment checks instead of duplicating ad hoc path allowlists.
- Revalidate the exact target immediately before every destructive mutation. A validation performed only during discovery is not sufficient.
- Never allow an empty, root, home, workspace-root, or otherwise broad path to become a recursive deletion target.
- Prefer moving files to Trash. If permanent deletion is required, make the distinction explicit in both code and UI.
- Treat time-of-check/time-of-use races as real. Minimize the interval between validation and mutation and verify the object still matches expectations.
- Return per-item results for batch operations where partial failure is possible.
- Add regression tests for every change to path validation, symlink handling, risk classification, cleanup policy, or deletion behavior.

## Privileged operations and command execution

- Keep the privileged surface narrow and expose only specific operations needed by the product.
- Validate and normalize inputs on both sides of a privilege boundary.
- Never pass user-controlled text through a shell interpreter.
- Use fixed executable paths where required and pass arguments as an array.
- Do not log secrets, full sensitive file contents, authentication material, or unnecessary personal paths.
- Make authorization prompts correspond to a clear, immediate user action.

## WebView bridges and embedded tools

- The native host owns capabilities. Register every tool and its capabilities explicitly; do not infer privileges from page content.
- Grant only the capabilities a tool actually needs, such as clipboard, hosts, storage, port scanning, file access, or curl execution.
- Validate the source frame, tool identity, message shape, request identifier, and capability before performing native work.
- Prefer versioned request/reply messages with bounded timeouts and structured errors.
- Avoid exposing generic filesystem, process, or network execution handlers to web content.
- Cancel or detach outstanding work when the tool view closes or navigates away.
- Keep WebView content local and bundled. Do not load remote scripts, fonts, trackers, or runtime UI dependencies.
- For H5 implementation details, component rules, themes, layouts, and bridge conventions, follow `Tool/AGENTS.md`.

## Embedded H5 tools

- The unified H5 component standard is shadcn/ui through the repository-owned component layer. Do not add HeroUI or another general-purpose UI system.
- The MachKit H5 visual language is calm, precise, compact, and macOS-native. Prefer neutral surfaces, clear hierarchy, restrained blue accents, thin borders, and functional density over decorative web styling.
- Keep the existing tool layout unless the task explicitly requests structural change.
- All tools must support the shared light and dark themes and visually align with the native app.
- Treat `Tool/src/ui/ui.css` as the source of truth for semantic colors, spacing, radii, control sizes, borders, elevation, focus, typography, and motion. Do not introduce arbitrary local values when a shared token exists.
- Reuse shared tokens, shadcn primitives, product-pattern components, page templates, states, and interaction patterns; do not create one-off local design systems.
- For broad H5 UI migrations, follow `Tool/UI_MIGRATION_PLAN.md` in addition to `Tool/AGENTS.md`.
- Keep tool identifiers, registry capabilities, bundled resource paths, and native bridge behavior synchronized.

## Website

- Keep the website compatible with its Vite client build and SSR/prerender pipeline.
- Do not access browser-only globals during module evaluation or server rendering without an explicit guard.
- Maintain semantic HTML, keyboard navigation, accessible names, focus visibility, readable contrast, and responsive layouts.
- Keep SEO metadata, structured data, navigation, tool catalog content, and localized copy consistent when pages or products change.
- Do not add analytics, trackers, remote scripts, or remotely hosted runtime fonts and assets.
- Change source files, not `Website/dist/`. The full website build includes prerender and output verification and is part of completion.

## Localization

- English is the source language. User-facing copy must be clear and stable before translation keys are propagated.
- Native app strings belong in `Resources/Localizable.xcstrings` and should be accessed through the established localization helpers.
- Keep all supported locales complete when adding or changing keys. Do not silently fall back because a catalog entry was omitted.
- H5 tool localization and website localization live in their respective source catalogs; keep matching concepts and product names consistent across surfaces.
- Preserve placeholders, plural behavior, punctuation intent, and formatting tokens across translations.
- Do not localize internal identifiers, file formats, command flags, protocol fields, or code examples unless the UI specifically requires it.

## Screenshot and geometry work

- Treat display coordinates, backing scale, multi-monitor origins, cropped bounds, and window/screen coordinate conversions as separate concerns.
- Keep reusable geometry math pure and covered by `ScreenshotGeometryTests` or an equivalent focused test.
- Ensure capture sessions clean up overlays, event monitors, temporary resources, and cancellation state on every exit path.
- Test at least one high-DPI and one multi-display edge case when changing capture geometry or selection behavior.

## Dependencies and assets

- Prefer standard-library, platform, and existing project capabilities before adding a dependency.
- A new dependency must have a clear maintenance, security, privacy, and bundle-size justification.
- Update the package manifest and lockfile together. Use locked/reproducible installs in verification and CI.
- Do not add a second UI component library to solve a local styling problem.
- Bundle required runtime assets locally and confirm their license is compatible with the project.
- Optimize large images and avoid duplicating equivalent assets across app, tool, and website targets.

## Generated files and release metadata

Do not manually edit build products or caches, including:

- `.build/`
- `build/`
- `Tool/dist/`
- `Website/dist/`
- generated or copied web bundles under `Resources/WebTools/`
- dependency directories such as `node_modules/`

Release tags are a source of version information for release automation. Do not casually change tag parsing, signing, notarization, packaging, update feeds, or release workflows. Verify such changes against the documented release process.

## Verification

Run the narrowest relevant checks while iterating, then run the complete checks affected by the change. Common commands are:

```bash
swift test
(cd Tool && npm test && npm run build)
(cd Website && npm test && npm run build)
xcodebuild -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath build/XcodeDerivedData \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Additional expectations:

- Run focused unit tests after modifying parsers, policies, geometry, or service behavior.
- Add a regression test for a safety fix or previously failing edge case.
- Verify both light and dark themes for UI changes.
- Check representative compact and wide layouts for embedded H5 changes.
- For visual changes, inspect the rendered result rather than relying only on compilation.
- If a check cannot run, report exactly which command was skipped or failed and why.

## Definition of done

A change is complete only when:

- The requested behavior works in the intended surface.
- Privacy, least-privilege, and filesystem safety guarantees remain intact.
- Relevant tests and builds pass, or any limitation is clearly reported.
- New user-visible copy is localized across supported locales.
- Light/dark appearance and accessibility have been considered for UI changes.
- Generated output and unrelated user changes are not included accidentally.
- Documentation and registry/catalog metadata are updated when behavior or developer contracts changed.
