import AppKit

protocol ScreenshotOverlayWindowMarker: AnyObject {}

@MainActor
final class ScreenshotSelectionSession {
    private let onSelect: (ScreenshotSelection) -> Void
    private let onCancel: () -> Void
    private var windows: [ScreenshotSelectionWindow] = []
    private var isFinished = false

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
        for window in windows {
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.frame.contains(pointer) } ?? windows.first
        keyWindow?.makeKeyAndOrderFront(nil)
        // Force the dim layer on-screen before any capture runs beneath it.
        for window in windows {
            window.displayIfNeeded()
        }
    }

    func applySnapshot(_ snapshot: ScreenshotDesktopSnapshot) {
        for window in windows {
            let displayID = window.screen?.displayID ?? window.trackedDisplayID
            guard let image = snapshot.image(for: displayID) else { continue }
            window.setFrozenImage(image)
        }
    }

    func dismiss() {
        let existing = windows
        windows.removeAll()
        for window in existing {
            window.ignoresMouseEvents = true
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        NSCursor.arrow.set()
    }

    func prepareForCapture() {
        setInteractionEnabled(false)
    }

    func setInteractionEnabled(_ enabled: Bool) {
        for window in windows {
            window.ignoresMouseEvents = !enabled
        }
    }

    private func select(_ selection: ScreenshotSelection) {
        guard !isFinished else { return }
        isFinished = true
        // Defer so mouseUp finishes before the selection session tears down.
        DispatchQueue.main.async { [onSelect] in onSelect(selection) }
    }

    private func cancel() {
        guard !isFinished else { return }
        isFinished = true
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
}

private final class ScreenshotSelectionView: NSView {
    private let displayID: CGDirectDisplayID
    private let onSelect: (ScreenshotSelection) -> Void
    private let onCancel: () -> Void
    private var frozenNSImage: NSImage?
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var completedSelectionRect: CGRect?

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
        frozenNSImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        needsDisplay = true
        displayIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        frame = window?.contentView?.bounds ?? frame
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
        needsDisplay = true
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
        NSColor.black.withAlphaComponent(0.42).setFill()
        if let selection, selection.width >= 1, selection.height >= 1 {
            let mask = NSBezierPath(rect: bounds)
            mask.append(NSBezierPath(rect: selection))
            mask.windingRule = .evenOdd
            mask.fill()
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
            drawSize(selection)
        } else {
            bounds.fill()
        }
        drawInstruction()
    }

    override func mouseDown(with event: NSEvent) {
        let point = clipped(convert(event.locationInWindow, from: nil))
        completedSelectionRect = nil
        dragStart = point
        dragCurrent = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragCurrent = clipped(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let end = clipped(convert(event.locationInWindow, from: nil))
        let rect = normalized(start, end).intersection(bounds)
        guard rect.width >= 3, rect.height >= 3 else {
            dragStart = nil
            dragCurrent = nil
            needsDisplay = true
            return
        }
        completedSelectionRect = rect
        dragStart = nil
        dragCurrent = nil
        needsDisplay = true
        let origin = window?.convertPoint(toScreen: rect.origin) ?? rect.origin
        onSelect(ScreenshotSelection(rect: CGRect(origin: origin, size: rect.size), displayID: displayID))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) { onCancel() }

    private var selectionRect: CGRect? {
        if let completedSelectionRect { return completedSelectionRect }
        guard let dragStart, let dragCurrent else { return nil }
        return normalized(dragStart, dragCurrent).intersection(bounds)
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

    private func drawInstruction() {
        drawPill("Drag to capture · Esc to cancel".localized, at: CGPoint(x: bounds.midX, y: bounds.maxY - 38))
    }

    private func drawSize(_ rect: CGRect) {
        var point = CGPoint(x: rect.midX, y: rect.minY - 20)
        if point.y < 18 { point.y = rect.maxY + 20 }
        drawPill("\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))", at: point)
    }

    private func drawPill(_ text: String, at center: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let frame = CGRect(x: center.x - size.width / 2 - 12, y: center.y - 14, width: size.width + 24, height: 28)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(at: CGPoint(x: frame.minX + 12, y: frame.minY + 7), withAttributes: attributes)
    }
}
