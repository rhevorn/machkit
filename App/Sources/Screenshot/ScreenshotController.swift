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

        if !ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: false) {
            let granted = ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: true)
            if !granted {
                presentPermissionError()
                return
            }
        }

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
                let snapshot = try await ScreenshotCapture.captureDesktopWithTimeout(
                    below: session.overlayWindows
                )
                try Task.checkCancellation()
                desktopSnapshot = snapshot
                session.applySnapshot(snapshot)
                session.setInteractionEnabled(true)
                captureTask = nil
            } catch is CancellationError {
                finish()
            } catch let error as ScreenshotCaptureError where error == .permissionDenied {
                selectionSession?.dismiss()
                selectionSession = nil
                presentPermissionError()
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
                // Release the full-desktop freeze as soon as the editor owns its backdrop.
                self.desktopSnapshot = nil
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

    private func presentPermissionError() {
        MachKitAppLifecycle.showInForeground()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = ScreenshotCaptureError.permissionDenied.localizedDescription
        alert.addButton(withTitle: "Open Screen Recording Settings".localized)
        alert.addButton(withTitle: "Cancel".localized)
        if alert.runModal() == .alertFirstButtonReturn {
            ScreenshotPermission.openScreenRecordingSettings()
        }
    }

    private func presentError(_ error: Error) {
        MachKitAppLifecycle.showInForeground()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = error.localizedDescription
        if let captureError = error as? ScreenshotCaptureError, captureError == .permissionDenied {
            alert.addButton(withTitle: "Open Screen Recording Settings".localized)
            alert.addButton(withTitle: "Cancel".localized)
            if alert.runModal() == .alertFirstButtonReturn {
                ScreenshotPermission.openScreenRecordingSettings()
            }
            return
        }
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
}
