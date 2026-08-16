import AppKit
import MachKitCore
import SwiftUI

@MainActor
private enum ScreenshotCursorFactory {
    static func cursor(
        for tool: ScreenshotAnnotationTool,
        ink: ScreenshotInk,
        lineWidth: CGFloat,
        canvasScale: CGFloat
    ) -> NSCursor {
        switch tool {
        case .pen:
            return brushCursor(
                diameter: max(8, lineWidth * canvasScale),
                color: ink.nsColor
            )
        case .highlight:
            return brushCursor(
                diameter: max(14, lineWidth * canvasScale),
                color: ink.nsColor.withAlphaComponent(0.35)
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

struct ScreenshotAnnotatorView: View {
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
                    ScreenshotStrokeRenderer.drawSwiftUI(
                        stroke,
                        in: &context,
                        imageSize: model.image.size,
                        fit: fit.size
                    )
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
        .onChange(of: model.ink) { _, _ in updateCanvasCursor(fit: fit) }
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
            ink: model.ink,
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
                    ForEach(ScreenshotInk.allCases) { ink in
                        colorButton(ink)
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

    private func colorButton(_ ink: ScreenshotInk) -> some View {
        let isSelected = model.ink == ink
        return Button {
            model.ink = ink
        } label: {
            ZStack {
                Circle()
                    .fill(ink.color)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle().strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.25),
                            lineWidth: isSelected ? 2 : 0.5
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
