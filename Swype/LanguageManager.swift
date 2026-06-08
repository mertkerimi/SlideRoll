import SwiftUI

@Observable
final class LanguageManager {
    private static let key = "selectedLanguage"

    var selected: AppLanguage {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }

    var s: Strings { Strings(language: selected) }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key) ?? ""
        selected = AppLanguage(rawValue: saved) ?? .turkish
    }
}
