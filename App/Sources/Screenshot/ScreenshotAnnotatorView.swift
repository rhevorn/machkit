import AppKit
import MachKitCore
import SwiftUI

@MainActor
private enum ScreenshotCursorFactory {
    static func cursor(
        for tool: ScreenshotAnnotationTool,
        ink: ScreenshotInk,
        lineWidth: CGFloat,
        canvasScale: CGFloat,
        mosaicMode: ScreenshotMosaicMode,
        mosaicBrushShape: ScreenshotMosaicBrushShape
    ) -> NSCursor {
        switch tool {
        case .pen:
            return brushCursor(
                diameter: max(8, lineWidth * canvasScale),
                color: ink.nsColor,
                shape: .circle
            )
        case .highlight:
            return brushCursor(
                diameter: max(14, lineWidth * canvasScale),
                color: ink.nsColor.withAlphaComponent(0.35),
                shape: .circle
            )
        case .mosaic:
            guard mosaicMode == .brush else { return .crosshair }
            return brushCursor(
                diameter: max(10, lineWidth * canvasScale),
                color: NSColor.black.withAlphaComponent(0.22),
                shape: mosaicBrushShape
            )
        case .text:
            return .iBeam
        case .rectangle, .ellipse, .arrow:
            return .crosshair
        }
    }

    private static func brushCursor(
        diameter: CGFloat,
        color: NSColor,
        shape: ScreenshotMosaicBrushShape
    ) -> NSCursor {
        let brushDiameter = min(48, ceil(diameter))
        let side = brushDiameter + 6
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let inset = rect.insetBy(dx: 3, dy: 3)
            let path: NSBezierPath
            switch shape {
            case .circle:
                path = NSBezierPath(ovalIn: inset)
            case .square:
                path = NSBezierPath(rect: inset)
            }
            color.setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.95).setStroke()
            path.lineWidth = 3
            path.stroke()
            NSColor.black.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
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

struct ScreenshotAnnotatorView: View {
    @ObservedObject var model: ScreenshotEditorModel
    let toolbarBounds: CGRect
    let onMoveCanvas: (CGRect) -> Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var canvasRect: CGRect
    @State private var isFrameDragging = false
    @GestureState private var frameDragTranslation: CGSize = .zero
    @State private var annotationGestureActive = false
    @State private var pointerIsInsideCanvas = false
    @FocusState private var textFieldIsFocused: Bool

    init(
        model: ScreenshotEditorModel,
        canvasRect: CGRect,
        toolbarBounds: CGRect,
        onMoveCanvas: @escaping (CGRect) -> Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.model = model
        self.toolbarBounds = toolbarBounds
        self.onMoveCanvas = onMoveCanvas
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onSave = onSave
        _canvasRect = State(initialValue: canvasRect)
    }

    var body: some View {
        GeometryReader { proxy in
            let presentedRect = presentedCanvasRect
            ZStack {
                ScreenshotDimmingShape(hole: presentedRect)
                    .fill(
                        Color.black.opacity(0.42),
                        style: FillStyle(eoFill: true)
                    )
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        publishModelUpdate { model.commitInlineTextIfNeeded() }
                    }

                imageCanvas(size: canvasRect.size)
                    .position(x: presentedRect.midX, y: presentedRect.midY)

                floatingToolbar
                    .position(
                        toolbarCenter(in: proxy.size)
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

    private func imageCanvas(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            canvasBackground(size: size)

            Canvas { context, _ in
                for stroke in model.strokes {
                    ScreenshotStrokeRenderer.drawSwiftUI(
                        stroke,
                        in: &context,
                        imageSize: model.image.size,
                        fit: size
                    )
                }
                if let draft = model.draft {
                    ScreenshotStrokeRenderer.drawSwiftUI(
                        draft,
                        in: &context,
                        imageSize: model.image.size,
                        fit: size,
                        showsMosaicSelection: true,
                        mosaicPreviewImage: model.mosaicPreviewImage
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .gesture(dragGesture(size: size))
            .allowsHitTesting(!model.editingText)

            if model.editingText, let point = model.pendingTextPoint {
                let scale = size.width / max(model.image.size.width, 1)
                let fontSize = ScreenshotTextLayout.fontSize(
                    lineWidth: model.activeSize,
                    scale: scale
                )
                let fieldSize = CGSize(
                    width: min(240, max(80, size.width)),
                    height: ScreenshotTextLayout.lineHeight(
                        lineWidth: model.activeSize,
                        scale: scale
                    )
                )
                let fieldOrigin = CGPoint(x: point.x * scale, y: point.y * scale)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        publishModelUpdate {
                            model.commitInlineTextIfNeeded()
                            textFieldIsFocused = false
                        }
                    }
                TextField("Text".localized, text: $model.textDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(model.color)
                    .frame(
                        width: fieldSize.width,
                        height: fieldSize.height,
                        alignment: .topLeading
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    }
                    .position(
                        x: fieldOrigin.x + fieldSize.width / 2,
                        y: fieldOrigin.y + fieldSize.height / 2
                    )
                    .focused($textFieldIsFocused)
                    .onAppear {
                        // Focus after the current update cycle finishes.
                        DispatchQueue.main.async { textFieldIsFocused = true }
                    }
                    .onKeyPress(.return) {
                        publishModelUpdate {
                            model.commitInlineTextIfNeeded()
                            textFieldIsFocused = false
                        }
                        return .handled
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay {
            movableFrameBorder
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !pointerIsInsideCanvas {
                    pointerIsInsideCanvas = true
                    updateCanvasCursor(canvasSize: size)
                }
            case .ended:
                pointerIsInsideCanvas = false
                NSCursor.arrow.set()
            }
        }
        .onChange(of: model.tool) { _, _ in updateCanvasCursor(canvasSize: size) }
        .onChange(of: model.ink) { _, _ in updateCanvasCursor(canvasSize: size) }
        .onChange(of: model.toolSizes) { _, _ in updateCanvasCursor(canvasSize: size) }
        .onChange(of: model.mosaicBrushShape) { _, _ in updateCanvasCursor(canvasSize: size) }
        .onChange(of: model.mosaicMode) { _, _ in updateCanvasCursor(canvasSize: size) }
        .onChange(of: model.editingText) { _, isEditing in
            if isEditing {
                DispatchQueue.main.async { textFieldIsFocused = true }
            }
        }
    }

    @ViewBuilder
    private func canvasBackground(size: CGSize) -> some View {
        if !isFrameDragging {
            Image(nsImage: model.image)
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
        } else {
            // The frozen AppKit backdrop is already underneath this view. A
            // transparent canvas makes the moving frame behave like glass:
            // only the mask hole moves; the desktop bitmap never does.
            Color.clear
        }
    }

    private func updateCanvasCursor(canvasSize: CGSize) {
        guard pointerIsInsideCanvas else {
            NSCursor.arrow.set()
            return
        }
        let scale = canvasSize.width / max(model.image.size.width, 1)
        ScreenshotCursorFactory.cursor(
            for: model.tool,
            ink: model.ink,
            lineWidth: model.activeSize,
            canvasScale: scale,
            mosaicMode: model.mosaicMode,
            mosaicBrushShape: model.mosaicBrushShape
        ).set()
    }

    private var floatingToolbar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(ScreenshotAnnotationTool.allCases) { tool in
                    toolButton(tool)
                }

                toolbarDivider

                actionButton("arrow.uturn.backward", enabled: model.canUndo, help: "Undo".localized, action: model.undo)
                    .keyboardShortcut("z", modifiers: .command)
                actionButton("arrow.uturn.forward", enabled: model.canRedo, help: "Redo".localized, action: model.redo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])

                actionButton(
                    "trash",
                    enabled: model.canUndo || model.canRedo,
                    help: "Clear".localized,
                    action: model.clearAnnotations
                )

                toolbarDivider

                actionButton("square.and.arrow.down", enabled: true, help: "Save…".localized, action: onSave)

                toolbarDivider

                cancelButton
                confirmButton
            }
            .toolbarSurface()

            HStack(spacing: 2) {
                if model.tool == .mosaic {
                    ForEach(ScreenshotMosaicMode.allCases) { mode in
                        mosaicModeButton(mode)
                    }
                    toolbarDivider
                    if model.mosaicMode == .brush {
                        ForEach(ScreenshotMosaicBrushShape.allCases) { shape in
                            mosaicShapeButton(shape)
                        }
                        toolbarDivider
                    }
                }

                if model.tool == .text {
                    textSizeMenu
                } else {
                    Text(verbatim: "\(Int(model.activeSize)) px")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 42)

                    ForEach(model.activeSizeOptions, id: \.self) { size in
                        sizeButton(size)
                    }
                }

                if model.tool.usesColor {
                    toolbarDivider
                    ForEach(ScreenshotInk.allCases) { ink in
                        colorButton(ink)
                    }
                }
            }
            .toolbarSurface()
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }

    private var textSizeMenu: some View {
        Menu {
            ForEach(model.activeSizeOptions, id: \.self) { size in
                Button {
                    model.setActiveSize(size)
                } label: {
                    if model.activeSize == size {
                        Label {
                            Text(verbatim: "\(Int(size)) px")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(verbatim: "\(Int(size)) px")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: "\(Int(model.activeSize)) px")
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Text".localized)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.95))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 3)
    }

    private func sizeButton(_ size: CGFloat) -> some View {
        let isSelected = model.activeSize == size
        let usesActualDiameter = model.tool == .mosaic
            || model.tool == .pen
            || model.tool == .highlight
        let buttonSize = usesActualDiameter
            ? CGSize(width: max(28, size + 4), height: max(28, size + 4))
            : CGSize(width: 28, height: 28)
        return Button {
            model.setActiveSize(size)
        } label: {
            sizePreview(size, selected: isSelected)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background(
                    isSelected && model.tool != .mosaic
                        ? Color.accentColor.opacity(0.16)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: "\(Int(size)) px"))
    }

    @ViewBuilder
    private func sizePreview(_ size: CGFloat, selected: Bool) -> some View {
        let tint = model.tool.usesColor
            ? model.ink.color
            : (selected ? Color.accentColor : Color.primary.opacity(0.72))
        switch model.tool {
        case .rectangle, .ellipse, .arrow:
            Capsule()
                .fill(tint)
                .frame(width: 17, height: size)
        case .pen:
            Circle()
                .fill(tint)
                .frame(width: size, height: size)
        case .highlight:
            Circle()
                .fill(tint.opacity(0.35))
                .frame(width: size, height: size)
        case .mosaic:
            mosaicSizePreview(size: size, tint: tint)
        case .text:
            Text(verbatim: "T")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func mosaicSizePreview(size: CGFloat, tint: Color) -> some View {
        ScreenshotMosaicGlyph(color: tint, size: size)
    }

    private func colorButton(_ ink: ScreenshotInk) -> some View {
        let isSelected = model.ink == ink
        return Button {
            model.ink = ink
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
                Circle()
                    .fill(ink.color)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle().strokeBorder(
                            ink == .white ? Color.secondary.opacity(0.7) : Color.white.opacity(0.35),
                            lineWidth: 0.75
                        )
                    }
            }
            .frame(width: 28, height: 28)
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
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(shape == .circle ? "Circle".localized : "Square".localized)
    }

    private func mosaicModeButton(_ mode: ScreenshotMosaicMode) -> some View {
        let isSelected = model.mosaicMode == mode
        return Button {
            model.mosaicMode = mode
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.72))
                .frame(width: 28, height: 28)
                .background(
                    isSelected && mode == .brush
                        ? Color.accentColor.opacity(0.16)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(mode == .brush ? "Pen".localized : "Rectangle".localized)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.orange)
                .frame(width: 28, height: 28)
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
                .frame(width: 28, height: 28)
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
                .frame(width: 28, height: 28)
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
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(help)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let start = imagePoint(value.startLocation, canvasSize: size)
                let current = imagePoint(value.location, canvasSize: size)
                let isStarting = !annotationGestureActive
                if isStarting { annotationGestureActive = true }
                // Drag callbacks can run inside a view update. Publishing
                // @ObservedObject changes there triggers SwiftUI warnings.
                publishModelUpdate {
                    if isStarting {
                        model.begin(at: start)
                        if current != start { model.move(to: current) }
                    } else {
                        model.move(to: current)
                    }
                }
            }
            .onEnded { _ in
                annotationGestureActive = false
                publishModelUpdate { model.end() }
            }
    }

    private func publishModelUpdate(_ update: @MainActor @escaping () -> Void) {
        Task { @MainActor in update() }
    }

    private func imagePoint(_ location: CGPoint, canvasSize: CGSize) -> CGPoint {
        let point = CGPoint(
            x: location.x / max(canvasSize.width, 1) * model.image.size.width,
            y: location.y / max(canvasSize.height, 1) * model.image.size.height
        )
        return CGPoint(
            x: min(max(0, point.x), model.image.size.width),
            y: min(max(0, point.y), model.image.size.height)
        )
    }

    private var movableFrameBorder: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 1)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                frameDragTarget.frame(height: 8)
                Spacer(minLength: 0)
                frameDragTarget.frame(height: 8)
            }

            HStack(spacing: 0) {
                frameDragTarget.frame(width: 8)
                Spacer(minLength: 0)
                frameDragTarget.frame(width: 8)
            }
        }
    }

    private var frameDragTarget: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(frameMoveGesture)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.openHand.set()
                case .ended:
                    updateCanvasCursor(canvasSize: canvasRect.size)
                }
            }
    }

    private var frameMoveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .updating($frameDragTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onChanged { _ in
                if !isFrameDragging {
                    isFrameDragging = true
                    publishModelUpdate { model.commitInlineTextIfNeeded() }
                    NSCursor.closedHand.set()
                }
            }
            .onEnded { value in
                let destination = clampedCanvasRect(
                    canvasRect.offsetBy(
                        dx: value.translation.width,
                        dy: value.translation.height
                    )
                )
                isFrameDragging = false
                NSCursor.openHand.set()
                // Commit the frame only after the crop succeeds so a failed
                // move cannot leave the hole out of sync with the bitmap.
                if onMoveCanvas(destination) {
                    canvasRect = destination
                }
            }
    }

    private var presentedCanvasRect: CGRect {
        guard isFrameDragging else { return canvasRect }
        return clampedCanvasRect(
            canvasRect.offsetBy(
                dx: frameDragTranslation.width,
                dy: frameDragTranslation.height
            )
        )
    }

    private func clampedCanvasRect(_ proposed: CGRect) -> CGRect {
        let available = toolbarBounds.isNull || toolbarBounds.isEmpty
            ? CGRect(origin: .zero, size: proposed.size)
            : toolbarBounds
        let alignedX = proposed.minX.rounded()
        let alignedY = proposed.minY.rounded()
        return CGRect(
            x: min(max(available.minX, alignedX), max(available.minX, available.maxX - proposed.width)),
            y: min(max(available.minY, alignedY), max(available.minY, available.maxY - proposed.height)),
            width: proposed.width,
            height: proposed.height
        )
    }

    private func toolbarCenter(in container: CGSize) -> CGPoint {
        let containerRect = CGRect(origin: .zero, size: container)
        let visibleBounds = toolbarBounds.intersection(containerRect)
        return ScreenshotGeometry.toolbarCenter(
            canvasRect: canvasRect,
            displayRect: visibleBounds.isNull ? containerRect : visibleBounds
        )
    }
}

private struct ScreenshotDimmingShape: Shape {
    var hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(hole.intersection(rect))
        return path
    }
}

private extension View {
    func toolbarSurface() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color(nsColor: .separatorColor).opacity(0.9),
                        lineWidth: 1
                    )
            }
    }
}
