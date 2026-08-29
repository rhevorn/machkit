import CoreGraphics

/// Shared native spacing scale. Prefer these over one-off padding values.
enum MachKitLayout {
    /// Distance from the window edge to headers and page content.
    static let pageMargin: CGFloat = 20

    /// Internal padding for large featured / hero cards.
    static let heroPadding: CGFloat = 20

    /// Left/right padding inside list and inventory rows.
    static let rowPaddingHorizontal: CGFloat = 16

    /// Top/bottom padding inside list and inventory rows.
    static let rowPaddingVertical: CGFloat = 10

    /// Internal padding for standard cards and panels.
    static let cardPadding: CGFloat = 16

    /// Internal padding for compact banners and tip strips.
    static let bannerPadding: CGFloat = 12

    /// Padding for modal sheets and result panels.
    static let sheetPadding: CGFloat = 24

    /// Vertical gap between major page sections.
    static let sectionSpacing: CGFloat = 16

    /// Spacing between clustered controls (chips, inline buttons).
    static let controlSpacing: CGFloat = 8
}
