# Screenshot module

Capture flow:

1. `ScreenshotController` shows dim overlays (`ScreenshotSelectionSession`).
2. `ScreenshotCapture` waits until those overlay window IDs appear in
   `SCShareableContent`, then freezes displays under them via ScreenCaptureKit
   (with short retries—new panels are often missing from the first query).
3. While hovering, a compact reticle with magnifier and a color chip
   (`#RRGGBB · Click to copy`) samples color. A click (movement under ~10pt)
   copies the hex; only dragging past that threshold starts a capture region.
   `C` / Space also copy once the overlay is key. During a real drag, sampling
   chrome hides and the selection frame / size label remain
   (`ScreenshotSelectionChrome`). `ScreenshotGeometry` maps AppKit screen space
   to CGImage pixels.
4. `ScreenshotEditorController` presents annotation UI on an AppKit-frozen desktop backdrop.
5. Export draws strokes through `ScreenshotStrokeRenderer` (same geometry as the canvas preview).

Coordinate spaces:

- Selection / display frames: AppKit, origin bottom-left, Y up.
- Editor model and SwiftUI canvas: top-left, Y down.
- `ScreenshotGeometry.pixelRect` converts selection → pixel crop with the Y flip.

Permissions:

- Requires Screen Recording (`NSScreenCaptureUsageDescription`).
- `ScreenshotPermission` preflights access and can open System Settings.
