import Foundation

extension ColorTheme {
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
}
