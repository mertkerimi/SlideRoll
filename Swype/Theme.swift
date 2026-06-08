import SwiftUI

enum Theme {
    // Adaptive backgrounds — system dark/light'a göre otomatik değişir
    static let bg          = Color(.systemBackground)
    static let surface     = Color(.secondarySystemBackground)
    static let surfaceHigh = Color(.tertiarySystemBackground)

    // Accent — her iki modda canlı durur
    static let accent      = Color(red: 0.25, green: 0.55, blue: 1.00)
    static let accentEnd   = Color(red: 0.10, green: 0.78, blue: 0.88)

    static let green       = Color(red: 0.12, green: 0.80, blue: 0.50)
    static let red         = Color(red: 1.00, green: 0.25, blue: 0.32)
    static let orange      = Color(red: 1.00, green: 0.60, blue: 0.10)

    // Text — system adaptive
    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary  = Color(.tertiaryLabel)

    // Card border
    static let border = Color(.separator).opacity(0.5)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [accent, accentEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
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
