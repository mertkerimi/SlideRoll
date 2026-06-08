import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case blue   = "blue"
    case purple = "purple"
    case mint   = "mint"
    case orange = "orange"
    case pink   = "pink"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:   return "Mavi"
        case .purple: return "Mor"
        case .mint:   return "Yeşil"
        case .orange: return "Turuncu"
        case .pink:   return "Pembe"
        }
    }

    var accent: Color {
        switch self {
        case .blue:   return Color(red: 0.25, green: 0.55, blue: 1.00)
        case .purple: return Color(red: 0.60, green: 0.30, blue: 1.00)
        case .mint:   return Color(red: 0.10, green: 0.78, blue: 0.55)
        case .orange: return Color(red: 1.00, green: 0.55, blue: 0.10)
        case .pink:   return Color(red: 1.00, green: 0.25, blue: 0.65)
        }
    }

    var accentEnd: Color {
        switch self {
        case .blue:   return Color(red: 0.10, green: 0.78, blue: 0.88)
        case .purple: return Color(red: 0.85, green: 0.40, blue: 1.00)
        case .mint:   return Color(red: 0.05, green: 0.90, blue: 0.70)
        case .orange: return Color(red: 1.00, green: 0.75, blue: 0.00)
        case .pink:   return Color(red: 1.00, green: 0.50, blue: 0.80)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
