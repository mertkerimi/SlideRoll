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

    var id: String { rawValue }

    var displayName: String { displayName(in: .turkish) }

    func displayName(in language: AppLanguage) -> String {
        switch language {
        case .turkish:
            switch self {
            case .blue:   return "Mavi"
            case .purple: return "Mor"
            case .mint:   return "Yeşil"
            case .orange: return "Turuncu"
            case .pink:   return "Pembe"
            case .red:    return "Kırmızı"
            case .gold:   return "Altın"
            case .cyan:   return "Turkuaz"
            case .indigo: return "Lacivert"
            }
        case .english:
            switch self {
            case .blue:   return "Blue"
            case .purple: return "Purple"
            case .mint:   return "Green"
            case .orange: return "Orange"
            case .pink:   return "Pink"
            case .red:    return "Red"
            case .gold:   return "Gold"
            case .cyan:   return "Cyan"
            case .indigo: return "Indigo"
            }
        case .german:
            switch self {
            case .blue:   return "Blau"
            case .purple: return "Lila"
            case .mint:   return "Grün"
            case .orange: return "Orange"
            case .pink:   return "Pink"
            case .red:    return "Rot"
            case .gold:   return "Gold"
            case .cyan:   return "Türkis"
            case .indigo: return "Indigo"
            }
        }
    }

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
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
