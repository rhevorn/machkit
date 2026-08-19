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
    private var activeSessionID: UUID?

    private init() {}

    func handleHotKey(_ targetID: String) {
        guard targetID == ScreenshotAction.capture.rawValue else { return }
        start()
    }

    func start() {
        guard !isBusy else {
            restoreActiveSession()
            return
        }

        if !ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: false) {
            let granted = ScreenshotPermission.hasScreenCaptureAccess(promptIfNeeded: true)
            if !granted {
                presentPermissionError()
                return
            }
        }

        isBusy = true
        let sessionID = UUID()
        activeSessionID = sessionID

        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != currentPID {
            previousApplication = frontmost
        }

        // Show the dim overlay first. Any capture flicker stays hidden underneath.
        let session = ScreenshotSelectionSession(
            onSelect: { [weak self] selection in
                self?.capture(selection, sessionID: sessionID)
            },
            onCancel: { [weak self] in
                self?.cancelSelection(sessionID: sessionID)
            }
        )
        selectionSession = session
        session.present()
        session.setInteractionEnabled(false)

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Let WindowServer finish publishing the new overlay window IDs
                // before the first ScreenCaptureKit shareable-content query.
                try await Task.sleep(for: .milliseconds(30))
                try Task.checkCancellation()
                let snapshot = try await ScreenshotCapture.captureDesktopWithTimeout(
                    below: session.overlayWindows
                )
                try Task.checkCancellation()
                guard activeSessionID == sessionID else { return }
                desktopSnapshot = snapshot
                session.applySnapshot(snapshot)
                // The frozen desktop is on screen now, so keyboard focus can
                // be taken safely: an open context menu closes at this point,
                // but its pixels are already preserved in the frozen image.
                session.makeKeyForInteraction()
                session.setInteractionEnabled(true)
                captureTask = nil
            } catch is CancellationError {
                finish(sessionID: sessionID)
            } catch let error as ScreenshotCaptureError where error == .permissionDenied {
                guard activeSessionID == sessionID else { return }
                selectionSession?.dismiss()
                selectionSession = nil
                presentPermissionError()
                finish(sessionID: sessionID)
            } catch {
                guard activeSessionID == sessionID else { return }
                selectionSession?.dismiss()
                selectionSession = nil
                presentError(error)
                finish(sessionID: sessionID)
            }
        }
    }

    private func capture(_ selection: ScreenshotSelection, sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        selectionSession?.prepareForCapture()

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard activeSessionID == sessionID else { return }
                guard let desktopSnapshot else { throw ScreenshotCaptureError.captureFailed }
                let result = try ScreenshotCapture.crop(selection, from: desktopSnapshot)
                guard let editorBackdrop = desktopSnapshot.retainingDisplay(result.displayID) else {
                    throw ScreenshotCaptureError.captureFailed
                }
                try Task.checkCancellation()
                guard activeSessionID == sessionID else { return }
                captureTask = nil
                presentEditor(
                    result.image,
                    selectionRect: result.selectionRect,
                    displayID: result.displayID,
                    backdrop: editorBackdrop,
                    sessionID: sessionID
                )
                // Release the full-desktop freeze as soon as the editor owns its backdrop.
                self.desktopSnapshot = nil
                selectionSession?.dismiss()
                selectionSession = nil
            } catch is CancellationError {
                finish(sessionID: sessionID)
            } catch {
                guard activeSessionID == sessionID else { return }
                selectionSession?.dismiss()
                selectionSession = nil
                presentError(error)
                finish(sessionID: sessionID)
            }
        }
    }

    private func cancelSelection(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        selectionSession?.dismiss()
        selectionSession = nil
        captureTask?.cancel()
        finish(sessionID: sessionID)
    }

    private func restoreActiveSession() {
        if let editorController {
            editorController.present()
        } else if let selectionSession {
            selectionSession.bringToFront()
            // Re-taking key is only safe once the frozen snapshot is up;
            // before that it would dismiss an open menu before it is captured.
            if selectionSession.isInteractive {
                selectionSession.makeKeyForInteraction()
            }
        }
    }

    private func presentEditor(
        _ image: CGImage,
        selectionRect: CGRect,
        displayID: CGDirectDisplayID,
        backdrop: ScreenshotDesktopSnapshot,
        sessionID: UUID
    ) {
        let editor = ScreenshotEditorController(
            image: image,
            selectionRect: selectionRect,
            displayID: displayID,
            backdrop: backdrop,
            onFinish: { [weak self] in
                guard let self else { return }
                guard activeSessionID == sessionID else { return }
                editorController = nil
                finish(sessionID: sessionID)
            }
        )
        editorController = editor
        editor.present()
    }

    private func finish(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
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
