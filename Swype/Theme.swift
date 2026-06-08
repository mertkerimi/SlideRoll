import SwiftUI

enum Theme {
    // Adaptive backgrounds
    static let bg          = Color(.systemBackground)
    static let surface     = Color(.secondarySystemBackground)
    static let surfaceHigh = Color(.tertiarySystemBackground)

    // Accent — updated by LanguageManager when theme changes
    static var accent: Color    = ColorTheme.blue.accent
    static var accentEnd: Color = ColorTheme.blue.accentEnd

    static let green  = Color(red: 0.12, green: 0.80, blue: 0.50)
    static let red    = Color(red: 1.00, green: 0.25, blue: 0.32)
    static let orange = Color(red: 1.00, green: 0.60, blue: 0.10)

    // Text — system adaptive
    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary  = Color(.tertiaryLabel)

    // Card border
    static let border = Color(.separator).opacity(0.5)

    // Gradients — recomputed via helpers so callers always get fresh value
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let greenGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.72, blue: 0.42), green],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let redGradient = LinearGradient(
        colors: [Color(red: 0.85, green: 0.10, blue: 0.20), red],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let orangeGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.45, blue: 0.05), orange],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
