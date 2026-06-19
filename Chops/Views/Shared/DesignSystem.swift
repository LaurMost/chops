import SwiftUI

// MARK: - Spacing

/// 4pt incremental spacing scale. Use these instead of magic numbers so spacing
/// stays consistent across the app.
enum Spacing {
    /// 2pt
    static let xxs: CGFloat = 2
    /// 4pt
    static let xs: CGFloat = 4
    /// 8pt
    static let sm: CGFloat = 8
    /// 12pt
    static let md: CGFloat = 12
    /// 16pt
    static let lg: CGFloat = 16
    /// 24pt
    static let xl: CGFloat = 24
    /// 32pt
    static let xxl: CGFloat = 32
}

// MARK: - Layering

/// Explicit z-index scale for `ZStack` overlays so stacking order is intentional
/// and consistent rather than relying on implicit declaration order.
enum Layering {
    static let content: Double = 0
    static let floatingAction: Double = 10
    static let bar: Double = 20
    static let overlay: Double = 40
    static let modalChrome: Double = 100
}

// MARK: - Sizing

/// Window and content sizing tokens.
enum Sizing {
    /// Minimum overall window width (3-column split needs room to breathe).
    static let windowMinWidth: CGFloat = 900
    /// Minimum overall window height.
    static let windowMinHeight: CGFloat = 500
    /// Sensible first-launch window size.
    static let windowIdealWidth: CGFloat = 1200
    static let windowIdealHeight: CGFloat = 760

    /// Maximum width for long-form reading/editing so line length stays in the
    /// comfortable 60–75 character range on wide windows. Matches the markdown
    /// preview's `max-width: 672px` plus editor gutters.
    static let readingMaxWidth: CGFloat = 720

    /// Standard sheet widths.
    static let sheetNarrow: CGFloat = 440
    static let sheetWide: CGFloat = 560

    /// Settings window width.
    static let settingsWidth: CGFloat = 520
    /// Default sheet height for the registry browser.
    static let sheetTallHeight: CGFloat = 500

    /// Minimum height the editor keeps when the compose panel is open, so the
    /// panel can never squeeze it to zero.
    static let editorMinHeight: CGFloat = 160
}

// MARK: - Radius

/// Corner-radius tokens to replace scattered `cornerRadius:` literals.
enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
}
