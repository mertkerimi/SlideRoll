import SwiftUI

@Observable
final class LanguageManager {
    private static let langKey   = "selectedLanguage"
    private static let themeKey  = "selectedColorTheme"

    var selected: AppLanguage {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.langKey) }
    }

    var selectedTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeKey)
            Theme.accent    = selectedTheme.accent
            Theme.accentEnd = selectedTheme.accentEnd
            themeVersion   += 1
        }
    }

    // Incrementing this causes RootView to re-render the full tree
    var themeVersion: Int = 0

    var s: Strings { Strings(language: selected) }

    init() {
        let savedLang  = UserDefaults.standard.string(forKey: Self.langKey) ?? ""
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? ""
        selected      = AppLanguage(rawValue: savedLang)  ?? .turkish
        selectedTheme = ColorTheme(rawValue: savedTheme)  ?? .blue

        // Apply persisted theme on launch
        Theme.accent    = selectedTheme.accent
        Theme.accentEnd = selectedTheme.accentEnd
    }
}
