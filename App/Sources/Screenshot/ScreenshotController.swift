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

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await ScreenshotCapture.captureDesktop()
                try Task.checkCancellation()
                captureTask = nil
                desktopSnapshot = snapshot
                presentSelection()
            } catch is CancellationError {
                finish()
            } catch {
                presentError(error)
                finish()
            }
        }
    }

    private func presentSelection() {
        let session = ScreenshotSelectionSession(
            onSelect: { [weak self] selection in self?.capture(selection) },
            onCancel: { [weak self] in self?.cancelSelection() }
        )
        selectionSession = session
        session.present()
    }

    private func capture(_ selection: ScreenshotSelection) {
        selectionSession?.prepareForCapture()

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let desktopSnapshot else { throw ScreenshotCaptureError.captureFailed }
                let result = try ScreenshotCapture.crop(selection, from: desktopSnapshot)
                self.desktopSnapshot = nil
                try Task.checkCancellation()
                captureTask = nil
                presentEditor(result.image, selectionRect: result.selectionRect)
                // Keep the frozen selector behind the editor until SwiftUI has
                // rendered the editor's first frame. This prevents a one-frame
                // reveal of the original desktop during the window handoff.
                try await Task.sleep(for: .milliseconds(34))
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
        selectionRect: CGRect
    ) {
        let editor = ScreenshotEditorController(
            image: image,
            selectionRect: selectionRect,
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
