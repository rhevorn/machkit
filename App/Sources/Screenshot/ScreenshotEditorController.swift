import AppKit
import MachKitCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ScreenshotEditorController: NSWindowController, NSWindowDelegate {
    private let model: ScreenshotEditorModel
    private var onFinish: (() -> Void)?
    private var isClosing = false
    private var hostingController: NSHostingController<ScreenshotAnnotatorView>?
    private var savePanel: NSSavePanel?
    private var errorAlert: NSAlert?

    init(
        image: CGImage,
        selectionRect: CGRect,
        displayID: CGDirectDisplayID,
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

        let selectedDisplay = backdrop.displays.first { $0.displayID == displayID }
            ?? backdrop.displays.first
        let displayFrame = selectedDisplay?.frame
            ?? NSScreen.screens.first { $0.displayID == displayID }?.frame
            ?? selectionRect
        let localCanvasRect = ScreenshotGeometry.editorCanvasRect(
            selection: selectionRect,
            displayFrame: displayFrame
        )
        let editorModel = model
        let localDisplayRect = CGRect(origin: .zero, size: displayFrame.size)
        let window = ScreenshotEditorWindow(
            contentRect: displayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.setFrame(displayFrame, display: false)
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

        let rootView = NSView(frame: localDisplayRect)
        rootView.wantsLayer = true

        let backdropView = ScreenshotEditorBackdropView(
            editorFrame: displayFrame,
            displays: selectedDisplay.map { [$0] } ?? []
        )
        backdropView.frame = rootView.bounds
        backdropView.autoresizingMask = [.width, .height]
        rootView.addSubview(backdropView)

        let hostingController = NSHostingController(
            rootView: ScreenshotAnnotatorView(
                model: model,
                canvasRect: localCanvasRect,
                toolbarBounds: localDisplayRect,
                onMoveCanvas: { localRect in
                    let screenRect = CGRect(
                        x: displayFrame.minX + localRect.minX,
                        y: displayFrame.maxY - localRect.maxY,
                        width: localRect.width,
                        height: localRect.height
                    )
                    let movedSelection = ScreenshotSelection(
                        rect: screenRect,
                        displayID: displayID
                    )
                    guard let result = try? ScreenshotCapture.crop(
                        movedSelection,
                        from: backdrop
                    ) else {
                        return false
                    }
                    editorModel.replaceBaseImage(result.image)
                    return true
                },
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
        window.setFrame(displayFrame, display: false)
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
        if let savePanel {
            savePanel.makeKeyAndOrderFront(nil)
            return
        }
        guard let editorWindow = window else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "MachKit Screenshot.png".localized
        savePanel = panel
        panel.beginSheetModal(for: editorWindow) { [weak self, weak panel] response in
            guard let self else { return }
            savePanel = nil
            guard response == .OK, let url = panel?.url else { return }
            do {
                guard let image = model.exportImage() else {
                    throw ScreenshotCaptureError.encodeFailed
                }
                let representation = NSBitmapImageRep(cgImage: image)
                guard let data = representation.representation(using: .png, properties: [:]) else {
                    throw ScreenshotCaptureError.encodeFailed
                }
                try data.write(to: url, options: .atomic)
            } catch {
                showEditorError(error)
            }
        }
    }

    private func showEditorError(_ error: Error) {
        guard errorAlert == nil, let editorWindow = window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK".localized)
        errorAlert = alert
        alert.beginSheetModal(for: editorWindow) { [weak self] _ in
            self?.errorAlert = nil
        }
    }

    private func closeSession() {
        guard !isClosing else { return }
        isClosing = true
        dismissPresentedSheets()
        let finish = onFinish
        onFinish = nil
        window?.orderOut(nil)
        window?.close()
        finish?()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosing else { return }
        isClosing = true
        dismissPresentedSheets()
        let finish = onFinish
        onFinish = nil
        finish?()
    }

    private func dismissPresentedSheets() {
        if let savePanel {
            window?.endSheet(savePanel, returnCode: .cancel)
            savePanel.orderOut(nil)
            self.savePanel = nil
        }
        if let errorAlert {
            window?.endSheet(errorAlert.window, returnCode: .cancel)
            errorAlert.window.orderOut(nil)
            self.errorAlert = nil
        }
    }
}

private final class ScreenshotEditorWindow: NSPanel, ScreenshotOverlayWindowMarker {
    let trackedDisplayID: CGDirectDisplayID = 0
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// AppKit-backed freeze so the editor's first on-screen frame already covers the
/// desktop. SwiftUI alone can lag one frame and flash the live screen.
private final class ScreenshotEditorBackdropView: NSView {
    private let layers: [(frame: CGRect, image: NSImage)]

    init(editorFrame: CGRect, displays: [ScreenshotDisplayBackdrop]) {
        self.layers = displays.map { display in
            let local = CGRect(
                x: display.frame.minX - editorFrame.minX,
                y: display.frame.minY - editorFrame.minY,
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
