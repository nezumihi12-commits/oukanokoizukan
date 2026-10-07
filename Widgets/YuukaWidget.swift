import SwiftUI
import WidgetKit

struct YuukaEntry: TimelineEntry {
    let date: Date
    let snapshot: CompanionSnapshot?
}
struct YuukaProvider: TimelineProvider {
    func placeholder(in context: Context) -> YuukaEntry {
        YuukaEntry(date: Date(), snapshot: .init(generatedAt: Date(), dueDates: [Date()], overdueCount: 0, stateID: .review_due))
    }
    func getSnapshot(in context: Context, completion: @escaping (YuukaEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : YuukaEntry(date: Date(), snapshot: CompanionStorage.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<YuukaEntry>) -> Void) {
        let now = Date(), snapshot = CompanionStorage.load()
        let dates = [now] + Array(Set(snapshot?.dueDates.filter { $0 > now && $0 < now.addingTimeInterval(86400) } ?? [])).sorted().prefix(30)
        completion(Timeline(entries: dates.map { YuukaEntry(date: $0, snapshot: snapshot) }, policy: .after(now.addingTimeInterval(3600))))
    }
}
struct YuukaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: YuukaEntry
    var body: some View {
        HStack(spacing: 8) {
            YuukaPortrait(state: entry.snapshot?.displayState(at: entry.date) ?? .idle)
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 8) {
                    Text("千花之恋図鑑").font(.caption)
                    label.font(.headline)
                    Text("復習を開く").font(.subheadline).foregroundStyle(.green)
                }
            }
        }
        .overlay(alignment: .bottom) { if family == .systemSmall { label.font(.headline) } }
        .containerBackground(Color(red: 0.96, green: 0.94, blue: 0.86), for: .widget)
        .widgetURL(URL(string: "hanazukan://review"))
    }
    private var label: Text {
        if let snapshot = entry.snapshot { return Text("復習 \(snapshot.count(at: entry.date))属") }
        return Text("アプリを開いて連携")
    }
}
@main
struct YuukaReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YuukaReview", provider: YuukaProvider()) { YuukaWidgetView(entry: $0) }
            .configurationDisplayName("幽香と復習")
            .description("復習の時期が来た植物を確認できます。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
