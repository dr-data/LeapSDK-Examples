import SwiftUI

/// Adaptive color palette that works in both light and dark mode.
/// All views should use these instead of hardcoded colors.
enum AppColors {
    static var background: Color {
        Color(UIColor.systemBackground)
    }

    static var secondaryBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }

    static var cardBackground: Color {
        Color(UIColor.secondarySystemGroupedBackground)
    }

    static var primaryText: Color {
        Color(UIColor.label)
    }

    static var secondaryText: Color {
        Color(UIColor.secondaryLabel)
    }

    static var tertiaryText: Color {
        Color(UIColor.tertiaryLabel)
    }

    static var separator: Color {
        Color(UIColor.separator)
    }

    static let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
    static let greenColor = Color(red: 0.133, green: 0.773, blue: 0.369)
}
