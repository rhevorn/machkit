import AppKit

@MainActor
final class ScreenshotController: ObservableObject {
    static let shared = ScreenshotController()

    @Published private(set) var isBusy = false

    private var captureTask: Task<Void, Never>?
    private var desktopSnapshot: ScreenshotDesktopSnapshot?
    private var selectionSession: ScreenshotSelectionSession?
    private var editorController: ScreenshotEditorController?
    private var previousApplication: NSRunningApplication?

    private init() {}

    func handleHotKey(_ targetID: String) {
        guard targetID == ScreenshotAction.capture.rawValue else { return }
        start()
    }

    func start() {
        guard !isBusy else { return }
        isBusy = true

        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != currentPID {
            previousApplication = frontmost
        }

        // Show the dim overlay first. Any capture flicker stays hidden underneath.
        let session = ScreenshotSelectionSession(
            onSelect: { [weak self] selection in self?.capture(selection) },
            onCancel: { [weak self] in self?.cancelSelection() }
        )
        selectionSession = session
        session.present()
        session.setInteractionEnabled(false)

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await ScreenshotCapture.captureDesktop(below: session.overlayWindows)
                try Task.checkCancellation()
                desktopSnapshot = snapshot
                session.applySnapshot(snapshot)
                session.setInteractionEnabled(true)
                captureTask = nil
            } catch is CancellationError {
                finish()
            } catch {
                selectionSession?.dismiss()
                selectionSession = nil
                presentError(error)
                finish()
            }
        }
    }

    private func capture(_ selection: ScreenshotSelection) {
        selectionSession?.prepareForCapture()

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let desktopSnapshot else { throw ScreenshotCaptureError.captureFailed }
                let result = try ScreenshotCapture.crop(selection, from: desktopSnapshot)
                try Task.checkCancellation()
                captureTask = nil
                presentEditor(
                    result.image,
                    selectionRect: result.selectionRect,
                    backdrop: desktopSnapshot
                )
                self.desktopSnapshot = nil
                // Editor now owns an opaque frozen backdrop, so the selector can
                // go away without revealing the live desktop for a frame.
                selectionSession?.dismiss()
                selectionSession = nil
            } catch is CancellationError {
                finish()
            } catch {
                selectionSession?.dismiss()
                selectionSession = nil
                presentError(error)
                finish()
            }
        }
    }

    private func cancelSelection() {
        selectionSession?.dismiss()
        selectionSession = nil
        captureTask?.cancel()
        finish()
    }

    private func presentEditor(
        _ image: CGImage,
        selectionRect: CGRect,
        backdrop: ScreenshotDesktopSnapshot
    ) {
        let editor = ScreenshotEditorController(
            image: image,
            selectionRect: selectionRect,
            backdrop: backdrop,
            onFinish: { [weak self] in
                guard let self else { return }
                editorController = nil
                finish()
            }
        )
        editorController = editor
        editor.present()
    }

    private func finish() {
        selectionSession?.dismiss()
        selectionSession = nil
        desktopSnapshot = nil
        captureTask = nil
        isBusy = false
        if let previousApplication {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == currentPID {
                previousApplication.activate()
            }
            self.previousApplication = nil
        }
        MachKitAppLifecycle.moveToBackgroundIfNeeded()
    }

    private func presentError(_ error: Error) {
        MachKitAppLifecycle.showInForeground()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
}
