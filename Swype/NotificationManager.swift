import UserNotifications
import SwiftUI

@MainActor
@Observable
final class NotificationManager {

    @ObservationIgnored @AppStorage("notifEnabled") var enabled = false

    var permissionStatus: UNAuthorizationStatus = .notDetermined

    #if DEBUG
    private static let debugCount = 10
    #endif

    // MARK: - Permission

    func refreshStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = s.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    func reschedule(language: AppLanguage) {
        cancelAll()
        guard enabled, permissionStatus == .authorized || permissionStatus == .provisional
        else { return }

        let msgs = messages(language)

        #if DEBUG
        for i in 0..<Self.debugCount {
            let msg = msgs[i % msgs.count]
            schedule(id: "swype.debug\(i)", delay: TimeInterval((i + 1) * 1800),
                     title: msg.0, body: msg.1)
        }
        #else
        schedule(id: "swype.remind1", delay: 3 * 24 * 3600, title: msgs[0].0, body: msgs[0].1)
        schedule(id: "swype.remind2", delay: 7 * 24 * 3600, title: msgs[1].0, body: msgs[1].1)
        #endif
    }

    func cancelAll() {
        #if DEBUG
        let ids = (0..<Self.debugCount).map { "swype.debug\($0)" }
        #else
        let ids = ["swype.remind1", "swype.remind2"]
        #endif
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    private func schedule(id: String, delay: TimeInterval, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Content

    private func messages(_ l: AppLanguage) -> [(String, String)] {
        switch l {
        case .turkish: return [
            ("Galerin seni bekliyor 📸", "Son birkaç günde fotoğraflar birikti. 2 dakikada temizleyebilirsin."),
            ("Depolama dolmadan önce…", "Bir süre galerine bakmadın. Hızlıca bir göz atmaya ne dersin?"),
            ("Temizlik vakti geldi 🧹", "Kaydettiklerinin kaçını gerçekten saklıyorsun? Swype ile öğren."),
            ("Fotoğrafların seni arıyor", "Galeride işlem bekleyen fotoğraflar var. Birkaç dakikan var mı?"),
            ("Az yer, çok anı ✨", "Gereksiz fotoğrafları silmek telefonunu hızlandırır. Hadi başlayalım."),
            ("Bugün iyi bir gün 🗓️", "Galerinle biraz zaman geçirmek için ideal bir an."),
            ("Telefon yavaşladı mı? 🐢", "Doldurmaya başlayan galeri performansı etkiliyor. Temizleyelim."),
            ("Bir dakikan var mı? ⏱️", "Sadece birkaç kaydırma ile galerine düzen gelsin."),
            ("Yeni anılara yer aç 🌅", "Eski ve gereksiz fotoğrafları temizle, yenilere yer kalsın."),
            ("Hatırlatıcı 🔔", "Swype ile galerine bir göz atmayı unutma.")
        ]
        case .english: return [
            ("Your gallery is waiting 📸", "Photos have been piling up. You can clean it up in 2 minutes."),
            ("Before storage fills up…", "You haven't checked your gallery in a while. Want to take a quick look?"),
            ("Time for a cleanup 🧹", "How many of those shots are you actually keeping? Find out with Swype."),
            ("Your photos are calling", "There are photos waiting for a decision. Got a few minutes?"),
            ("Less clutter, more memories ✨", "Deleting extras speeds up your phone. Let's get started."),
            ("Today's a good day 🗓️", "A perfect moment to spend a little time with your gallery."),
            ("Is your phone slowing down? 🐢", "A full gallery affects performance. Let's clean it up."),
            ("Got a minute? ⏱️", "Just a few swipes and your gallery is back in order."),
            ("Make room for new memories 🌅", "Clear out the old ones so the new ones have a place."),
            ("Quick reminder 🔔", "Don't forget to check your gallery with Swype today.")
        ]
        case .german: return [
            ("Deine Galerie wartet 📸", "Fotos haben sich angesammelt. In 2 Minuten aufgeräumt."),
            ("Bevor der Speicher voll ist…", "Du hast deine Galerie eine Weile nicht geöffnet. Kurz nachschauen?"),
            ("Zeit zum Aufräumen 🧹", "Wie viele Aufnahmen behältst du wirklich? Finde es mit Swype heraus."),
            ("Deine Fotos rufen", "Es warten Fotos auf eine Entscheidung. Hast du ein paar Minuten?"),
            ("Weniger Chaos, mehr Erinnerungen ✨", "Extras löschen macht dein Handy schneller. Fangen wir an."),
            ("Heute ist ein guter Tag 🗓️", "Ein perfekter Moment für deine Galerie."),
            ("Wird dein Handy langsamer? 🐢", "Eine volle Galerie bremst die Leistung. Lass uns aufräumen."),
            ("Hast du eine Minute? ⏱️", "Nur ein paar Wischgesten und deine Galerie ist ordentlich."),
            ("Platz für neue Erinnerungen 🌅", "Alte Fotos löschen, damit neue ihren Platz finden."),
            ("Kurze Erinnerung 🔔", "Vergiss nicht, heute deine Galerie mit Swype zu prüfen.")
        ]
        // Other languages fall back to English notification copy for now.
        default: return messages(.english)
        }
    }
}
