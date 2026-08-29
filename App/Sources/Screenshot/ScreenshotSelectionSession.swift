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
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.frame.contains(pointer) } ?? windows.first
        keyWindow?.makeKeyAndOrderFront(nil)
    }

    func applySnapshot(_ snapshot: ScreenshotDesktopSnapshot) {
        for window in windows {
            guard let image = snapshot.image(for: window.trackedDisplayID) else { continue }
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

        let probe = dragCurrent ?? cursorPoint
        if let probe {
            drawCrosshair(at: probe)
            drawLoupe(at: probe)
        }

        if selection == nil {
            drawInstruction()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = clipped(convert(event.locationInWindow, from: nil))
        completedSelectionRect = nil
        dragStart = point
        dragCurrent = point
        cursorPoint = point
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
            dragStart = nil
            dragCurrent = nil
            cursorPoint = end
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

    private func updateCursor(from event: NSEvent) {
        let point = clipped(convert(event.locationInWindow, from: nil))
        cursorPoint = point
        needsDisplay = true
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

    private func drawCrosshair(at point: CGPoint) {
        // Compact reticle near the pointer — not full-screen guide lines.
        let arm: CGFloat = 9
        let gap: CGFloat = 2.5
        let x = point.x
        let y = point.y

        func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
            color.setStroke()
            path.lineWidth = width
            path.lineCapStyle = .square
            path.stroke()
        }

        let path = NSBezierPath()
        path.move(to: CGPoint(x: x - arm, y: y))
        path.line(to: CGPoint(x: x - gap, y: y))
        path.move(to: CGPoint(x: x + gap, y: y))
        path.line(to: CGPoint(x: x + arm, y: y))
        path.move(to: CGPoint(x: x, y: y - arm))
        path.line(to: CGPoint(x: x, y: y - gap))
        path.move(to: CGPoint(x: x, y: y + gap))
        path.line(to: CGPoint(x: x, y: y + arm))

        stroke(path, color: NSColor.black.withAlphaComponent(0.55), width: 2.5)
        stroke(path, color: NSColor.white.withAlphaComponent(0.95), width: 1)
    }

    private func drawLoupe(at point: CGPoint) {
        guard let frozenCGImage,
              let pixel = ScreenshotGeometry.pixelPoint(
                at: point,
                viewSize: bounds.size,
                imageWidth: frozenCGImage.width,
                imageHeight: frozenCGImage.height
              ),
              let source = ScreenshotGeometry.loupeSourceRect(
                pixelX: pixel.x,
                pixelY: pixel.y,
                imageWidth: frozenCGImage.width,
                imageHeight: frozenCGImage.height
              ),
              let cropped = frozenCGImage.cropping(to: source)
        else { return }

        let loupe = ScreenshotGeometry.loupeFrame(cursor: point, viewBounds: bounds)
        let color = ScreenshotPixelSampling.color(in: frozenCGImage, atX: pixel.x, atY: pixel.y)

        NSGraphicsContext.saveGraphicsState()
        let circle = NSBezierPath(ovalIn: loupe)
        circle.addClip()

        let loupeImage = NSImage(cgImage: cropped, size: loupe.size)
        loupeImage.draw(
            in: loupe,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.none.rawValue)]
        )

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let ring = NSBezierPath(ovalIn: loupe.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 2
        ring.stroke()

        let cross = NSBezierPath()
        let inset: CGFloat = 18
        cross.move(to: CGPoint(x: loupe.midX, y: loupe.minY + inset))
        cross.line(to: CGPoint(x: loupe.midX, y: loupe.maxY - inset))
        cross.move(to: CGPoint(x: loupe.minX + inset, y: loupe.midY))
        cross.line(to: CGPoint(x: loupe.maxX - inset, y: loupe.midY))
        NSColor.black.withAlphaComponent(0.35).setStroke()
        cross.lineWidth = 2
        cross.stroke()
        NSColor.white.withAlphaComponent(0.7).setStroke()
        cross.lineWidth = 1
        cross.stroke()
        NSGraphicsContext.restoreGraphicsState()

        if let color {
            drawColorBadge(color, under: loupe)
        }
    }

    private func drawColorBadge(_ color: ScreenshotPixelColor, under loupe: CGRect) {
        let hex = color.hexString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (hex as NSString).size(withAttributes: attributes)
        let swatch: CGFloat = 12
        let padding: CGFloat = 8
        let width = padding + swatch + 6 + textSize.width + padding
        let height: CGFloat = 24
        var frame = CGRect(
            x: loupe.midX - width / 2,
            y: loupe.minY - height - 8,
            width: width,
            height: height
        )
        if frame.minY < bounds.minY + 4 {
            frame.origin.y = loupe.maxY + 8
        }
        if frame.minX < bounds.minX + 4 {
            frame.origin.x = bounds.minX + 4
        }
        if frame.maxX > bounds.maxX - 4 {
            frame.origin.x = bounds.maxX - 4 - width
        }

        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7).fill()

        let swatchRect = CGRect(
            x: frame.minX + padding,
            y: frame.midY - swatch / 2,
            width: swatch,
            height: swatch
        )
        NSColor(srgbRed: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255, alpha: 1).setFill()
        NSBezierPath(roundedRect: swatchRect, xRadius: 3, yRadius: 3).fill()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        let swatchBorder = NSBezierPath(roundedRect: swatchRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
        swatchBorder.lineWidth = 1
        swatchBorder.stroke()

        (hex as NSString).draw(
            at: CGPoint(x: swatchRect.maxX + 6, y: frame.minY + (height - textSize.height) / 2),
            withAttributes: attributes
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
