import UserNotifications
import SwiftUI

@MainActor
@Observable
final class NotificationManager {

    @ObservationIgnored @AppStorage("notifEnabled") var enabled = false

    var permissionStatus: UNAuthorizationStatus = .notDetermined

    // Last day-offset (from last app open) we schedule reminders for. Two
    // notifications per active day → keep under iOS's 64 pending-request cap.
    private static let lastDay = 30

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

        let pool = messages(language).shuffled()
        var msgIndex = 0
        var notifIndex = 0

        func fire(dayOffset: Int, hour: Int, minute: Int) {
            let msg = pool[msgIndex % pool.count]; msgIndex += 1
            scheduleAt(id: "slideroll.remind\(notifIndex)", dayOffset: dayOffset,
                       hour: hour, minute: minute, title: msg.0, body: msg.1)
            notifIndex += 1
        }

        // Days (from the last app open) a reminder fires: every 2 days for the
        // first week, then daily — escalating for users who stop opening the app.
        // Active users reset this on every launch, so they're never nagged.
        var days = [2, 4, 6]
        days += Array(7...Self.lastDay)

        for day in days {
            // Two per day: morning (09:00–11:59) and evening (19:00–23:59),
            // at a random time within each window so it doesn't feel robotic.
            fire(dayOffset: day, hour: Int.random(in: 9...11),  minute: Int.random(in: 0...59))
            fire(dayOffset: day, hour: Int.random(in: 19...23), minute: Int.random(in: 0...59))
        }
    }

    func cancelAll() {
        // We are the only source of notifications, so clearing everything also
        // sweeps away any stragglers from older builds.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    /// Fires `dayOffset` days from now at the given local hour and minute.
    private func scheduleAt(id: String, dayOffset: Int, hour: Int, minute: Int, title: String, body: String) {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Content

    private func messages(_ l: AppLanguage) -> [(String, String)] {
        switch l {
        case .turkish: return [
            ("Galerin seni bekliyor 📸", "Son birkaç günde fotoğraflar birikti. 2 dakikada temizleyebilirsin."),
            ("Depolama dolmadan önce…", "Bir süre galerine bakmadın. Hızlıca bir göz atmaya ne dersin?"),
            ("Temizlik vakti geldi 🧹", "Kaydettiklerinin kaçını gerçekten saklıyorsun? SlideRoll ile öğren."),
            ("Fotoğrafların seni arıyor", "Galeride işlem bekleyen fotoğraflar var. Birkaç dakikan var mı?"),
            ("Az yer, çok anı ✨", "Gereksiz fotoğrafları silmek telefonunu hızlandırır. Hadi başlayalım."),
            ("Bugün iyi bir gün 🗓️", "Galerinle biraz zaman geçirmek için ideal bir an."),
            ("Telefon yavaşladı mı? 🐢", "Doldurmaya başlayan galeri performansı etkiliyor. Temizleyelim."),
            ("Bir dakikan var mı? ⏱️", "Sadece birkaç kaydırma ile galerine düzen gelsin."),
            ("Yeni anılara yer aç 🌅", "Eski ve gereksiz fotoğrafları temizle, yenilere yer kalsın."),
            ("Hatırlatıcı 🔔", "SlideRoll ile galerine bir göz atmayı unutma.")
        ]
        case .english: return [
            ("Your gallery is waiting 📸", "Photos have been piling up. You can clean it up in 2 minutes."),
            ("Before storage fills up…", "You haven't checked your gallery in a while. Want to take a quick look?"),
            ("Time for a cleanup 🧹", "How many of those shots are you actually keeping? Find out with SlideRoll."),
            ("Your photos are calling", "There are photos waiting for a decision. Got a few minutes?"),
            ("Less clutter, more memories ✨", "Deleting extras speeds up your phone. Let's get started."),
            ("Today's a good day 🗓️", "A perfect moment to spend a little time with your gallery."),
            ("Is your phone slowing down? 🐢", "A full gallery affects performance. Let's clean it up."),
            ("Got a minute? ⏱️", "Just a few swipes and your gallery is back in order."),
            ("Make room for new memories 🌅", "Clear out the old ones so the new ones have a place."),
            ("Quick reminder 🔔", "Don't forget to check your gallery with SlideRoll today.")
        ]
        case .german: return [
            ("Deine Galerie wartet 📸", "Fotos haben sich angesammelt. In 2 Minuten aufgeräumt."),
            ("Bevor der Speicher voll ist…", "Du hast deine Galerie eine Weile nicht geöffnet. Kurz nachschauen?"),
            ("Zeit zum Aufräumen 🧹", "Wie viele Aufnahmen behältst du wirklich? Finde es mit SlideRoll heraus."),
            ("Deine Fotos rufen", "Es warten Fotos auf eine Entscheidung. Hast du ein paar Minuten?"),
            ("Weniger Chaos, mehr Erinnerungen ✨", "Extras löschen macht dein Handy schneller. Fangen wir an."),
            ("Heute ist ein guter Tag 🗓️", "Ein perfekter Moment für deine Galerie."),
            ("Wird dein Handy langsamer? 🐢", "Eine volle Galerie bremst die Leistung. Lass uns aufräumen."),
            ("Hast du eine Minute? ⏱️", "Nur ein paar Wischgesten und deine Galerie ist ordentlich."),
            ("Platz für neue Erinnerungen 🌅", "Alte Fotos löschen, damit neue ihren Platz finden."),
            ("Kurze Erinnerung 🔔", "Vergiss nicht, heute deine Galerie mit SlideRoll zu prüfen.")
        ]
        case .spanish: return [
            ("Tu galería te espera 📸", "Las fotos se han acumulado. Puedes limpiarla en 2 minutos."),
            ("Antes de que se llene…", "Hace tiempo que no revisas tu galería. ¿Echamos un vistazo rápido?"),
            ("Hora de limpiar 🧹", "¿Cuántas de esas fotos guardas de verdad? Descúbrelo con SlideRoll."),
            ("Tus fotos te llaman", "Hay fotos esperando una decisión. ¿Tienes unos minutos?"),
            ("Menos desorden, más recuerdos ✨", "Borrar lo de más acelera tu teléfono. Empecemos."),
            ("Hoy es un buen día 🗓️", "Un momento perfecto para dedicar un rato a tu galería."),
            ("¿Tu teléfono va lento? 🐢", "Una galería llena afecta el rendimiento. Vamos a limpiarla."),
            ("¿Tienes un minuto? ⏱️", "Solo unos deslizamientos y tu galería estará en orden."),
            ("Haz sitio para nuevos recuerdos 🌅", "Borra las viejas para que las nuevas tengan lugar."),
            ("Recordatorio 🔔", "No olvides revisar tu galería con SlideRoll hoy.")
        ]
        case .french: return [
            ("Votre galerie vous attend 📸", "Les photos s'accumulent. Vous pouvez la nettoyer en 2 minutes."),
            ("Avant que le stockage se remplisse…", "Vous n'avez pas regardé votre galerie depuis un moment. Un coup d'œil ?"),
            ("L'heure du tri 🧹", "Combien de ces photos gardez-vous vraiment ? Découvrez-le avec SlideRoll."),
            ("Vos photos vous appellent", "Des photos attendent une décision. Vous avez quelques minutes ?"),
            ("Moins de fouillis, plus de souvenirs ✨", "Supprimer le superflu accélère votre téléphone. C'est parti."),
            ("Aujourd'hui est un bon jour 🗓️", "Un moment idéal pour vous occuper de votre galerie."),
            ("Votre téléphone ralentit ? 🐢", "Une galerie pleine affecte les performances. Nettoyons-la."),
            ("Vous avez une minute ? ⏱️", "Quelques balayages et votre galerie est en ordre."),
            ("Faites de la place aux souvenirs 🌅", "Supprimez les anciennes pour laisser place aux nouvelles."),
            ("Petit rappel 🔔", "N'oubliez pas de vérifier votre galerie avec SlideRoll aujourd'hui.")
        ]
        case .italian: return [
            ("La tua galleria ti aspetta 📸", "Le foto si sono accumulate. Puoi pulirla in 2 minuti."),
            ("Prima che lo spazio finisca…", "Non controlli la galleria da un po'. Diamo un'occhiata veloce?"),
            ("È ora di fare ordine 🧹", "Quante di quelle foto tieni davvero? Scoprilo con SlideRoll."),
            ("Le tue foto ti chiamano", "Ci sono foto in attesa di una decisione. Hai qualche minuto?"),
            ("Meno disordine, più ricordi ✨", "Eliminare il superfluo velocizza il telefono. Iniziamo."),
            ("Oggi è una buona giornata 🗓️", "Il momento perfetto per dedicare un po' di tempo alla galleria."),
            ("Il telefono va lento? 🐢", "Una galleria piena influisce sulle prestazioni. Puliamola."),
            ("Hai un minuto? ⏱️", "Bastano pochi swipe e la galleria torna in ordine."),
            ("Fai spazio a nuovi ricordi 🌅", "Elimina le vecchie per fare posto alle nuove."),
            ("Promemoria 🔔", "Non dimenticare di controllare la galleria con SlideRoll oggi.")
        ]
        case .portuguese: return [
            ("Sua galeria está esperando 📸", "As fotos se acumularam. Você pode limpar em 2 minutos."),
            ("Antes que o armazenamento encha…", "Você não vê sua galeria há um tempo. Que tal uma olhada rápida?"),
            ("Hora da limpeza 🧹", "Quantas dessas fotos você realmente guarda? Descubra com o SlideRoll."),
            ("Suas fotos estão chamando", "Há fotos esperando uma decisão. Tem alguns minutos?"),
            ("Menos bagunça, mais memórias ✨", "Apagar o excesso deixa o telefone mais rápido. Vamos começar."),
            ("Hoje é um bom dia 🗓️", "Um momento perfeito para cuidar da sua galeria."),
            ("Seu telefone está lento? 🐢", "Uma galeria cheia afeta o desempenho. Vamos limpar."),
            ("Tem um minuto? ⏱️", "Só alguns deslizes e sua galeria volta à ordem."),
            ("Abra espaço para novas memórias 🌅", "Apague as antigas para as novas terem lugar."),
            ("Lembrete 🔔", "Não esqueça de revisar sua galeria com o SlideRoll hoje.")
        ]
        case .japanese: return [
            ("ギャラリーが待っています 📸", "写真がたまってきました。2分でお片付けできます。"),
            ("ストレージがいっぱいになる前に…", "しばらくギャラリーを見ていませんね。さっと確認しませんか？"),
            ("お片付けの時間です 🧹", "その写真、本当に何枚残しますか？SlideRollで確認しましょう。"),
            ("写真が呼んでいます", "判断待ちの写真があります。数分ありますか？"),
            ("散らかりを減らして思い出を ✨", "不要な写真を消すと端末が速くなります。始めましょう。"),
            ("今日はいい日 🗓️", "ギャラリーに少し時間をかけるのにぴったりです。"),
            ("端末が遅い？ 🐢", "いっぱいのギャラリーは動作に影響します。整理しましょう。"),
            ("1分ありますか？ ⏱️", "数回スワイプするだけでギャラリーが整います。"),
            ("新しい思い出にスペースを 🌅", "古い写真を消して新しい写真の場所をつくりましょう。"),
            ("リマインダー 🔔", "今日もSlideRollでギャラリーを確認するのをお忘れなく。")
        ]
        case .korean: return [
            ("갤러리가 기다리고 있어요 📸", "사진이 쌓였어요. 2분이면 정리할 수 있어요."),
            ("저장 공간이 차기 전에…", "한동안 갤러리를 안 보셨네요. 빠르게 살펴볼까요?"),
            ("정리할 시간이에요 🧹", "그 사진들 중 몇 장이나 정말 보관하나요? SlideRoll로 확인해 보세요."),
            ("사진이 부르고 있어요", "결정을 기다리는 사진이 있어요. 몇 분 있으세요?"),
            ("덜 어수선하게, 더 많은 추억 ✨", "불필요한 사진을 지우면 폰이 빨라져요. 시작해요."),
            ("오늘은 좋은 날 🗓️", "갤러리에 잠깐 시간을 쓰기 딱 좋은 때예요."),
            ("폰이 느려졌나요? 🐢", "가득 찬 갤러리는 성능에 영향을 줘요. 정리해요."),
            ("1분 있으세요? ⏱️", "몇 번만 넘기면 갤러리가 정돈돼요."),
            ("새 추억을 위한 공간을 🌅", "오래된 사진을 지워 새 사진의 자리를 만들어요."),
            ("알림 🔔", "오늘 SlideRoll로 갤러리 확인하는 것 잊지 마세요.")
        ]
        case .chinese: return [
            ("你的图库在等你 📸", "照片越积越多了。2 分钟就能清理好。"),
            ("在存储占满之前…", "你有一阵子没看图库了。要不要快速看一眼？"),
            ("该清理一下了 🧹", "那些照片你真正会留几张？用 SlideRoll 来看看。"),
            ("你的照片在召唤", "有照片在等你处理。有几分钟吗？"),
            ("少点杂乱，多点回忆 ✨", "删掉多余的照片能让手机更快。开始吧。"),
            ("今天是个好日子 🗓️", "花点时间整理图库的好时机。"),
            ("手机变慢了吗？ 🐢", "满满的图库会影响性能。来清理一下。"),
            ("有一分钟吗？ ⏱️", "只需几次滑动，图库就井井有条。"),
            ("为新回忆腾出空间 🌅", "删掉旧照片，给新照片留位置。"),
            ("提醒 🔔", "别忘了今天用 SlideRoll 看看你的图库。")
        ]
        case .arabic: return [
            ("معرض صورك ينتظرك 📸", "تراكمت الصور. يمكنك تنظيفه في دقيقتين."),
            ("قبل أن تمتلئ المساحة…", "لم تتفقد معرضك منذ فترة. ما رأيك بنظرة سريعة؟"),
            ("حان وقت التنظيف 🧹", "كم من تلك الصور تحتفظ بها فعلًا؟ اكتشف ذلك مع SlideRoll."),
            ("صورك تناديك", "هناك صور تنتظر قرارك. هل لديك بضع دقائق؟"),
            ("فوضى أقل، ذكريات أكثر ✨", "حذف الزائد يسرّع هاتفك. لنبدأ."),
            ("اليوم يوم جميل 🗓️", "لحظة مثالية لقضاء بعض الوقت مع معرضك."),
            ("هل أصبح هاتفك بطيئًا؟ 🐢", "المعرض الممتلئ يؤثر على الأداء. لننظّفه."),
            ("هل لديك دقيقة؟ ⏱️", "بضع تمريرات فقط ويعود معرضك مرتبًا."),
            ("أفسح مجالًا لذكريات جديدة 🌅", "احذف القديمة ليكون للجديدة مكان."),
            ("تذكير 🔔", "لا تنسَ تفقّد معرضك مع SlideRoll اليوم.")
        ]
        case .russian: return [
            ("Ваша галерея ждёт 📸", "Фотографии накопились. Можно навести порядок за 2 минуты."),
            ("Пока память не заполнилась…", "Вы давно не заглядывали в галерею. Посмотрим быстро?"),
            ("Время навести порядок 🧹", "Сколько из этих снимков вы правда храните? Узнайте со SlideRoll."),
            ("Ваши фото зовут", "Есть фото, ждущие решения. Найдётся пара минут?"),
            ("Меньше хлама — больше воспоминаний ✨", "Удаление лишнего ускоряет телефон. Начнём."),
            ("Сегодня хороший день 🗓️", "Идеальный момент уделить время галерее."),
            ("Телефон стал медленнее? 🐢", "Полная галерея влияет на производительность. Наведём порядок."),
            ("Есть минутка? ⏱️", "Пара свайпов — и галерея в порядке."),
            ("Освободите место для новых воспоминаний 🌅", "Удалите старые, чтобы было место для новых."),
            ("Напоминание 🔔", "Не забудьте сегодня проверить галерею со SlideRoll.")
        ]
        }
    }
}
