# Sift

[English](README.md) · [简体中文](README.zh-CN.md)

A privacy-first macOS utility for storage analysis, cleanup, app uninstall, network tools, and login items & extensions.

Everything runs locally on your Mac. Scans read file metadata only, risky items stay unchecked by default, and deletions go to the Trash.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Website/public/assets/img20.png" />
    <img src="Website/public/assets/img10.png" alt="Sift overview" width="900" />
  </picture>
</p>

## Features

- **Cleanup** — Find caches, logs, leftovers, and developer files; risky items stay unchecked
- **Apps** — Browse apps and command-line tools, then uninstall with related support files
- **Storage** — Understand disk usage and large folders
- **Performance** — Monitor CPU, memory pressure, and busy apps
- **Network** — Inspect traffic, connections, listening ports, routes, VPN/TUN, and proxies
- **System** — Review login items, background activity, and extensions

## Requirements

- macOS 14 or later
- Xcode 16 / Swift 6 (for building from source)
- Full Disk Access may be required for some user directories

## Install

Sift is currently distributed as an **unsigned** ad-hoc build, so macOS Gatekeeper will block a normal double-click the first time.

1. Download `Sift-*-macOS.zip` from [GitHub Releases](https://github.com/rhevorn/sift/releases/latest).
2. Unzip it, then move `Sift.app` into `/Applications`.
3. Open it with either method:
   - Right-click `Sift.app` → **Open** → **Open**
   - Or go to **System Settings → Privacy & Security**, find the blocked-app notice, and choose **Open Anyway**
4. After the first successful launch, you can open Sift normally from Applications or Spotlight.

## Build

Open the Xcode project and run the `Sift App` scheme:

```bash
open Sift.xcodeproj
```

Or build from the terminal:

```bash
xcodebuild \
  -project Sift.xcodeproj \
  -scheme "Sift App" \
  -configuration Debug \
  -derivedDataPath build/XcodeDerivedData \
  build

open build/XcodeDerivedData/Build/Products/Debug/Sift.app
```

Core library tests:

```bash
swift test
```

## Releases

Local builds use `dev`. Release tags are the source of truth for shipped versions: pushing a tag such as `v0.9.0` overrides the app version with `CFBundleShortVersionString=0.9.0`, while the GitHub Actions run number becomes `CFBundleVersion`. The workflow verifies both values before packaging and publishing the ZIP.

```bash
git tag v0.9.0
git push origin v0.9.0
```

## Localization

English is the source language. The app also includes Simplified Chinese, Traditional Chinese, Japanese, Korean, Spanish, French, German, Brazilian Portuguese, and Russian.

## Project layout

```text
App/                 SwiftUI app, preferences, and app state
Sources/SiftCore/    Scanning, risk rules, cleanup, and system inventory
Resources/           App icon and Localizable.xcstrings
Tests/SiftCoreTests/ Core behavior and safety tests
Sift.xcodeproj/      macOS app project
Website/             Marketing site
```

## Contributing

Issues and pull requests are welcome. Keep changes focused, and prefer local, reversible operations for anything that deletes or terminates processes.

## License

[MIT](LICENSE)
