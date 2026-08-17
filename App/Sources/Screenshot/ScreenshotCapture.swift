import AppKit
import CoreGraphics
import MachKitCore
import ScreenCaptureKit

enum ScreenshotCaptureError: LocalizedError, Equatable {
    case captureFailed
    case permissionDenied
    case emptySelection
    case pasteboardFailed
    case encodeFailed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            "Unable to capture the screen.".localized
        case .permissionDenied:
            "Screen Recording permission is required to capture screenshots.".localized
        case .emptySelection:
            "The selected area is too small.".localized
        case .pasteboardFailed:
            "Unable to copy the screenshot to the clipboard.".localized
        case .encodeFailed:
            "Unable to encode the screenshot.".localized
        case .timedOut:
            "Screenshot capture timed out.".localized
        }
    }
}

struct ScreenshotSelection {
    let rect: CGRect
    let displayID: CGDirectDisplayID
}

struct ScreenshotCaptureResult {
    let image: CGImage
    let selectionRect: CGRect
    let displayID: CGDirectDisplayID
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
        display(for: displayID)?.image
    }

    func display(for displayID: CGDirectDisplayID) -> ScreenshotDisplayBackdrop? {
        displays.first { $0.displayID == displayID }
    }

    func retainingDisplay(_ displayID: CGDirectDisplayID) -> ScreenshotDesktopSnapshot? {
        guard let display = display(for: displayID) else { return nil }
        return ScreenshotDesktopSnapshot(displays: [display])
    }
}

@MainActor
enum ScreenshotCapture {
    static let captureTimeout: Duration = .seconds(8)
    /// Newly ordered overlay panels are often missing from the first
    /// `SCShareableContent` snapshot; wait briefly instead of failing outright.
    private static let overlayResolveTimeout: Duration = .milliseconds(1200)
    private static let overlayResolvePoll: Duration = .milliseconds(40)
    private static let imageCaptureAttempts = 3

    /// Captures what is currently behind the selector windows. Call this only
    /// after the overlays are on-screen so any capture-side flicker stays hidden.
    static func captureDesktop(below windows: [NSWindow]) async throws -> ScreenshotDesktopSnapshot {
        try Task.checkCancellation()
        guard ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: false) else {
            throw ScreenshotCaptureError.permissionDenied
        }

        let overlayIDs = Set(windows.map { CGWindowID($0.windowNumber) })
        guard !overlayIDs.isEmpty else { throw ScreenshotCaptureError.captureFailed }

        let (content, excludedWindows) = try await resolveOverlayWindows(overlayIDs)

        var displays: [ScreenshotDisplayBackdrop] = []
        var capturedDisplayIDs = Set<CGDirectDisplayID>()
        for window in windows {
            try Task.checkCancellation()
            let displayID: CGDirectDisplayID
            let frame: CGRect
            if let overlay = window as? ScreenshotOverlayWindowMarker {
                displayID = overlay.trackedDisplayID
                frame = NSScreen.screens.first { $0.displayID == displayID }?.frame ?? window.frame
            } else if let screen = window.screen, let id = screen.displayID {
                displayID = id
                frame = screen.frame
            } else {
                continue
            }
            guard !capturedDisplayIDs.contains(displayID),
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

            let image = try await captureImageWithRetry(
                contentFilter: filter,
                configuration: configuration
            )
            guard image.width > 0, image.height > 0 else { continue }
            displays.append(
                ScreenshotDisplayBackdrop(displayID: displayID, frame: frame, image: image)
            )
            capturedDisplayIDs.insert(displayID)
        }

        guard !displays.isEmpty else { throw ScreenshotCaptureError.captureFailed }
        return ScreenshotDesktopSnapshot(displays: displays)
    }

    static func captureDesktopWithTimeout(below windows: [NSWindow]) async throws -> ScreenshotDesktopSnapshot {
        try await withThrowingTaskGroup(of: ScreenshotDesktopSnapshot.self) { group in
            group.addTask {
                try await captureDesktop(below: windows)
            }
            group.addTask {
                try await Task.sleep(for: captureTimeout)
                throw ScreenshotCaptureError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private static func resolveOverlayWindows(
        _ overlayIDs: Set<CGWindowID>
    ) async throws -> (SCShareableContent, [SCWindow]) {
        let deadline = ContinuousClock.now + overlayResolveTimeout
        var lastError: Error?

        while true {
            try Task.checkCancellation()
            do {
                // `onScreenWindowsOnly: false` still returns on-screen windows and
                // is more reliable for panels that just became key/frontmost.
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: false
                )
                let excludedWindows = content.windows.filter { overlayIDs.contains($0.windowID) }
                if excludedWindows.count == overlayIDs.count {
                    return (content, excludedWindows)
                }
            } catch {
                lastError = error
            }

            if ContinuousClock.now >= deadline { break }
            try await Task.sleep(for: overlayResolvePoll)
        }

        if let lastError { throw lastError }
        throw ScreenshotCaptureError.captureFailed
    }

    private static func captureImageWithRetry(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        var lastError: Error = ScreenshotCaptureError.captureFailed
        for attempt in 1...imageCaptureAttempts {
            try Task.checkCancellation()
            do {
                return try await SCScreenshotManager.captureImage(
                    contentFilter: contentFilter,
                    configuration: configuration
                )
            } catch {
                lastError = error
                if attempt == imageCaptureAttempts { break }
                try await Task.sleep(for: .milliseconds(40 * attempt))
            }
        }
        throw lastError
    }

    static func crop(
        _ selection: ScreenshotSelection,
        from snapshot: ScreenshotDesktopSnapshot
    ) throws -> ScreenshotCaptureResult {
        guard let display = snapshot.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw ScreenshotCaptureError.captureFailed
        }
        let selectedRect = selection.rect.standardized.intersection(display.frame.standardized)
        guard let pixelRect = ScreenshotGeometry.pixelRect(
            selection: selectedRect,
            displayFrame: display.frame,
            imageWidth: display.image.width,
            imageHeight: display.image.height
        ), let image = display.image.cropping(to: pixelRect)
        else {
            throw ScreenshotCaptureError.emptySelection
        }
        return ScreenshotCaptureResult(
            image: image,
            selectionRect: selectedRect,
            displayID: selection.displayID
        )
    }

    static func copyToPasteboard(_ image: CGImage) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw ScreenshotCaptureError.encodeFailed
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setData(png, forType: .png) else {
            throw ScreenshotCaptureError.pasteboardFailed
        }
        if let tiff = representation.representation(using: .tiff, properties: [:]) {
            _ = pasteboard.setData(tiff, forType: .tiff)
        }
    }
}

enum ScreenshotPermission {
    static func hasScreenCaptureAccess(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            return CGRequestScreenCaptureAccess()
        }
        return CGPreflightScreenCaptureAccess()
    }

    @MainActor
    static func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
