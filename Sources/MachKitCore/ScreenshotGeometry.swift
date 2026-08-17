import CoreGraphics

/// Pure geometry for mapping AppKit screen-space selections onto CGImage
/// pixel rects. Coordinates follow AppKit: origin bottom-left, Y up.
public enum ScreenshotGeometry {
    /// Converts an AppKit screen-space selection into the top-left-origin
    /// coordinate space of an editor window confined to one display.
    public static func editorCanvasRect(
        selection: CGRect,
        displayFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: selection.minX - displayFrame.minX,
            y: displayFrame.maxY - selection.maxY,
            width: selection.width,
            height: selection.height
        )
    }

    /// Places the two-row annotation toolbar next to the selection while
    /// keeping its center inside the display that owns the selection.
    public static func toolbarCenter(
        canvasRect: CGRect,
        displayRect: CGRect,
        toolbarHalfSize: CGSize = CGSize(width: 350, height: 52),
        margin: CGFloat = 12,
        gap: CGFloat = 6
    ) -> CGPoint {
        guard !displayRect.isNull, !displayRect.isEmpty else {
            return CGPoint(x: canvasRect.midX, y: canvasRect.maxY + toolbarHalfSize.height + gap)
        }

        let halfWidth = min(
            toolbarHalfSize.width,
            max(0, displayRect.width / 2 - margin)
        )
        let halfHeight = min(
            toolbarHalfSize.height,
            max(0, displayRect.height / 2 - margin)
        )
        let minimumX = displayRect.minX + margin + halfWidth
        let maximumX = displayRect.maxX - margin - halfWidth
        let x = min(max(canvasRect.midX, minimumX), maximumX)

        let below = canvasRect.maxY + gap + halfHeight
        let maximumY = displayRect.maxY - margin - halfHeight
        if below <= maximumY {
            return CGPoint(x: x, y: below)
        }

        let above = canvasRect.minY - gap - halfHeight
        let minimumY = displayRect.minY + margin + halfHeight
        return CGPoint(x: x, y: max(minimumY, above))
    }

    /// Converts a selection rect into a fixed-size pixel crop. Origin and size
    /// are rounded independently so a fractional origin cannot expand the
    /// crop by one pixel, and the rounded origin is then clamped without
    /// changing that size.
    public static func pixelRect(
        selection: CGRect,
        displayFrame: CGRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGRect? {
        guard imageWidth > 0,
              imageHeight > 0,
              displayFrame.width > 0,
              displayFrame.height > 0,
              displayFrame.width.isFinite,
              displayFrame.height.isFinite
        else { return nil }
        let selected = selection.standardized.intersection(displayFrame.standardized)
        guard selected.width >= 2, selected.height >= 2 else { return nil }

        let scaleX = CGFloat(imageWidth) / displayFrame.width
        let scaleY = CGFloat(imageHeight) / displayFrame.height
        let width = min(
            imageWidth,
            max(1, Int((selected.width * scaleX).rounded()))
        )
        let height = min(
            imageHeight,
            max(1, Int((selected.height * scaleY).rounded()))
        )
        guard width >= 2, height >= 2 else { return nil }

        let proposedX = Int(
            ((selected.minX - displayFrame.minX) * scaleX).rounded()
        )
        let proposedY = Int(
            ((displayFrame.maxY - selected.maxY) * scaleY).rounded()
        )
        let x = min(max(0, proposedX), imageWidth - width)
        let y = min(max(0, proposedY), imageHeight - height)
        return CGRect(
            x: CGFloat(x),
            y: CGFloat(y),
            width: CGFloat(width),
            height: CGFloat(height)
        )
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
