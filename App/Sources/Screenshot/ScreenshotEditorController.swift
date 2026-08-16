import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ScreenshotEditorController: NSWindowController, NSWindowDelegate {
    private let model: ScreenshotEditorModel
    private var onFinish: (() -> Void)?
    private var isClosing = false
    private var hostingController: NSHostingController<ScreenshotAnnotatorView>?

    init(
        image: CGImage,
        selectionRect: CGRect,
        backdrop: ScreenshotDesktopSnapshot,
        onFinish: @escaping () -> Void
    ) {
        // Annotation sizes are expressed in screen points. Keeping the NSImage at
        // the selected region's logical size prevents Retina captures from halving
        // brush cursors and text while the backing CGImage remains full resolution.
        self.model = ScreenshotEditorModel(
            image: NSImage(cgImage: image, size: selectionRect.size)
        )
        self.onFinish = onFinish

        let screens = NSScreen.screens
        let desktopFrame = screens.reduce(CGRect.null) { $0.union($1.frame) }
        let localCanvasRect = CGRect(
            x: selectionRect.minX - desktopFrame.minX,
            y: desktopFrame.maxY - selectionRect.maxY,
            width: selectionRect.width,
            height: selectionRect.height
        )
        let window = ScreenshotEditorWindow(
            contentRect: desktopFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.setFrame(desktopFrame, display: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        super.init(window: window)
        window.delegate = self

        let rootView = NSView(frame: CGRect(origin: .zero, size: desktopFrame.size))
        rootView.wantsLayer = true

        let backdropView = ScreenshotEditorBackdropView(
            desktopFrame: desktopFrame,
            displays: backdrop.displays
        )
        backdropView.frame = rootView.bounds
        backdropView.autoresizingMask = [.width, .height]
        rootView.addSubview(backdropView)

        let hostingController = NSHostingController(
            rootView: ScreenshotAnnotatorView(
                model: model,
                canvasRect: localCanvasRect,
                onConfirm: { [weak self] in self?.confirmAndCopy() },
                onCancel: { [weak self] in self?.closeSession() },
                onSave: { [weak self] in self?.save() }
            )
        )
        hostingController.view.frame = rootView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.addSubview(hostingController.view)
        self.hostingController = hostingController

        window.contentView = rootView
        window.setFrame(desktopFrame, display: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        window?.contentView?.layoutSubtreeIfNeeded()
        window?.displayIfNeeded()
        window?.orderFrontRegardless()
        window?.makeKey()
    }

    private func confirmAndCopy() {
        guard copyRenderedImage() else { return }
        NSSound(named: "Tink")?.play()
        closeSession()
    }

    private func copyRenderedImage() -> Bool {
        guard let image = model.exportImage() else {
            showEditorError(ScreenshotCaptureError.encodeFailed)
            return false
        }
        do {
            try ScreenshotCapture.copyToPasteboard(image)
            return true
        } catch {
            showEditorError(error)
            return false
        }
    }

    private func save() {
        guard let image = model.exportImage() else {
            showEditorError(ScreenshotCaptureError.encodeFailed)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "MachKit Screenshot.png".localized
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let representation = NSBitmapImageRep(cgImage: image)
        do {
            guard let data = representation.representation(using: .png, properties: [:]) else {
                throw ScreenshotCaptureError.encodeFailed
            }
            try data.write(to: url, options: .atomic)
        } catch {
            showEditorError(error)
        }
    }

    private func showEditorError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }

    private func closeSession() {
        guard !isClosing else { return }
        isClosing = true
        let finish = onFinish
        onFinish = nil
        window?.orderOut(nil)
        window?.close()
        finish?()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosing else { return }
        isClosing = true
        let finish = onFinish
        onFinish = nil
        finish?()
    }
}

private final class ScreenshotEditorWindow: NSPanel, ScreenshotOverlayWindowMarker {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// AppKit-backed freeze so the editor's first on-screen frame already covers the
/// desktop. SwiftUI alone can lag one frame and flash the live screen.
private final class ScreenshotEditorBackdropView: NSView {
    private let layers: [(frame: CGRect, image: NSImage)]

    init(desktopFrame: CGRect, displays: [ScreenshotDisplayBackdrop]) {
        self.layers = displays.map { display in
            let local = CGRect(
                x: display.frame.minX - desktopFrame.minX,
                y: display.frame.minY - desktopFrame.minY,
                width: display.frame.width,
                height: display.frame.height
            )
            let image = NSImage(
                cgImage: display.image,
                size: NSSize(width: display.image.width, height: display.image.height)
            )
            return (local, image)
        }
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        for layer in layers {
            layer.image.draw(
                in: layer.frame,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }
    }
}
