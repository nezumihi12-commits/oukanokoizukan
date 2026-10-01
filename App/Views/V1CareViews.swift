import SwiftUI
import UserNotifications

struct StudyPreview: View {
    let questions: [Question]
    let start: () -> Void
    private var plants: [Plant] { Array(Dictionary(grouping: questions, by: { $0.plant.id }).values.compactMap { $0.first?.plant }).sorted { $0.id < $1.id } }
    var body: some View {
        List {
            ForEach(plants) { plant in
                Section(plant.latin) { Text(plant.jpName); Text(plant.family); Text(plant.note).font(.footnote) }
            }
            Button("覚えた。問題へ", action: start).buttonStyle(.borderedProminent)
        }.navigationTitle("予習")
            .toolbar { Button("もう覚えている", action: start) }
    }
}
struct CareHub: View {
    @EnvironmentObject private var store: AppStore
    @State private var preview = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let recommendations = store.recommendedPlants(at: context.date)
            List {
                Section("今日の手入れ") {
                    if recommendations.isEmpty { Text("今日は特に手入れの必要はありません") }
                    else { Button("今日の手入れ　\(recommendations.count)属") { preview = true }.font(.headline) }
                    let locked = store.state.records.values.filter { ReviewEngine.isRelearnLocked($0, at: context.date) }.count
                    if locked > 0 { Text("\(locked)属は確認したばかり。明日以降に思い出してみましょう。").font(.footnote) }
                    NavigationLink("自由に見直す") { FreeReviewView() }
                    NavigationLink("手入れ待ちを見る") { ReviewQueueView() }
                }
                Section("近日の手入れ") {
                    let upcoming = store.plants.filter { p in
                        guard let r = store.state.records[p.id], let due = r.nextReviewAt else { return false }
                        return r.hasBloomed && due > context.date && due < context.date.addingTimeInterval(3 * ReviewEngine.day)
                    }.sorted { store.state.records[$0.id]!.nextReviewAt! < store.state.records[$1.id]!.nextReviewAt! }
                    if upcoming.isEmpty { Text("近日の予定はありません").foregroundStyle(.secondary) }
                    ForEach(Array(upcoming.prefix(5))) { plant in
                        NavigationLink { PlantDetail(plant: plant) } label: {
                            HStack {
                                MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: 1).frame(width: 45, height: 60)
                                VStack(alignment: .leading) {
                                    Text(store.isProtected(plant.id) ? "手入れが近い植物" : plant.latin)
                                    Text(store.state.records[plant.id]!.nextReviewAt!.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                }
                            }
                        }
                    }
                }
                if store.state.garden.layout?.ambiguousUnlocked == true { NavigationLink("曖昧の庭を見る") { AmbiguousGardenView() } }
                Section("記録と設定") {
                    NavigationLink("学習記録・バックアップ") { StatisticsView() }
                    NavigationLink("最近の出来事") { GardenEventsView() }
                    NavigationLink("設定") { GardenSettingsView() }
                }
            }
        }.navigationTitle("手入れ")
            .sheet(isPresented: $preview) { NavigationStack { CarePreview() }.environmentObject(store) }
    }
}
struct CarePreview: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var asked: Plant?
    @State private var launch: ReviewLaunch?
    var body: some View {
        let selected = store.recommendedPlants(at: Date())
        List {
            Text("今日はこの植物たちを思い出します。答えは伏せています。").font(.footnote)
            ForEach(selected) { plant in
                HStack {
                    MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: ReviewEngine.freshness(store.state.records[plant.id]!, at: Date())).frame(width: 65, height: 85)
                    VStack(alignment: .leading) {
                        Text(MemoryAppearance.of(ReviewEngine.freshness(store.state.records[plant.id]!, at: Date())).rawValue)
                        Text(store.state.garden.layout?.memberships?[plant.id]?.assignedGardenID == "central" ? "中央庭園" : "所属庭園の植物").font(.caption)
                        Button("幽香に訊く") { store.ask(plant.id); if store.revealedCatalogID == plant.id { asked = plant } }
                    }
                }
            }
            Button("この\(selected.count)属を手入れする") { launch = ReviewLaunch(questions: store.reviewQuestions(for: selected)) }.disabled(selected.isEmpty)
        }.navigationTitle("手入れの準備")
            .toolbar { Button("戻る") { dismiss() } }
            .alert("思い出し直す", isPresented: Binding(get: { asked != nil }, set: { if !$0 { asked = nil } })) { Button("確認しました") { asked = nil } } message: {
                if let p = asked { Text("\(p.latin)\n\(p.family)\n\(p.jpName)\n\(p.note)\n\n今日は演習として確認し、正式復習は24時間後に。") }
            }
            .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
}
struct PhotoBonusView: View {
    @EnvironmentObject private var store: AppStore
    let plant: Plant
    @State private var values = ["", ""]
    @State private var field = 0
    @State private var result: String?
    @State private var pad = true
    var body: some View {
        List {
            PhotoStrip(photos: store.state.photos[plant.id] ?? [], concealMetadata: true)
            ForEach(0..<2, id: \.self) { i in Button { field = i; pad = true } label: { Text((i == 0 ? "ラテン語属名：" : "科名：") + values[i]) } }
            if result == nil {
                if pad { AnswerPad(text: $values[field], latin: field == 0, previous: { field = 0 }, next: { if field == 0 { field = 1 } else { pad = false } }) }
                Button("回答する") {
                    let q = QuizEngine.question(plant, mode: .photo, all: store.plants, japanese: store.japanese)
                    let grade = QuizEngine.grade(q, values: values)
                    if grade.fullCorrect {
                        if store.update({ state in if var r = state.records[plant.id] { ReviewEngine.photoBonus(&r, at: Date()); state.records[plant.id] = r } }) { result = "正解。今回の間隔ボーナスを記録しました。" }
                    } else { result = grade.feedback.joined(separator: "\n") + "\n次回予定への追加ペナルティはありません。" }
                }
            } else { Text(result!) }
        }.navigationTitle("写真ボーナス")
    }
}
struct GardenEventsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List((store.state.garden.layout?.eventHistory ?? []).reversed()) { event in
            VStack(alignment: .leading) { Text(event.systemText); Text(event.createdAt.formatted()).font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("最近の出来事")
    }
}
struct GardenSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationTime = Date()
    var body: some View {
        Form {
            Section("通知") {
                Toggle("手入れの通知", isOn: Binding(get: { store.preferences.notifications }, set: { enabled in
                    Task {
                        if enabled {
                            let allowed = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                            store.setPreferences { $0.notifications = allowed }
                            if !allowed { store.error = "通知は許可されていません。iOSの設定から変更できます。" }
                        } else { store.setPreferences { $0.notifications = false } }
                    }
                }))
                DatePicker("通知時刻", selection: $notificationTime, displayedComponents: .hourAndMinute)
                    .onChange(of: notificationTime) { _, date in let c = Calendar.current.dateComponents([.hour, .minute], from: date); store.setPreferences { $0.notificationHour = c.hour ?? 19; $0.notificationMinute = c.minute ?? 0 } }
                Text("必要な日に1回だけ。設定変更・アプリ利用時に次の通知を更新します。").font(.caption)
            }
            Section("表示と操作") {
                Toggle("アニメーションを減らす", isOn: Binding(get: { store.preferences.reduceMotion }, set: { v in store.setPreferences { $0.reduceMotion = v } }))
                Toggle("触覚", isOn: Binding(get: { store.preferences.haptics }, set: { v in store.setPreferences { $0.haptics = v } }))
                Text("復習保護：標準（ON）")
            }
            Section("データ") { NavigationLink("記録・バックアップ") { StatisticsView() } }
            Section("千花之恋図鑑") {
                Text("せんかのこいずかん / Garden of memory")
                Text("v1.0 · build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local") · schema \(store.state.schemaVersion)")
                Text("ソース：" + BuildIdentity.commit).font(.caption).textSelection(.enabled)
                Text("植物・人物・音楽は仮素材または未収録。正式台詞は未収録です。").font(.caption)
                NavigationLink("描画の実機検証") { GardenSpikeView() }
            }
        }.navigationTitle("設定")
            .onAppear { notificationTime = Calendar.current.date(bySettingHour: store.preferences.notificationHour, minute: store.preferences.notificationMinute, second: 0, of: Date()) ?? Date() }
    }
}
actor CareNotifications {
    static let shared = CareNotifications()
    static func refresh(_ state: AppState) async { await shared.schedule(state) }
    private var generation = 0
    private func schedule(_ state: AppState) async {
        generation += 1; let revision = generation
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard revision == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["garden-care"])
        guard let p = state.preferences, p.notifications else { return }
        let now = Date(), calendar = Calendar.current
        // One non-repeating reminder; no unattended daily loop or multiplying overdue debt.
        guard let fire = calendar.nextDate(after: now, matching: DateComponents(hour: p.notificationHour, minute: p.notificationMinute), matchingPolicy: .nextTime),
              !ReviewEngine.recommendedIDs(in: state, at: fire).isEmpty else { return }
        let completedToday = state.sessions.contains { $0.gardenReview == true && $0.completed && calendar.isDate($0.endedAt, inSameDayAs: fire) }
        guard !completedToday else { return }
        let delivered = await center.deliveredNotifications()
        guard revision == generation else { return }
        guard !delivered.contains(where: { $0.request.identifier == "garden-care" && calendar.isDate($0.date, inSameDayAs: fire) }) else { return }
        let dayKey = AppState.dayKey(fire)
        let previousDay = UserDefaults.standard.string(forKey: "care-notification-day")
        // If the OS has consumed a scheduled notification, never schedule another for that day,
        // even when the user has cleared Notification Center.
        if previousDay == dayKey && !pending.contains(where: { $0.identifier == "garden-care" }) { return }
        UserDefaults.standard.set(dayKey, forKey: "care-notification-day")
        let content = UNMutableNotificationContent(); content.title = "千花之恋図鑑"; content.body = "そろそろ手入れどきの植物があります"
        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year,.month,.day,.hour,.minute], from: fire), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "garden-care", content: content, trigger: trigger))
    }
}

enum BuildIdentity {
    static var commit: String {
        guard let u = Bundle.main.url(forResource: "buildInfo", withExtension: "json"), let d = try? Data(contentsOf: u), let info = try? JSONDecoder().decode([String: String].self, from: d) else { return "不明" }
        return info["commit"] ?? "不明"
    }
}
