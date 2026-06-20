import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case blue   = "blue"
    case purple = "purple"
    case mint   = "mint"
    case orange = "orange"
    case pink   = "pink"
    case red    = "red"
    case gold   = "gold"
    case cyan   = "cyan"
    case indigo = "indigo"
    case emerald = "emerald"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .blue:   return Color(red: 0.25, green: 0.55, blue: 1.00)
        case .purple: return Color(red: 0.60, green: 0.30, blue: 1.00)
        case .mint:   return Color(red: 0.10, green: 0.78, blue: 0.55)
        case .orange: return Color(red: 1.00, green: 0.55, blue: 0.10)
        case .pink:   return Color(red: 1.00, green: 0.25, blue: 0.65)
        case .red:    return Color(red: 0.95, green: 0.18, blue: 0.22)
        case .gold:   return Color(red: 0.95, green: 0.78, blue: 0.10)
        case .cyan:   return Color(red: 0.05, green: 0.78, blue: 0.95)
        case .indigo: return Color(red: 0.35, green: 0.25, blue: 0.90)
        case .emerald: return Color(red: 0.13, green: 0.70, blue: 0.35)
        }
    }

    var accentEnd: Color {
        switch self {
        case .blue:   return Color(red: 0.10, green: 0.78, blue: 0.88)
        case .purple: return Color(red: 0.85, green: 0.40, blue: 1.00)
        case .mint:   return Color(red: 0.05, green: 0.90, blue: 0.70)
        case .orange: return Color(red: 1.00, green: 0.75, blue: 0.00)
        case .pink:   return Color(red: 1.00, green: 0.50, blue: 0.80)
        case .red:    return Color(red: 1.00, green: 0.42, blue: 0.28)
        case .gold:   return Color(red: 1.00, green: 0.92, blue: 0.35)
        case .cyan:   return Color(red: 0.15, green: 0.92, blue: 1.00)
        case .indigo: return Color(red: 0.55, green: 0.40, blue: 1.00)
        case .emerald: return Color(red: 0.30, green: 0.88, blue: 0.50)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
