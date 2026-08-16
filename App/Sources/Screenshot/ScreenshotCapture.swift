import AppKit
import ScreenCaptureKit

enum ScreenshotCaptureError: LocalizedError {
    case captureFailed

    var errorDescription: String? {
        "Unable to capture the screen.".localized
    }
}

struct ScreenshotSelection {
    let rect: CGRect
    let displayID: CGDirectDisplayID
}

struct ScreenshotCaptureResult {
    let image: CGImage
    let selectionRect: CGRect
}

struct ScreenshotDisplayBackdrop: Identifiable {
    var id: CGDirectDisplayID { displayID }
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let image: CGImage
}

struct ScreenshotDesktopSnapshot {
    let displays: [ScreenshotDisplayBackdrop]

    func image(for displayID: CGDirectDisplayID) -> CGImage? {
        displays.first { $0.displayID == displayID }?.image
    }
}

@MainActor
enum ScreenshotCapture {
    /// Captures what is currently behind the selector windows. Call this only
    /// after the overlays are on-screen so any capture-side flicker stays hidden.
    static func captureDesktop(below windows: [NSWindow]) async throws -> ScreenshotDesktopSnapshot {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let overlayIDs = Set(windows.map { CGWindowID($0.windowNumber) })
        let excludedWindows = content.windows.filter { overlayIDs.contains($0.windowID) }

        var displays: [ScreenshotDisplayBackdrop] = []
        var capturedDisplayIDs = Set<CGDirectDisplayID>()
        for window in windows {
            guard let screen = window.screen,
                  let displayID = screen.displayID,
                  !capturedDisplayIDs.contains(displayID),
                  let scDisplay = content.displays.first(where: { $0.displayID == displayID })
            else {
                continue
            }

            let filter = SCContentFilter(display: scDisplay, excludingWindows: excludedWindows)
            let configuration = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            configuration.width = max(1, Int((filter.contentRect.width * scale).rounded()))
            configuration.height = max(1, Int((filter.contentRect.height * scale).rounded()))
            configuration.showsCursor = false
            configuration.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            guard image.width > 0, image.height > 0 else { continue }
            displays.append(
                ScreenshotDisplayBackdrop(displayID: displayID, frame: screen.frame, image: image)
            )
            capturedDisplayIDs.insert(displayID)
        }

        guard !displays.isEmpty else { throw ScreenshotCaptureError.captureFailed }
        return ScreenshotDesktopSnapshot(displays: displays)
    }

    static func crop(
        _ selection: ScreenshotSelection,
        from snapshot: ScreenshotDesktopSnapshot
    ) throws -> ScreenshotCaptureResult {
        guard let display = snapshot.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw ScreenshotCaptureError.captureFailed
        }
        let selectedRect = selection.rect.intersection(display.frame).integral
        guard selectedRect.width >= 2, selectedRect.height >= 2 else {
            throw ScreenshotCaptureError.captureFailed
        }

        let scaleX = CGFloat(display.image.width) / display.frame.width
        let scaleY = CGFloat(display.image.height) / display.frame.height
        let pixelRect = CGRect(
            x: (selectedRect.minX - display.frame.minX) * scaleX,
            y: (display.frame.maxY - selectedRect.maxY) * scaleY,
            width: selectedRect.width * scaleX,
            height: selectedRect.height * scaleY
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: display.image.width, height: display.image.height)
        )
        guard pixelRect.width >= 2, pixelRect.height >= 2,
              let image = display.image.cropping(to: pixelRect)
        else {
            throw ScreenshotCaptureError.captureFailed
        }
        return ScreenshotCaptureResult(image: image, selectionRect: selectedRect)
    }

    static func copyToPasteboard(_ image: CGImage) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw ScreenshotCaptureError.captureFailed
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setData(png, forType: .png) else {
            throw ScreenshotCaptureError.captureFailed
        }
        if let tiff = representation.representation(using: .tiff, properties: [:]) {
            _ = pasteboard.setData(tiff, forType: .tiff)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
