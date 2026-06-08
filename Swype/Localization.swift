import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case german  = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .german:  return "Deutsch"
        }
    }

    var flag: String {
        switch self {
        case .turkish: return "🇹🇷"
        case .english: return "🇬🇧"
        case .german:  return "🇩🇪"
        }
    }
}

struct Strings {
    let language: AppLanguage

    // MARK: - Common
    var close: String        { pick("Kapat",  "Close",  "Schließen") }
    var cancel: String       { pick("İptal",  "Cancel", "Abbrechen") }
    var ok: String           { pick("Tamam",  "OK",     "OK") }
    var done: String         { pick("Tamam",  "Done",   "Fertig") }
    var error: String        { pick("Hata",   "Error",  "Fehler") }
    var settings: String     { pick("Ayarlar","Settings","Einstellungen") }
    var languageLabel: String { pick("Dil",    "Language","Sprache") }

    // MARK: - Permission
    var appTagline: String { pick(
        "Binlerce fotoğrafı saniyeler içinde\ndüzenle ve temizle.",
        "Organize and clean thousands of\nphotos in seconds.",
        "Tausende Fotos in Sekunden\norganisieren und bereinigen."
    )}
    var allowPhotos: String  { pick("Fotoğraflara İzin Ver", "Allow Photos Access", "Fotozugriff erlauben") }
    var allowInSettings: String { pick("Ayarlarda İzin Ver", "Allow in Settings", "In Einstellungen erlauben") }

    // MARK: - Month List / Year
    var overallProgress: String { pick("Genel İlerleme", "Overall Progress", "Gesamtfortschritt") }
    var loadingPhotos: String   { pick("Fotoğraflar yükleniyor…", "Loading photos…", "Fotos werden geladen…") }
    var noPhotosFound: String   { pick("Fotoğraf Bulunamadı", "No Photos Found", "Keine Fotos gefunden") }
    var yearLabel: String       { pick("Yıl",     "Year",    "Jahr") }
    var monthLabel: String      { pick("Ay",      "Month",   "Monat") }
    var reviewedLabel: String   { pick("İncelendi","Reviewed","Überprüft") }
    var pendingLabel: String    { pick("Bekliyor", "Pending", "Ausstehend") }
    var completedLabel: String  { pick("Tamamlandı","Completed","Abgeschlossen") }
    var tapToDelete: String     { pick("Silmek için dokun", "Tap to delete", "Tippen zum Löschen") }

    func photosSelected(_ n: Int) -> String { pick(
        "\(n) fotoğraf seçildi",
        "\(n) photos selected",
        "\(n) Fotos ausgewählt"
    )}
    func monthsAndPhotos(months: Int, photos: Int) -> String { pick(
        "\(months) ay · \(photos) fotoğraf",
        "\(months) months · \(photos) photos",
        "\(months) Monate · \(photos) Fotos"
    )}
    func photosReviewedOf(reviewed: Int, total: Int) -> String { pick(
        "\(reviewed) / \(total) fotoğraf incelendi",
        "\(reviewed) / \(total) photos reviewed",
        "\(reviewed) / \(total) Fotos überprüft"
    )}

    // Mini stats labels
    var keptStat: String    { pick("Tutuldu",  "Kept",    "Behalten") }
    var toDeleteStat: String { pick("Silinecek","To Delete","Löschen") }
    var skippedStat: String { pick("Atlandı",  "Skipped", "Übersprungen") }
    var waitingStat: String  { pick("Bekliyor", "Waiting", "Wartend") }

    // MARK: - Review
    var keptCounter: String    { pick("Tutulan",  "Kept",    "Behalten") }
    var toDeleteCounter: String { pick("Silinecek","To Delete","Zu löschen") }
    var skippedCounter: String { pick("Atlanan",  "Skipped", "Übersprungen") }

    func percentCompleted(_ pct: Double) -> String { pick(
        String(format: "%0.f%% tamamlandı", pct),
        String(format: "%0.f%% completed",  pct),
        String(format: "%0.f%% abgeschlossen", pct)
    )}
    var monthCompleted: String { pick("Bu ay tamamlandı!", "This month is done!", "Dieser Monat ist fertig!") }
    func photosReviewedCount(_ n: Int) -> String { pick(
        "\(n) fotoğraf incelendi",
        "\(n) photos reviewed",
        "\(n) Fotos überprüft"
    )}
    func permanentlyDelete(_ n: Int) -> String { pick(
        "\(n) fotoğrafı kalıcı sil",
        "Permanently delete \(n) photos",
        "\(n) Fotos dauerhaft löschen"
    )}
    var keptDone: String    { pick("Tutuldu",  "Kept",    "Behalten") }
    var skippedDone: String { pick("Atlandı",  "Skipped", "Übersprungen") }

    // MARK: - Card badges
    var keepBadge: String   { pick("TUT",   "KEEP",   "BEHALTEN") }
    var deleteBadge: String { pick("SİL",   "DELETE", "LÖSCHEN") }
    var laterBadge: String  { pick("SONRA", "LATER",  "SPÄTER") }

    // MARK: - Trash
    var trashTitle: String  { pick("Silinecekler", "Trash",      "Papierkorb") }
    var cannotUndo: String  { pick("Bu işlem geri alınamaz.", "This action cannot be undone.", "Nicht rückgängig zu machen.") }
    var cannotUndoShort: String { pick("Bu işlem geri alınamaz", "This action cannot be undone", "Nicht rückgängig zu machen") }
    var deleting: String    { pick("Siliniyor…", "Deleting…", "Wird gelöscht…") }
    var noPhotosToDelete: String { pick("Silinecek Fotoğraf Yok", "No Photos to Delete", "Keine Fotos zu löschen") }
    var swipeLeftHint: String { pick(
        "Sola kaydırdığınız fotoğraflar burada görünür.",
        "Photos you swipe left will appear here.",
        "Nach links gewischte Fotos erscheinen hier."
    )}
    func photosCount(_ n: Int) -> String { pick(
        "\(n) fotoğraf",
        "\(n) photos",
        "\(n) Fotos"
    )}
    func permanentlyDeleteN(_ n: Int) -> String { pick(
        "\(n) fotoğrafı kalıcı sil",
        "Permanently delete \(n) photos",
        "\(n) Fotos dauerhaft löschen"
    )}
    func permanentlyDeleteButton(_ n: Int) -> String { pick(
        "\(n) Fotoğrafı Kalıcı Sil",
        "Permanently Delete \(n) Photos",
        "\(n) Fotos dauerhaft löschen"
    )}
    func permanentlyDeleteMsg(_ n: Int) -> String { pick(
        "\(n) fotoğraf cihazınızdan kalıcı olarak silinecek.",
        "\(n) photos will be permanently deleted from your device.",
        "\(n) Fotos werden dauerhaft von Ihrem Gerät gelöscht."
    )}

    // MARK: - Date formatting
    var locale: Locale {
        switch language {
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        case .german:  return Locale(identifier: "de_DE")
        }
    }

    func monthTitle(from groupID: String) -> String {
        let fmt = DateFormatter()
        fmt.locale = locale
        fmt.dateFormat = "yyyy-MM"
        guard let date = fmt.date(from: groupID) else { return groupID }
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date).capitalized
    }

    // MARK: - Helper
    private func pick(_ tr: String, _ en: String, _ de: String) -> String {
        switch language {
        case .turkish: return tr
        case .english: return en
        case .german:  return de
        }
    }
}
