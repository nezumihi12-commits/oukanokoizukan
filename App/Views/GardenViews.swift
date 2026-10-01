import SwiftUI

struct ReviewLaunch: Identifiable {
    let id = UUID()
    let questions: [Question]
}

struct GardenPlantCard: View {
    let plant: Plant
    let record: StudyRecord
    let definition: PlantRenderDefinition
    let now: Date
    var body: some View {
        let freshness = ReviewEngine.freshness(record, at: now)
        VStack(alignment: .leading, spacing: 6) {
            MemoryPlantView(definition: definition, freshness: freshness).frame(height: 145)
            HStack { Text(ReviewEngine.protected(record, at: Date()) ? "手入れ対象の植物" : plant.latin).font(.headline).lineLimit(1).minimumScaleFactor(0.7); if record.favorite { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) } }
            Text(ReviewEngine.protected(record, at: Date()) ? "" : plant.jpName).font(.caption).lineLimit(2)
            Text(MemoryAppearance.of(freshness).rawValue).font(.caption2).foregroundStyle(.secondary)
            if ReviewEngine.isDue(record, at: now) { Label("手入れの時期", systemImage: "clock").font(.caption2).foregroundStyle(.orange) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine)
    }
}

struct ReviewPlantRow: View {
    let plant: Plant
    let record: StudyRecord
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ReviewEngine.protected(record, at: Date()) ? "手入れ対象の植物" : plant.latin).font(.headline)
            Text("\(MemoryAppearance.of(ReviewEngine.freshness(record, at: now)).rawValue)").font(.caption).foregroundStyle(.secondary)
            if let next = record.nextReviewAt { Text("予定：\(next.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary) }
            if record.lastReviewResult == .incorrect { Text("前回は不正解").font(.caption2).foregroundStyle(.orange) }
        }
    }
}

struct ReviewQueueView: View {
    @EnvironmentObject private var store: AppStore
    @State private var launch: ReviewLaunch?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let due = store.duePlants(at: context.date)
            List {
                Section {
                    NavigationLink("自由復習：好きな属を選ぶ") { FreeReviewView() }
                    Text("復習待ち \(due.count) 属").font(.headline)
                    Text("おすすめ5件は入口です。ここでは全件を続けて手入れできます。1属につき1形式で復習します。").font(.footnote).foregroundStyle(.secondary)
                    Button("全\(due.count)属の手入れを始める") { start(due) }.disabled(due.isEmpty)
                }
                ForEach(ReviewBucket.allCases) { bucket in
                    let members = due.filter { ReviewEngine.bucket(store.state.records[$0.id]!, at: context.date) == bucket }
                    if !members.isEmpty {
                        Section("\(bucket.rawValue)（\(members.count)属）") {
                            ForEach(members) { plant in
                                HStack {
                                    NavigationLink { PlantMemoryDetail(plant: plant) } label: { ReviewPlantRow(plant: plant, record: store.state.records[plant.id]!, now: context.date) }
                                    Button { start([plant]) } label: { Image(systemName: "play.circle") }.buttonStyle(.borderless).accessibilityLabel("\(plant.latin)を復習")
                                }
                            }
                        }
                    }
                }
                if due.isEmpty { Text("いま復習待ちはありません。").foregroundStyle(.secondary) }
            }
        }.navigationTitle("庭の手入れ")
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
    private func start(_ plants: [Plant]) { guard !plants.isEmpty else { return }; launch = ReviewLaunch(questions: store.reviewQuestions(for: plants)) }
}

struct PlantMemoryDetail: View {
    @EnvironmentObject private var store: AppStore
    let plant: Plant
    @State private var launch: ReviewLaunch?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let record = store.state.records[plant.id] ?? StudyRecord()
            let freshness = ReviewEngine.freshness(record, at: context.date)
            List {
                Section {
                    MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: freshness).frame(width: 220, height: 220).frame(maxWidth: .infinity)
                    Text(ReviewEngine.protected(record, at: Date()) ? "手入れ対象の植物" : plant.latin).font(.title.bold())
                    Text(ReviewEngine.protected(record, at: Date()) ? "" : plant.jpName).foregroundStyle(.secondary)
                    LabeledContent("開花実績", value: record.hasBloomed ? "開花済み（永久）" : "未開花")
                    if let date = record.firstBloomedAt { LabeledContent("初開花", value: date.formatted(date: .abbreviated, time: .omitted)) }
                }
                Section("記憶の状態") {
                    LabeledContent("記憶の状態", value: MemoryAppearance.of(freshness).rawValue)
                    ProgressView(value: freshness)
                    LabeledContent("復習段階", value: "Stage \(record.reviewStage) / 6")
                    if let next = record.nextReviewAt { LabeledContent("次回復習", value: next.formatted(date: .abbreviated, time: .shortened)) }
                    if let last = record.lastReviewedAt { LabeledContent("前回の手入れ", value: last.formatted(date: .abbreviated, time: .shortened)) }
                    Text("期限後の正解で段階が進みます。答えを確認して24時間以内は、演習として記録します。").font(.footnote).foregroundStyle(.secondary)
                    Button("今すぐ復習（1問）") { launch = ReviewLaunch(questions: store.reviewQuestions(for: [plant])) }.disabled(!record.hasBloomed)
                }
                Section {
                    Toggle("お気に入り（自動移植を抑止）", isOn: Binding(get: { store.state.records[plant.id]?.favorite ?? false }, set: { value in store.update { $0.records[plant.id, default: StudyRecord()].favorite = value; $0.records[plant.id]?.plantID = plant.id } }))
                    NavigationLink("図鑑詳細へ") { PlantDetail(plant: plant) }
                }
            }
        }.navigationTitle("記憶の状態").navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
}
