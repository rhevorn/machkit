import AppKit
import MachKitCore
import SwiftUI

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
            let fontSize = ScreenshotGeometry.textFontSize(lineWidth: stroke.lineWidth, scale: scale)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color,
            ]
            let size = (value as NSString).size(withAttributes: attributes)
            let rect = CGRect(x: point.x, y: point.y, width: ceil(size.width), height: ceil(size.height))
            (value as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )

        case .mosaic:
            break
        }
    }

    static func drawSwiftUI(
        _ stroke: ScreenshotStroke,
        in context: inout GraphicsContext,
        imageSize: CGSize,
        fit: CGSize
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
        case .pen, .highlight, .mosaic:
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            let isMosaic = stroke.kind == .mosaic
            context.stroke(
                path,
                with: .color(
                    isMosaic
                        ? .black.opacity(0.22)
                        : stroke.ink.color.opacity(stroke.kind == .highlight ? 0.35 : 1)
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: isMosaic && stroke.mosaicShape == .square ? .square : .round,
                    lineJoin: isMosaic && stroke.mosaicShape == .square ? .bevel : .round
                )
            )

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
            let fontSize = ScreenshotGeometry.textFontSize(lineWidth: stroke.lineWidth, scale: scale)
            context.draw(
                Text(value)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(stroke.ink.color),
                at: point,
                anchor: .topLeading
            )
        }
    }
}
