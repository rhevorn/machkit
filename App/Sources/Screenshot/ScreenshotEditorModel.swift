import AppKit
import MachKitCore
import SwiftUI

@MainActor
final class ScreenshotEditorModel: ObservableObject {
    @Published var image: NSImage
    @Published var tool: ScreenshotAnnotationTool = .rectangle
    @Published var ink = ScreenshotInk.red
    @Published var mosaicBrushShape: ScreenshotMosaicBrushShape = .square
    @Published var mosaicMode: ScreenshotMosaicMode = .brush
    @Published var toolSizes: [ScreenshotAnnotationTool: CGFloat] = [
        .rectangle: 2,
        .ellipse: 2,
        .arrow: 2,
        .pen: 2,
        .highlight: 4,
        .mosaic: 12,
        .text: 16,
    ]
    @Published var strokes: [ScreenshotStroke] = []
    @Published var draft: ScreenshotStroke?
    @Published private(set) var mosaicPreviewImage: NSImage?
    @Published var textDraft = ""
    @Published var editingText = false
    @Published var pendingTextPoint: CGPoint?

    /// Mosaic strokes are destructive in the preview bitmap, so retain one
    /// immutable source and rebuild the composite only when history rewinds.
    private var baseImage: NSImage
    private var undoHistory: [EditOperation] = []
    private var redoHistory: [EditOperation] = []
    private var movingText: MovingText?
    private var activeMosaicTexture: MosaicTexture?

    private struct MosaicTexture {
        let source: CGImage
        let pixels: CGImage
        let scaleX: CGFloat
        let scaleY: CGFloat
        let colorSpace: CGColorSpace
        let bitmapInfo: UInt32
    }

    private enum EditOperation {
        case added(ScreenshotStroke)
        case movedText(id: UUID, from: CGPoint, to: CGPoint)
    }

    private struct MovingText {
        let id: UUID
        let pointerOrigin: CGPoint
        let textOrigin: CGPoint
    }

    init(image: NSImage) {
        self.image = image
        baseImage = image
    }

    var canUndo: Bool { !undoHistory.isEmpty }
    var canRedo: Bool { !redoHistory.isEmpty }
    var activeSize: CGFloat { toolSizes[tool] ?? 4 }
    var color: Color { ink.color }

    var activeSizeOptions: [CGFloat] {
        switch tool {
        case .rectangle, .ellipse, .arrow:
            [2, 4, 8]
        case .pen, .highlight:
            [2, 4, 8, 12, 16]
        case .mosaic:
            [6, 12, 18]
        case .text:
            stride(from: CGFloat(12), through: CGFloat(64), by: 2).map { $0 }
        }
    }

    func setActiveSize(_ size: CGFloat) {
        toolSizes[tool] = size
    }

    func undo() {
        commitInlineTextIfNeeded()
        guard let operation = undoHistory.popLast() else { return }
        switch operation {
        case .added(let stroke):
            strokes.removeAll { $0.id == stroke.id }
            if case .mosaic = stroke.kind {
                rebuildMosaicComposite()
            }
        case .movedText(let id, let origin, _):
            setTextOrigin(origin, for: id)
        }
        redoHistory.append(operation)
    }

    func redo() {
        guard let operation = redoHistory.popLast() else { return }
        switch operation {
        case .added(let stroke):
            if case .mosaic = stroke.kind {
                guard applyMosaic(
                    stroke,
                    clearingRedo: false,
                    recordingHistory: false
                ) else {
                    redoHistory.append(operation)
                    return
                }
            } else {
                strokes.append(stroke)
            }
        case .movedText(let id, _, let destination):
            setTextOrigin(destination, for: id)
        }
        undoHistory.append(operation)
    }

    func clearAnnotations() {
        commitInlineTextIfNeeded()
        strokes.removeAll()
        draft = nil
        mosaicPreviewImage = nil
        activeMosaicTexture = nil
        movingText = nil
        undoHistory.removeAll()
        redoHistory.removeAll()
        image = baseImage
    }

    func begin(at point: CGPoint) {
        commitInlineTextIfNeeded()
        if tool == .text {
            if let stroke = textStroke(at: point), let origin = stroke.points.first {
                movingText = MovingText(
                    id: stroke.id,
                    pointerOrigin: point,
                    textOrigin: origin
                )
                return
            }
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
            mosaicShape: mosaicBrushShape,
            mosaicMode: mosaicMode
        )
        if tool == .mosaic, mosaicMode == .brush {
            activeMosaicTexture = makeMosaicTexture(
                from: image,
                lineWidth: activeSize
            )
            mosaicPreviewImage = activeMosaicTexture.flatMap(makeMosaicPreview)
        }
    }

    func move(to point: CGPoint) {
        if let movingText {
            let proposed = CGPoint(
                x: movingText.textOrigin.x + point.x - movingText.pointerOrigin.x,
                y: movingText.textOrigin.y + point.y - movingText.pointerOrigin.y
            )
            setTextOrigin(clampedTextOrigin(proposed, for: movingText.id), for: movingText.id)
            return
        }
        guard var draft else { return }
        switch draft.kind {
        case .pen, .highlight:
            draft.points.append(point)
        case .mosaic:
            if draft.mosaicMode == .rectangle {
                if draft.points.count == 1 {
                    draft.points.append(point)
                } else {
                    draft.points[1] = point
                }
            } else {
                draft.points.append(point)
            }
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
        if let movingText {
            defer { self.movingText = nil }
            guard let destination = strokes.first(where: { $0.id == movingText.id })?.points.first,
                  destination != movingText.textOrigin
            else { return }
            undoHistory.append(
                .movedText(id: movingText.id, from: movingText.textOrigin, to: destination)
            )
            redoHistory.removeAll()
            return
        }
        guard let draft else { return }
        defer {
            self.draft = nil
            mosaicPreviewImage = nil
            activeMosaicTexture = nil
        }
        guard usable(draft) else { return }
        if case .mosaic = draft.kind {
            _ = applyMosaic(
                draft,
                clearingRedo: true,
                texture: activeMosaicTexture
            )
        } else {
            strokes.append(draft)
            recordAddition(draft)
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
        let stroke = ScreenshotStroke(
            kind: .text(value),
            points: [point],
            ink: ink,
            lineWidth: activeSize
        )
        strokes.append(stroke)
        recordAddition(stroke)
    }

    func replaceBaseImage(_ source: CGImage) {
        let logicalSize = image.size
        baseImage = NSImage(cgImage: source, size: logicalSize)
        rebuildMosaicComposite()
        redoHistory.removeAll()
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
            let scaleX = CGFloat(width) / size.width
            let scaleY = CGFloat(height) / size.height
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }

            let outputRect = CGRect(x: 0, y: 0, width: width, height: height)
            context.interpolationQuality = .none
            context.draw(source, in: outputRect)

            // Strokes use the editor's top-left coordinate system. Flip only
            // the annotation pass; the captured CGImage stays in its native
            // orientation and the output remains exactly source-sized.
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            for stroke in self.strokes where stroke.kind != .mosaic {
                var scaled = stroke
                scaled.points = stroke.points.map {
                    CGPoint(x: $0.x * scaleX, y: $0.y * scaleY)
                }
                scaled.lineWidth = stroke.lineWidth * (scaleX + scaleY) / 2
                ScreenshotStrokeRenderer.drawAppKit(scaled, scale: 1)
            }
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            return context.makeImage()
        }
    }

    private func usable(_ stroke: ScreenshotStroke) -> Bool {
        switch stroke.kind {
        case .pen, .highlight:
            return stroke.points.count >= 2
        case .mosaic:
            guard stroke.mosaicMode == .rectangle else { return !stroke.points.isEmpty }
            guard stroke.points.count >= 2 else { return false }
            return abs(stroke.points[0].x - stroke.points[1].x) >= 2
                && abs(stroke.points[0].y - stroke.points[1].y) >= 2
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

    private func applyMosaic(
        _ stroke: ScreenshotStroke,
        clearingRedo: Bool,
        recordingHistory: Bool = true,
        texture: MosaicTexture? = nil
    ) -> Bool {
        guard let result = renderMosaic(stroke, onto: image, texture: texture) else { return false }
        image = result
        if !strokes.contains(where: { $0.id == stroke.id }) {
            strokes.append(stroke)
        }
        if clearingRedo {
            redoHistory.removeAll()
        }
        if recordingHistory {
            undoHistory.append(.added(stroke))
        }
        return true
    }

    private func renderMosaic(
        _ stroke: ScreenshotStroke,
        onto sourceImage: NSImage,
        texture suppliedTexture: MosaicTexture? = nil
    ) -> NSImage? {
        guard !stroke.points.isEmpty,
              let texture = suppliedTexture
                ?? makeMosaicTexture(from: sourceImage, lineWidth: stroke.lineWidth)
        else { return nil }
        let source = texture.source
        guard let output = CGContext(
            data: nil,
            width: source.width,
            height: source.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: texture.colorSpace,
            bitmapInfo: texture.bitmapInfo
        ) else { return nil }
        let outputRect = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        output.draw(source, in: outputRect)

        let mappedPoints = stroke.points.map {
            CGPoint(
                x: $0.x * texture.scaleX,
                y: (sourceImage.size.height - $0.y) * texture.scaleY
            )
        }
        guard let first = mappedPoints.first else { return nil }

        output.saveGState()
        let brushWidth = stroke.lineWidth * (texture.scaleX + texture.scaleY) / 2
        if stroke.mosaicMode == .rectangle, mappedPoints.count >= 2 {
            let last = mappedPoints[1]
            output.addRect(CGRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: abs(first.x - last.x),
                height: abs(first.y - last.y)
            ))
        } else if mappedPoints.count == 1 {
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
        output.draw(texture.pixels, in: outputRect)
        output.restoreGState()
        guard let result = output.makeImage() else { return nil }
        return NSImage(cgImage: result, size: sourceImage.size)
    }

    private func makeMosaicTexture(
        from sourceImage: NSImage,
        lineWidth: CGFloat
    ) -> MosaicTexture? {
        guard let source = sourceImage.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return nil }
        let scaleX = CGFloat(source.width) / max(sourceImage.size.width, 1)
        let scaleY = CGFloat(source.height) / max(sourceImage.size.height, 1)
        let pixelBlock = max(3, Int(lineWidth * max(scaleX, scaleY) / 2))
        let tinyWidth = max(1, source.width / pixelBlock)
        let tinyHeight = max(1, source.height / pixelBlock)
        let colorSpace = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: tinyWidth,
            height: tinyHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: 0, y: 0, width: tinyWidth, height: tinyHeight))
        guard let pixels = context.makeImage() else { return nil }
        return MosaicTexture(
            source: source,
            pixels: pixels,
            scaleX: scaleX,
            scaleY: scaleY,
            colorSpace: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    private func makeMosaicPreview(from texture: MosaicTexture) -> NSImage? {
        guard let context = CGContext(
            data: nil,
            width: texture.source.width,
            height: texture.source.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: texture.colorSpace,
            bitmapInfo: texture.bitmapInfo
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(
            texture.pixels,
            in: CGRect(
                x: 0,
                y: 0,
                width: texture.source.width,
                height: texture.source.height
            )
        )
        guard let preview = context.makeImage() else { return nil }
        return NSImage(cgImage: preview, size: image.size)
    }

    @discardableResult
    private func rebuildMosaicComposite() -> Bool {
        var composite = baseImage
        for stroke in strokes where stroke.kind == .mosaic {
            guard let rendered = renderMosaic(stroke, onto: composite) else {
                return false
            }
            composite = rendered
        }
        image = composite
        return true
    }

    private func recordAddition(_ stroke: ScreenshotStroke) {
        undoHistory.append(.added(stroke))
        redoHistory.removeAll()
    }

    private func setTextOrigin(_ origin: CGPoint, for id: UUID) {
        guard let index = strokes.firstIndex(where: { $0.id == id }),
              case .text = strokes[index].kind,
              !strokes[index].points.isEmpty
        else { return }
        strokes[index].points[0] = origin
    }

    private func textStroke(at point: CGPoint) -> ScreenshotStroke? {
        strokes.reversed().first { stroke in
            guard case .text(let value) = stroke.kind,
                  let origin = stroke.points.first
            else { return false }
            return textBounds(value: value, stroke: stroke, origin: origin)
                .insetBy(dx: -6, dy: -6)
                .contains(point)
        }
    }

    private func clampedTextOrigin(_ origin: CGPoint, for id: UUID) -> CGPoint {
        guard let stroke = strokes.first(where: { $0.id == id }),
              case .text(let value) = stroke.kind
        else { return origin }
        let bounds = textBounds(value: value, stroke: stroke, origin: .zero)
        return CGPoint(
            x: min(max(0, origin.x), max(0, image.size.width - bounds.width)),
            y: min(max(0, origin.y), max(0, image.size.height - bounds.height))
        )
    }

    private func textBounds(
        value: String,
        stroke: ScreenshotStroke,
        origin: CGPoint
    ) -> CGRect {
        ScreenshotTextLayout.bounds(
            for: value,
            at: origin,
            lineWidth: stroke.lineWidth
        )
    }
}
