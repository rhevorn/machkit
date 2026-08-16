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
        for window in windows { window.orderFrontRegardless() }
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.frame.contains(pointer) } ?? windows.first
        keyWindow?.makeKeyAndOrderFront(nil)
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
        for window in windows {
            window.ignoresMouseEvents = true
        }
    }

    private func select(_ selection: ScreenshotSelection) {
        guard !isFinished else { return }
        isFinished = true
        DispatchQueue.main.async { [onSelect] in onSelect(selection) }
    }

    private func cancel() {
        guard !isFinished else { return }
        isFinished = true
        DispatchQueue.main.async { [onCancel] in onCancel() }
    }
}

private final class ScreenshotSelectionWindow: NSPanel, ScreenshotOverlayWindowMarker {
    init(
        screen: NSScreen,
        displayID: CGDirectDisplayID,
        onSelect: @escaping (ScreenshotSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: true)
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
        contentView = ScreenshotSelectionView(
            displayID: displayID,
            onSelect: onSelect,
            onCancel: onCancel
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ScreenshotSelectionView: NSView {
    private let displayID: CGDirectDisplayID
    private let onSelect: (ScreenshotSelection) -> Void
    private let onCancel: () -> Void
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        frame = window?.contentView?.bounds ?? frame
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    override func draw(_ dirtyRect: NSRect) {
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
