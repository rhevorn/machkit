import CoreGraphics
import Foundation

struct ScreenshotStroke: Identifiable, Equatable {
    enum Kind: Equatable {
        case rectangle
        case ellipse
        case arrow
        case pen
        case highlight
        case mosaic
        case text(String)
    }

    let id: UUID
    var kind: Kind
    var points: [CGPoint]
    var ink: ScreenshotInk
    var lineWidth: CGFloat
    var mosaicShape: ScreenshotMosaicBrushShape

    init(
        id: UUID = UUID(),
        kind: Kind,
        points: [CGPoint],
        ink: ScreenshotInk,
        lineWidth: CGFloat,
        mosaicShape: ScreenshotMosaicBrushShape = .square
    ) {
        self.id = id
        self.kind = kind
        self.points = points
        self.ink = ink
        self.lineWidth = lineWidth
        self.mosaicShape = mosaicShape
    }
}
