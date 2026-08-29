import AppKit
import MachKitCore

/// Calm, precise chrome for the region-selection overlay.
/// Drawn with AppKit so the full-screen mask stays cheap to refresh.
enum ScreenshotSelectionChrome {
    static let dimFill = NSColor.black.withAlphaComponent(0.30)
    static let hairlineOuter = NSColor.black.withAlphaComponent(0.28)
    static let hairlineInner = NSColor.white.withAlphaComponent(0.92)
    static let hudFill = NSColor.black.withAlphaComponent(0.55)
    static let hudStroke = NSColor.white.withAlphaComponent(0.16)
    static let hudRadius: CGFloat = 10
    static let cornerMark: CGFloat = 7
    static let loupeDiameter: CGFloat = 96
    static let loupeGap: CGFloat = 8

    static func fillDim(in bounds: CGRect, punching selection: CGRect?) {
        dimFill.setFill()
        guard let selection, selection.width >= 1, selection.height >= 1 else {
            bounds.fill()
            return
        }
        let mask = NSBezierPath(rect: bounds)
        mask.append(NSBezierPath(rect: selection))
        mask.windingRule = .evenOdd
        mask.fill()
    }

    static func strokeSelection(_ rect: CGRect) {
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        let outer = NSBezierPath(rect: inset.insetBy(dx: -0.5, dy: -0.5))
        hairlineOuter.setStroke()
        outer.lineWidth = 1
        outer.stroke()

        let inner = NSBezierPath(rect: inset)
        hairlineInner.setStroke()
        inner.lineWidth = 1
        inner.stroke()

        drawCornerMarks(in: inset)
    }

    static func drawCornerMarks(in rect: CGRect) {
        let length = min(cornerMark, min(rect.width, rect.height) / 2)
        guard length >= 3 else { return }

        let path = NSBezierPath()
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.line(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // Top-left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        NSColor.black.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .square
        path.lineJoinStyle = .miter
        path.stroke()

        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func drawReticle(at point: CGPoint) {
        let arm: CGFloat = 7
        let gap: CGFloat = 2
        let path = NSBezierPath()
        path.move(to: CGPoint(x: point.x - arm, y: point.y))
        path.line(to: CGPoint(x: point.x - gap, y: point.y))
        path.move(to: CGPoint(x: point.x + gap, y: point.y))
        path.line(to: CGPoint(x: point.x + arm, y: point.y))
        path.move(to: CGPoint(x: point.x, y: point.y - arm))
        path.line(to: CGPoint(x: point.x, y: point.y - gap))
        path.move(to: CGPoint(x: point.x, y: point.y + gap))
        path.line(to: CGPoint(x: point.x, y: point.y + arm))

        NSColor.black.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 2
        path.lineCapStyle = .square
        path.stroke()
        NSColor.white.withAlphaComponent(0.88).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func drawLoupe(
        at point: CGPoint,
        in bounds: CGRect,
        image: CGImage
    ) {
        guard let pixel = ScreenshotGeometry.pixelPoint(
            at: point,
            viewSize: bounds.size,
            imageWidth: image.width,
            imageHeight: image.height
        ),
        let source = ScreenshotGeometry.loupeSourceRect(
            pixelX: pixel.x,
            pixelY: pixel.y,
            imageWidth: image.width,
            imageHeight: image.height
        ),
        let cropped = image.cropping(to: source)
        else { return }

        let loupe = ScreenshotGeometry.loupeFrame(
            cursor: point,
            viewBounds: bounds,
            diameter: loupeDiameter,
            gap: loupeGap
        )
        let color = ScreenshotPixelSampling.color(in: image, atX: pixel.x, atY: pixel.y)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: loupe).addClip()

        let loupeImage = NSImage(cgImage: cropped, size: loupe.size)
        loupeImage.draw(
            in: loupe,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.none.rawValue)]
        )

        NSColor.black.withAlphaComponent(0.22).setStroke()
        let outerRing = NSBezierPath(ovalIn: loupe.insetBy(dx: 0.5, dy: 0.5))
        outerRing.lineWidth = 2
        outerRing.stroke()
        NSColor.white.withAlphaComponent(0.78).setStroke()
        let ring = NSBezierPath(ovalIn: loupe.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 1
        ring.stroke()

        let inset: CGFloat = 18
        let cross = NSBezierPath()
        cross.move(to: CGPoint(x: loupe.midX, y: loupe.minY + inset))
        cross.line(to: CGPoint(x: loupe.midX, y: loupe.maxY - inset))
        cross.move(to: CGPoint(x: loupe.minX + inset, y: loupe.midY))
        cross.line(to: CGPoint(x: loupe.maxX - inset, y: loupe.midY))
        NSColor.black.withAlphaComponent(0.22).setStroke()
        cross.lineWidth = 1.5
        cross.stroke()
        NSColor.white.withAlphaComponent(0.45).setStroke()
        cross.lineWidth = 0.75
        cross.stroke()
        NSGraphicsContext.restoreGraphicsState()

        if let color {
            drawColorHUD(color, under: loupe, in: bounds)
        }
    }

    static func drawInstruction(_ text: String, in bounds: CGRect) {
        drawHUD(
            text,
            font: NSFont.systemFont(ofSize: 12, weight: .medium),
            at: CGPoint(x: bounds.midX, y: bounds.maxY - 36),
            in: bounds,
            monospaced: false
        )
    }

    static func drawSizeLabel(for rect: CGRect, in bounds: CGRect) {
        let label = "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))"
        var center = CGPoint(x: rect.midX, y: rect.minY - 12)
        if center.y < bounds.minY + 16 {
            center.y = rect.maxY + 12
        }
        drawHUD(
            label,
            font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            at: center,
            in: bounds,
            monospaced: true
        )
    }

    private static func drawColorHUD(_ color: ScreenshotPixelColor, under loupe: CGRect, in bounds: CGRect) {
        let hex = color.hexString
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        let textSize = (hex as NSString).size(withAttributes: attributes)
        let swatch: CGFloat = 10
        let paddingX: CGFloat = 9
        let height: CGFloat = 24
        let width = paddingX + swatch + 6 + textSize.width + paddingX
        var frame = CGRect(
            x: loupe.midX - width / 2,
            y: loupe.minY - height - 5,
            width: width,
            height: height
        )
        frame = clampHUD(frame, in: bounds)
        if frame.maxY > loupe.minY - 4, frame.minY < loupe.maxY {
            frame.origin.y = loupe.maxY + 5
            frame = clampHUD(frame, in: bounds)
        }

        fillHUD(frame)

        let swatchRect = CGRect(
            x: frame.minX + paddingX,
            y: frame.midY - swatch / 2,
            width: swatch,
            height: swatch
        )
        NSColor(
            srgbRed: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        ).setFill()
        NSBezierPath(roundedRect: swatchRect, xRadius: 2.5, yRadius: 2.5).fill()
        NSColor.white.withAlphaComponent(0.28).setStroke()
        let swatchBorder = NSBezierPath(roundedRect: swatchRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
        swatchBorder.lineWidth = 1
        swatchBorder.stroke()

        (hex as NSString).draw(
            at: CGPoint(x: swatchRect.maxX + 6, y: frame.minY + (height - textSize.height) / 2),
            withAttributes: attributes
        )
    }

    private static func drawHUD(
        _ text: String,
        font: NSFont,
        at center: CGPoint,
        in bounds: CGRect,
        monospaced: Bool
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let paddingX: CGFloat = monospaced ? 10 : 12
        var frame = CGRect(
            x: center.x - size.width / 2 - paddingX,
            y: center.y - 12,
            width: size.width + paddingX * 2,
            height: 24
        )
        frame = clampHUD(frame, in: bounds)
        fillHUD(frame)
        (text as NSString).draw(
            at: CGPoint(x: frame.minX + paddingX, y: frame.minY + (24 - size.height) / 2),
            withAttributes: attributes
        )
    }

    private static func fillHUD(_ frame: CGRect) {
        hudFill.setFill()
        NSBezierPath(roundedRect: frame, xRadius: hudRadius, yRadius: hudRadius).fill()
        hudStroke.setStroke()
        let border = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: hudRadius - 0.5, yRadius: hudRadius - 0.5)
        border.lineWidth = 1
        border.stroke()
    }

    private static func clampHUD(_ frame: CGRect, in bounds: CGRect) -> CGRect {
        var next = frame
        if next.minX < bounds.minX + 8 {
            next.origin.x = bounds.minX + 8
        }
        if next.maxX > bounds.maxX - 8 {
            next.origin.x = bounds.maxX - 8 - next.width
        }
        if next.minY < bounds.minY + 8 {
            next.origin.y = bounds.minY + 8
        }
        if next.maxY > bounds.maxY - 8 {
            next.origin.y = bounds.maxY - 8 - next.height
        }
        return next
    }
}
