import SwiftUI

// Language order used by every L([...]) array below.
// Index: 0 en · 1 tr · 2 es · 3 fr · 4 it · 5 pt · 6 de · 7 ja · 8 ko · 9 zh · 10 ar · 11 ru
enum AppLanguage: String, CaseIterable, Identifiable {
    case english    = "en"
    case turkish    = "tr"
    case spanish    = "es"
    case french     = "fr"
    case italian    = "it"
    case portuguese = "pt"
    case german     = "de"
    case japanese   = "ja"
    case korean     = "ko"
    case chinese    = "zh"
    case arabic     = "ar"
    case russian    = "ru"

    var id: String { rawValue }

    /// Native name of the language.
    var displayName: String {
        switch self {
        case .english:    return "English"
        case .turkish:    return "Türkçe"
        case .spanish:    return "Español"
        case .french:     return "Français"
        case .italian:    return "Italiano"
        case .portuguese: return "Português"
        case .german:     return "Deutsch"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .chinese:    return "中文"
        case .arabic:     return "العربية"
        case .russian:    return "Русский"
        }
    }

    /// Name of this language localized into `other`'s language (e.g. "İngilizce").
    func localizedName(in other: AppLanguage) -> String {
        let loc = Locale(identifier: other.rawValue)
        return loc.localizedString(forLanguageCode: rawValue)?.capitalized(with: loc) ?? displayName
    }

    var flag: String {
        switch self {
        case .english:    return "🇬🇧"
        case .turkish:    return "🇹🇷"
        case .spanish:    return "🇪🇸"
        case .french:     return "🇫🇷"
        case .italian:    return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .german:     return "🇩🇪"
        case .japanese:   return "🇯🇵"
        case .korean:     return "🇰🇷"
        case .chinese:    return "🇨🇳"
        case .arabic:     return "🇸🇦"
        case .russian:    return "🇷🇺"
        }
    }
}

struct Strings {
    let language: AppLanguage

    // MARK: - Common
    var close: String     { L(["Close","Kapat","Cerrar","Fermer","Chiudi","Fechar","Schließen","閉じる","닫기","关闭","إغلاق","Закрыть"]) }
    var cancel: String    { L(["Cancel","İptal","Cancelar","Annuler","Annulla","Cancelar","Abbrechen","キャンセル","취소","取消","إلغاء","Отмена"]) }
    var selectAll: String { L(["Select All","Tümünü Seç","Seleccionar todo","Tout sélectionner","Seleziona tutto","Selecionar tudo","Alle auswählen","すべて選択","모두 선택","全选","تحديد الكل","Выбрать все"]) }
    var cancelAllDeletes: String { L(["Undo All Deletes","Silmekten Vazgeç","Deshacer eliminaciones","Annuler les suppressions","Annulla eliminazioni","Desfazer exclusões","Alle Löschungen rückgängig","すべての削除を取り消す","모든 삭제 취소","撤销所有删除","تراجع عن كل عمليات الحذف","Отменить все удаления"]) }
    var cancelAllDeletesHint: String { L(["All photos will be removed from the delete list.","Tüm fotoğraflar silinecekler listesinden çıkarılır.","Todas las fotos se quitarán de la lista de eliminación.","Toutes les photos seront retirées de la liste de suppression.","Tutte le foto verranno rimosse dall'elenco di eliminazione.","Todas as fotos serão removidas da lista de exclusão.","Alle Fotos werden aus der Löschliste entfernt.","すべての写真が削除リストから外されます。","모든 사진이 삭제 목록에서 제거됩니다.","所有照片将从删除列表中移除。","ستتم إزالة جميع الصور من قائمة الحذف.","Все фото будут удалены из списка удаления."]) }
    var ok: String        { L(["OK","Tamam","OK","OK","OK","OK","OK","OK","확인","确定","موافق","ОК"]) }
    var done: String      { L(["Done","Tamam","Hecho","Terminé","Fatto","Concluído","Fertig","完了","완료","完成","تم","Готово"]) }
    var error: String     { L(["Error","Hata","Error","Erreur","Errore","Erro","Fehler","エラー","오류","错误","خطأ","Ошибка"]) }
    var settings: String  { L(["Settings","Ayarlar","Ajustes","Réglages","Impostazioni","Ajustes","Einstellungen","設定","설정","设置","الإعدادات","Настройки"]) }
    var languageLabel: String { L(["Language","Dil","Idioma","Langue","Lingua","Idioma","Sprache","言語","언어","语言","اللغة","Язык"]) }
    var themeColor: String    { L(["Color Theme","Renk Teması","Tema de color","Thème de couleur","Tema colore","Tema de cor","Farbdesign","カラーテーマ","색상 테마","颜色主题","سمة اللون","Цветовая тема"]) }

    // MARK: - Language screen
    var languagesRecommended: String { L(["Recommended Languages","Önerilen Diller","Idiomas recomendados","Langues recommandées","Lingue consigliate","Idiomas recomendados","Empfohlene Sprachen","おすすめの言語","추천 언어","推荐语言","اللغات المقترحة","Рекомендуемые языки"]) }
    var languagesOther: String { L(["Other Languages","Diğer Diller","Otros idiomas","Autres langues","Altre lingue","Outros idiomas","Weitere Sprachen","その他の言語","기타 언어","其他语言","لغات أخرى","Другие языки"]) }

    // MARK: - Permission
    var appTagline: String { L(["Organize and clean thousands of\nphotos in seconds.","Binlerce fotoğrafı saniyeler içinde\ndüzenle ve temizle.","Organiza y limpia miles de\nfotos en segundos.","Organisez et nettoyez des milliers\nde photos en quelques secondes.","Organizza e pulisci migliaia di\nfoto in pochi secondi.","Organize e limpe milhares de\nfotos em segundos.","Tausende Fotos in Sekunden\norganisieren und bereinigen.","何千枚もの写真を数秒で\n整理してクリーンに。","수천 장의 사진을 몇 초 만에\n정리하고 비우세요.","数秒内整理并清理\n成千上万张照片。","نظّم وامسح آلاف الصور\nفي ثوانٍ.","Организуйте и очистите тысячи\nфото за секунды."]) }
    var allowPhotos: String  { L(["Continue","Devam","Continuar","Continuer","Continua","Continuar","Weiter","続ける","계속","继续","متابعة","Продолжить"]) }
    var allowPhotosReason: String { L(["SlideRoll needs access to your photo library to help you review, organize, and clean up your photos. Your photos never leave your device.","SlideRoll, fotoğraflarını incelemene, düzenlene ve temizlemene yardımcı olmak için fotoğraf kütüphanene erişmesi gerekiyor. Fotoğrafların hiçbir zaman cihazından çıkmaz.","SlideRoll necesita acceso a tu biblioteca de fotos para ayudarte a revisar, organizar y limpiar tus fotos. Tus fotos nunca salen de tu dispositivo.","SlideRoll a besoin d'accéder à votre photothèque pour vous aider à examiner, organiser et nettoyer vos photos. Vos photos ne quittent jamais votre appareil.","SlideRoll ha bisogno di accedere alla tua libreria foto per aiutarti a rivedere, organizzare e pulire le tue foto. Le tue foto non lasciano mai il dispositivo.","SlideRoll precisa de acesso à sua biblioteca de fotos para ajudá-lo a revisar, organizar e limpar suas fotos. Suas fotos nunca saem do dispositivo.","SlideRoll benötigt Zugriff auf deine Fotomediathek, um dir beim Überprüfen, Organisieren und Bereinigen deiner Fotos zu helfen. Deine Fotos verlassen nie dein Gerät.","SlideRollは写真のレビュー、整理、クリーンアップを支援するためにフォトライブラリへのアクセスが必要です。写真がデバイスから出ることはありません。","SlideRoll은 사진을 검토하고 정리하며 정리하는 데 도움을 드리기 위해 사진 라이브러리에 접근해야 합니다. 사진은 기기 밖으로 나가지 않습니다.","SlideRoll需要访问您的照片库，以帮助您查看、整理和清理照片。您的照片永远不会离开您的设备。","يحتاج SlideRoll إلى الوصول إلى مكتبة الصور لمساعدتك في مراجعة صورك وتنظيمها وتنظيفها. لا تغادر صورك جهازك أبدًا.","SlideRoll нуждается в доступе к вашей библиотеке фотографий, чтобы помочь вам просматривать, организовывать и очищать фотографии. Ваши фото никогда не покидают устройство."]) }
    var allowInSettings: String { L(["Allow in Settings","Ayarlarda İzin Ver","Permitir en Ajustes","Autoriser dans Réglages","Consenti in Impostazioni","Permitir nos Ajustes","In Einstellungen erlauben","設定で許可","설정에서 허용","在设置中允许","السماح في الإعدادات","Разрешить в настройках"]) }

    // MARK: - Limited Access Banner
    var limitedAccessTitle: String  { L(["Limited Photo Access","Sınırlı Fotoğraf Erişimi","Acceso limitado a fotos","Accès limité aux photos","Accesso limitato alle foto","Acesso limitado às fotos","Eingeschränkter Fotozugriff","写真アクセスが制限されています","사진 접근이 제한됨","照片访问受限","الوصول المحدود للصور","Ограниченный доступ к фото"]) }
    var limitedAccessSub: String    { L(["You've given access to selected photos only.","Yalnızca seçili fotoğraflara erişim izni verildi.","Solo tienes acceso a fotos seleccionadas.","Vous n'avez autorisé que des photos sélectionnées.","Hai concesso l'accesso solo alle foto selezionate.","Você concedeu acesso apenas a fotos selecionadas.","Du hast nur ausgewählten Fotos Zugriff gewährt.","選択した写真のみアクセスが許可されています。","선택한 사진에만 접근이 허용되었습니다.","您仅授权了部分照片的访问权限。","منحت الوصول للصور المحددة فقط.","Вы разрешили доступ только к выбранным фото."]) }
    var limitedAddMore: String      { L(["Add More Photos","Daha Fazla Fotoğraf Ekle","Agregar más fotos","Ajouter plus de photos","Aggiungi altre foto","Adicionar mais fotos","Mehr Fotos hinzufügen","さらに写真を追加","사진 더 추가","添加更多照片","إضافة المزيد من الصور","Добавить ещё фото"]) }
    var limitedFullAccess: String   { L(["Allow Full Access","Tam Erişime İzin Ver","Permitir acceso completo","Autoriser l'accès complet","Consenti accesso completo","Permitir acesso completo","Vollen Zugriff erlauben","フルアクセスを許可","전체 접근 허용","允许完整访问","السماح بالوصول الكامل","Разрешить полный доступ"]) }

    // MARK: - Month List / Year
    var overallProgress: String { L(["Overall Progress","Genel İlerleme","Progreso general","Progression globale","Avanzamento totale","Progresso geral","Gesamtfortschritt","全体の進捗","전체 진행률","总体进度","التقدم العام","Общий прогресс"]) }
    var loadingPhotos: String   { L(["Loading photos…","Fotoğraflar yükleniyor…","Cargando fotos…","Chargement des photos…","Caricamento foto…","Carregando fotos…","Fotos werden geladen…","写真を読み込み中…","사진 불러오는 중…","正在加载照片…","جارٍ تحميل الصور…","Загрузка фото…"]) }
    var noPhotosFound: String   { L(["No Photos Found","Fotoğraf Bulunamadı","No se encontraron fotos","Aucune photo trouvée","Nessuna foto trovata","Nenhuma foto encontrada","Keine Fotos gefunden","写真が見つかりません","사진을 찾을 수 없음","未找到照片","لم يتم العثور على صور","Фото не найдены"]) }
    var yearLabel: String       { L(["Year","Yıl","Año","Année","Anno","Ano","Jahr","年","연도","年","سنة","Год"]) }
    var monthLabel: String      { L(["Month","Ay","Mes","Mois","Mese","Mês","Monat","月","월","月","شهر","Месяц"]) }
    var reviewedLabel: String   { L(["Reviewed","İncelendi","Revisado","Examiné","Esaminato","Revisado","Überprüft","確認済み","검토됨","已查看","تمت المراجعة","Просмотрено"]) }
    var pendingLabel: String    { L(["Pending","Bekliyor","Pendiente","En attente","In attesa","Pendente","Ausstehend","保留中","대기 중","待处理","قيد الانتظار","Ожидает"]) }
    var completedLabel: String  { L(["Completed","Tamamlandı","Completado","Terminé","Completato","Concluído","Abgeschlossen","完了","완료","已完成","مكتمل","Завершено"]) }
    var tapToDelete: String   { L(["Tap to delete","Silmek için dokun","Toca para eliminar","Touchez pour supprimer","Tocca per eliminare","Toque para excluir","Tippen zum Löschen","タップして削除","탭하여 삭제","点按删除","انقر للحذف","Нажмите, чтобы удалить"]) }
    var savingsLabel: String   { L(["Space Freed","Kazanılan Alan","Espacio liberado","Espace libéré","Spazio liberato","Espaço liberado","Freigegebener Speicher","空けた容量","확보한 공간","已释放空间","المساحة المحررة","Освобождено места"]) }
    var actionStart: String    { L(["Start","Başla","Empezar","Commencer","Inizia","Começar","Starten","開始","시작","开始","ابدأ","Начать"]) }
    var actionContinue: String { L(["Continue","Devam Et","Continuar","Continuer","Continua","Continuar","Weiter","続ける","계속","继续","متابعة","Продолжить"]) }
    var continueFromTitle: String { L(["Continue Where You Left Off","Kaldığın Yerden Devam Et","Continúa donde lo dejaste","Reprenez où vous vous êtes arrêté","Riprendi da dove eri","Continue de onde parou","Weitermachen","続きから再開","이어서 계속하기","从上次中断处继续","تابع من حيث توقفت","Продолжить с того места"]) }
    func pendingPhotos(_ n: Int) -> String { L(["\(n.fmtCount) photos pending","\(n.fmtCount) fotoğraf bekliyor","\(n.fmtCount) fotos pendientes","\(n.fmtCount) photos en attente","\(n.fmtCount) foto in attesa","\(n.fmtCount) fotos pendentes","\(n.fmtCount) Fotos ausstehend","\(n.fmtCount)枚の写真が保留中","사진 \(n.fmtCount)장 대기 중","\(n.fmtCount) 张照片待处理","\(n.fmtCount) صورة قيد الانتظار","\(n.fmtCount) фото в ожидании"]) }
    var shuffleTitle: String   { L(["Shuffle Review","Karışık İnceleme","Revisión aleatoria","Révision aléatoire","Revisione casuale","Revisão aleatória","Zufällige Überprüfung","シャッフル確認","셔플 검토","随机查看","مراجعة عشوائية","Случайный просмотр"]) }
    var shuffleCompleted: String { L(["All done!","Hepsi tamamlandı!","¡Todo listo!","Terminé !","Tutto fatto!","Tudo pronto!","Alles erledigt!","すべて完了！","모두 완료!","全部完成！","تم كل شيء!","Готово!"]) }
    var shuffleHint: String    { L(["Review all photos in shuffle mode","Tüm fotoğrafları karışık incele","Revisa todas las fotos en modo aleatorio","Examinez toutes les photos en mode aléatoire","Esamina tutte le foto in modo casuale","Revise todas as fotos no modo aleatório","Alle Fotos zufällig überprüfen","すべての写真をシャッフルで確認","모든 사진을 셔플로 검토","以随机模式查看所有照片","راجع كل الصور بشكل عشوائي","Просмотрите все фото в случайном порядке"]) }

    func photosSelected(_ n: Int) -> String { L(["\(n.fmtCount) photos selected","\(n.fmtCount) fotoğraf seçildi","\(n.fmtCount) fotos seleccionadas","\(n.fmtCount) photos sélectionnées","\(n.fmtCount) foto selezionate","\(n.fmtCount) fotos selecionadas","\(n.fmtCount) Fotos ausgewählt","\(n.fmtCount)枚の写真を選択","사진 \(n.fmtCount)장 선택됨","已选择 \(n.fmtCount) 张照片","تم تحديد \(n.fmtCount) صورة","Выбрано \(n.fmtCount) фото"]) }

    func monthsAndPhotos(months: Int, photos: Int) -> String {
        L(["\(months) months · \(photos.fmtCount) photos","\(months) ay · \(photos.fmtCount) fotoğraf","\(months) meses · \(photos.fmtCount) fotos","\(months) mois · \(photos.fmtCount) photos","\(months) mesi · \(photos.fmtCount) foto","\(months) meses · \(photos.fmtCount) fotos","\(months) Monate · \(photos.fmtCount) Fotos","\(months)か月・\(photos.fmtCount)枚","\(months)개월 · 사진 \(photos.fmtCount)장","\(months) 个月 · \(photos.fmtCount) 张照片","\(months) أشهر · \(photos.fmtCount) صورة","\(months) мес. · \(photos.fmtCount) фото"])
    }
    func monthsPhotosAndVideos(months: Int, photos: Int, videos: Int) -> String {
        let base = monthsAndPhotos(months: months, photos: photos)
        guard videos > 0 else { return base }
        let videoStr = L(["\(videos.fmtCount) videos","\(videos.fmtCount) video","\(videos.fmtCount) vídeos","\(videos.fmtCount) vidéos","\(videos.fmtCount) video","\(videos.fmtCount) vídeos","\(videos.fmtCount) Videos","\(videos.fmtCount)本の動画","동영상 \(videos.fmtCount)개","\(videos.fmtCount) 个视频","\(videos.fmtCount) فيديو","\(videos.fmtCount) видео"])
        return base + " · " + videoStr
    }
    func photosReviewedOf(reviewed: Int, total: Int) -> String { L(["\(reviewed.fmtCount) / \(total.fmtCount) photos reviewed","\(reviewed.fmtCount) / \(total.fmtCount) fotoğraf incelendi","\(reviewed.fmtCount) / \(total.fmtCount) fotos revisadas","\(reviewed.fmtCount) / \(total.fmtCount) photos examinées","\(reviewed.fmtCount) / \(total.fmtCount) foto esaminate","\(reviewed.fmtCount) / \(total.fmtCount) fotos revisadas","\(reviewed.fmtCount) / \(total.fmtCount) Fotos überprüft","\(reviewed.fmtCount) / \(total.fmtCount)枚を確認","\(reviewed.fmtCount) / \(total.fmtCount)장 검토됨","已查看 \(reviewed.fmtCount) / \(total.fmtCount) 张","تمت مراجعة \(reviewed.fmtCount) / \(total.fmtCount)","Просмотрено \(reviewed.fmtCount) / \(total.fmtCount)"]) }
    func photosReviewedOfWithVideos(reviewed: Int, total: Int, videos: Int) -> String {
        let base = photosReviewedOf(reviewed: reviewed, total: total)
        guard videos > 0 else { return base }
        let videoStr = L(["\(videos.fmtCount) videos","\(videos.fmtCount) video","\(videos.fmtCount) vídeos","\(videos.fmtCount) vidéos","\(videos.fmtCount) video","\(videos.fmtCount) vídeos","\(videos.fmtCount) Videos","\(videos.fmtCount)本の動画","동영상 \(videos.fmtCount)개","\(videos.fmtCount) 个视频","\(videos.fmtCount) فيديو","\(videos.fmtCount) видео"])
        return base + " · " + videoStr
    }

    // Mini stats labels
    var keptStat: String     { L(["Kept","Tutuldu","Conservadas","Conservées","Tenute","Mantidas","Behalten","保持","유지","保留","محتفظ","Оставлено"]) }
    var toDeleteStat: String { L(["To Delete","Silinecek","Para eliminar","À supprimer","Da eliminare","Para excluir","Löschen","削除予定","삭제 예정","待删除","للحذف","К удалению"]) }
    var skippedStat: String  { L(["Skipped","Atlandı","Omitidas","Ignorées","Saltate","Ignoradas","Übersprungen","スキップ","건너뜀","已跳过","تم تخطيها","Пропущено"]) }
    var waitingStat: String  { L(["Waiting","Bekliyor","Esperando","En attente","In attesa","Aguardando","Wartend","待機中","대기 중","等待中","قيد الانتظار","Ожидает"]) }

    // MARK: - Review
    var keptCounter: String     { L(["Kept","Tutulan","Conservadas","Conservées","Tenute","Mantidas","Behalten","保持","유지","保留","محتفظ","Оставлено"]) }
    var toDeleteCounter: String { L(["To Delete","Silinecek","Para eliminar","À supprimer","Da eliminare","Para excluir","Zu löschen","削除予定","삭제 예정","待删除","للحذف","К удалению"]) }
    var skippedCounter: String  { L(["Skipped","Atlanan","Omitidas","Ignorées","Saltate","Ignoradas","Übersprungen","スキップ","건너뜀","已跳过","تم تخطيها","Пропущено"]) }

    func percentCompleted(_ pct: Double) -> String {
        let p = String(format: "%0.f%%", pct)
        return L(["\(p) completed","\(p) tamamlandı","\(p) completado","\(p) terminé","\(p) completato","\(p) concluído","\(p) abgeschlossen","\(p) 完了","\(p) 완료","\(p) 完成","\(p) مكتمل","\(p) завершено"])
    }
    var monthCompleted: String { L(["This month is done!","Bu ay tamamlandı!","¡Este mes está listo!","Ce mois est terminé !","Questo mese è completato!","Este mês está concluído!","Dieser Monat ist fertig!","今月は完了！","이번 달 완료!","本月已完成！","انتهى هذا الشهر!","Этот месяц завершён!"]) }
    var albumCompleted: String { L(["Album completed!","Albüm tamamlandı!","¡Álbum completado!","Album terminé !","Album completato!","Álbum concluído!","Album fertig!","アルバム完了！","앨범 완료!","专辑完成！","اكتمل الألبوم!","Альбом завершён!"]) }
    func photosReviewedCount(_ n: Int) -> String { L(["\(n.fmtCount) photos reviewed","\(n.fmtCount) fotoğraf incelendi","\(n.fmtCount) fotos revisadas","\(n.fmtCount) photos examinées","\(n.fmtCount) foto esaminate","\(n.fmtCount) fotos revisadas","\(n.fmtCount) Fotos überprüft","\(n.fmtCount)枚を確認","사진 \(n.fmtCount)장 검토됨","已查看 \(n.fmtCount) 张照片","تمت مراجعة \(n.fmtCount) صورة","Просмотрено \(n.fmtCount) фото"]) }
    func permanentlyDelete(_ n: Int) -> String { L(["Permanently delete \(n.fmtCount) photos","\(n.fmtCount) fotoğrafı kalıcı sil","Eliminar \(n.fmtCount) fotos para siempre","Supprimer définitivement \(n.fmtCount) photos","Elimina definitivamente \(n.fmtCount) foto","Excluir \(n.fmtCount) fotos permanentemente","\(n.fmtCount) Fotos dauerhaft löschen","\(n.fmtCount)枚を完全に削除","사진 \(n.fmtCount)장 영구 삭제","永久删除 \(n.fmtCount) 张照片","حذف \(n.fmtCount) صورة نهائيًا","Удалить \(n.fmtCount) фото навсегда"]) }
    var keptDone: String    { L(["Kept","Tutuldu","Conservadas","Conservées","Tenute","Mantidas","Behalten","保持","유지","保留","محتفظ","Оставлено"]) }
    var skippedDone: String { L(["Skipped","Atlandı","Omitidas","Ignorées","Saltate","Ignoradas","Übersprungen","スキップ","건너뜀","已跳过","تم تخطيها","Пропущено"]) }
    var browsePhotos: String { L(["Browse Photos","Fotoğrafları Gör","Ver fotos","Parcourir les photos","Sfoglia foto","Ver fotos","Fotos anzeigen","写真を見る","사진 보기","浏览照片","تصفح الصور","Просмотр фото"]) }
    var restartReview: String { L(["Restart","Yeniden Başla","Reiniciar","Recommencer","Ricomincia","Recomeçar","Neu starten","やり直す","다시 시작","重新开始","إعادة","Заново"]) }

    // MARK: - Card badges
    var keepBadge: String   { L(["KEEP","TUT","CONSERVAR","GARDER","TIENI","MANTER","BEHALTEN","保持","유지","保留","احتفظ","ОСТАВИТЬ"]) }
    var deleteBadge: String { L(["DELETE","SİL","ELIMINAR","SUPPRIMER","ELIMINA","EXCLUIR","LÖSCHEN","削除","삭제","删除","حذف","УДАЛИТЬ"]) }
    var laterBadge: String  { L(["LATER","SONRA","LUEGO","PLUS TARD","DOPO","DEPOIS","SPÄTER","後で","나중에","稍后","لاحقًا","ПОЗЖЕ"]) }

    // MARK: - Trash
    var trashTitle: String  { L(["Trash","Silinecekler","Papelera","Corbeille","Cestino","Lixeira","Papierkorb","ゴミ箱","휴지통","回收站","المهملات","Корзина"]) }
    var cannotUndo: String  { L(["This action cannot be undone.","Bu işlem geri alınamaz.","Esta acción no se puede deshacer.","Cette action est irréversible.","Questa azione non può essere annullata.","Esta ação não pode ser desfeita.","Nicht rückgängig zu machen.","この操作は取り消せません。","이 작업은 되돌릴 수 없습니다.","此操作无法撤销。","لا يمكن التراجع عن هذا الإجراء.","Это действие нельзя отменить."]) }
    var cannotUndoShort: String { L(["This action cannot be undone","Bu işlem geri alınamaz","Esta acción no se puede deshacer","Action irréversible","Azione irreversibile","Ação irreversível","Nicht rückgängig zu machen","この操作は取り消せません","되돌릴 수 없습니다","此操作无法撤销","لا يمكن التراجع","Нельзя отменить"]) }
    var deleting: String    { L(["Deleting…","Siliniyor…","Eliminando…","Suppression…","Eliminazione…","Excluindo…","Wird gelöscht…","削除中…","삭제 중…","正在删除…","جارٍ الحذف…","Удаление…"]) }
    var noPhotosToDelete: String { L(["No Photos to Delete","Silinecek Fotoğraf Yok","No hay fotos para eliminar","Aucune photo à supprimer","Nessuna foto da eliminare","Nenhuma foto para excluir","Keine Fotos zu löschen","削除する写真がありません","삭제할 사진 없음","没有可删除的照片","لا توجد صور للحذف","Нет фото для удаления"]) }
    var swipeLeftHint: String { L(["Photos you swipe left will appear here.","Sola kaydırdığınız fotoğraflar burada görünür.","Las fotos que deslices a la izquierda aparecerán aquí.","Les photos glissées à gauche apparaîtront ici.","Le foto scorse a sinistra appariranno qui.","As fotos deslizadas para a esquerda aparecerão aqui.","Nach links gewischte Fotos erscheinen hier.","左にスワイプした写真がここに表示されます。","왼쪽으로 넘긴 사진이 여기에 표시됩니다.","向左滑动的照片会显示在这里。","ستظهر هنا الصور التي تمررها يسارًا.","Фото, смахнутые влево, появятся здесь."]) }
    func photosCount(_ n: Int) -> String { L(["\(n.fmtCount) photos","\(n.fmtCount) fotoğraf","\(n.fmtCount) fotos","\(n.fmtCount) photos","\(n.fmtCount) foto","\(n.fmtCount) fotos","\(n.fmtCount) Fotos","\(n.fmtCount)枚の写真","사진 \(n.fmtCount)장","\(n.fmtCount) 张照片","\(n.fmtCount) صورة","\(n.fmtCount) фото"]) }
    func permanentlyDeleteN(_ n: Int) -> String { permanentlyDelete(n) }
    func permanentlyDeleteButton(_ n: Int) -> String { L(["Permanently Delete \(n.fmtCount) Photos","\(n.fmtCount) Fotoğrafı Kalıcı Sil","Eliminar \(n.fmtCount) fotos para siempre","Supprimer définitivement \(n.fmtCount) photos","Elimina definitivamente \(n.fmtCount) foto","Excluir \(n.fmtCount) fotos permanentemente","\(n.fmtCount) Fotos dauerhaft löschen","\(n.fmtCount)枚を完全に削除","사진 \(n.fmtCount)장 영구 삭제","永久删除 \(n.fmtCount) 张照片","حذف \(n.fmtCount) صورة نهائيًا","Удалить \(n.fmtCount) фото навсегда"]) }
    func permanentlyDeleteMsg(_ n: Int) -> String { L(["\(n.fmtCount) photos will be permanently deleted from your device.","\(n.fmtCount) fotoğraf cihazınızdan kalıcı olarak silinecek.","\(n.fmtCount) fotos se eliminarán permanentemente de tu dispositivo.","\(n.fmtCount) photos seront définitivement supprimées de votre appareil.","\(n.fmtCount) foto verranno eliminate definitivamente dal dispositivo.","\(n.fmtCount) fotos serão excluídas permanentemente do seu dispositivo.","\(n.fmtCount) Fotos werden dauerhaft von Ihrem Gerät gelöscht.","\(n.fmtCount)枚の写真がデバイスから完全に削除されます。","사진 \(n.fmtCount)장이 기기에서 영구적으로 삭제됩니다.","\(n.fmtCount) 张照片将从您的设备中永久删除。","سيتم حذف \(n.fmtCount) صورة نهائيًا من جهازك.","\(n.fmtCount) фото будут навсегда удалены с устройства."]) }

    // MARK: - Onboarding
    var onboardingSkip: String  { L(["Skip","Atla","Omitir","Passer","Salta","Pular","Überspringen","スキップ","건너뛰기","跳过","تخطٍ","Пропустить"]) }
    var onboardingNext: String  { L(["Next","Devam","Siguiente","Suivant","Avanti","Próximo","Weiter","次へ","다음","下一步","التالي","Далее"]) }
    var onboardingStart: String { L(["Get Started","Başla","Empezar","Commencer","Inizia","Começar","Loslegen","始める","시작하기","开始使用","ابدأ","Начать"]) }

    var ob1Title: String { L(["Welcome to SlideRoll","SlideRoll'a Hoş Geldin","Bienvenido a SlideRoll","Bienvenue sur SlideRoll","Benvenuto su SlideRoll","Bem-vindo ao SlideRoll","Willkommen bei SlideRoll","SlideRollへようこそ","SlideRoll에 오신 것을 환영합니다","欢迎使用 SlideRoll","مرحبًا بك في SlideRoll","Добро пожаловать в SlideRoll"]) }
    var ob1Desc: String  { L(["Quickly review, organize and clean\nthousands of photos and videos.","Binlerce fotoğraf ve videoyu hızlıca\ngözden geçir, düzenle ve temizle.","Revisa, organiza y limpia rápidamente\nmiles de fotos y videos.","Examinez, organisez et nettoyez\nrapidement des milliers de photos et vidéos.","Esamina, organizza e pulisci\nrapidamente migliaia di foto e video.","Revise, organize e limpe rapidamente\nmilhares de fotos e vídeos.","Tausende Fotos und Videos schnell\ndurchsehen, sortieren und bereinigen.","何千枚もの写真や動画を\nすばやく確認・整理・整頓。","수천 장의 사진과 동영상을\n빠르게 검토하고 정리하세요.","快速查看、整理并清理\n成千上万张照片和视频。","راجع ونظّم وامسح آلاف\nالصور والفيديوهات بسرعة.","Быстро просматривайте, упорядочивайте\nи очищайте тысячи фото и видео."]) }

    var ob2Title: String { L(["How It Works","Nasıl Kullanılır?","Cómo funciona","Comment ça marche","Come funziona","Como funciona","So funktioniert's","使い方","사용 방법","使用方法","كيف يعمل","Как это работает"]) }
    var ob2Desc: String  { L(["Swipe photos to organize your library\nin seconds.","Fotoğrafları kaydırarak saniyeler içinde\nkütüphaneni düzenle.","Desliza las fotos para organizar tu\nbiblioteca en segundos.","Glissez les photos pour organiser votre\nbibliothèque en quelques secondes.","Scorri le foto per organizzare la tua\nlibreria in pochi secondi.","Deslize as fotos para organizar sua\nbiblioteca em segundos.","Wische Fotos und sortiere deine\nMediathek in Sekunden.","写真をスワイプして数秒で\nライブラリを整理。","사진을 넘겨 몇 초 만에\n라이브러리를 정리하세요.","滑动照片，几秒钟内\n整理你的图库。","مرّر الصور لتنظيم مكتبتك\nفي ثوانٍ.","Смахивайте фото и упорядочивайте\nбиблиотеку за секунды."]) }
    var ob2Keep: String   { L(["Right: Keep","Sağa: Tut","Derecha: conservar","Droite : garder","Destra: tieni","Direita: manter","Rechts: Behalten","右：保持","오른쪽: 유지","右滑：保留","يمين: احتفظ","Вправо: оставить"]) }
    var ob2Delete: String { L(["Left: Delete","Sola: Sil","Izquierda: eliminar","Gauche : supprimer","Sinistra: elimina","Esquerda: excluir","Links: Löschen","左：削除","왼쪽: 삭제","左滑：删除","يسار: حذف","Влево: удалить"]) }
    var ob2Skip: String   { L(["Up: Later","Yukarı: Sonra","Arriba: luego","Haut : plus tard","Su: dopo","Cima: depois","Oben: Später","上：後で","위로: 나중에","上滑：稍后","أعلى: لاحقًا","Вверх: позже"]) }

    var ob3Title: String { L(["More Features","Daha Fazlası","Más funciones","Plus de fonctions","Altre funzioni","Mais recursos","Weitere Funktionen","その他の機能","더 많은 기능","更多功能","المزيد من الميزات","Больше возможностей"]) }
    var ob3Feat1Title: String { L(["Videos Included","Videolar Dahil","Videos incluidos","Vidéos incluses","Video inclusi","Vídeos incluídos","Videos inklusive","動画も対応","동영상 포함","包含视频","الفيديو متضمَّن","Видео тоже"]) }
    var ob3Feat1Desc: String  { L(["Review photos and videos\nin the same flow.","Fotoğraf ve videolarını\naynı akışta incele.","Revisa fotos y videos\nen el mismo flujo.","Examinez photos et vidéos\ndans le même flux.","Esamina foto e video\nnello stesso flusso.","Revise fotos e vídeos\nno mesmo fluxo.","Fotos und Videos im\nselben Ablauf prüfen.","写真も動画も\n同じ流れで確認。","사진과 동영상을\n같은 흐름에서 검토.","在同一流程中\n查看照片和视频。","راجع الصور والفيديو\nفي نفس التدفق.","Просматривайте фото и видео\nв одном потоке."]) }
    var ob3Feat2Title: String { L(["Favorites","Favorile","Favoritos","Favoris","Preferiti","Favoritos","Favoriten","お気に入り","즐겨찾기","收藏","المفضلة","Избранное"]) }
    var ob3Feat2Desc: String  { L(["Tap the heart icon to\nadd to favorites.","Kalp ikonuna dokunarak\nfavorilere ekle.","Toca el corazón para\nañadir a favoritos.","Touchez le cœur pour\najouter aux favoris.","Tocca il cuore per\naggiungere ai preferiti.","Toque no coração para\nadicionar aos favoritos.","Tippe das Herz-Symbol\num Favoriten hinzuzufügen.","ハートをタップして\nお気に入りに追加。","하트 아이콘을 눌러\n즐겨찾기에 추가.","点按心形图标\n添加到收藏。","انقر القلب\nللإضافة إلى المفضلة.","Нажмите на сердечко,\nчтобы добавить в избранное."]) }
    var ob3Feat3Title: String { L(["Share","Paylaş","Compartir","Partager","Condividi","Compartilhar","Teilen","共有","공유","分享","مشاركة","Поделиться"]) }
    var ob3Feat3Desc: String  { L(["Share directly with\nthe share icon.","Paylaşım ikonuyla\ndirekt paylaş.","Comparte directamente con\nel icono de compartir.","Partagez directement avec\nl'icône de partage.","Condividi direttamente con\nl'icona di condivisione.","Compartilhe direto com\no ícone de compartilhar.","Direkt teilen mit\ndem Teilen-Symbol.","共有アイコンで\nそのまま共有。","공유 아이콘으로\n바로 공유.","用分享图标\n直接分享。","شارك مباشرة\nبأيقونة المشاركة.","Делитесь сразу через\nзначок «Поделиться»."]) }

    // Review tutorial
    var tutorialTitle: String   { L(["How to Review","Nasıl İncelenir?","Cómo revisar","Comment examiner","Come esaminare","Como revisar","Wie zu prüfen?","確認のしかた","검토 방법","如何查看","كيفية المراجعة","Как просматривать"]) }
    var tutorialDismiss: String { L(["Got it!","Anladım!","¡Entendido!","Compris !","Capito!","Entendi!","Verstanden!","了解！","알겠어요!","明白了！","فهمت!","Понятно!"]) }

    // App tour steps
    var tourStep1Title: String { L(["Overall Progress","Genel İlerleme","Progreso general","Progression globale","Avanzamento totale","Progresso geral","Gesamtfortschritt","全体の進捗","전체 진행률","总体进度","التقدم العام","Общий прогресс"]) }
    var tourStep1Desc: String  { L(["Track your total reviewed media, items to delete, and yearly breakdown here.","Toplam incelenen medya sayını, silinecekleri ve yıllara göre dağılımı buradan takip et.","Controla aquí tu contenido revisado, lo que vas a eliminar y el desglose anual.","Suivez ici vos médias examinés, les éléments à supprimer et la répartition annuelle.","Tieni traccia dei media esaminati, degli elementi da eliminare e del riepilogo annuale.","Acompanhe aqui sua mídia revisada, itens para excluir e o resumo anual.","Verfolge deinen Fortschritt, zu löschende Elemente und die jährliche Aufschlüsselung hier.","確認済みメディア、削除予定、年別内訳をここで確認。","검토한 미디어, 삭제 항목, 연도별 분포를 여기서 확인하세요.","在此跟踪已查看的媒体、待删除项和年度分布。","تابع هنا الوسائط المراجَعة والعناصر للحذف والتوزيع السنوي.","Здесь отслеживайте просмотренное, элементы для удаления и разбивку по годам."]) }
    var tourStep2Title: String { L(["Media by Year & Month","Yıl & Ay Bazlı Medyalar","Contenido por año y mes","Médias par année et mois","Media per anno e mese","Mídia por ano e mês","Medien nach Jahr & Monat","年・月別メディア","연도 & 월별 미디어","按年和月分类的媒体","الوسائط حسب السنة والشهر","Медиа по годам и месяцам"]) }
    var tourStep2Desc: String  { L(["Your photos and videos are grouped by year and month. Tap a year to see months.","Fotoğraf ve videoların yıl ve aylara göre gruplanmış. Bir yıla dokun, aylara geç.","Tus fotos y videos se agrupan por año y mes. Toca un año para ver los meses.","Vos photos et vidéos sont groupées par année et mois. Touchez une année pour voir les mois.","Le tue foto e i video sono raggruppati per anno e mese. Tocca un anno per i mesi.","Suas fotos e vídeos são agrupados por ano e mês. Toque em um ano para ver os meses.","Fotos und Videos sind nach Jahr und Monat gruppiert. Tippe ein Jahr an.","写真と動画は年・月でグループ化。年をタップして月を表示。","사진과 동영상은 연도와 월로 그룹화됩니다. 연도를 눌러 월을 보세요.","照片和视频按年和月分组。点按某一年查看月份。","صورك وفيديوهاتك مجمَّعة حسب السنة والشهر. انقر سنة لرؤية الأشهر.","Фото и видео сгруппированы по годам и месяцам. Нажмите год, чтобы увидеть месяцы."]) }
    var tourStep3Title: String { L(["Monthly View","Aylık Görünüm","Vista mensual","Vue mensuelle","Vista mensile","Visão mensal","Monatsansicht","月別ビュー","월별 보기","月度视图","العرض الشهري","Помесячный вид"]) }
    var tourStep3Desc: String  { L(["See how many photos and videos each month contains. Tap any month to start reviewing.","Her ay kaç fotoğraf ve video olduğunu buradan görürsün. Bir aya dokunarak incelemeye başlayabilirsin.","Mira cuántas fotos y videos hay en cada mes. Toca un mes para empezar a revisar.","Voyez combien de photos et vidéos contient chaque mois. Touchez un mois pour commencer.","Vedi quante foto e video contiene ogni mese. Tocca un mese per iniziare.","Veja quantas fotos e vídeos cada mês contém. Toque em um mês para começar.","Sieh, wie viele Fotos und Videos jeder Monat enthält. Tippe einen Monat an, um zu beginnen.","各月の写真・動画の数を確認。月をタップして確認を開始。","각 달에 사진과 동영상이 몇 개인지 확인하세요. 월을 눌러 검토를 시작하세요.","查看每个月有多少照片和视频。点按任意月份开始查看。","شاهد عدد الصور والفيديوهات في كل شهر. انقر شهرًا لبدء المراجعة.","Узнайте, сколько фото и видео в каждом месяце. Нажмите месяц, чтобы начать."]) }
    var tourStep4Title: String { L(["Tabs","Sekmeler","Pestañas","Onglets","Schede","Abas","Registerkarten","タブ","탭","标签页","علامات التبويب","Вкладки"]) }
    var tourStep4Desc: String  { L(["Find storage stats in the Library tab and app settings in the Settings tab.","Kütüphane sekmesinde depolama istatistiklerini, Ayarlar sekmesinde uygulama ayarlarını bulabilirsin.","Encuentra estadísticas de almacenamiento en Biblioteca y los ajustes en Ajustes.","Trouvez les stats de stockage dans Bibliothèque et les réglages dans Réglages.","Trova le statistiche di spazio nella scheda Libreria e le impostazioni in Impostazioni.","Veja estatísticas de armazenamento na aba Biblioteca e os ajustes na aba Ajustes.","Speicherstatistiken im Mediathek-Tab, App-Einstellungen im Einstellungen-Tab.","ライブラリタブで容量統計、設定タブでアプリ設定を確認。","라이브러리 탭에서 저장 공간 통계를, 설정 탭에서 앱 설정을 확인하세요.","在“图库”标签查看存储统计，在“设置”标签查看应用设置。","تجد إحصائيات التخزين في تبويب المكتبة وإعدادات التطبيق في تبويب الإعدادات.","Статистика хранилища — во вкладке «Библиотека», настройки — во вкладке «Настройки»."]) }

    // MARK: - Tab bar
    var tabHome: String     { L(["Home","Ana Sayfa","Inicio","Accueil","Home","Início","Startseite","ホーム","홈","主页","الرئيسية","Главная"]) }
    var tabAlbums: String   { L(["Albums","Albümler","Álbumes","Albums","Album","Álbuns","Alben","アルバム","앨범","相册","الألبومات","Альбомы"]) }
    var tabStats: String    { L(["Library","Kütüphane","Biblioteca","Bibliothèque","Libreria","Biblioteca","Mediathek","ライブラリ","라이브러리","图库","المكتبة","Библиотека"]) }
    var tabSettings: String { L(["Settings","Ayarlar","Ajustes","Réglages","Impostazioni","Ajustes","Einstellungen","設定","설정","设置","الإعدادات","Настройки"]) }

    // MARK: - Stats
    var statTitle: String       { L(["Library","Kütüphane","Biblioteca","Bibliothèque","Libreria","Biblioteca","Mediathek","ライブラリ","라이브러리","图库","المكتبة","Библиотека"]) }
    var statPhotos: String      { L(["Photos","Fotoğraflar","Fotos","Photos","Foto","Fotos","Fotos","写真","사진","照片","الصور","Фото"]) }
    var statVideos: String      { L(["Videos","Videolar","Videos","Vidéos","Video","Vídeos","Videos","動画","동영상","视频","الفيديو","Видео"]) }
    var statStorage: String     { L(["Storage","Depolama","Almacenamiento","Stockage","Spazio","Armazenamento","Speicher","ストレージ","저장 공간","存储","التخزين","Хранилище"]) }
    var statCalculating: String { L(["Calculating…","Hesaplanıyor…","Calculando…","Calcul…","Calcolo…","Calculando…","Wird berechnet…","計算中…","계산 중…","正在计算…","جارٍ الحساب…","Подсчёт…"]) }
    var statCalculatingHint: String { L(["Calculating library size,\nplease wait a moment.","Kütüphane boyutu hesaplanıyor,\n lütfen bekleyiniz.","Calculando el tamaño de la biblioteca,\nespera un momento.","Calcul de la taille de la bibliothèque,\nveuillez patienter.","Calcolo della dimensione della libreria,\nattendi un momento.","Calculando o tamanho da biblioteca,\naguarde um momento.","Bibliotheksgröße wird berechnet,\nbitte warten.","ライブラリのサイズを計算中、\n少々お待ちください。","라이브러리 크기를 계산 중입니다,\n잠시만 기다려 주세요.","正在计算图库大小，\n请稍候。","جارٍ حساب حجم المكتبة،\nيرجى الانتظار.","Подсчёт размера библиотеки,\nподождите."]) }
    var statProgress: String    { L(["Progress","İlerleme","Progreso","Progression","Avanzamento","Progresso","Fortschritt","進捗","진행률","进度","التقدم","Прогресс"]) }
    var statReviewed: String    { L(["Reviewed","İncelendi","Revisado","Examiné","Esaminato","Revisado","Überprüft","確認済み","검토됨","已查看","تمت المراجعة","Просмотрено"]) }
    var statKept: String        { L(["Kept","Tutuldu","Conservadas","Conservées","Tenute","Mantidas","Behalten","保持","유지","保留","محتفظ","Оставлено"]) }
    var statToDelete: String    { L(["To Delete","Silinecek","Para eliminar","À supprimer","Da eliminare","Para excluir","Zu löschen","削除予定","삭제 예정","待删除","للحذف","К удалению"]) }
    var statDeleted: String     { L(["Deleted","Silindi","Eliminadas","Supprimées","Eliminate","Excluídas","Gelöscht","削除済み","삭제됨","已删除","تم الحذف","Удалено"]) }
    var statFavorites: String   { L(["Favorites","Favori","Favoritos","Favoris","Preferiti","Favoritos","Favoriten","お気に入り","즐겨찾기","收藏","المفضلة","Избранное"]) }
    var statTrashSize: String   { L(["Trash Size","Silinecek Alan","Tamaño de papelera","Taille corbeille","Dimensione cestino","Tamanho da lixeira","Papierkorb","ゴミ箱の容量","휴지통 용량","回收站大小","حجم المهملات","Размер корзины"]) }
    var statDuplicates: String  { L(["Duplicates","Olası Kopya","Duplicados","Doublons","Duplicati","Duplicados","Duplikate","重複","중복","重复项","التكرارات","Дубликаты"]) }
    var statByYear: String      { L(["Storage by Year","Yıllara Göre Depolama","Almacenamiento por año","Stockage par année","Spazio per anno","Armazenamento por ano","Speicher nach Jahr","年別ストレージ","연도별 저장 공간","按年存储","التخزين حسب السنة","Хранилище по годам"]) }
    var statLargestPhotos: String { L(["Largest Photos","En Büyük Fotoğraflar","Fotos más grandes","Photos les plus volumineuses","Foto più grandi","Maiores fotos","Größte Fotos","大きい写真","가장 큰 사진","最大的照片","أكبر الصور","Самые большие фото"]) }
    var statLargestVideos: String { L(["Largest Videos","En Büyük Videolar","Videos más grandes","Vidéos les plus volumineuses","Video più grandi","Maiores vídeos","Größte Videos","大きい動画","가장 큰 동영상","最大的视频","أكبر الفيديوهات","Самые большие видео"]) }

    // MARK: - Duplicates
    var dupTitle: String        { L(["Potential Duplicates","Olası Kopyalar","Posibles duplicados","Doublons potentiels","Possibili duplicati","Possíveis duplicados","Mögliche Duplikate","重複の可能性","중복 가능성","可能的重复项","تكرارات محتملة","Возможные дубликаты"]) }
    var dupHint: String         { L(["Tap the photo you want to keep","Saklamak istediğin fotoğrafa dokun","Toca la foto que quieres conservar","Touchez la photo à garder","Tocca la foto da tenere","Toque na foto que deseja manter","Tippe auf das Foto, das du behalten möchtest","残したい写真をタップ","유지할 사진을 탭하세요","点按要保留的照片","انقر الصورة التي تريد الاحتفاظ بها","Нажмите фото, которое хотите оставить"]) }
    var dupSkip: String         { L(["Skip this group","Bu grubu atla","Omitir este grupo","Ignorer ce groupe","Salta questo gruppo","Pular este grupo","Diese Gruppe überspringen","このグループをスキップ","이 그룹 건너뛰기","跳过此组","تخطّ هذه المجموعة","Пропустить эту группу"]) }
    var dupCompleted: String    { L(["All done!","Hepsi tamam!","¡Todo listo!","Terminé !","Tutto fatto!","Tudo pronto!","Alles erledigt!","すべて完了！","모두 완료!","全部完成！","تم كل شيء!","Готово!"]) }
    var dupCompletedSub: String { L(["All duplicate groups reviewed.","Tüm kopya grupları incelendi.","Todos los grupos de duplicados revisados.","Tous les groupes de doublons examinés.","Tutti i gruppi di duplicati esaminati.","Todos os grupos de duplicados revisados.","Alle Duplikatgruppen überprüft.","すべての重複グループを確認しました。","모든 중복 그룹을 검토했습니다.","已查看所有重复组。","تمت مراجعة كل مجموعات التكرار.","Все группы дубликатов просмотрены."]) }

    func statItemCount(_ n: Int) -> String { L(["\(n.fmtCount) items","\(n.fmtCount) öğe","\(n.fmtCount) elementos","\(n.fmtCount) éléments","\(n.fmtCount) elementi","\(n.fmtCount) itens","\(n.fmtCount) Elemente","\(n.fmtCount)個","\(n.fmtCount)개","\(n.fmtCount) 个项目","\(n.fmtCount) عنصر","\(n.fmtCount) элем."]) }

    // MARK: - Date formatting
    var locale: Locale { Locale(identifier: language.rawValue) }

    func monthTitle(from groupID: String) -> String {
        let fmt = DateFormatter()
        fmt.locale = locale
        fmt.dateFormat = "yyyy-MM"
        guard let date = fmt.date(from: groupID) else { return groupID }
        fmt.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return fmt.string(from: date).capitalized(with: locale)
    }

    // MARK: - Appearance
    var appearanceSection: String  { L(["Appearance","Görünüm","Apariencia","Apparence","Aspetto","Aparência","Erscheinungsbild","外観","외관","外观","المظهر","Внешний вид"]) }
    var appearanceSystem: String   { L(["System","Sistem","Sistema","Système","Sistema","Sistema","System","システム","시스템","跟随系统","النظام","Системное"]) }
    var appearanceLight: String    { L(["Light","Açık","Claro","Clair","Chiaro","Claro","Hell","ライト","밝게","浅色","فاتح","Светлое"]) }
    var appearanceDark: String     { L(["Dark","Koyu","Oscuro","Sombre","Scuro","Escuro","Dunkel","ダーク","어둡게","深色","داكن","Тёмное"]) }

    // MARK: - Notifications
    var notificationsSection: String { L(["Notifications","Bildirimler","Notificaciones","Notifications","Notifiche","Notificações","Benachrichtigungen","通知","알림","通知","الإشعارات","Уведомления"]) }
    var weeklyReminder: String       { L(["Daily Reminders","Günlük Hatırlatıcılar","Recordatorios diarios","Rappels quotidiens","Promemoria giornalieri","Lembretes diários","Tägliche Erinnerungen","毎日のリマインダー","매일 알림","每日提醒","تذكيرات يومية","Ежедневные напоминания"]) }
    var weeklyReminderSub: String    { L(["Sends two reminders a day to review your gallery","Galeriyi incelemen için günde iki hatırlatıcı gönderir","Envía dos recordatorios al día para revisar tu galería","Envoie deux rappels par jour pour réviser votre galerie","Invia due promemoria al giorno per revisionare la galleria","Envia dois lembretes por dia para revisar sua galeria","Sendet zweimal täglich eine Erinnerung zur Galerie","1日2回ギャラリーを確認するリマインダーを送信","하루 두 번 갤러리 확인 알림을 보냅니다","每天发送两次提醒，帮助您查看图库","يرسل تذكيرَين يوميًا لمراجعة معرضك","Отправляет два напоминания в день для просмотра галереи"]) }
    var storageWarning: String       { L(["Storage Warning","Depolama Uyarısı","Aviso de almacenamiento","Alerte de stockage","Avviso spazio","Aviso de armazenamento","Speicherwarnung","ストレージ警告","저장 공간 경고","存储警告","تنبيه التخزين","Предупреждение о памяти"]) }
    var storageWarningSub: String    { L(["Sends a notification when storage exceeds 80%","Depolama %80'i geçince bildirim gönderir","Envía un aviso cuando el almacenamiento supera el 80%","Envoie une alerte quand le stockage dépasse 80 %","Invia un avviso quando lo spazio supera l'80%","Envia um aviso quando o armazenamento passa de 80%","Benachrichtigung bei mehr als 80 % Speicher","ストレージが80%を超えると通知","저장 공간이 80%를 넘으면 알림","存储超过 80% 时发送通知","يرسل تنبيهًا عند تجاوز التخزين 80%","Уведомляет, когда память превышает 80%"]) }
    var reminderDay: String          { L(["Day","Gün","Día","Jour","Giorno","Dia","Tag","曜日","요일","日期","اليوم","День"]) }
    var reminderTime: String         { L(["Time","Saat","Hora","Heure","Ora","Hora","Uhrzeit","時刻","시간","时间","الوقت","Время"]) }
    var allowNotifications: String   { L(["Allow Notifications","Bildirimlere İzin Ver","Permitir notificaciones","Autoriser les notifications","Consenti notifiche","Permitir notificações","Benachrichtigungen erlauben","通知を許可","알림 허용","允许通知","السماح بالإشعارات","Разрешить уведомления"]) }
    var notifPermissionSub: String   { L(["Permission required to receive reminders","Hatırlatıcı almak için izin gerekli","Se necesita permiso para recibir recordatorios","Autorisation requise pour les rappels","Permesso necessario per i promemoria","Permissão necessária para receber lembretes","Berechtigung für Erinnerungen erforderlich","リマインダー受信には許可が必要","알림을 받으려면 권한이 필요합니다","接收提醒需要权限","يلزم الإذن لاستلام التذكيرات","Для напоминаний нужно разрешение"]) }
    var notifDenied: String          { L(["Notifications disabled","Bildirimler kapalı","Notificaciones desactivadas","Notifications désactivées","Notifiche disattivate","Notificações desativadas","Benachrichtigungen deaktiviert","通知がオフ","알림 꺼짐","通知已关闭","الإشعارات معطّلة","Уведомления выключены"]) }
    var notifDeniedSub: String       { L(["Allow notifications in System Settings","Sistem ayarlarından bildirimlere izin ver","Permite las notificaciones en Ajustes","Autorisez les notifications dans Réglages","Consenti le notifiche in Impostazioni","Permita as notificações nos Ajustes","Benachrichtigungen in Einstellungen erlauben","システム設定で通知を許可","시스템 설정에서 알림을 허용하세요","在系统设置中允许通知","فعّل الإشعارات من إعدادات النظام","Разрешите уведомления в настройках"]) }
    var openSettings: String         { L(["Open Settings","Ayarları Aç","Abrir Ajustes","Ouvrir Réglages","Apri Impostazioni","Abrir Ajustes","Einstellungen öffnen","設定を開く","설정 열기","打开设置","فتح الإعدادات","Открыть настройки"]) }
    var notifOn: String              { L(["On","Açık","Activadas","Activées","Attive","Ativadas","Aktiv","オン","켜짐","已开启","مفعّل","Вкл"]) }
    var notifOff: String             { L(["Off","Kapalı","Desactivadas","Désactivées","Disattive","Desativadas","Inaktiv","オフ","꺼짐","已关闭","معطّل","Выкл"]) }
    var weekdays: [String] {
        LA([
            ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"],
            ["Pazar","Pazartesi","Salı","Çarşamba","Perşembe","Cuma","Cumartesi"],
            ["Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"],
            ["Dimanche","Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi"],
            ["Domenica","Lunedì","Martedì","Mercoledì","Giovedì","Venerdì","Sabato"],
            ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"],
            ["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"],
            ["日曜日","月曜日","火曜日","水曜日","木曜日","金曜日","土曜日"],
            ["일요일","월요일","화요일","수요일","목요일","금요일","토요일"],
            ["星期日","星期一","星期二","星期三","星期四","星期五","星期六"],
            ["الأحد","الإثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"],
            ["Воскресенье","Понедельник","Вторник","Среда","Четверг","Пятница","Суббота"]
        ])
    }

    // MARK: - Daily Stats
    func todayCount(_ n: Int) -> String { L(["\(n.fmtCount) photos reviewed today 🔥","Bugün \(n.fmtCount) fotoğraf incelendi 🔥","\(n.fmtCount) fotos revisadas hoy 🔥","\(n.fmtCount) photos examinées aujourd'hui 🔥","\(n.fmtCount) foto esaminate oggi 🔥","\(n.fmtCount) fotos revisadas hoje 🔥","Heute \(n.fmtCount) Fotos bewertet 🔥","今日 \(n.fmtCount)枚を確認 🔥","오늘 사진 \(n.fmtCount)장 검토 🔥","今天已查看 \(n.fmtCount) 张照片 🔥","تمت مراجعة \(n.fmtCount) صورة اليوم 🔥","Сегодня просмотрено \(n.fmtCount) фото 🔥"]) }

    var videoLoadError: String { L(["Video could not be loaded","Video yüklenemedi","No se pudo cargar el video","Impossible de charger la vidéo","Impossibile caricare il video","Não foi possível carregar o vídeo","Video konnte nicht geladen werden","動画を読み込めませんでした","동영상을 불러올 수 없습니다","无法加载视频","تعذّر تحميل الفيديو","Не удалось загрузить видео"]) }

    // MARK: - Albums
    var albumsEmptyTitle: String    { L(["Add Album","Albüm Ekle","Añadir álbum","Ajouter un album","Aggiungi album","Adicionar álbum","Album hinzufügen","アルバムを追加","앨범 추가","添加相册","إضافة ألبوم","Добавить альбом"]) }
    var albumsEmptyDesc: String     { L(["Select albums you want to follow\nto build your personal gallery.","Takip etmek istediğin albümleri seçerek\nkendi galerinizi oluşturun.","Selecciona los álbumes a seguir\npara crear tu galería personal.","Sélectionnez les albums à suivre\npour créer votre galerie.","Seleziona gli album da seguire\nper creare la tua galleria.","Selecione os álbuns que deseja seguir\npara criar sua galeria pessoal.","Wähle Alben aus, die du verfolgen möchtest,\num deine Galerie zu erstellen.","フォローするアルバムを選んで\nマイギャラリーを作りましょう。","팔로우할 앨범을 선택하여\n나만의 갤러리를 만드세요.","选择要关注的相册\n以建立您的个人画廊。","اختر الألبومات التي تريد متابعتها\nلبناء معرضك الشخصي.","Выберите альбомы для создания\nвашей личной галереи."]) }
    var albumsAddButton: String     { L(["Select Album","Albüm Seç","Seleccionar álbum","Sélectionner un album","Seleziona album","Selecionar álbum","Album auswählen","アルバムを選択","앨범 선택","选择相册","اختر ألبومًا","Выбрать альбом"]) }
    var albumsLoading: String       { L(["Loading albums…","Albümler yükleniyor…","Cargando álbumes…","Chargement des albums…","Caricamento album…","Carregando álbuns…","Alben werden geladen…","アルバム読み込み中…","앨범 불러오는 중…","正在加载相册…","جارٍ تحميل الألبومات…","Загрузка альбомов…"]) }
    var albumsClear: String         { L(["Clear","Temizle","Borrar","Effacer","Cancella","Limpar","Löschen","クリア","초기화","清除","مسح","Очистить"]) }
    func albumsSelectedCount(_ n: Int) -> String { L(["\(n) album\(n == 1 ? "" : "s") selected","\(n) albüm seçili","\(n) álbum\(n == 1 ? "" : "es") seleccionado\(n == 1 ? "" : "s")","\(n) album\(n > 1 ? "s" : "") sélectionné\(n > 1 ? "s" : "")","\(n) album\(n == 1 ? "" : "i") selezionat\(n == 1 ? "o" : "i")","\(n) álbum\(n == 1 ? "" : "ns") selecionado\(n == 1 ? "" : "s")","\(n) Album\(n == 1 ? "" : "s") ausgewählt","\(n)件のアルバムを選択","앨범 \(n)개 선택됨","已选择 \(n) 个相册","تم تحديد \(n) ألبوم","Выбрано \(n) альбомов"]) }
    var albumsSectionSmart: String  { L(["System Albums","Sistem Albümleri","Álbumes del sistema","Albums système","Album di sistema","Álbuns do sistema","Systemalben","システムアルバム","시스템 앨범","系统相册","ألبومات النظام","Системные альбомы"]) }
    var albumsSectionShared: String { L(["Shared Albums","Paylaşılan Albümler","Álbumes compartidos","Albums partagés","Album condivisi","Álbuns compartilhados","Geteilte Alben","共有アルバム","공유 앨범","共享相册","الألبومات المشتركة","Общие альбомы"]) }
    var albumsSectionUser: String   { L(["My Albums","Albümlerim","Mis álbumes","Mes albums","I miei album","Meus álbuns","Meine Alben","マイアルバム","나의 앨범","我的相册","ألبوماتي","Мои альбомы"]) }

    // Smart album names (cihaz dilinden bağımsız tutarlı çeviriler)
    var smartSelfies: String       { L(["Selfies","Selfie'ler","Selfis","Selfies","Selfie","Selfies","Selfies","自撮り","셀카","自拍","سيلفي","Селфи"]) }
    var smartScreenshots: String   { L(["Screenshots","Ekran Görüntüleri","Capturas","Captures d'écran","Screenshot","Capturas de ecrã","Bildschirmfotos","スクリーンショット","스크린샷","截图","لقطات شاشة","Снимки экрана"]) }
    var smartFavorites: String     { L(["Favorites","Favoriler","Favoritos","Favoris","Preferiti","Favoritos","Favoriten","お気に入り","즐겨찾기","收藏","المفضلة","Избранное"]) }
    var smartVideos: String        { L(["Videos","Videolar","Videos","Vidéos","Video","Vídeos","Videos","動画","동영상","视频","الفيديوهات","Видео"]) }
    var smartBursts: String        { L(["Duplicates","Yinelenenler","Duplicados","Doublons","Duplicati","Duplicados","Duplikate","重複","중복","重复项","مكررة","Дубликаты"]) }
    var smartPanoramas: String     { L(["Panoramas","Panoramalar","Panoramas","Panoramas","Panorami","Panoramas","Panoramas","パノラマ","파노라마","全景","بانوراما","Панорамы"]) }
    var smartSlowMotion: String    { L(["Slow Motion","Ağır Çekim","Cámara lenta","Ralenti","Slow motion","Câmera lenta","Zeitlupe","スロー","슬로모션","慢动作","الحركة البطيئة","Замедленная съёмка"]) }
    var smartTimelapse: String     { L(["Time-lapse","Zaman Atlamalı","Time-lapse","Time-lapse","Time-lapse","Time-lapse","Zeitraffer","タイムラプス","타임랩스","延时","الفاصل الزمني","Таймلапس"]) }
    var smartAnimated: String      { L(["Animated","Animasyonlar","Animadas","Animés","Animate","Animados","Animiert","アニメーション","애니메이션","动态图","متحركة","Анимированные"]) }
    var smartLivePhotos: String    { L(["Live Photos","Live Photo'lar","Live Photos","Live Photos","Live Photo","Live Photos","Live Photos","Live Photos","Live Photos","实况照片","Live Photos","Live Photos"]) }
    var smartPortrait: String      { L(["Portrait","Portre","Retrato","Portrait","Ritratto","Retrato","Porträt","ポートレート","인물 사진","人像","بورتريه","Портрет"]) }
    var smartRecentlyAdded: String { L(["Recently Added","Son Eklenenler","Añadidos recientemente","Récemment ajoutés","Aggiunti di recente","Adicionados recentemente","Zuletzt hinzugefügt","最近追加","최근 추가","最近添加","المضافة مؤخرًا","Недавно добавленные"]) }

    // MARK: - About / Legal
    var aboutSection: String   { L(["About","Hakkında","Acerca de","À propos","Informazioni","Sobre","Über","アプリについて","정보","关于","حول","О приложении"]) }
    var privacyPolicy: String  { L(["Privacy Policy","Gizlilik Politikası","Política de privacidad","Politique de confidentialité","Informativa sulla privacy","Política de privacidade","Datenschutzerklärung","プライバシーポリシー","개인정보 처리방침","隐私政策","سياسة الخصوصية","Политика конфиденциальности"]) }
    var contactSupport: String { L(["Contact & Support","İletişim & Destek","Contacto y soporte","Contact et assistance","Contatti e supporto","Contato e suporte","Kontakt & Support","お問い合わせ・サポート","문의 및 지원","联系与支持","التواصل والدعم","Контакты и поддержка"]) }
    var versionLabel: String   { L(["Version","Sürüm","Versión","Version","Versione","Versão","Version","バージョン","버전","版本","الإصدار","Версия"]) }

    // MARK: - Accessibility (VoiceOver)
    var a11yPhoto: String     { L(["Photo","Fotoğraf","Foto","Photo","Foto","Foto","Foto","写真","사진","照片","صورة","Фото"]) }
    var a11ySwipeHint: String { L(["Swipe right to keep, left to delete, up for later. Double-tap to undo.","Sağa kaydır tut, sola kaydır sil, yukarı sonraya bırak. Geri almak için çift dokun.","Desliza a la derecha para conservar, a la izquierda para eliminar, arriba para después. Doble toque para deshacer.","Glissez à droite pour garder, à gauche pour supprimer, en haut pour plus tard. Double-touchez pour annuler.","Scorri a destra per tenere, a sinistra per eliminare, su per dopo. Tocca due volte per annullare.","Deslize para a direita para manter, para a esquerda para excluir, para cima para depois. Toque duplo para desfazer.","Nach rechts wischen zum Behalten, links zum Löschen, oben für später. Zum Rückgängigmachen doppeltippen.","右で保持、左で削除、上で後で。取り消すにはダブルタップ。","오른쪽으로 넘기면 유지, 왼쪽은 삭제, 위는 나중에. 실행 취소하려면 두 번 탭.","右滑保留，左滑删除，上滑稍后。双击撤销。","اسحب يمينًا للاحتفاظ، يسارًا للحذف، أعلى للاحقًا. انقر مرتين للتراجع.","Свайп вправо — оставить, влево — удалить, вверх — позже. Двойное нажатие — отмена."]) }
    var a11yTrash: String     { L(["Trash","Silinecekler","Papelera","Corbeille","Cestino","Lixeira","Papierkorb","ゴミ箱","휴지통","回收站","المهملات","Корзина"]) }

    // MARK: - Helpers
    // Returns the string for the current language; falls back to English (index 0).
    private func L(_ v: [String]) -> String {
        let i = AppLanguage.allCases.firstIndex(of: language) ?? 0
        return i < v.count ? v[i] : v[0]
    }
    // Array-of-arrays variant (e.g. weekday names).
    private func LA(_ v: [[String]]) -> [String] {
        let i = AppLanguage.allCases.firstIndex(of: language) ?? 0
        return i < v.count ? v[i] : v[0]
    }
}
