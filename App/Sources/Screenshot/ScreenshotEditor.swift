import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ScreenshotAnnotationTool: String, CaseIterable, Identifiable {
    case rectangle
    case ellipse
    case arrow
    case pen
    case highlight
    case mosaic
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .arrow: "Arrow"
        case .pen: "Pen"
        case .highlight: "Highlight"
        case .mosaic: "Mosaic"
        case .text: "Text"
        }
    }

    var icon: String {
        switch self {
        case .rectangle: "rectangle"
        case .ellipse: "oval"
        case .arrow: "arrow.up.right"
        case .pen: "pencil.tip"
        case .highlight: "highlighter"
        case .mosaic: "square.grid.3x3.fill"
        case .text: "textformat"
        }
    }

    var usesColor: Bool {
        switch self {
        case .rectangle, .ellipse, .arrow, .pen, .highlight, .text: true
        case .mosaic: false
        }
    }
}

private enum ScreenshotPalette {
    static let red = Color(red: 1, green: 0.23, blue: 0.19)
    static let yellow = Color(red: 1, green: 0.8, blue: 0)
    static let green = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)

    static let swatches: [Color] = [red, yellow, green, blue, .white]

    static func nsColor(_ color: Color) -> NSColor {
        if color == red { return NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1) }
        if color == yellow { return NSColor(red: 1, green: 0.8, blue: 0, alpha: 1) }
        if color == green { return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1) }
        if color == blue { return NSColor(red: 0.04, green: 0.52, blue: 1, alpha: 1) }
        if color == .white { return .white }
        return .systemRed
    }
}

private enum ScreenshotMosaicBrushShape: String, CaseIterable, Identifiable {
    case circle
    case square

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .circle: "circle.fill"
        case .square: "square.fill"
        }
    }
}

@MainActor
private enum ScreenshotCursorFactory {
    static func cursor(
        for tool: ScreenshotAnnotationTool,
        color: Color,
        lineWidth: CGFloat,
        canvasScale: CGFloat
    ) -> NSCursor {
        switch tool {
        case .pen:
            return brushCursor(
                diameter: max(8, lineWidth * canvasScale),
                color: ScreenshotPalette.nsColor(color)
            )
        case .highlight:
            return brushCursor(
                diameter: max(14, lineWidth * canvasScale),
                color: ScreenshotPalette.nsColor(color).withAlphaComponent(0.35)
            )
        case .mosaic:
            return transparentCursor()
        case .text:
            return .iBeam
        case .rectangle, .ellipse, .arrow:
            return .crosshair
        }
    }

    private static func brushCursor(diameter: CGFloat, color: NSColor) -> NSCursor {
        let brushDiameter = min(36, ceil(diameter))
        let side = brushDiameter + 6
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            color.setFill()
            circle.fill()
            NSColor.white.withAlphaComponent(0.95).setStroke()
            circle.lineWidth = 3
            circle.stroke()
            NSColor.black.withAlphaComponent(0.9).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    private static func transparentCursor() -> NSCursor {
        let image = NSImage(size: NSSize(width: 1, height: 1), flipped: false) { _ in true }
        return NSCursor(image: image, hotSpot: .zero)
    }
}

private struct ScreenshotMosaicGlyph: View {
    let color: Color
    var size: CGFloat = 15

    var body: some View {
        VStack(spacing: 1.5) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 0.7)
                            .fill(color.opacity((row + column).isMultiple(of: 2) ? 1 : 0.58))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ScreenshotMosaicBrushPreview: View {
    let shape: ScreenshotMosaicBrushShape

    var body: some View {
        Group {
            if shape == .circle {
                Circle()
                    .fill(Color.black.opacity(0.22))
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.22))
            }
        }
    }
}

private struct ScreenshotStroke: Identifiable {
    enum Kind: Equatable {
        case rectangle
        case ellipse
        case arrow
        case pen
        case highlight
        case mosaic
        case text(String)
    }

    let id = UUID()
    var kind: Kind
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var mosaicShape: ScreenshotMosaicBrushShape = .square
}

@MainActor
private final class ScreenshotEditorModel: ObservableObject {
    @Published var image: NSImage
    @Published var tool: ScreenshotAnnotationTool = .rectangle
    @Published var color = ScreenshotPalette.red
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

    private var mosaicBeforeImages: [UUID: NSImage] = [:]
    private var mosaicAfterImages: [UUID: NSImage] = [:]

    init(image: NSImage) {
        self.image = image
    }

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var displayStrokes: [ScreenshotStroke] { strokes + (draft.map { [$0] } ?? []) }
    var activeSize: CGFloat { toolSizes[tool] ?? 4 }

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
        if case .mosaic = last.kind, let before = mosaicBeforeImages[last.id] {
            image = before
        }
        redoStack.append(last)
    }

    func redo() {
        guard let last = redoStack.popLast() else { return }
        if case .mosaic = last.kind, let after = mosaicAfterImages[last.id] {
            image = after
        }
        strokes.append(last)
    }

    func clear() {
        commitInlineTextIfNeeded()
        while !strokes.isEmpty { undo() }
        redoStack.removeAll()
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
            color: color,
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
            applyMosaic(draft)
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
            ScreenshotStroke(kind: .text(value), points: [point], color: color, lineWidth: activeSize)
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
            guard let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let context = NSGraphicsContext(bitmapImageRep: representation)
            else { return nil }

            representation.size = pixelSize
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = context
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
            let scaleX = CGFloat(width) / size.width
            let scaleY = CGFloat(height) / size.height
            for stroke in strokes where stroke.kind != .mosaic {
                var scaled = stroke
                scaled.points = stroke.points.map {
                    CGPoint(x: $0.x * scaleX, y: $0.y * scaleY)
                }
                scaled.lineWidth = stroke.lineWidth * (scaleX + scaleY) / 2
                draw(flipped(scaled, height: pixelSize.height))
            }
            return representation.cgImage
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

    private func applyMosaic(_ stroke: ScreenshotStroke) {
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

        let before = image
        let after = NSImage(cgImage: result, size: image.size)
        mosaicBeforeImages[stroke.id] = before
        mosaicAfterImages[stroke.id] = after
        image = after
        strokes.append(stroke)
        redoStack.removeAll()
    }

    private func flipped(_ stroke: ScreenshotStroke, height: CGFloat) -> ScreenshotStroke {
        var copy = stroke
        copy.points = stroke.points.map { CGPoint(x: $0.x, y: height - $0.y) }
        return copy
    }

    private func draw(_ stroke: ScreenshotStroke) {
        let color = ScreenshotPalette.nsColor(stroke.color)
        switch stroke.kind {
        case .pen, .highlight:
            guard let first = stroke.points.first else { return }
            let path = NSBezierPath()
            path.move(to: first)
            stroke.points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = stroke.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            (stroke.kind == .highlight ? color.withAlphaComponent(0.35) : color).setStroke()
            path.stroke()
        case .rectangle, .ellipse:
            guard stroke.points.count >= 2 else { return }
            let first = stroke.points[0]
            let second = stroke.points[1]
            let rect = CGRect(
                x: min(first.x, second.x),
                y: min(first.y, second.y),
                width: abs(first.x - second.x),
                height: abs(first.y - second.y)
            )
            color.setStroke()
            let path = stroke.kind == .ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
            path.lineWidth = stroke.lineWidth
            path.stroke()
        case .arrow:
            guard stroke.points.count >= 2 else { return }
            let start = stroke.points[0]
            let end = stroke.points[1]
            let distance = hypot(end.x - start.x, end.y - start.y)
            guard distance >= 1 else { return }
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length = min(10 + stroke.lineWidth * 2, max(2, distance * 0.45))
            let left = CGPoint(
                x: end.x - length * cos(angle - .pi / 6),
                y: end.y - length * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: end.x - length * cos(angle + .pi / 6),
                y: end.y - length * sin(angle + .pi / 6)
            )
            let bodyEnd = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            color.setStroke()
            color.setFill()
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: bodyEnd)
            path.lineWidth = stroke.lineWidth
            path.lineCapStyle = .butt
            path.stroke()
            let head = NSBezierPath()
            head.move(to: end)
            head.line(to: left)
            head.line(to: right)
            head.close()
            head.fill()
        case .text(let value):
            guard let point = stroke.points.first else { return }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: stroke.lineWidth, weight: .semibold),
                .foregroundColor: color,
            ]
            (value as NSString).draw(at: point, withAttributes: attributes)
        case .mosaic:
            break
        }
    }
}

private struct ScreenshotAnnotatorView: View {
    @ObservedObject var model: ScreenshotEditorModel
    let canvasRect: CGRect
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var pointerIsInsideCanvas = false
    @State private var canvasPointerLocation: CGPoint?
    @FocusState private var textFieldIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { model.commitInlineTextIfNeeded() }

                imageCanvas(fit: canvasRect)
                    .position(x: canvasRect.midX, y: canvasRect.midY)

                floatingToolbar
                    .position(
                        x: toolbarX(in: proxy.size),
                        y: toolbarY(in: proxy.size)
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .focusable()
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
            .onKeyPress(.return) {
                guard !model.editingText else { return .ignored }
                onConfirm()
                return .handled
            }
        }
    }

    private func imageCanvas(fit: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: model.image)
                .resizable()
                .interpolation(.high)
                .frame(width: fit.width, height: fit.height)

            Canvas { context, _ in
                for stroke in model.displayStrokes {
                    draw(stroke, in: &context, imageSize: model.image.size, fit: fit.size)
                }
            }
            .frame(width: fit.width, height: fit.height)
            .gesture(dragGesture(fit: fit))
            .allowsHitTesting(!model.editingText)

            if model.tool == .mosaic, let canvasPointerLocation, !model.editingText {
                let scale = fit.width / max(model.image.size.width, 1)
                ScreenshotMosaicBrushPreview(shape: model.mosaicBrushShape)
                    .frame(
                        width: model.activeSize * scale,
                        height: model.activeSize * scale
                    )
                    .position(canvasPointerLocation)
                    .allowsHitTesting(false)
            }

            if model.editingText, let point = model.pendingTextPoint {
                let scale = fit.width / max(model.image.size.width, 1)
                let fieldSize = CGSize(
                    width: min(160, max(1, fit.width - 8)),
                    height: min(30, max(1, fit.height - 8))
                )
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.commitInlineTextIfNeeded()
                        textFieldIsFocused = false
                    }
                TextField("", text: $model.textDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: max(12, model.activeSize * scale), weight: .semibold))
                    .foregroundStyle(model.color)
                    .padding(.horizontal, 7)
                    .frame(width: fieldSize.width, height: fieldSize.height)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    }
                    .position(
                        x: min(
                            max(fieldSize.width / 2, point.x * scale + fieldSize.width / 2),
                            fit.width - fieldSize.width / 2
                        ),
                        y: min(
                            max(fieldSize.height / 2, point.y * scale + fieldSize.height / 2),
                            fit.height - fieldSize.height / 2
                        )
                    )
                    .focused($textFieldIsFocused)
                    .onAppear { textFieldIsFocused = true }
                    .onKeyPress(.return) {
                        model.commitInlineTextIfNeeded()
                        textFieldIsFocused = false
                        return .handled
                    }
            }
        }
        .frame(width: fit.width, height: fit.height)
        .clipped()
        .overlay {
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                pointerIsInsideCanvas = true
                canvasPointerLocation = location
                updateCanvasCursor(fit: fit)
            case .ended:
                pointerIsInsideCanvas = false
                canvasPointerLocation = nil
                NSCursor.arrow.set()
            }
        }
        .onChange(of: model.tool) { _, _ in updateCanvasCursor(fit: fit) }
        .onChange(of: model.color) { _, _ in updateCanvasCursor(fit: fit) }
        .onChange(of: model.toolSizes) { _, _ in updateCanvasCursor(fit: fit) }
        .onChange(of: model.mosaicBrushShape) { _, _ in updateCanvasCursor(fit: fit) }
        .onChange(of: model.editingText) { _, isEditing in
            if isEditing { textFieldIsFocused = true }
        }
    }

    private func updateCanvasCursor(fit: CGRect) {
        guard pointerIsInsideCanvas else {
            NSCursor.arrow.set()
            return
        }
        let scale = fit.width / max(model.image.size.width, 1)
        ScreenshotCursorFactory.cursor(
            for: model.tool,
            color: model.color,
            lineWidth: model.activeSize,
            canvasScale: scale
        ).set()
    }

    private var floatingToolbar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(ScreenshotAnnotationTool.allCases) { tool in
                    toolButton(tool)
                }

                toolbarDivider

                actionButton("arrow.uturn.backward", enabled: model.canUndo, help: "Undo".localized, action: model.undo)
                actionButton("arrow.uturn.forward", enabled: model.canRedo, help: "Redo".localized, action: model.redo)

                toolbarDivider

                actionButton("square.and.arrow.down", enabled: true, help: "Save…".localized, action: onSave)

                toolbarDivider

                cancelButton
                confirmButton
            }
            .toolbarSurface()

            HStack(spacing: 4) {
                if model.tool == .mosaic {
                    ForEach(ScreenshotMosaicBrushShape.allCases) { shape in
                        mosaicShapeButton(shape)
                    }
                    toolbarDivider
                }

                Text(verbatim: "\(Int(model.activeSize)) px")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 42)

                ForEach(model.activeSizeOptions, id: \.self) { size in
                    sizeButton(size)
                }

                if model.tool.usesColor {
                    toolbarDivider
                    ForEach(Array(ScreenshotPalette.swatches.enumerated()), id: \.offset) { _, swatch in
                        colorButton(swatch)
                    }
                }
            }
            .toolbarSurface()
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 3)
    }

    private func sizeButton(_ size: CGFloat) -> some View {
        let isSelected = model.activeSize == size
        let buttonSize = model.tool == .mosaic
            ? CGSize(width: max(32, size + 8), height: max(32, size + 8))
            : CGSize(width: 32, height: 32)
        return Button {
            model.setActiveSize(size)
        } label: {
            sizePreview(size, selected: isSelected)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background(
                    isSelected ? Color.accentColor.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(Int(size)) px")
    }

    @ViewBuilder
    private func sizePreview(_ size: CGFloat, selected: Bool) -> some View {
        let tint = selected ? Color.accentColor : Color.primary.opacity(0.72)
        let index = model.activeSizeOptions.firstIndex(of: size) ?? 0
        switch model.tool {
        case .rectangle, .ellipse, .arrow:
            Capsule()
                .fill(tint)
                .frame(width: 17, height: [1.5, 3, 5][min(index, 2)])
        case .pen, .highlight:
            Circle()
                .fill(tint)
                .frame(width: [6, 10, 15][min(index, 2)], height: [6, 10, 15][min(index, 2)])
        case .mosaic:
            mosaicSizePreview(size: size, tint: tint)
        case .text:
            Text(verbatim: "T")
                .font(.system(size: [10, 13, 17][min(index, 2)], weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func mosaicSizePreview(size: CGFloat, tint: Color) -> some View {
        ScreenshotMosaicGlyph(color: tint, size: size)
    }

    private func colorButton(_ swatch: Color) -> some View {
        Button {
            model.color = swatch
        } label: {
            ZStack {
                Circle()
                    .fill(swatch)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle().strokeBorder(
                            model.color == swatch ? Color.white : Color.white.opacity(0.25),
                            lineWidth: model.color == swatch ? 2 : 0.5
                        )
                    }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mosaicShapeButton(_ shape: ScreenshotMosaicBrushShape) -> some View {
        let isSelected = model.mosaicBrushShape == shape
        return Button {
            model.mosaicBrushShape = shape
        } label: {
            Image(systemName: shape.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.72))
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? Color.accentColor.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(shape == .circle ? "Circle".localized : "Square".localized)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.orange)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Cancel".localized)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Done".localized)
    }

    private func toolButton(_ tool: ScreenshotAnnotationTool) -> some View {
        Button {
            model.commitInlineTextIfNeeded()
            model.tool = tool
        } label: {
            Group {
                if tool == .text {
                    Text(verbatim: "T")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                } else if tool == .mosaic {
                    ScreenshotMosaicGlyph(
                        color: model.tool == tool ? Color.accentColor : Color.primary
                    )
                } else {
                    Image(systemName: tool.icon)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
                .foregroundStyle(model.tool == tool ? Color.accentColor : Color.primary)
                .frame(width: 32, height: 32)
                .background(
                    model.tool == tool ? Color.accentColor.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tool.title.localized)
    }

    private func actionButton(
        _ icon: String,
        enabled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(help)
    }

    private func dragGesture(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                canvasPointerLocation = value.location
                let point = CGPoint(
                    x: value.location.x / max(fit.width, 1) * model.image.size.width,
                    y: value.location.y / max(fit.height, 1) * model.image.size.height
                )
                let clamped = CGPoint(
                    x: min(max(0, point.x), model.image.size.width),
                    y: min(max(0, point.y), model.image.size.height)
                )
                if model.draft == nil {
                    model.begin(at: clamped)
                } else {
                    model.move(to: clamped)
                }
            }
            .onEnded { _ in model.end() }
    }

    private func draw(
        _ stroke: ScreenshotStroke,
        in context: inout GraphicsContext,
        imageSize: CGSize,
        fit: CGSize
    ) {
        let scaleX = fit.width / max(imageSize.width, 1)
        let scaleY = fit.height / max(imageSize.height, 1)
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        let lineWidth = max(1, stroke.lineWidth * scaleX)

        switch stroke.kind {
        case .pen, .highlight, .mosaic:
            guard let first = stroke.points.first else { return }
            var path = Path()
            path.move(to: map(first))
            stroke.points.dropFirst().forEach { path.addLine(to: map($0)) }
            let isMosaic = stroke.kind == .mosaic
            context.stroke(
                path,
                with: .color(isMosaic ? .black.opacity(0.22) : stroke.color.opacity(stroke.kind == .highlight ? 0.35 : 1)),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: isMosaic && stroke.mosaicShape == .square ? .square : .round,
                    lineJoin: isMosaic && stroke.mosaicShape == .square ? .bevel : .round
                )
            )
        case .rectangle, .ellipse:
            guard stroke.points.count >= 2 else { return }
            let first = map(stroke.points[0])
            let second = map(stroke.points[1])
            let rect = CGRect(
                x: min(first.x, second.x),
                y: min(first.y, second.y),
                width: abs(first.x - second.x),
                height: abs(first.y - second.y)
            )
            if stroke.kind == .ellipse {
                context.stroke(Path(ellipseIn: rect), with: .color(stroke.color), lineWidth: lineWidth)
            } else {
                context.stroke(Path(rect), with: .color(stroke.color), lineWidth: lineWidth)
            }
        case .arrow:
            guard stroke.points.count >= 2 else { return }
            let start = map(stroke.points[0])
            let end = map(stroke.points[1])
            let distance = hypot(end.x - start.x, end.y - start.y)
            guard distance >= 1 else { return }
            let angle = atan2(end.y - start.y, end.x - start.x)
            let desiredLength = (10 + stroke.lineWidth * 2) * scaleX
            let length = min(desiredLength, max(2, distance * 0.45))
            let left = CGPoint(
                x: end.x - length * cos(angle - .pi / 6),
                y: end.y - length * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: end.x - length * cos(angle + .pi / 6),
                y: end.y - length * sin(angle + .pi / 6)
            )
            let bodyEnd = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            var path = Path()
            path.move(to: start)
            path.addLine(to: bodyEnd)
            context.stroke(
                path,
                with: .color(stroke.color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            var head = Path()
            head.move(to: end)
            head.addLine(to: left)
            head.addLine(to: right)
            head.closeSubpath()
            context.fill(head, with: .color(stroke.color))
        case .text(let value):
            guard let point = stroke.points.first.map(map) else { return }
            context.draw(
                Text(value)
                    .font(.system(size: max(12, stroke.lineWidth * scaleX), weight: .semibold))
                    .foregroundStyle(stroke.color),
                at: point,
                anchor: .topLeading
            )
        }
    }

    private func toolbarX(in container: CGSize) -> CGFloat {
        let halfWidth: CGFloat = min(350, max(0, container.width / 2 - 12))
        return min(max(canvasRect.midX, halfWidth), container.width - halfWidth)
    }

    private func toolbarY(in container: CGSize) -> CGFloat {
        let offset: CGFloat = 58
        let below = canvasRect.maxY + offset
        if below <= container.height - offset { return below }
        return max(offset, canvasRect.minY - offset)
    }
}

private extension View {
    func toolbarSurface() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
    }
}

@MainActor
final class ScreenshotEditorController: NSWindowController, NSWindowDelegate {
    private let model: ScreenshotEditorModel
    private var onFinish: (() -> Void)?
    private var isClosing = false
    private var hostingController: NSHostingController<ScreenshotAnnotatorView>?

    init(
        image: CGImage,
        selectionRect: CGRect,
        backdrop: ScreenshotDesktopSnapshot,
        onFinish: @escaping () -> Void
    ) {
        // Annotation sizes are expressed in screen points. Keeping the NSImage at
        // the selected region's logical size prevents Retina captures from halving
        // brush cursors and text while the backing CGImage remains full resolution.
        self.model = ScreenshotEditorModel(
            image: NSImage(cgImage: image, size: selectionRect.size)
        )
        self.onFinish = onFinish

        let screens = NSScreen.screens
        let desktopFrame = screens.reduce(CGRect.null) { $0.union($1.frame) }
        let localCanvasRect = CGRect(
            x: selectionRect.minX - desktopFrame.minX,
            y: desktopFrame.maxY - selectionRect.maxY,
            width: selectionRect.width,
            height: selectionRect.height
        )
        let window = ScreenshotEditorWindow(
            contentRect: desktopFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.setFrame(desktopFrame, display: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        super.init(window: window)
        window.delegate = self

        let rootView = NSView(frame: CGRect(origin: .zero, size: desktopFrame.size))
        rootView.wantsLayer = true

        let backdropView = ScreenshotEditorBackdropView(
            desktopFrame: desktopFrame,
            displays: backdrop.displays
        )
        backdropView.frame = rootView.bounds
        backdropView.autoresizingMask = [.width, .height]
        rootView.addSubview(backdropView)

        let hostingController = NSHostingController(
            rootView: ScreenshotAnnotatorView(
                model: model,
                canvasRect: localCanvasRect,
                onConfirm: { [weak self] in self?.confirmAndCopy() },
                onCancel: { [weak self] in self?.closeSession() },
                onSave: { [weak self] in self?.save() }
            )
        )
        hostingController.view.frame = rootView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        hostingController.view.wantsLayer = true
        // Keep SwiftUI translucent so the AppKit-frozen backdrop stays visible
        // underneath the dimmer from the very first composited frame.
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.addSubview(hostingController.view)
        self.hostingController = hostingController

        window.contentView = rootView
        window.setFrame(desktopFrame, display: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        window?.contentView?.layoutSubtreeIfNeeded()
        window?.displayIfNeeded()
        window?.orderFrontRegardless()
        window?.makeKey()
    }

    private func confirmAndCopy() {
        guard copyRenderedImage() else { return }
        NSSound(named: "Tink")?.play()
        closeSession()
    }

    private func copyRenderedImage() -> Bool {
        guard let image = model.exportImage() else {
            showEditorError(ScreenshotCaptureError.captureFailed)
            return false
        }
        do {
            try ScreenshotCapture.copyToPasteboard(image)
            return true
        } catch {
            showEditorError(error)
            return false
        }
    }

    private func save() {
        guard let image = model.exportImage() else {
            showEditorError(ScreenshotCaptureError.captureFailed)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "MachKit Screenshot.png".localized
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let representation = NSBitmapImageRep(cgImage: image)
        do {
            guard let data = representation.representation(using: .png, properties: [:]) else {
                throw ScreenshotCaptureError.captureFailed
            }
            try data.write(to: url, options: .atomic)
        } catch {
            showEditorError(error)
        }
    }

    private func showEditorError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot".localized
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }

    private func closeSession() {
        guard !isClosing else { return }
        isClosing = true
        let finish = onFinish
        onFinish = nil
        window?.orderOut(nil)
        window?.close()
        finish?()
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosing else { return }
        isClosing = true
        let finish = onFinish
        onFinish = nil
        finish?()
    }
}

private final class ScreenshotEditorWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// AppKit-backed freeze so the editor's first on-screen frame already covers the
/// desktop. SwiftUI alone can lag one frame and flash the live screen.
private final class ScreenshotEditorBackdropView: NSView {
    private let layers: [(frame: CGRect, image: NSImage)]

    init(desktopFrame: CGRect, displays: [ScreenshotDisplayBackdrop]) {
        self.layers = displays.map { display in
            let local = CGRect(
                x: display.frame.minX - desktopFrame.minX,
                y: display.frame.minY - desktopFrame.minY,
                width: display.frame.width,
                height: display.frame.height
            )
            let image = NSImage(
                cgImage: display.image,
                size: NSSize(width: display.image.width, height: display.image.height)
            )
            return (local, image)
        }
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        for layer in layers {
            layer.image.draw(
                in: layer.frame,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }
    }
}
