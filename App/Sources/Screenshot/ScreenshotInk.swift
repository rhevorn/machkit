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

    var color: Color {
        switch self {
        case .red: Color(red: 1, green: 0.23, blue: 0.19)
        case .yellow: Color(red: 1, green: 0.8, blue: 0)
        case .blue: Color(red: 0.04, green: 0.52, blue: 1)
        case .green: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .black: Color(red: 0.08, green: 0.08, blue: 0.1)
        case .gray: Color(red: 0.56, green: 0.56, blue: 0.58)
        case .white: .white
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        case .yellow: NSColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        case .blue: NSColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        case .green: NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        case .black: NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
        case .gray: NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
        case .white: .white
        }
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
