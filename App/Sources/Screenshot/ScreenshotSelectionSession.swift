import AppKit
import MachKitCore

protocol ScreenshotOverlayWindowMarker: AnyObject {
    var trackedDisplayID: CGDirectDisplayID { get }
}

@MainActor
final class ScreenshotSelectionSession {
    private let onSelect: (ScreenshotSelection) -> Void
    private let onCancel: () -> Void
    private var windows: [ScreenshotSelectionWindow] = []
    private var isFinished = false
    private(set) var isInteractive = false
    private var keyMonitor: Any?

    init(
        onSelect: @escaping (ScreenshotSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    var overlayWindows: [NSWindow] { windows }

    func present() {
        guard windows.isEmpty, !isFinished else { return }
        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else { return nil }
            return ScreenshotSelectionWindow(
                screen: screen,
                displayID: displayID,
                onSelect: { [weak self] selection in self?.select(selection) },
                onCancel: { [weak self] in self?.cancel() }
            )
        }
        bringToFront()
        // Force the dim layer on-screen before any capture runs beneath it.
        for window in windows {
            window.displayIfNeeded()
        }
    }

    func bringToFront() {
        for window in windows {
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        // Deliberately stop short of becoming key. Taking key window status
        // resigns key from any open context menu (Finder, status bar, …) and
        // dismisses it before it can be captured. Keyboard focus is taken by
        // makeKeyForInteraction() once the frozen snapshot is on screen.
    }

    /// Gives keyboard focus to the overlay under the pointer so Esc and drag
    /// selection work. Call this only after the frozen snapshot is visible:
    /// becoming key lets any open context menu close, but its pixels are
    /// already preserved in the frozen image, so it appears to stay open.
    func makeKeyForInteraction() {
        // Hotkey-started captures often leave another app frontmost; activate so
        // local key monitors and panel keyDown actually receive C/Esc.
        NSApp.activate(ignoringOtherApps: true)
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.frame.contains(pointer) } ?? windows.first
        keyWindow?.makeKeyAndOrderFront(nil)
        keyWindow?.makeFirstResponder(keyWindow?.contentView)
    }

    func applySnapshot(_ snapshot: ScreenshotDesktopSnapshot) {
        for window in windows {
            guard let image = snapshot.image(for: window.trackedDisplayID) else { continue }
            window.setFrozenImage(image)
        }
    }

    func dismiss() {
        stopKeyMonitor()
        let existing = windows
        windows.removeAll()
        for window in existing {
            window.ignoresMouseEvents = true
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        ScreenshotCursorRestore.forceSystemArrow()
    }

    func prepareForCapture() {
        setInteractionEnabled(false)
    }

    func setInteractionEnabled(_ enabled: Bool) {
        isInteractive = enabled
        for window in windows {
            window.ignoresMouseEvents = !enabled
        }
        if enabled {
            startKeyMonitor()
        } else {
            stopKeyMonitor()
        }
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        // Local monitor keeps C/Esc reliable under IME and nonactivating panels.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isFinished, self.isInteractive else { return event }
            if event.keyCode == 53 {
                self.cancel()
                return nil
            }
            if Self.isCopyColorKey(event), self.copyColorUnderPointer() {
                return nil
            }
            return event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func copyColorUnderPointer() -> Bool {
        let pointer = NSEvent.mouseLocation
        let window = windows.first { $0.frame.contains(pointer) } ?? windows.first
        return window?.copySampledColor() == true
    }

    fileprivate static func isCopyColorKey(_ event: NSEvent) -> Bool {
        // ANSI: C == 8, Space == 49 (Space survives CJK IME more reliably than letters).
        if event.keyCode == 8 || event.keyCode == 49 { return true }
        let character = event.charactersIgnoringModifiers?.lowercased() ?? ""
        return character == "c" || character == " "
    }

    private func select(_ selection: ScreenshotSelection) {
        guard !isFinished else { return }
        isFinished = true
        stopKeyMonitor()
        // Defer so mouseUp finishes before the selection session tears down.
        DispatchQueue.main.async { [onSelect] in onSelect(selection) }
    }

    private func cancel() {
        guard !isFinished else { return }
        isFinished = true
        stopKeyMonitor()
        // Defer so key handling finishes before the selection session tears down.
        DispatchQueue.main.async { [onCancel] in onCancel() }
    }
}

private final class ScreenshotSelectionWindow: NSPanel, ScreenshotOverlayWindowMarker {
    let trackedDisplayID: CGDirectDisplayID
    private let selectionView: ScreenshotSelectionView

    init(
        screen: NSScreen,
        displayID: CGDirectDisplayID,
        onSelect: @escaping (ScreenshotSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.trackedDisplayID = displayID
        self.selectionView = ScreenshotSelectionView(
            displayID: displayID,
            onSelect: onSelect,
            onCancel: onCancel
        )
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setFrozenImage(_ image: CGImage) {
        selectionView.setFrozenImage(image)
    }

    @discardableResult
    func copySampledColor() -> Bool {
        selectionView.copySampledColor()
    }
}

enum ScreenshotCursorRestore {
    /// `NSCursor.hide()` nests; a mismatched count leaves the pointer invisible
    /// system-wide. Always unwind hide depth, then install the arrow.
    static func forceSystemArrow() {
        for _ in 0..<16 {
            NSCursor.unhide()
        }
        NSCursor.arrow.set()
    }
}

private final class ScreenshotSelectionView: NSView {
    private let displayID: CGDirectDisplayID
    private let onSelect: (ScreenshotSelection) -> Void
    private let onCancel: () -> Void
    private var frozenCGImage: CGImage?
    private var frozenNSImage: NSImage?
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var completedSelectionRect: CGRect?
    private var cursorPoint: CGPoint?
    /// Last hover chrome (reticle + loupe + hex HUD) invalidate region.
    private var samplingDirtyRect: CGRect?
    private var loupeTileCache = ScreenshotSelectionChrome.LoupeTileCache()
    /// Brief “Copied” label after C copies the hovered hex.
    private var colorCopyFeedbackUntil: Date?
    private var colorCopyFeedbackWorkItem: DispatchWorkItem?

    init(
        displayID: CGDirectDisplayID,
        onSelect: @escaping (ScreenshotSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.displayID = displayID
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { frozenNSImage != nil }

    func setFrozenImage(_ image: CGImage) {
        frozenCGImage = image
        frozenNSImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        loupeTileCache.reset()
        needsDisplay = true
        displayIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        frame = window?.contentView?.bounds ?? frame
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
        NSCursor.crosshair.set()
        updateTrackingAreas()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(from: event)
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(from: event)
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) {
        cursorPoint = nil
        invalidateSamplingChrome()
    }

    override func draw(_ dirtyRect: NSRect) {
        if let frozenNSImage {
            frozenNSImage.draw(
                in: bounds,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }

        let selection = selectionRect
        ScreenshotSelectionChrome.fillDim(in: bounds, punching: selection)
        if let selection, selection.width >= 1, selection.height >= 1 {
            ScreenshotSelectionChrome.strokeSelection(selection)
            ScreenshotSelectionChrome.drawSizeLabel(for: selection, in: bounds)
        }

        // Color sampling is hover-only: hide while dragging and after a region is committed
        // (mouseUp clears dragStart before the overlay dismisses, which would otherwise flash).
        if dragStart == nil, completedSelectionRect == nil, let probe = cursorPoint {
            ScreenshotSelectionChrome.drawReticle(at: probe)
            if let frozenCGImage {
                let showCopied = (colorCopyFeedbackUntil ?? .distantPast) > Date()
                ScreenshotSelectionChrome.drawLoupe(
                    at: probe,
                    in: bounds,
                    image: frozenCGImage,
                    cache: &loupeTileCache,
                    copiedLabel: showCopied ? "Copied".localized : nil,
                    actionHint: "Click to copy".localized
                )
            }
        }

        if selection == nil {
            ScreenshotSelectionChrome.drawInstruction(
                "Drag to capture · Esc to cancel".localized,
                in: bounds
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = clipped(convert(event.locationInWindow, from: nil))
        completedSelectionRect = nil
        dragStart = point
        dragCurrent = point
        cursorPoint = point
        // Drop hover chrome, then redraw for the nascent selection frame.
        invalidateSamplingChrome()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        let point = clipped(convert(event.locationInWindow, from: nil))
        dragCurrent = point
        cursorPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let end = clipped(convert(event.locationInWindow, from: nil))
        let rect = normalized(start, end).intersection(bounds)
        guard rect.width >= 3, rect.height >= 3 else {
            // Tiny press = color sample click, not a capture region.
            dragStart = nil
            dragCurrent = nil
            cursorPoint = end
            _ = copySampledColor(at: end)
            return
        }
        completedSelectionRect = rect
        dragStart = nil
        dragCurrent = nil
        cursorPoint = nil
        // Skip needsDisplay — overlay dismisses immediately via onSelect.
        let origin = window?.convertPoint(toScreen: rect.origin) ?? rect.origin
        onSelect(ScreenshotSelection(rect: CGRect(origin: origin, size: rect.size), displayID: displayID))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        // Prefer keyCode so C still works under CJK input methods that
        // leave charactersIgnoringModifiers empty until composition ends.
        if ScreenshotSelectionSession.isCopyColorKey(event),
           dragStart == nil,
           completedSelectionRect == nil,
           copySampledColor() {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if ScreenshotSelectionSession.isCopyColorKey(event),
           dragStart == nil,
           completedSelectionRect == nil,
           copySampledColor() {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) { onCancel() }

    @discardableResult
    func copySampledColor(at explicitPoint: CGPoint? = nil) -> Bool {
        guard let probe = explicitPoint ?? samplingProbePoint(),
              let frozenCGImage,
              let pixel = ScreenshotGeometry.pixelPoint(
                at: probe,
                viewSize: bounds.size,
                imageWidth: frozenCGImage.width,
                imageHeight: frozenCGImage.height
              ),
              let color = ScreenshotPixelSampling.color(
                in: frozenCGImage,
                atX: pixel.x,
                atY: pixel.y
              )
        else { return false }
        cursorPoint = probe
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(color.hexString, forType: .string)
        showColorCopyFeedback()
        return true
    }

    /// Prefer the last hover point; fall back to the live mouse position.
    private func samplingProbePoint() -> CGPoint? {
        if let cursorPoint { return cursorPoint }
        guard let window else { return nil }
        let screenPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let point = clipped(convert(windowPoint, from: nil))
        return bounds.contains(point) ? point : nil
    }

    private func showColorCopyFeedback() {
        colorCopyFeedbackWorkItem?.cancel()
        colorCopyFeedbackUntil = Date().addingTimeInterval(0.9)
        invalidateSamplingChrome(around: cursorPoint)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.colorCopyFeedbackUntil = nil
            self.invalidateSamplingChrome(around: self.cursorPoint)
        }
        colorCopyFeedbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private var selectionRect: CGRect? {
        if let completedSelectionRect { return completedSelectionRect }
        guard let dragStart, let dragCurrent else { return nil }
        return normalized(dragStart, dragCurrent).intersection(bounds)
    }

    private func updateCursor(from event: NSEvent) {
        let point = clipped(convert(event.locationInWindow, from: nil))
        if cursorPoint == point { return }
        cursorPoint = point
        // While dragging, mouseDragged owns full-view redraws for the selection mask.
        guard dragStart == nil, completedSelectionRect == nil else { return }
        invalidateSamplingChrome(around: point)
    }

    /// Marks only reticle + loupe + hex HUD for redraw instead of the full screen.
    private func invalidateSamplingChrome(around point: CGPoint? = nil) {
        let previous = samplingDirtyRect
        let next = point.map { Self.samplingChromeRect(around: $0, in: bounds) }
        samplingDirtyRect = next
        switch (previous, next) {
        case let (old?, new?):
            setNeedsDisplay(old.union(new))
        case let (old?, nil):
            setNeedsDisplay(old)
        case let (nil, new?):
            setNeedsDisplay(new)
        case (nil, nil):
            break
        }
    }

    private static func samplingChromeRect(around point: CGPoint, in bounds: CGRect) -> CGRect {
        let reticlePad: CGFloat = 12
        let reticle = CGRect(
            x: point.x - reticlePad,
            y: point.y - reticlePad,
            width: reticlePad * 2,
            height: reticlePad * 2
        )
        let loupe = ScreenshotGeometry.loupeFrame(
            cursor: point,
            viewBounds: bounds,
            diameter: ScreenshotSelectionChrome.loupeDiameter,
            gap: ScreenshotSelectionChrome.loupeGap
        )
        // Hex HUD sits under/above loupe and may include a "Click to copy" action.
        let loupePad = loupe.insetBy(dx: -80, dy: -44)
        return reticle.union(loupePad).intersection(bounds)
    }

    private func normalized(_ first: CGPoint, _ second: CGPoint) -> CGRect {
        CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(first.x - second.x),
            height: abs(first.y - second.y)
        )
    }

    private func clipped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(bounds.minX, point.x), bounds.maxX),
            y: min(max(bounds.minY, point.y), bounds.maxY)
        )
    }
}
