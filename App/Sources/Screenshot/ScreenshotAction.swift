import Foundation

enum ScreenshotAction: String, CaseIterable, Identifiable {
    case capture = "__screenshot"

    var id: String { rawValue }

    var title: String {
        "Screenshot"
    }

    var detail: String {
        "Drag to select an area, then annotate or copy the screenshot."
    }

    var icon: String {
        "rectangle.dashed"
    }

    var localizedTitle: String { title.localized }
    var localizedDetail: String { detail.localized }

    static let allIDs = Set(allCases.map(\.rawValue))
}
