import AppKit
import SwiftUI

/// Accessibility helpers shared across the UI.
///
/// macOS exposes a handful of system-wide accessibility preferences through
/// `NSWorkspace`. These mirror the SwiftUI environment values (`accessibilityReduceMotion`,
/// `colorSchemeContrast`) but are readable from imperative, non-`View` contexts such as
/// `withAnimation` call sites.
enum Accessibility {
    /// Whether the user has enabled "Reduce Motion" in System Settings.
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Whether the user has enabled "Increase Contrast" in System Settings.
    static var increaseContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

/// Runs `body` inside `withAnimation`, but honors the user's "Reduce Motion"
/// preference by applying the change instantly (no animation) when it is enabled.
///
/// Drop-in replacement for `withAnimation { ... }`.
@discardableResult
func withMotion<Result>(
    _ animation: Animation = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(Accessibility.reduceMotion ? nil : animation, body)
}

extension View {
    /// Marks a view as a single accessibility element with the given label, and
    /// optionally a trait. Convenience for icon-only controls.
    func accessibleIconButton(_ label: String, hint: String? = nil) -> some View {
        accessibilityLabel(label)
            .modifier(OptionalHint(hint: hint))
    }
}

private struct OptionalHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
