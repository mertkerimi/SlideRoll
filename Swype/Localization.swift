import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
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
    var selectAll: String    { pick("Tümünü Seç", "Select All", "Alle auswählen") }
    var cancelAllDeletes: String { pick("Silmekten Vazgeç", "Undo All Deletes", "Alle Löschungen rückgängig") }
    var cancelAllDeletesHint: String { pick("Tüm fotoğraflar silinecekler listesinden çıkarılır.", "All photos will be removed from the delete list.", "Alle Fotos werden aus der Löschliste entfernt.") }
    var ok: String           { pick("Tamam",  "OK",     "OK") }
    var done: String         { pick("Tamam",  "Done",   "Fertig") }
    var error: String        { pick("Hata",   "Error",  "Fehler") }
    var settings: String     { pick("Ayarlar","Settings","Einstellungen") }
    var languageLabel: String { pick("Dil",       "Language", "Sprache") }
    var themeColor: String    { pick("Renk Teması","Color Theme","Farbdesign") }

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
    var tapToDelete: String   { pick("Silmek için dokun", "Tap to delete", "Tippen zum Löschen") }
    var savingsLabel: String   { pick("Kazanılan Alan", "Space Freed", "Freigegebener Speicher") }
    var actionStart: String    { pick("Başla",     "Start",     "Starten") }
    var actionContinue: String { pick("Devam Et",  "Continue",  "Weiter") }
    var continueFromTitle: String { pick("Kaldığın Yerden Devam Et", "Continue Where You Left Off", "Weitermachen") }
    func pendingPhotos(_ n: Int) -> String { pick("\(n.fmtCount) fotoğraf bekliyor", "\(n.fmtCount) photos pending", "\(n.fmtCount) Fotos ausstehend") }
    var shuffleTitle: String   { pick("Karışık İnceleme", "Shuffle Review", "Zufällige Überprüfung") }
    var shuffleCompleted: String { pick("Hepsi tamamlandı!", "All done!", "Alles erledigt!") }
    var shuffleHint: String    { pick("Tüm fotoğrafları karışık incele", "Review all photos in shuffle mode", "Alle Fotos zufällig überprüfen") }

    func photosSelected(_ n: Int) -> String { pick(
        "\(n.fmtCount) fotoğraf seçildi",
        "\(n.fmtCount) photos selected",
        "\(n.fmtCount) Fotos ausgewählt"
    )}
    func monthsAndPhotos(months: Int, photos: Int) -> String { pick(
        "\(months) ay · \(photos.fmtCount) fotoğraf",
        "\(months) months · \(photos.fmtCount) photos",
        "\(months) Monate · \(photos.fmtCount) Fotos"
    )}
    func monthsPhotosAndVideos(months: Int, photos: Int, videos: Int) -> String {
        let base = pick(
            "\(months) ay · \(photos.fmtCount) fotoğraf",
            "\(months) months · \(photos.fmtCount) photos",
            "\(months) Monate · \(photos.fmtCount) Fotos"
        )
        guard videos > 0 else { return base }
        let videoStr = pick("\(videos.fmtCount) video", "\(videos.fmtCount) videos", "\(videos.fmtCount) Videos")
        return base + " · " + videoStr
    }
    func photosReviewedOf(reviewed: Int, total: Int) -> String { pick(
        "\(reviewed.fmtCount) / \(total.fmtCount) fotoğraf incelendi",
        "\(reviewed.fmtCount) / \(total.fmtCount) photos reviewed",
        "\(reviewed.fmtCount) / \(total.fmtCount) Fotos überprüft"
    )}
    func photosReviewedOfWithVideos(reviewed: Int, total: Int, videos: Int) -> String {
        let base = pick(
            "\(reviewed.fmtCount) / \(total.fmtCount) fotoğraf incelendi",
            "\(reviewed.fmtCount) / \(total.fmtCount) photos reviewed",
            "\(reviewed.fmtCount) / \(total.fmtCount) Fotos überprüft"
        )
        guard videos > 0 else { return base }
        let videoStr = pick("\(videos.fmtCount) video", "\(videos.fmtCount) videos", "\(videos.fmtCount) Videos")
        return base + " · " + videoStr
    }

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
        "\(n.fmtCount) fotoğraf incelendi",
        "\(n.fmtCount) photos reviewed",
        "\(n.fmtCount) Fotos überprüft"
    )}
    func permanentlyDelete(_ n: Int) -> String { pick(
        "\(n.fmtCount) fotoğrafı kalıcı sil",
        "Permanently delete \(n.fmtCount) photos",
        "\(n.fmtCount) Fotos dauerhaft löschen"
    )}
    var keptDone: String    { pick("Tutuldu",  "Kept",    "Behalten") }
    var skippedDone: String { pick("Atlandı",  "Skipped", "Übersprungen") }
    var browsePhotos: String { pick("Fotoğrafları Gör", "Browse Photos", "Fotos anzeigen") }
    var restartReview: String { pick("Yeniden Başla", "Restart", "Neu starten") }

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
        "\(n.fmtCount) fotoğraf",
        "\(n.fmtCount) photos",
        "\(n.fmtCount) Fotos"
    )}
    func permanentlyDeleteN(_ n: Int) -> String { pick(
        "\(n.fmtCount) fotoğrafı kalıcı sil",
        "Permanently delete \(n.fmtCount) photos",
        "\(n.fmtCount) Fotos dauerhaft löschen"
    )}
    func permanentlyDeleteButton(_ n: Int) -> String { pick(
        "\(n.fmtCount) Fotoğrafı Kalıcı Sil",
        "Permanently Delete \(n.fmtCount) Photos",
        "\(n.fmtCount) Fotos dauerhaft löschen"
    )}
    func permanentlyDeleteMsg(_ n: Int) -> String { pick(
        "\(n.fmtCount) fotoğraf cihazınızdan kalıcı olarak silinecek.",
        "\(n.fmtCount) photos will be permanently deleted from your device.",
        "\(n.fmtCount) Fotos werden dauerhaft von Ihrem Gerät gelöscht."
    )}

    // MARK: - Onboarding
    var onboardingSkip: String  { pick("Atla",   "Skip",        "Überspringen") }
    var onboardingNext: String  { pick("Devam",  "Next",        "Weiter") }
    var onboardingStart: String { pick("Başla",  "Get Started", "Loslegen") }

    var ob1Title: String { pick("Swype'a Hoş Geldin", "Welcome to Swype", "Willkommen bei Swype") }
    var ob1Desc: String  { pick(
        "Binlerce fotoğraf ve videoyu hızlıca\ngözden geçir, düzenle ve temizle.",
        "Quickly review, organize and clean\nthousands of photos and videos.",
        "Tausende Fotos und Videos schnell\ndurchsehen, sortieren und bereinigen."
    )}

    var ob2Title: String { pick("Nasıl Kullanılır?", "How It Works", "So funktioniert's") }
    var ob2Desc: String  { pick(
        "Fotoğrafları kaydırarak saniyeler içinde\nkütüphaneni düzenle.",
        "Swipe photos to organize your library\nin seconds.",
        "Wische Fotos und sortiere deine\nMediathek in Sekunden."
    )}
    var ob2Keep: String   { pick("Sağa: Tut",   "Right: Keep",  "Rechts: Behalten") }
    var ob2Delete: String { pick("Sola: Sil",   "Left: Delete", "Links: Löschen") }
    var ob2Skip: String   { pick("Yukarı: Sonra", "Up: Later",  "Oben: Später") }

    var ob3Title: String { pick("Daha Fazlası", "More Features", "Weitere Funktionen") }
    var ob3Feat1Title: String { pick("Videolar Dahil",     "Videos Included",  "Videos inklusive") }
    var ob3Feat1Desc: String  { pick("Fotoğraf ve videolarını\naynı akışta incele.", "Review photos and videos\nin the same flow.", "Fotos und Videos im\nselben Ablauf prüfen.") }
    var ob3Feat2Title: String { pick("Favorile",           "Favorites",        "Favoriten") }
    var ob3Feat2Desc: String  { pick("Kalp ikonuna dokunarak\nfavorilere ekle.", "Tap the heart icon to\nadd to favorites.", "Tippe das Herz-Symbol\num Favoriten hinzuzufügen.") }
    var ob3Feat3Title: String { pick("Paylaş",             "Share",            "Teilen") }
    var ob3Feat3Desc: String  { pick("Paylaşım ikonuyla\ndirekt paylaş.", "Share directly with\nthe share icon.", "Direkt teilen mit\ndem Teilen-Symbol.") }

    // Review tutorial
    var tutorialTitle: String   { pick("Nasıl İncelenir?", "How to Review",  "Wie zu prüfen?") }
    var tutorialDismiss: String { pick("Anladım!",         "Got it!",         "Verstanden!") }

    // App tour steps
    var tourStep1Title: String { pick("Genel İlerleme",       "Overall Progress",    "Gesamtfortschritt") }
    var tourStep1Desc: String  { pick(
        "Toplam incelenen medya sayını, silinecekleri ve yıllara göre dağılımı buradan takip et.",
        "Track your total reviewed media, items to delete, and yearly breakdown here.",
        "Verfolge deinen Fortschritt, zu löschende Elemente und die jährliche Aufschlüsselung hier."
    )}
    var tourStep2Title: String { pick("Yıl & Ay Bazlı Medyalar", "Media by Year & Month", "Medien nach Jahr & Monat") }
    var tourStep2Desc: String  { pick(
        "Fotoğraf ve videoların yıl ve aylara göre gruplanmış. Bir yıla dokun, aylara geç.",
        "Your photos and videos are grouped by year and month. Tap a year to see months.",
        "Fotos und Videos sind nach Jahr und Monat gruppiert. Tippe ein Jahr an."
    )}
    var tourStep3Title: String { pick("Aylık Görünüm",    "Monthly View",      "Monatsansicht") }
    var tourStep3Desc: String  { pick(
        "Her ay kaç fotoğraf ve video olduğunu buradan görürsün. Bir aya dokunarak incelemeye başlayabilirsin.",
        "See how many photos and videos each month contains. Tap any month to start reviewing.",
        "Sieh, wie viele Fotos und Videos jeder Monat enthält. Tippe einen Monat an, um zu beginnen."
    )}
    var tourStep4Title: String { pick("Sekmeler",          "Tabs",                "Registerkarten") }
    var tourStep4Desc: String  { pick(
        "Kütüphane sekmesinde depolama istatistiklerini, Ayarlar sekmesinde uygulama ayarlarını bulabilirsin.",
        "Find storage stats in the Library tab and app settings in the Settings tab.",
        "Speicherstatistiken im Mediathek-Tab, App-Einstellungen im Einstellungen-Tab."
    )}

    // MARK: - Tab bar
    var tabHome: String     { pick("Ana Sayfa", "Home",     "Startseite") }
    var tabStats: String    { pick("Kütüphane", "Library",  "Mediathek") }
    var tabSettings: String { pick("Ayarlar",   "Settings", "Einstellungen") }

    // MARK: - Stats
    var statTitle: String       { pick("Kütüphane",       "Library",        "Mediathek") }
    var statPhotos: String      { pick("Fotoğraflar",     "Photos",         "Fotos") }
    var statVideos: String      { pick("Videolar",        "Videos",         "Videos") }
    var statStorage: String     { pick("Depolama",        "Storage",        "Speicher") }
    var statCalculating: String     { pick("Hesaplanıyor…",   "Calculating…",   "Wird berechnet…") }
    var statCalculatingHint: String { pick("Kütüphane boyutu hesaplanıyor,\n lütfen bekleyiniz.", "Calculating library size,\nplease wait a moment.", "Bibliotheksgröße wird berechnet,\nbitte warten.") }
    var statProgress: String        { pick("İlerleme",        "Progress",        "Fortschritt") }
    var statReviewed: String    { pick("İncelendi",  "Reviewed",   "Überprüft") }
    var statKept: String        { pick("Tutuldu",    "Kept",       "Behalten") }
    var statToDelete: String    { pick("Silinecek",  "To Delete",  "Zu löschen") }
    var statDeleted: String     { pick("Silindi",    "Deleted",    "Gelöscht") }
    var statFavorites: String   { pick("Favori",     "Favorites",  "Favoriten") }
    var statTrashSize: String   { pick("Silinecek Alan", "Trash Size", "Papierkorb") }
    var statDuplicates: String  { pick("Olası Kopya","Duplicates", "Duplikate") }
    var statByYear: String          { pick("Yıllara Göre Depolama", "Storage by Year", "Speicher nach Jahr") }
    var statLargestPhotos: String   { pick("En Büyük Fotoğraflar", "Largest Photos", "Größte Fotos") }
    var statLargestVideos: String   { pick("En Büyük Videolar", "Largest Videos", "Größte Videos") }

    // MARK: - Duplicates
    var dupTitle: String        { pick("Olası Kopyalar",    "Potential Duplicates", "Mögliche Duplikate") }
    var dupHint: String         { pick("Saklamak istediğin fotoğrafa dokun", "Tap the photo you want to keep", "Tippe auf das Foto, das du behalten möchtest") }
    var dupSkip: String         { pick("Bu grubu atla",     "Skip this group",      "Diese Gruppe überspringen") }
    var dupCompleted: String    { pick("Hepsi tamam!",       "All done!",            "Alles erledigt!") }
    var dupCompletedSub: String { pick("Tüm kopya grupları incelendi.", "All duplicate groups reviewed.", "Alle Duplikatgruppen überprüft.") }

    func statItemCount(_ n: Int) -> String { pick(
        "\(n.fmtCount) öğe",
        "\(n.fmtCount) items",
        "\(n.fmtCount) Elemente"
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

    // MARK: - Notifications
    var notificationsSection: String { pick("Bildirimler", "Notifications", "Benachrichtigungen") }
    var weeklyReminder: String       { pick("Haftalık Hatırlatıcı", "Weekly Reminder", "Wöchentliche Erinnerung") }
    var weeklyReminderSub: String    { pick("Her hafta belirtilen günde hatırlatır", "Reminds you every week on the chosen day", "Jede Woche am gewählten Tag erinnern") }
    var storageWarning: String       { pick("Depolama Uyarısı", "Storage Warning", "Speicherwarnung") }
    var storageWarningSub: String    { pick("Depolama %80'i geçince bildirim gönderir", "Sends a notification when storage exceeds 80%", "Benachrichtigung bei mehr als 80 % Speicher") }
    var reminderDay: String          { pick("Gün", "Day", "Tag") }
    var reminderTime: String         { pick("Saat", "Time", "Uhrzeit") }
    var allowNotifications: String   { pick("Bildirimlere İzin Ver", "Allow Notifications", "Benachrichtigungen erlauben") }
    var notifPermissionSub: String   { pick("Hatırlatıcı almak için izin gerekli", "Permission required to receive reminders", "Berechtigung für Erinnerungen erforderlich") }
    var notifDenied: String          { pick("Bildirimler kapalı", "Notifications disabled", "Benachrichtigungen deaktiviert") }
    var notifDeniedSub: String       { pick("Sistem ayarlarından bildirimlere izin ver", "Allow notifications in System Settings", "Benachrichtigungen in Einstellungen erlauben") }
    var openSettings: String         { pick("Ayarları Aç", "Open Settings", "Einstellungen öffnen") }
    var weekdays: [String]           { pick(
        ["Pazar","Pazartesi","Salı","Çarşamba","Perşembe","Cuma","Cumartesi"],
        ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"],
        ["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"]
    )}

    // MARK: - Daily Stats
    func todayCount(_ n: Int) -> String {
        pick("Bugün \(n.fmtCount) fotoğraf incelendi 🔥", "\(n.fmtCount) photos reviewed today 🔥", "Heute \(n.fmtCount) Fotos bewertet 🔥")
    }

    var videoLoadError: String { pick("Video yüklenemedi", "Video could not be loaded", "Video konnte nicht geladen werden") }

    // MARK: - About / Legal
    var aboutSection: String   { pick("Hakkında", "About", "Über") }
    var privacyPolicy: String  { pick("Gizlilik Politikası", "Privacy Policy", "Datenschutzerklärung") }
    var contactSupport: String { pick("İletişim & Destek", "Contact & Support", "Kontakt & Support") }
    var versionLabel: String   { pick("Sürüm", "Version", "Version") }

    // MARK: - Helper
    private func pick(_ tr: [String], _ en: [String], _ de: [String]) -> [String] {
        switch language {
        case .turkish: return tr
        case .english: return en
        case .german:  return de
        }
    }

    private func pick(_ tr: String, _ en: String, _ de: String) -> String {
        switch language {
        case .turkish: return tr
        case .english: return en
        case .german:  return de
        }
    }
}
