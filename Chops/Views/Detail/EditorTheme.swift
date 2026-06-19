import AppKit

enum EditorTheme {
    // MARK: - Editor Font

    static let defaultEditorFontSize: CGFloat = 13
    static let minEditorFontSize: CGFloat = 10
    static let maxEditorFontSize: CGFloat = 24

    /// User-adjustable editor font size (Settings → Library). macOS lacks a global
    /// Dynamic Type scale, so the editor exposes its own size preference.
    static var editorFontSize: CGFloat {
        let stored = UserDefaults.standard.object(forKey: "editorFontSize") as? Double
        let value = stored.map { CGFloat($0) } ?? defaultEditorFontSize
        return min(maxEditorFontSize, max(minEditorFontSize, value))
    }

    static var editorFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }

    // MARK: - Margins

    static let editorInsetX: CGFloat = 48
    static let editorInsetTop: CGFloat = 12

    // MARK: - Line Spacing

    static let lineSpacing: CGFloat = 6

    static var editorLineHeight: CGFloat {
        let font = editorFont
        return ceil(font.ascender - font.descender + font.leading) + lineSpacing
    }

    static var editorBaselineOffset: CGFloat {
        let font = editorFont
        let naturalHeight = ceil(font.ascender - font.descender + font.leading)
        return (editorLineHeight - naturalHeight) / 2
    }

    // MARK: - Dynamic Colors

    //
    // Body/emphasis colors use AppKit's semantic system colors so they track
    // light/dark, vibrancy, and the "Increase Contrast" setting automatically.
    // The two colors that carry hue (inline code, frontmatter) are resolved per
    // appearance and bumped further when high contrast is active; every value is
    // chosen to clear 4.5:1 against the editor background.

    static let textColor = NSColor.textColor
    static let headingColor = NSColor.labelColor
    static let boldColor = NSColor.labelColor
    static let italicColor = NSColor.labelColor
    static let linkColor = NSColor.linkColor

    /// Markdown syntax delimiters (#, *, -, >). Dimmed but kept readable.
    static let syntaxColor = NSColor(name: "editorSyntax") { appearance in
        appearance.isHighContrast ? .labelColor : .secondaryLabelColor
    }

    static let blockquoteColor = NSColor(name: "editorBlockquote") { appearance in
        appearance.isHighContrast ? .labelColor : .secondaryLabelColor
    }

    static let codeColor = NSColor(name: "editorCode") { appearance in
        switch (appearance.isDark, appearance.isHighContrast) {
        case (true, true): NSColor(red: 1.00, green: 0.62, blue: 0.62, alpha: 1)
        case (true, false): NSColor(red: 0.92, green: 0.49, blue: 0.49, alpha: 1)
        case (false, true): NSColor(red: 0.58, green: 0.09, blue: 0.07, alpha: 1)
        case (false, false): NSColor(red: 0.70, green: 0.15, blue: 0.12, alpha: 1)
        }
    }

    static let frontmatterColor = NSColor(name: "editorFrontmatter") { appearance in
        switch (appearance.isDark, appearance.isHighContrast) {
        case (true, true): NSColor(red: 0.78, green: 0.78, blue: 0.94, alpha: 1)
        case (true, false): NSColor(red: 0.66, green: 0.66, blue: 0.85, alpha: 1)
        case (false, true): NSColor(red: 0.16, green: 0.16, blue: 0.44, alpha: 1)
        case (false, false): NSColor(red: 0.26, green: 0.26, blue: 0.56, alpha: 1)
        }
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// True when the user has enabled "Increase Contrast" — macOS exposes this
    /// as dedicated high-contrast appearance variants.
    var isHighContrast: Bool {
        bestMatch(from: [
            .aqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastDarkAqua,
        ]).map { name in
            name == .accessibilityHighContrastAqua || name == .accessibilityHighContrastDarkAqua
        } ?? false
    }
}
