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
    static let captureTimeout: Duration = .seconds(8)

    /// Captures what is currently behind the selector windows. Call this only
    /// after the overlays are on-screen so any capture-side flicker stays hidden.
    static func captureDesktop(below windows: [NSWindow]) async throws -> ScreenshotDesktopSnapshot {
        try Task.checkCancellation()
        guard ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: false) else {
            throw ScreenshotCaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let overlayIDs = Set(windows.map { CGWindowID($0.windowNumber) })
        let excludedWindows = content.windows.filter { overlayIDs.contains($0.windowID) }
        guard excludedWindows.count == overlayIDs.count else {
            throw ScreenshotCaptureError.captureFailed
        }

        var displays: [ScreenshotDisplayBackdrop] = []
        var capturedDisplayIDs = Set<CGDirectDisplayID>()
        for window in windows {
            try Task.checkCancellation()
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

    static func crop(
        _ selection: ScreenshotSelection,
        from snapshot: ScreenshotDesktopSnapshot
    ) throws -> ScreenshotCaptureResult {
        guard let display = snapshot.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw ScreenshotCaptureError.captureFailed
        }
        let selectedRect = selection.rect.intersection(display.frame).integral
        guard let pixelRect = ScreenshotGeometry.pixelRect(
            selection: selectedRect,
            displayFrame: display.frame,
            imageWidth: display.image.width,
            imageHeight: display.image.height
        ), let image = display.image.cropping(to: pixelRect)
        else {
            throw ScreenshotCaptureError.emptySelection
        }
        return ScreenshotCaptureResult(image: image, selectionRect: selectedRect)
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
