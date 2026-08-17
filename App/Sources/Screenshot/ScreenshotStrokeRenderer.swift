import AppKit
import MachKitCore
import SwiftUI

enum ScreenshotTextLayout {
    private static let drawingOptions: NSString.DrawingOptions = [
        .usesLineFragmentOrigin,
        .usesFontLeading,
    ]

    static func fontSize(lineWidth: CGFloat, scale: CGFloat = 1) -> CGFloat {
        ScreenshotGeometry.textFontSize(lineWidth: lineWidth, scale: scale)
    }

    static func font(lineWidth: CGFloat, scale: CGFloat = 1) -> NSFont {
        NSFont.systemFont(
            ofSize: fontSize(lineWidth: lineWidth, scale: scale),
            weight: .semibold
        )
    }

    static func bounds(
        for value: String,
        at origin: CGPoint = .zero,
        lineWidth: CGFloat,
        scale: CGFloat = 1
    ) -> CGRect {
        let attributed = attributedString(
            value,
            lineWidth: lineWidth,
            scale: scale,
            color: .labelColor
        )
        let measured = attributed.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: drawingOptions
        )
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: max(1, ceil(measured.width)),
            height: max(1, ceil(measured.height))
        )
    }

    static func lineHeight(lineWidth: CGFloat, scale: CGFloat = 1) -> CGFloat {
        ceil(font(lineWidth: lineWidth, scale: scale).boundingRectForFont.height)
    }

    static func draw(
        _ value: String,
        at origin: CGPoint,
        lineWidth: CGFloat,
        scale: CGFloat = 1,
        color: NSColor
    ) {
        let attributed = attributedString(
            value,
            lineWidth: lineWidth,
            scale: scale,
            color: color
        )
        attributed.draw(
            with: bounds(for: value, at: origin, lineWidth: lineWidth, scale: scale),
            options: drawingOptions
        )
    }

    private static func attributedString(
        _ value: String,
        lineWidth: CGFloat,
        scale: CGFloat,
        color: NSColor
    ) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .font: font(lineWidth: lineWidth, scale: scale),
                .foregroundColor: color,
            ]
        )
    }
}

/// Shared stroke drawing for canvas preview and PNG export.
/// Point space is top-left origin (Y down), matching the editor model and SwiftUI Canvas.
enum ScreenshotStrokeRenderer {
    static func drawAppKit(_ stroke: ScreenshotStroke, scale: CGFloat = 1) {
        let color = stroke.ink.nsColor
        let lineWidth = max(1, stroke.lineWidth * scale)
        let points = stroke.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }

        switch stroke.kind {
        case .pen, .highlight:
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.move(to: first)
            points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            (stroke.kind == .highlight ? color.withAlphaComponent(0.35) : color).setStroke()
            path.stroke()

        case .rectangle, .ellipse:
            guard points.count >= 2 else { return }
            let rect = CGRect(
                x: min(points[0].x, points[1].x),
                y: min(points[0].y, points[1].y),
                width: abs(points[0].x - points[1].x),
                height: abs(points[0].y - points[1].y)
            )
            color.setStroke()
            let path = stroke.kind == .ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
            path.lineWidth = lineWidth
            path.stroke()

        case .arrow:
            guard points.count >= 2,
                  let parts = ScreenshotGeometry.arrowHead(
                    from: points[0],
                    to: points[1],
                    lineWidth: stroke.lineWidth,
                    scale: scale
                  )
            else { return }
            color.setStroke()
            color.setFill()
            let path = NSBezierPath()
            path.move(to: points[0])
            path.line(to: parts.bodyEnd)
            path.lineWidth = lineWidth
            path.lineCapStyle = .butt
            path.stroke()
            let head = NSBezierPath()
            head.move(to: points[1])
            head.line(to: parts.left)
            head.line(to: parts.right)
            head.close()
            head.fill()

        case .text(let value):
            guard let point = points.first else { return }
            ScreenshotTextLayout.draw(
                value,
                at: point,
                lineWidth: stroke.lineWidth,
                scale: scale,
                color: color
            )

        case .mosaic:
            break
        }
    }

    static func drawSwiftUI(
        _ stroke: ScreenshotStroke,
        in context: inout GraphicsContext,
        imageSize: CGSize,
        fit: CGSize,
        showsMosaicSelection: Bool = false,
        mosaicPreviewImage: NSImage? = nil
    ) {
        let scaleX = fit.width / max(imageSize.width, 1)
        let scaleY = fit.height / max(imageSize.height, 1)
        let scale = scaleX
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        let lineWidth = max(1, stroke.lineWidth * scale)
        let points = stroke.points.map(map)

        switch stroke.kind {
        case .pen, .highlight:
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(
                path,
                with: .color(stroke.ink.color.opacity(stroke.kind == .highlight ? 0.35 : 1)),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

        case .mosaic:
            guard let first = points.first else { return }
            if stroke.mosaicMode == .rectangle, points.count >= 2 {
                guard showsMosaicSelection else { return }
                let rect = CGRect(
                    x: min(first.x, points[1].x),
                    y: min(first.y, points[1].y),
                    width: abs(first.x - points[1].x),
                    height: abs(first.y - points[1].y)
                )
                context.stroke(
                    Path(rect),
                    with: .color(.accentColor),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            } else {
                let brushStyle = StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: stroke.mosaicShape == .square ? .square : .round,
                    lineJoin: stroke.mosaicShape == .square ? .bevel : .round
                )
                let brushRegion: Path
                if points.count == 1 {
                    let brushRect = CGRect(
                        x: first.x - lineWidth / 2,
                        y: first.y - lineWidth / 2,
                        width: lineWidth,
                        height: lineWidth
                    )
                    brushRegion = stroke.mosaicShape == .circle
                        ? Path(ellipseIn: brushRect)
                        : Path(brushRect)
                } else {
                    var centerline = Path()
                    centerline.move(to: first)
                    points.dropFirst().forEach { centerline.addLine(to: $0) }
                    brushRegion = centerline.strokedPath(brushStyle)
                }
                guard let mosaicPreviewImage else { return }
                var previewContext = context
                previewContext.clip(to: brushRegion)
                previewContext.draw(
                    Image(nsImage: mosaicPreviewImage),
                    in: CGRect(origin: .zero, size: fit)
                )
            }

        case .rectangle, .ellipse:
            guard points.count >= 2 else { return }
            let rect = CGRect(
                x: min(points[0].x, points[1].x),
                y: min(points[0].y, points[1].y),
                width: abs(points[0].x - points[1].x),
                height: abs(points[0].y - points[1].y)
            )
            if stroke.kind == .ellipse {
                context.stroke(Path(ellipseIn: rect), with: .color(stroke.ink.color), lineWidth: lineWidth)
            } else {
                context.stroke(Path(rect), with: .color(stroke.ink.color), lineWidth: lineWidth)
            }

        case .arrow:
            guard points.count >= 2,
                  let parts = ScreenshotGeometry.arrowHead(
                    from: points[0],
                    to: points[1],
                    lineWidth: stroke.lineWidth,
                    scale: scale
                  )
            else { return }
            var path = Path()
            path.move(to: points[0])
            path.addLine(to: parts.bodyEnd)
            context.stroke(
                path,
                with: .color(stroke.ink.color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            var head = Path()
            head.move(to: points[1])
            head.addLine(to: parts.left)
            head.addLine(to: parts.right)
            head.closeSubpath()
            context.fill(head, with: .color(stroke.ink.color))

        case .text(let value):
            guard let point = points.first else { return }
            context.withCGContext { cgContext in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(
                    cgContext: cgContext,
                    flipped: true
                )
                ScreenshotTextLayout.draw(
                    value,
                    at: point,
                    lineWidth: stroke.lineWidth,
                    scale: scale,
                    color: stroke.ink.nsColor
                )
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}
