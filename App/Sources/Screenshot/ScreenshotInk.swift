import AppKit
import SwiftUI

enum ScreenshotInk: String, CaseIterable, Identifiable {
    case red
    case yellow
    case blue
    case green
    case black
    case gray
    case white

    var id: String { rawValue }

    /// Single source of truth for ink colors; the SwiftUI and AppKit
    /// representations both derive from it so they can't drift apart.
    private var rgb: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .red: (1, 0.23, 0.19)
        case .yellow: (1, 0.8, 0)
        case .blue: (0.04, 0.52, 1)
        case .green: (0.2, 0.78, 0.35)
        case .black: (0.08, 0.08, 0.1)
        case .gray: (0.56, 0.56, 0.58)
        case .white: (1, 1, 1)
        }
    }

    var color: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var nsColor: NSColor {
        NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

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

enum ScreenshotMosaicBrushShape: String, CaseIterable, Identifiable {
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

enum ScreenshotMosaicMode: String, CaseIterable, Identifiable {
    case brush
    case rectangle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brush: "paintbrush.pointed.fill"
        case .rectangle: "rectangle.dashed"
        }
    }
}
