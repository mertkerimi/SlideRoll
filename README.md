# Swype 📸

**Swype**, iPhone'unuzdaki binlerce fotoğrafı hızlıca temizlemenizi sağlayan bir iOS uygulamasıdır. Tinder'dan ilham alan kart kaydırma sistemiyle fotoğraflarınızı kolayca yönetin.

---

## Özellikler

- **Tinder Benzeri Kaydırma** — Sağa kaydır: tut, Sola kaydır: sil, Yukarı kaydır: sonraya bırak
- **Yıl & Ay Grupları** — Fotoğraflar otomatik olarak yıla ve aya göre gruplandırılır
- **İlerleme Takibi** — Her ay ve yıl için detaylı inceleme istatistikleri
- **Silinecekler Merkezi** — Silinmek üzere işaretlenen fotoğrafları tek ekranda yönet
- **Geri Al** — Yanlış kaydırmaları anında geri al
- **Tam Ekran Önizleme** — Fotoğrafa dokun, tam boyutunu gör; pinch ile zoom yap
- **Kalıcı İlerleme** — Uygulamayı kapatsanız bile kaldığınız yerden devam edin
- **50.000+ Fotoğraf Desteği** — Lazy loading ve thumbnail cache ile akıcı performans
- **Dark / Light Mode** — Sistem temasına otomatik uyum

---

## Ekran Görüntüleri

| Ana Ekran | Ay İnceleme | Kart Kaydırma | Silinecekler |
|-----------|-------------|---------------|--------------|
| Yıl bazlı gruplar ve ilerleme | Ay bazlı detaylar | Swipe ile hızlı karar | Toplu silme merkezi |

---

## Kurulum

1. Repoyu klonlayın:
   ```bash
   git clone https://github.com/mertkerimi/Swype.git
   ```
2. `PhotoCleaner.xcodeproj` dosyasını Xcode ile açın
3. Gerçek bir iPhone'a veya simülatöre build edin (`⌘R`)
4. Fotoğraflar iznini verin ve kullanmaya başlayın

**Gereksinimler:** Xcode 26+, iOS 18+, Swift 6

---

## Nasıl Kullanılır

1. Uygulamayı açın ve fotoğraflara erişim izni verin
2. Yıl → Ay seçin
3. Fotoğrafları kaydırarak değerlendirin:
   - **→ Sağ:** Tut
   - **← Sol:** Sil
   - **↑ Yukarı:** Sonraya bırak
4. Silinecekler ekranından fotoğrafları kalıcı olarak silin

---

## Teknoloji

- **SwiftUI** — Tüm arayüz
- **Photos Framework** — Fotoğraf erişimi ve silme
- **PHCachingImageManager** — Performanslı görsel yükleme
- **Swift Observation (@Observable)** — State yönetimi
- **UserDefaults** — İlerleme kalıcılığı

---

## Geliştirici

**Mert Kerimi** — [@mertkerimi](https://github.com/mertkerimi)

---

## Lisans

MIT License — dilediğiniz gibi kullanabilirsiniz.
