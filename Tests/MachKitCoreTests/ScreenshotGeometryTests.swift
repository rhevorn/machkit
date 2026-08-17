import CoreGraphics
import Testing
@testable import MachKitCore

@Test func screenshotGeometryMapsAppKitSelectionIntoPixelCrop() {
    let display = CGRect(x: 100, y: 200, width: 1000, height: 800)
    let selection = CGRect(x: 300, y: 400, width: 200, height: 100)
    let pixel = ScreenshotGeometry.pixelRect(
        selection: selection,
        displayFrame: display,
        imageWidth: 2000,
        imageHeight: 1600
    )
    #expect(pixel == CGRect(x: 400, y: 1000, width: 400, height: 200))
}

@Test func screenshotGeometryRejectsTinyOrEmptySelections() {
    let display = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(
        ScreenshotGeometry.pixelRect(
            selection: CGRect(x: 10, y: 10, width: 1, height: 1),
            displayFrame: display,
            imageWidth: 100,
            imageHeight: 100
        ) == nil
    )
    #expect(
        ScreenshotGeometry.pixelRect(
            selection: .null,
            displayFrame: display,
            imageWidth: 100,
            imageHeight: 100
        ) == nil
    )
}

@Test func screenshotGeometryClampsToImageBounds() {
    let display = CGRect(x: 0, y: 0, width: 100, height: 100)
    let pixel = ScreenshotGeometry.pixelRect(
        selection: CGRect(x: -20, y: -20, width: 80, height: 80),
        displayFrame: display,
        imageWidth: 100,
        imageHeight: 100
    )
    #expect(pixel == CGRect(x: 0, y: 40, width: 60, height: 60))
}

@Test func screenshotGeometryRoundsOriginWithoutExpandingCropSize() {
    let display = CGRect(x: 0, y: 0, width: 100, height: 100)
    let pixel = ScreenshotGeometry.pixelRect(
        selection: CGRect(x: 10.25, y: 20.25, width: 20, height: 10),
        displayFrame: display,
        imageWidth: 200,
        imageHeight: 200
    )

    #expect(pixel == CGRect(x: 21, y: 140, width: 40, height: 20))
}

@Test func screenshotEditorCanvasRectUsesTheSelectedDisplaysCoordinates() {
    let display = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
    let selection = CGRect(x: 1712, y: 382, width: 400, height: 300)

    #expect(
        ScreenshotGeometry.editorCanvasRect(
            selection: selection,
            displayFrame: display
        ) == CGRect(x: 200, y: 300, width: 400, height: 300)
    )
}

@Test func screenshotToolbarStaysOnTheSelectedDisplay() {
    let display = CGRect(x: 1920, y: 0, width: 1280, height: 900)
    let nearLeftEdge = CGRect(x: 1924, y: 100, width: 160, height: 120)
    let center = ScreenshotGeometry.toolbarCenter(
        canvasRect: nearLeftEdge,
        displayRect: display
    )

    #expect(center.x == 2282)
    #expect(center.y == 278)
    #expect(center.x - 350 >= display.minX + 12)
    #expect(center.x + 350 <= display.maxX - 12)
}

@Test func screenshotToolbarMovesAboveASelectionNearTheBottomEdge() {
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let nearBottom = CGRect(x: 500, y: 760, width: 300, height: 120)
    let center = ScreenshotGeometry.toolbarCenter(
        canvasRect: nearBottom,
        displayRect: display
    )

    #expect(center == CGPoint(x: 650, y: 702))
}

@Test func screenshotTextFontSizeKeepsReadableFloor() {
    #expect(ScreenshotGeometry.textFontSize(lineWidth: 4, scale: 1) == 12)
    #expect(ScreenshotGeometry.textFontSize(lineWidth: 24, scale: 2) == 48)
}

@Test func screenshotArrowHeadReturnsNilForDegenerateSegment() {
    #expect(
        ScreenshotGeometry.arrowHead(
            from: .zero,
            to: .zero,
            lineWidth: 4
        ) == nil
    )
    let parts = ScreenshotGeometry.arrowHead(
        from: .zero,
        to: CGPoint(x: 100, y: 0),
        lineWidth: 4
    )
    #expect(parts != nil)
    #expect(parts?.left.y != parts?.right.y)
}
