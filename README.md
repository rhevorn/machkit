# Sift

[English](README.md) · [简体中文](README.zh-CN.md)

A privacy-first macOS utility for storage analysis, cleanup, app uninstall, network tools, and login items & extensions.

Everything runs locally on your Mac. Scans read file metadata only, risky items stay unchecked by default, and deletions go to the Trash.

<p align="center">
  <img src="Website/public/assets/img10.png" alt="Sift overview in light appearance" width="900" />
</p>

<p align="center">
  <img src="Website/public/assets/img11.png" alt="Sift cleanup results in light appearance" width="900" />
</p>

## Features

- **Cleanup** — Find caches, logs, leftover app data, and regenerable developer files, with clear safe / needs-review labels
- **Uninstall** — Remove apps together with related support files
- **Storage** — See disk usage by category and drill into large folders
- **Performance** — Monitor CPU, memory pressure, and top processes
- **Network** — Use dedicated views for Overview, App Traffic, Active Connections, Listening Ports, and Routing; rates stay consistent in B/s, KB/s, MB/s, or GB/s, while route lookup shows the resolved IP and outbound interface
- **Login Items & Extensions** — Review login items, background tasks, and system extensions in one place

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
