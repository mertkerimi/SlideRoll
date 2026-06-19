import WidgetKit
import SwiftUI

// MARK: - Shared Data

private let shared = UserDefaults(suiteName: "group.com.mertkerimi.Swype")
private let dailyGoal = 100

struct YearStat: Identifiable {
    let year: String
    let total: Int
    let reviewed: Int
    var id: String { year }
    var progress: Double { total > 0 ? Double(reviewed) / Double(total) : 0 }
}

struct SwypeEntry: TimelineEntry {
    let date: Date
    let pending: Int
    let total: Int
    let reviewed: Int
    let savingsBytes: Int64
    let todayCount: Int
    let deletedCount: Int
    let keptCount: Int
    let years: [YearStat]
    let themeColor: Color
    let themeColorEnd: Color
    let lang: String
    var ws: WidgetStrings { WidgetStrings(lang: lang) }
}

struct WidgetStrings {
    let lang: String
    // Order: en, tr, es, fr, it, pt, de, ja, ko, zh, ar, ru
    private static let order = ["en","tr","es","fr","it","pt","de","ja","ko","zh","ar","ru"]
    private func p(_ v: [String]) -> String {
        let i = Self.order.firstIndex(of: lang) ?? 0
        return i < v.count ? v[i] : v[0]
    }
    var continueBtn: String  { p(["Continue","Devam Et","Continuar","Continuer","Continua","Continuar","Weiter","続ける","계속","继续","متابعة","Продолжить"]) }
    var pending: String      { p(["pending","bekliyor","pendientes","en attente","in attesa","pendentes","ausstehend","保留中","대기","待处理","قيد الانتظار","в ожидании"]) }
    var reviewed: String     { p(["reviewed","incelendi","revisadas","examinées","esaminate","revisadas","geprüft","確認済み","검토됨","已查看","تمت المراجعة","просмотрено"]) }
    var kept: String         { p(["kept","tutuldu","conservadas","conservées","tenute","mantidas","behalten","保持","유지","保留","محتفظ","оставлено"]) }
    var deleted: String      { p(["deleted","silindi","eliminadas","supprimées","eliminate","excluídas","gelöscht","削除済み","삭제됨","已删除","تم حذفها","удалено"]) }
    var savings: String      { p(["saved","tasarruf","liberado","libéré","liberato","liberado","gespart","空き","확보","已释放","تم توفيره","сэкономлено"]) }
    var today: String        { p(["today","bugün","hoy","aujourd'hui","oggi","hoje","heute","今日","오늘","今天","اليوم","сегодня"]) }
    var done: String         { p(["done","tamam","listo","terminé","fatto","concluído","fertig","完了","완료","完成","تم","готово"]) }
    var waitingPhotos: String{ p(["photos pending","fotoğraf bekliyor","fotos pendientes","photos en attente","foto in attesa","fotos pendentes","Fotos ausstehend","枚の写真が保留中","사진 대기 중","张照片待处理","صورة قيد الانتظار","фото в ожидании"]) }
    var byYear: String       { p(["BY YEAR","YILLARA GÖRE İLERLEME","POR AÑO","PAR ANNÉE","PER ANNO","POR ANO","NACH JAHR","年別","연도별","按年份","حسب السنة","ПО ГОДАМ"]) }
    var level: String        { p(["Level","Seviye","Nivel","Niveau","Livello","Nível","Level","レベル","레벨","等级","المستوى","Уровень"]) }
    func completed(_ pct: Int) -> String { p(["\(pct)% done","%\(pct) tamamlandı","\(pct)% completado","\(pct)% terminé","\(pct)% completato","\(pct)% concluído","\(pct)% erledigt","\(pct)% 完了","\(pct)% 완료","\(pct)% 完成","\(pct)% مكتمل","\(pct)% завершено"]) }
    func reviewedOf(_ pct: Int) -> String { p(["\(pct)% reviewed","%\(pct) incelendi","\(pct)% revisadas","\(pct)% examinées","\(pct)% esaminate","\(pct)% revisadas","\(pct)% geprüft","\(pct)% 確認済み","\(pct)% 검토됨","\(pct)% 已查看","\(pct)% تمت المراجعة","\(pct)% просмотрено"]) }
}

// MARK: - Theme Color

private extension ColorTheme {
    static func resolve(_ raw: String) -> ColorTheme { ColorTheme(rawValue: raw) ?? .blue }
}

// MARK: - Provider

struct SwypeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SwypeEntry { sampleEntry() }
    func getSnapshot(in context: Context, completion: @escaping (SwypeEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SwypeEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> SwypeEntry {
        let pending   = shared?.integer(forKey: "widgetPendingCount")  ?? 0
        let total     = shared?.integer(forKey: "widgetTotalCount")    ?? 0
        let reviewed  = shared?.integer(forKey: "widgetReviewedCount") ?? 0
        let savings   = shared?.object(forKey: "widgetSavingsBytes") as? Int64 ?? 0
        let deleted   = shared?.integer(forKey: "widgetDeletedCount")  ?? 0
        let kept      = shared?.integer(forKey: "widgetKeptCount")     ?? 0
        let count     = shared?.integer(forKey: "dailyDecisionCount")  ?? 0
        let dateStr   = shared?.string(forKey: "dailyDecisionDate")    ?? ""
        let theme     = shared?.string(forKey: "widgetTheme")     ?? "blue"
        let lang      = shared?.string(forKey: "widgetLanguage")   ?? "en"
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: .now) == dateStr ? count : 0

        var years: [YearStat] = []
        if let data = shared?.data(forKey: "widgetYearData"),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            years = arr.compactMap { d in
                guard let y = d["year"] as? String,
                      let t = d["total"] as? Int,
                      let r = d["reviewed"] as? Int else { return nil }
                return YearStat(year: y, total: t, reviewed: r)
            }
        }

        let resolved = ColorTheme.resolve(theme)
        return SwypeEntry(date: .now, pending: pending, total: total, reviewed: reviewed,
                          savingsBytes: savings, todayCount: today,
                          deletedCount: deleted, keptCount: kept,
                          years: years,
                          themeColor: resolved.accent, themeColorEnd: resolved.accentEnd,
                          lang: lang)
    }

    private func sampleEntry() -> SwypeEntry {
        SwypeEntry(date: .now, pending: 142, total: 800, reviewed: 658,
                   savingsBytes: 1_200_000_000, todayCount: 47,
                   deletedCount: 312, keptCount: 346,
                   years: [YearStat(year: "2026", total: 300, reviewed: 120),
                            YearStat(year: "2025", total: 400, reviewed: 380),
                            YearStat(year: "2024", total: 100, reviewed: 158)],
                   themeColor: ColorTheme.blue.accent, themeColorEnd: ColorTheme.blue.accentEnd,
                   lang: "tr")
    }
}

// MARK: - Helpers

@ViewBuilder
private func widgetBackground(themeColor: Color) -> some View {
    ZStack {
        // Koyu taban gradyanı
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.14),
                Color(red: 0.04, green: 0.04, blue: 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // Üstten aşağı inen ince tema rengi hattı
        LinearGradient(
            colors: [themeColor.opacity(0.28), Color.clear],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.45)
        )
        // Hafif tema rengi tonu — tüm yüzey
        themeColor.opacity(0.04)
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    if bytes >= 1_000_000_000 { return String(format: "%.1f GB", Double(bytes) / 1e9) }
    if bytes >= 1_000_000     { return String(format: "%.0f MB", Double(bytes) / 1e6) }
    if bytes > 0               { return String(format: "%.0f KB", Double(bytes) / 1e3) }
    return "—"
}

private func fmtNum(_ n: Int) -> String { n.formatted(.number) }

// MARK: - Small Streak Widget View

struct SmallStreakView: View {
    let entry: SwypeEntry

    private var levelBase: Int {
        guard entry.todayCount > 0 else { return 0 }
        return ((entry.todayCount - 1) / 100) * 100
    }
    private var currentGoal: Int  { levelBase + 100 }
    private var currentLevel: Int { levelBase / 100 + 1 }
    private var levelProgress: Double {
        Double(entry.todayCount - levelBase) / 100.0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: levelProgress)
                    .stroke(
                        LinearGradient(colors: [entry.themeColor, entry.themeColorEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [entry.themeColorEnd, entry.themeColor],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: entry.themeColor.opacity(0.8), radius: 10)
                    Text(fmtNum(entry.todayCount))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text("\(fmtNum(entry.todayCount)) / \(currentGoal)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(entry.ws.level) \(currentLevel)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(entry.themeColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "swype://shuffle")!)
    }
}

// MARK: - Small Storage Widget View

struct SmallStorageView: View {
    let entry: SwypeEntry

    private var progress: Double {
        entry.total > 0 ? Double(entry.reviewed) / Double(entry.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: shuffle linki
            Link(destination: URL(string: "swype://shuffle")!) {
                HStack(spacing: 4) {
                    Image(systemName: "shuffle").font(.system(size: 11, weight: .bold)).foregroundStyle(entry.themeColor)
                    Text(entry.ws.continueBtn).font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                    if entry.todayCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(.orange)
                            Text(fmtNum(entry.todayCount)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            Text(fmtNum(entry.pending))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5).lineLimit(1)

            Text(entry.ws.waitingPhotos)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [entry.themeColor, entry.themeColorEnd],
                                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }.frame(height: 4)

                HStack {
                    Text(entry.ws.reviewedOf(Int(progress * 100)))
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    if entry.savingsBytes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.green)
                            Text(formatBytes(entry.savingsBytes))
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct MediumView: View {
    let entry: SwypeEntry

    private var progress: Double {
        entry.total > 0 ? Double(entry.reviewed) / Double(entry.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- ÜST BÖLÜM ---
            VStack(alignment: .leading, spacing: 6) {
                // Header
                Link(destination: URL(string: "swype://shuffle")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "shuffle").font(.system(size: 10, weight: .bold)).foregroundStyle(entry.themeColor)
                        Text(entry.ws.continueBtn).font(.system(size: 10, weight: .semibold)).foregroundStyle(.primary)
                        Spacer()
                        if entry.todayCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(.orange)
                                Text(fmtNum(entry.todayCount)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // Büyük sayaç
                Text("\(fmtNum(entry.reviewed))/\(fmtNum(entry.total)) \(entry.ws.reviewed)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7).lineLimit(1)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [entry.themeColor, entry.themeColorEnd],
                                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }.frame(height: 5)

                // Depolama + yüzde
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.green)
                        Text(formatBytes(entry.savingsBytes))
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                    }
                    Spacer()
                    Text(entry.ws.completed(Int(progress * 100)))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.25).padding(.vertical, 4)

            // --- ALT BÖLÜM: 5'li İstatistik Kutuları ---
            HStack(spacing: 5) {
                statCell(value: fmtNum(entry.pending),           label: entry.ws.pending,  icon: "clock.fill",             color: entry.themeColor)
                statCell(value: fmtNum(entry.reviewed),          label: entry.ws.reviewed, icon: "checkmark.circle.fill",  color: .primary)
                statCell(value: fmtNum(entry.keptCount),         label: entry.ws.kept,     icon: "heart.fill",             color: entry.themeColor)
                statCell(value: fmtNum(entry.deletedCount),      label: entry.ws.deleted,  icon: "trash.fill",             color: .red.opacity(0.85))
                statCell(value: formatBytes(entry.savingsBytes), label: entry.ws.savings,  icon: "arrow.down.circle.fill", color: .green)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Large Widget View

struct LargeView: View {
    let entry: SwypeEntry

    private var progress: Double {
        entry.total > 0 ? Double(entry.reviewed) / Double(entry.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Üst: ring + stat sayıları
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(entry.themeColor.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(LinearGradient(colors: [entry.themeColor, entry.themeColorEnd],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(String(format: "%d%%", Int(progress * 100)))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(entry.ws.done).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        largeStat(value: fmtNum(entry.deletedCount), label: entry.ws.deleted,  color: .red.opacity(0.85))
                        largeStat(value: fmtNum(entry.keptCount),    label: entry.ws.kept,     color: entry.themeColor)
                    }
                    HStack(spacing: 8) {
                        largeStat(value: fmtNum(entry.pending),           label: entry.ws.pending,  color: .primary)
                        largeStat(value: formatBytes(entry.savingsBytes),  label: entry.ws.savings,  color: .green)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider().opacity(0.3)

            // Shuffle header
            Link(destination: URL(string: "swype://shuffle")!) {
                HStack(spacing: 5) {
                    Image(systemName: "shuffle").font(.system(size: 12, weight: .bold)).foregroundStyle(entry.themeColor)
                    Text(entry.ws.continueBtn).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                    if entry.todayCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(.orange)
                            Text(fmtNum(entry.todayCount)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Yıllar
            Text(entry.ws.byYear).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(1)

            ForEach(entry.years.prefix(6)) { stat in
                Link(destination: URL(string: "swype://year/\(stat.year)")!) {
                    HStack(spacing: 8) {
                        Text(stat.year)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .frame(width: 44, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 7)
                                Capsule()
                                    .fill(LinearGradient(colors: [entry.themeColor, entry.themeColorEnd],
                                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * stat.progress, height: 7)
                            }
                        }.frame(height: 7)

                        Text(String(format: "%%%.0f", stat.progress * 100))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func largeStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Lock Screen Views

struct LockCircularView: View {
    let entry: SwypeEntry
    private var dailyProgress: Double { min(1.0, Double(entry.todayCount) / Double(dailyGoal)) }

    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: dailyProgress)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "flame.fill").font(.system(size: 12, weight: .bold))
        }
    }
}

struct LockInlineView: View {
    let entry: SwypeEntry
    var body: some View {
        Text("🔥 \(fmtNum(entry.todayCount))/\(dailyGoal) · \(fmtNum(entry.pending)) \(entry.ws.pending)")
    }
}

// MARK: - Widget Entry View Router

struct SwypeWidgetEntryView: View {
    let entry: SwypeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:       SmallStorageView(entry: entry)
        case .systemMedium:      MediumView(entry: entry)
        case .systemLarge:       LargeView(entry: entry)
        case .accessoryCircular: LockCircularView(entry: entry)
        case .accessoryInline:   LockInlineView(entry: entry)
        default:                 SmallStorageView(entry: entry)
        }
    }
}

// MARK: - Streak Small Widget (separate kind)

struct SwypeStreakEntryView: View {
    let entry: SwypeEntry
    var body: some View { SmallStreakView(entry: entry) }
}

// MARK: - Widgets & Bundle

struct SwypeMainWidget: Widget {
    let kind = "SwypeMainWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwypeProvider()) { entry in
            SwypeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    widgetBackground(themeColor: entry.themeColor)
                }
        }
        .configurationDisplayName("Swype")
        .description("Galeri durumu ve depolama özeti.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SwypeStreakWidget: Widget {
    let kind = "SwypeStreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwypeProvider()) { entry in
            SwypeStreakEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color(red: 0.04, green: 0.03, blue: 0.06)
                        RadialGradient(
                            colors: [entry.themeColor.opacity(0.55), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 130
                        )
                        RadialGradient(
                            colors: [entry.themeColor.opacity(0.20), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    }
                }
        }
        .configurationDisplayName("Swype — Günlük Hedef")
        .description("Bugünkü inceleme hedefinizi takip edin.")
        .supportedFamilies([.systemSmall])
    }
}

struct SwypeLockWidget: Widget {
    let kind = "SwypeLockWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwypeProvider()) { entry in
            SwypeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Swype — Kilit Ekranı")
        .description("Günlük ilerlemenizi kilit ekranında görün.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

@main
struct SwypeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SwypeMainWidget()
        SwypeStreakWidget()
        SwypeLockWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SwypeMainWidget()
} timeline: {
    SwypeEntry(date: .now, pending: 142, total: 800, reviewed: 658,
               savingsBytes: 1_200_000_000, todayCount: 47,
               deletedCount: 312, keptCount: 346,
               years: [], themeColor: ColorTheme.blue.accent,
               themeColorEnd: ColorTheme.blue.accentEnd, lang: "tr")
}

