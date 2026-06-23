import SwiftUI
import WidgetKit

@Observable
final class LanguageManager {
    private static let langKey   = "selectedLanguage"
    private static let themeKey  = "selectedColorTheme"

    var selected: AppLanguage {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: Self.langKey)
            UserDefaults(suiteName: "group.com.mertkerimi.slideroll")?.set(selected.rawValue, forKey: "widgetLanguage")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var selectedTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.themeKey)
            UserDefaults(suiteName: "group.com.mertkerimi.slideroll")?.set(selectedTheme.rawValue, forKey: "widgetTheme")
            Theme.accent    = selectedTheme.accent
            Theme.accentEnd = selectedTheme.accentEnd
            themeVersion   += 1
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // Incrementing this causes RootView to re-render the full tree
    var themeVersion: Int = 0

    var s: Strings { Strings(language: selected) }

    /// The device's preferred language if SlideRoll supports it, else English.
    private static func deviceLanguage() -> AppLanguage {
        for lang in Locale.preferredLanguages {
            let code = String(lang.prefix(2)).lowercased()
            if let match = AppLanguage(rawValue: code) { return match }
        }
        return .english
    }

    init() {
        let savedLang  = UserDefaults.standard.string(forKey: Self.langKey) ?? ""
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey) ?? ""
        // On first launch (no saved language) match the device language if we
        // support it, otherwise fall back to English.
        selected      = AppLanguage(rawValue: savedLang) ?? Self.deviceLanguage()
        selectedTheme = ColorTheme(rawValue: savedTheme)  ?? .blue

        // Apply persisted theme & language on launch
        Theme.accent    = selectedTheme.accent
        Theme.accentEnd = selectedTheme.accentEnd
        let shared = UserDefaults(suiteName: "group.com.mertkerimi.slideroll")
        shared?.set(selectedTheme.rawValue, forKey: "widgetTheme")
        shared?.set(selected.rawValue,      forKey: "widgetLanguage")
    }
}
