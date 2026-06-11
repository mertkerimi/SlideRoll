import WidgetKit
import SwiftUI

private let sharedDefaults = UserDefaults(suiteName: "group.com.mertkerimi.Swype")

struct SwypeEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let totalCount: Int
    let reviewedCount: Int
    let savingsBytes: Int64
    let todayCount: Int
}

struct SwypeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SwypeEntry {
        SwypeEntry(date: .now, pendingCount: 142, totalCount: 800, reviewedCount: 658, savingsBytes: 1_200_000_000, todayCount: 18)
    }

    func getSnapshot(in context: Context, completion: @escaping (SwypeEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwypeEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> SwypeEntry {
        let pending  = sharedDefaults?.integer(forKey: "widgetPendingCount")  ?? 0
        let total    = sharedDefaults?.integer(forKey: "widgetTotalCount")    ?? 0
        let reviewed = sharedDefaults?.integer(forKey: "widgetReviewedCount") ?? 0
        let savings  = sharedDefaults?.object(forKey: "widgetSavingsBytes") as? Int64 ?? 0
        let count    = sharedDefaults?.integer(forKey: "dailyDecisionCount")  ?? 0
        let dateStr  = sharedDefaults?.string(forKey: "dailyDecisionDate")    ?? ""
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: .now) == dateStr ? count : 0
        return SwypeEntry(date: .now, pendingCount: pending, totalCount: total,
                          reviewedCount: reviewed, savingsBytes: savings, todayCount: today)
    }
}

struct SwypeWidgetView: View {
    let entry: SwypeEntry
    @Environment(\.widgetFamily) var family

    private var progress: Double {
        entry.totalCount > 0 ? Double(entry.reviewedCount) / Double(entry.totalCount) : 0
    }

    private var savingsText: String {
        let bytes = entry.savingsBytes
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            return String(format: "%.0f MB", Double(bytes) / 1_000_000)
        } else if bytes > 0 {
            return String(format: "%.0f KB", Double(bytes) / 1_000)
        }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 5) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("Swype")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if entry.todayCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(entry.todayCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                // Pending count
                Text("\(entry.pendingCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("fotoğraf bekliyor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(String(format: "%%%d incelendi", Int(progress * 100)))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if entry.savingsBytes > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green)
                                Text(savingsText)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .padding(3)
    }
}

struct SwypeWidget: Widget {
    let kind = "SwypeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwypeWidgetProvider()) { entry in
            SwypeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Swype")
        .description("Bekleyen fotoğraf sayısını gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SwypeWidget()
} timeline: {
    SwypeEntry(date: .now, pendingCount: 142, totalCount: 800,
               reviewedCount: 658, savingsBytes: 1_200_000_000, todayCount: 18)
}
