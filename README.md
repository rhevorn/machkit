# MachKit

[English](README.md) · [简体中文](README.zh-CN.md)

A privacy-first macOS utility for storage analysis, cleanup, app uninstall, system monitoring, network inspection, annotated screenshots, and a growing collection of local utilities.

MachKit has no analytics service or cloud backend. Scans read local file metadata only, risky items stay unchecked by default, and removable items go to the Trash unless the UI explicitly identifies an operation as permanent. Network diagnostics and cURL Lab send requests only when you explicitly start them, directly from your Mac.

<p align="center">
  <table cellpadding="12" cellspacing="0">
    <tr>
      <td align="center" bgcolor="#e8e8ed">
        <img src="Website/public/assets/overview.webp" alt="MachKit overview" width="900" />
      </td>
    </tr>
  </table>
</p>

## Features

- **Cleanup** — Find caches, logs, leftovers, and developer files; risky items stay unchecked
- **Apps** — Browse apps and command-line tools, then uninstall with related support files
- **Storage** — Understand disk usage and large folders
- **Monitor** — Follow CPU, memory pressure, thermal state, and busy apps ([monitoring details](docs/monitoring.md))
- **Network** — Inspect traffic, connections, listening ports, routes, VPN/TUN, and proxies
- **System** — Review login items, background activity, and extensions
- **Menu bar** — Keep a lightweight monitor for CPU, memory, network speed, and quick actions
- **Screenshot** — Capture any screen region from a global shortcut, freeze the desktop, annotate with rectangles, ellipses, arrows, pen, highlight, mosaic, and text, then copy or save—all on your Mac, without opening another window
- **Utilities** — Open focused local tools from the Tools workspace, menu, or global shortcuts:
  - **Hosts Manager** — View `/etc/hosts` and switch shared / environment mappings safely
  - **Timestamp Converter** — Convert dates and Unix timestamps across units and time zones
  - **JSON Formatter** — Format, minify, sort keys, and query values with path expressions
  - **Codec** — Encode and decode Base64, Base32, Base62, Hex, URL, HTML, Unicode, Escape, and Hash
  - **String Generator** — Generate UUID v1–v7, ULIDs, Nano IDs, hex strings, and passwords locally
  - **Regex Lab** — Highlight matches, inspect capture groups, and try common replacements
  - **Text Diff** — Compare two texts side by side with line-level highlighting
  - **IP / CIDR Calculator** — Calculate IPv4 network details, ranges, and membership checks
  - **Cron Expression** — Build five-field cron schedules and preview upcoming runs
  - **Data Format** — Convert between JSON, YAML, and TOML locally
  - **Color Lab** — Convert HEX, RGB, HSL, and HSV with local contrast checks
  - **QR Code** — Generate QR codes from text or URLs locally
  - **URL Lab** — Parse and rebuild URLs with query and hash editing
  - **Number Base** — Convert integers across bases and byte units locally
  - **IP Inspector** — Inspect IPv4 and IPv6 addresses, kinds, and reverse DNS labels
  - **Image Tools** — Convert formats and control output by quality, target size, or dimensions
  - **JWT Lab** — Decode, inspect, and create JSON Web Tokens locally
  - **chmod Lab** — Convert Unix permission modes and preview symbolic changes
  - **Certificate Lab** — Inspect certificates, CSRs, and certificate chains locally
  - **Text Lab** — Clean, transform, sort, count, and reshape text
  - **cURL Lab** — Build, parse, edit, and explicitly run cURL requests directly from your Mac
  - **Connection Trace** — Trace how a destination resolves and routes through the Mac
  - **Port Scanner** — Scan any TCP port or range with progress and open-port results

## Requirements

- macOS 14 or later
- Xcode 16 / Swift 6 (for building from source)
- Node.js 24 / npm (for building the embedded H5 tools)
- Full Disk Access may be required for some user directories
- Editing hosts files requires administrator authentication when writing

## Install

When the maintainers configure Apple release credentials, MachKit releases are signed with Developer ID and notarized by Apple. Otherwise, the release workflow publishes an ad-hoc signed, non-notarized build and labels it clearly in the release notes. Source builds use your local Xcode signing configuration.

1. Download `MachKit-*-macOS.zip` from [GitHub Releases](https://github.com/rhevorn/machkit/releases/latest).
2. Unzip it, then move `MachKit.app` into `/Applications`.
3. Open MachKit from Applications or Spotlight.

## Build

Install the locked frontend dependencies once, then open the Xcode project and run the `MachKit App` scheme:

```bash
cd Tool && npm ci && cd ..
open MachKit.xcodeproj
```

Or build from the terminal:

```bash
xcodebuild \
  -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -derivedDataPath build/XcodeDerivedData \
  build

open build/XcodeDerivedData/Build/Products/Debug/MachKit.app
```

Core library tests:

```bash
swift test
```

Run the H5 development server when working on embedded tools:

```bash
cd Tool
npm ci
npm run dev
```

Debug builds can load tools from the local Vite server with HMR; Release builds always use the bundled `Resources/WebTools` output. See [Tool/README.md](Tool/README.md) for adding a tool.

## Releases

Local builds use `dev`. Release tags are the source of truth for shipped versions: pushing a tag such as `v0.9.0` overrides the app version with `CFBundleShortVersionString=0.9.0`, while the GitHub Actions run number becomes `CFBundleVersion`. The workflow verifies both values, then selects one of two explicit release modes: all documented Apple secrets produce a Developer ID signed, notarized, and stapled ZIP; no Apple secrets produce an ad-hoc signed, non-notarized ZIP. A partially configured secret set fails instead of silently downgrading. Existing tags can also be rebuilt from the workflow’s manual dispatch input.

```bash
git tag v0.9.0
git push origin v0.9.0
```

## Localization

English is the source language. The app also includes Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, Brazilian Portuguese, and Russian. Embedded web tools follow the same locale and appearance preferences as the native UI.

## Project layout

```text
App/                 SwiftUI app, preferences, tools shell, bridges, and screenshot
Sources/MachKitCore/    Scanning, risk rules, cleanup, hosts, system inventory, geometry helpers
Tool/                H5 utilities (Vite + React), bundled into Resources/WebTools
Resources/           App icon and Localizable.xcstrings
Tests/MachKitCoreTests/ Core behavior and safety tests
MachKit.xcodeproj/      macOS app project
Website/             Marketing site
```

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks, and safety rules. Security reports should follow [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
