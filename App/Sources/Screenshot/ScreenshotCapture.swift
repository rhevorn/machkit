import AppKit
import ImageIO

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

private struct ScreenshotDisplaySnapshot {
    let frame: CGRect
    let image: CGImage
}

struct ScreenshotDesktopSnapshot {
    fileprivate let displays: [CGDirectDisplayID: ScreenshotDisplaySnapshot]
}

@MainActor
enum ScreenshotCapture {
    /// Freezes all displays before MachKit presents its selector. Cropping the
    /// selected region later is synchronous and cannot flash the desktop.
    static func captureDesktop() async throws -> ScreenshotDesktopSnapshot {
        let displayIDs = activeDisplayIDs()
        guard !displayIDs.isEmpty else { throw ScreenshotCaptureError.captureFailed }

        var displays: [CGDirectDisplayID: ScreenshotDisplaySnapshot] = [:]
        for displayID in displayIDs {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
                continue
            }
            let destination = temporaryDestination()
            let displayBounds = CGDisplayBounds(displayID).integral
            let rectangle = [
                displayBounds.minX,
                displayBounds.minY,
                displayBounds.width,
                displayBounds.height,
            ]
                .map { String(Int($0.rounded())) }
                .joined(separator: ",")
            do {
                try await runSystemCapture(
                    arguments: ["-x", "-R\(rectangle)", "-tpng", destination.path],
                    destination: destination
                )
                defer { try? FileManager.default.removeItem(at: destination) }
                let image = try loadImage(at: destination)
                displays[displayID] = ScreenshotDisplaySnapshot(frame: screen.frame, image: image)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
        guard !displays.isEmpty else { throw ScreenshotCaptureError.captureFailed }
        return ScreenshotDesktopSnapshot(displays: displays)
    }

    static func crop(
        _ selection: ScreenshotSelection,
        from snapshot: ScreenshotDesktopSnapshot
    ) throws -> ScreenshotCaptureResult {
        guard let display = snapshot.displays[selection.displayID] else {
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

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return Array(displays.prefix(Int(count)))
    }

    private static func temporaryDestination() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("machkit-screen-\(UUID().uuidString)")
            .appendingPathExtension("png")
    }

    private static func loadImage(at destination: URL) throws -> CGImage {
        guard let data = try? Data(contentsOf: destination), !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0
        else {
            throw ScreenshotCaptureError.captureFailed
        }
        return image
    }

    private static func runSystemCapture(
        arguments: [String],
        destination: URL
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finishedProcess in
                guard finishedProcess.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: destination.path)
                else {
                    try? FileManager.default.removeItem(at: destination)
                    continuation.resume(throwing: ScreenshotCaptureError.captureFailed)
                    return
                }
                continuation.resume()
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                try? FileManager.default.removeItem(at: destination)
                continuation.resume(throwing: ScreenshotCaptureError.captureFailed)
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
