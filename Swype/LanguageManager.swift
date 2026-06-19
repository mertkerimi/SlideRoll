import SwiftUI
import WidgetKit

@Observable
final class LanguageManager {
    private static let langKey   = "selectedLanguage"
    private static let themeKey  = "selectedColorTheme"

    var selected: AppLanguage {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: Self.langKey)
            UserDefaults(suiteName: "group.com.mertkerimi.Swype")?.set(selected.rawValue, forKey: "widgetLanguage")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var selectedTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeKey)
            UserDefaults(suiteName: "group.com.mertkerimi.Swype")?.set(selectedTheme.rawValue, forKey: "widgetTheme")
            Theme.accent    = selectedTheme.accent
            Theme.accentEnd = selectedTheme.accentEnd
            themeVersion   += 1
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // Incrementing this causes RootView to re-render the full tree
    var themeVersion: Int = 0

    var s: Strings { Strings(language: selected) }

    init() {
        let savedLang  = UserDefaults.standard.string(forKey: Self.langKey) ?? ""
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? ""
        selected      = AppLanguage(rawValue: savedLang)  ?? .english
        selectedTheme = ColorTheme(rawValue: savedTheme)  ?? .blue

        // Apply persisted theme & language on launch
        Theme.accent    = selectedTheme.accent
        Theme.accentEnd = selectedTheme.accentEnd
        let shared = UserDefaults(suiteName: "group.com.mertkerimi.Swype")
        shared?.set(selectedTheme.rawValue, forKey: "widgetTheme")
        shared?.set(selected.rawValue,      forKey: "widgetLanguage")
    }
}
