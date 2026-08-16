import CoreGraphics

/// Pure geometry for mapping AppKit screen-space selections onto CGImage
/// pixel rects. Coordinates follow AppKit: origin bottom-left, Y up.
public enum ScreenshotGeometry {
    /// Converts a selection rect (display frame space) into an integral pixel
    /// crop inside a captured display image.
    public static func pixelRect(
        selection: CGRect,
        displayFrame: CGRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGRect? {
        guard imageWidth > 0, imageHeight > 0 else { return nil }
        let selected = selection.intersection(displayFrame).integral
        guard selected.width >= 2, selected.height >= 2 else { return nil }

        let scaleX = CGFloat(imageWidth) / displayFrame.width
        let scaleY = CGFloat(imageHeight) / displayFrame.height
        let pixel = CGRect(
            x: (selected.minX - displayFrame.minX) * scaleX,
            y: (displayFrame.maxY - selected.maxY) * scaleY,
            width: selected.width * scaleX,
            height: selected.height * scaleY
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        )
        guard pixel.width >= 2, pixel.height >= 2 else { return nil }
        return pixel
    }

    public static func textFontSize(lineWidth: CGFloat, scale: CGFloat = 1) -> CGFloat {
        max(12, lineWidth * scale)
    }

    public static func arrowHead(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        scale: CGFloat = 1
    ) -> (bodyEnd: CGPoint, left: CGPoint, right: CGPoint)? {
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance >= 1 else { return nil }
        let angle = atan2(end.y - start.y, end.x - start.x)
        let desired = (10 + lineWidth * 2) * scale
        let length = min(desired, max(2, distance * 0.45))
        let left = CGPoint(
            x: end.x - length * cos(angle - .pi / 6),
            y: end.y - length * sin(angle - .pi / 6)
        )
        let right = CGPoint(
            x: end.x - length * cos(angle + .pi / 6),
            y: end.y - length * sin(angle + .pi / 6)
        )
        let bodyEnd = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        return (bodyEnd, left, right)
    }
}
