# Contributing to MachKit

Thanks for helping improve MachKit. Keep pull requests focused and explain the
user-visible behavior they change.

## Set up

1. Install Xcode 16 or later and Node.js 24.
2. Run `npm ci` in `Tool/` and `Website/`.
3. Open `MachKit.xcodeproj` and build the `MachKit App` scheme.

## Before opening a pull request

Run the same boundaries enforced by CI:

```bash
swift test
(cd Tool && npm test && npm run build:app)
(cd Website && npm test && npm run build)
xcodebuild \
  -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Safety rules

- Revalidate filesystem targets immediately before every destructive action.
- Prefer moving files to the Trash. Label permanent deletion explicitly.
- Never construct shell commands from untrusted strings. Pass arguments as an
  array, or use the narrow administrator boundary already in the core module.
- Keep WebView capabilities least-privileged and validate the requesting frame.
- Do not add analytics, remote scripts, or implicit network requests.
- Add a regression test for every safety or parsing fix.

English is the source language. New user-facing strings must include every
locale already present in the string catalog.
