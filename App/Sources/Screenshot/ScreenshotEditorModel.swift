import AppKit
import MachKitCore
import SwiftUI

@MainActor
final class ScreenshotEditorModel: ObservableObject {
    @Published var image: NSImage
    @Published var tool: ScreenshotAnnotationTool = .rectangle
    @Published var ink = ScreenshotInk.red
    @Published var mosaicBrushShape: ScreenshotMosaicBrushShape = .square
    @Published var toolSizes: [ScreenshotAnnotationTool: CGFloat] = [
        .rectangle: 4,
        .ellipse: 4,
        .arrow: 4,
        .pen: 4,
        .highlight: 20,
        .mosaic: 12,
        .text: 24,
    ]
    @Published var strokes: [ScreenshotStroke] = []
    @Published var redoStack: [ScreenshotStroke] = []
    @Published var draft: ScreenshotStroke?
    @Published var textDraft = ""
    @Published var editingText = false
    @Published var pendingTextPoint: CGPoint?

    /// Only the pre-mosaic image is retained so redo can re-apply the stroke
    /// instead of keeping a second full-resolution bitmap per mosaic action.
    private var mosaicBeforeImages: [UUID: NSImage] = [:]

    init(image: NSImage) {
        self.image = image
    }

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var displayStrokes: [ScreenshotStroke] { strokes + (draft.map { [$0] } ?? []) }
    var activeSize: CGFloat { toolSizes[tool] ?? 4 }
    var color: Color { ink.color }

    var activeSizeOptions: [CGFloat] {
        switch tool {
        case .rectangle, .ellipse, .arrow:
            [2, 4, 8]
        case .pen:
            [4, 8, 16]
        case .highlight:
            [12, 20, 32]
        case .mosaic:
            [6, 12, 24]
        case .text:
            [18, 24, 36]
        }
    }

    func setActiveSize(_ size: CGFloat) {
        toolSizes[tool] = size
    }

    func undo() {
        commitInlineTextIfNeeded()
        guard let last = strokes.popLast() else { return }
        if case .mosaic = last.kind, let before = mosaicBeforeImages.removeValue(forKey: last.id) {
            image = before
        }
        redoStack.append(last)
    }

    func redo() {
        guard let last = redoStack.popLast() else { return }
        if case .mosaic = last.kind {
            applyMosaic(last, clearingRedo: false)
            return
        }
        strokes.append(last)
    }

    func clearAnnotations() {
        commitInlineTextIfNeeded()
        while !strokes.isEmpty { undo() }
        redoStack.removeAll()
        mosaicBeforeImages.removeAll()
    }

    func begin(at point: CGPoint) {
        commitInlineTextIfNeeded()
        if tool == .text {
            pendingTextPoint = point
            textDraft = ""
            editingText = true
            return
        }

        let kind: ScreenshotStroke.Kind = switch tool {
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .arrow: .arrow
        case .pen: .pen
        case .highlight: .highlight
        case .mosaic: .mosaic
        case .text: .pen
        }
        draft = ScreenshotStroke(
            kind: kind,
            points: [point],
            ink: ink,
            lineWidth: activeSize,
            mosaicShape: mosaicBrushShape
        )
    }

    func move(to point: CGPoint) {
        guard var draft else { return }
        switch draft.kind {
        case .pen, .highlight, .mosaic:
            draft.points.append(point)
        case .rectangle, .ellipse, .arrow:
            if draft.points.count == 1 {
                draft.points.append(point)
            } else {
                draft.points[1] = point
            }
        case .text:
            break
        }
        self.draft = draft
    }

    func end() {
        guard let draft else { return }
        defer { self.draft = nil }
        guard usable(draft) else { return }
        if case .mosaic = draft.kind {
            applyMosaic(draft, clearingRedo: true)
        } else {
            strokes.append(draft)
            redoStack.removeAll()
        }
    }

    func commitInlineTextIfNeeded() {
        guard editingText else { return }
        let value = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let point = pendingTextPoint
        editingText = false
        pendingTextPoint = nil
        textDraft = ""
        guard !value.isEmpty, let point else { return }
        strokes.append(
            ScreenshotStroke(kind: .text(value), points: [point], ink: ink, lineWidth: activeSize)
        )
        redoStack.removeAll()
    }

    func exportImage() -> CGImage? {
        commitInlineTextIfNeeded()
        let size = image.size
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite,
              source.width <= 16_000, source.height <= 16_000
        else { return nil }

        if strokes.allSatisfy({ $0.kind == .mosaic }) {
            return source
        }

        return autoreleasepool {
            let width = source.width
            let height = source.height
            let pixelSize = CGSize(width: width, height: height)
            let scaleX = CGFloat(width) / size.width
            let scaleY = CGFloat(height) / size.height
            let composed = NSImage(size: pixelSize, flipped: true) { bounds in
                NSImage(cgImage: source, size: pixelSize).draw(
                    in: bounds,
                    from: .zero,
                    operation: .copy,
                    fraction: 1
                )
                for stroke in self.strokes where stroke.kind != .mosaic {
                    var scaled = stroke
                    scaled.points = stroke.points.map {
                        CGPoint(x: $0.x * scaleX, y: $0.y * scaleY)
                    }
                    // Points are already scaled into pixel space; draw at scale 1.
                    scaled.lineWidth = stroke.lineWidth * (scaleX + scaleY) / 2
                    ScreenshotStrokeRenderer.drawAppKit(scaled, scale: 1)
                }
                return true
            }
            return composed.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }

    private func usable(_ stroke: ScreenshotStroke) -> Bool {
        switch stroke.kind {
        case .pen, .highlight:
            return stroke.points.count >= 2
        case .mosaic:
            return !stroke.points.isEmpty
        case .rectangle, .ellipse, .arrow:
            guard stroke.points.count >= 2 else { return false }
            return hypot(
                stroke.points[0].x - stroke.points[1].x,
                stroke.points[0].y - stroke.points[1].y
            ) >= 2
        case .text(let value):
            return !value.isEmpty
        }
    }

    private func applyMosaic(_ stroke: ScreenshotStroke, clearingRedo: Bool) {
        guard !stroke.points.isEmpty,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        let scaleX = CGFloat(source.width) / max(image.size.width, 1)
        let scaleY = CGFloat(source.height) / max(image.size.height, 1)
        let pixelBlock = max(8, Int(stroke.lineWidth * max(scaleX, scaleY) / 3))
        let tinyWidth = max(1, source.width / pixelBlock)
        let tinyHeight = max(1, source.height / pixelBlock)
        let colorSpace = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let tinyContext = CGContext(
            data: nil,
            width: tinyWidth,
            height: tinyHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let output = CGContext(
            data: nil,
            width: source.width,
            height: source.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }

        tinyContext.interpolationQuality = .none
        tinyContext.draw(source, in: CGRect(x: 0, y: 0, width: tinyWidth, height: tinyHeight))
        guard let tinyImage = tinyContext.makeImage() else { return }
        let outputRect = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        output.draw(source, in: outputRect)

        let mappedPoints = stroke.points.map {
            CGPoint(x: $0.x * scaleX, y: (image.size.height - $0.y) * scaleY)
        }
        guard let first = mappedPoints.first else { return }

        output.saveGState()
        let brushWidth = stroke.lineWidth * (scaleX + scaleY) / 2
        if mappedPoints.count == 1 {
            let brushRect = CGRect(
                x: first.x - brushWidth / 2,
                y: first.y - brushWidth / 2,
                width: brushWidth,
                height: brushWidth
            )
            if stroke.mosaicShape == .circle {
                output.addEllipse(in: brushRect)
            } else {
                output.addRect(brushRect)
            }
        } else {
            let brushPath = CGMutablePath()
            brushPath.move(to: first)
            mappedPoints.dropFirst().forEach { brushPath.addLine(to: $0) }
            output.addPath(brushPath)
            output.setLineWidth(brushWidth)
            output.setLineCap(stroke.mosaicShape == .circle ? .round : .square)
            output.setLineJoin(stroke.mosaicShape == .circle ? .round : .bevel)
            output.replacePathWithStrokedPath()
        }
        output.clip()
        output.interpolationQuality = .none
        output.draw(tinyImage, in: outputRect)
        output.restoreGState()
        guard let result = output.makeImage() else { return }

        mosaicBeforeImages[stroke.id] = image
        image = NSImage(cgImage: result, size: image.size)
        if !strokes.contains(where: { $0.id == stroke.id }) {
            strokes.append(stroke)
        }
        if clearingRedo {
            redoStack.removeAll()
        }
    }
}
