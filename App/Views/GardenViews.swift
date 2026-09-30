import SwiftUI

struct ReviewLaunch: Identifiable {
    let id = UUID()
    let questions: [Question]
}

struct GardenView: View {
    @EnvironmentObject private var store: AppStore
    @State private var launch: ReviewLaunch?
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]
    private var planted: [Plant] {
        store.plants.filter {
            store.state.records[$0.id]?.hasBloomed == true &&
            (store.state.records[$0.id]?.favorite == true || (store.state.garden.plantZones?[$0.id] ?? GardenZone.central.id) == GardenZone.central.id)
        }
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let due = store.duePlants(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    gardenHeader
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("今日の手入れ　\(min(5, due.count))件").font(.title3.bold())
                            Spacer()
                            NavigationLink("全\(due.count)件") { ReviewQueueView() }
                        }
                        if due.isEmpty {
                            Text("いま復習時期の植物はありません。\n新しい属を学ぶか、庭の植物から自由に復習できます。").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(due.prefix(5))) { plant in
                                HStack {
                                    NavigationLink { PlantMemoryDetail(plant: plant) } label: {
                                        ReviewPlantRow(plant: plant, record: store.state.records[plant.id]!, now: context.date)
                                    }.buttonStyle(.plain)
                                    Spacer()
                                    Button { start([plant]) } label: { Image(systemName: "play.circle.fill").font(.title) }.accessibilityLabel("\(plant.latin)を復習")
                                }
                            }
                            Button("おすすめをまとめて手入れ") { start(Array(due.prefix(5))) }.buttonStyle(.borderedProminent)
                        }
                    }.padding(18).background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))

                    let favorites = planted.filter { store.state.records[$0.id]?.favorite == true }
                    if !favorites.isEmpty {
                        Label("中央庭園に固定", systemImage: "pin.fill").font(.headline)
                        gardenGrid(favorites, now: context.date)
                    }
                    HStack { Text("中央庭園").font(.title2.bold()); Spacer(); Text("開花 \(planted.count) / \(store.plants.count) 属").font(.caption).foregroundStyle(.secondary) }
                    if planted.isEmpty {
                        ContentUnavailableView("最初の開花を待っています", systemImage: "leaf", description: Text("学習タブで、同じ属の基本3形式にそれぞれ正解してみましょう。"))
                    } else {
                        gardenGrid(planted.filter { store.state.records[$0.id]?.favorite != true }, now: context.date)
                    }
                    Text("色彩は植物の健康ではなく、記憶の鮮度を表します。植物像が薄れても開花実績は消えません。").font(.footnote).foregroundStyle(.secondary)
                }.padding(18)
            }
        }
        .navigationTitle("記憶の庭園")
        .toolbar { NavigationLink { ReviewQueueView() } label: { Label("復習待ち", systemImage: "list.bullet.clipboard") } }
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
    private var gardenHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Label("中央庭園", systemImage: "sun.max.fill").font(.headline).foregroundStyle(.green)
                Text("覚えた植物が、\nここに咲く。").font(.title.bold())
                Text("開花実績 \(store.bloomed) 属").font(.subheadline)
            }
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.dashed").font(.system(size: 55)).foregroundStyle(.secondary)
                Text("キャラクター\n準備中").font(.caption2).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }.accessibilityLabel("キャラクターの仮表示")
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.mint.opacity(0.2), .yellow.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }
    private func gardenGrid(_ plants: [Plant], now: Date) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(plants) { plant in
                NavigationLink { PlantMemoryDetail(plant: plant) } label: {
                    GardenPlantCard(plant: plant, record: store.state.records[plant.id]!, definition: store.renderDefinition(for: plant.id), now: now)
                }.buttonStyle(.plain)
            }
        }
    }
    private func start(_ plants: [Plant]) { launch = ReviewLaunch(questions: store.reviewQuestions(for: plants)) }
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
            HStack { Text(plant.latin).font(.headline).lineLimit(1).minimumScaleFactor(0.7); if record.favorite { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) } }
            Text(plant.jpName).font(.caption).lineLimit(2)
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
            Text(plant.latin).font(.headline)
            Text("\(plant.jpName) · \(MemoryAppearance.of(ReviewEngine.freshness(record, at: now)).rawValue)").font(.caption).foregroundStyle(.secondary)
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
                    Text("復習待ち \(due.count) 属").font(.headline)
                    Text("おすすめ5件は入口です。ここでは全件を続けて手入れできます。1属につき基本3形式を復習します。").font(.footnote).foregroundStyle(.secondary)
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
                    Text(plant.latin).font(.title.bold())
                    Text(plant.jpName).foregroundStyle(.secondary)
                    LabeledContent("開花実績", value: record.hasBloomed ? "開花済み（永久）" : "未開花")
                    if let date = record.firstBloomedAt { LabeledContent("初開花", value: date.formatted(date: .abbreviated, time: .omitted)) }
                }
                Section("記憶の状態") {
                    LabeledContent("鮮度", value: "\(Int(freshness * 100))% · \(MemoryAppearance.of(freshness).rawValue)")
                    ProgressView(value: freshness)
                    LabeledContent("復習段階", value: "Stage \(record.reviewStage) / 6")
                    if let next = record.nextReviewAt { LabeledContent("次回復習", value: next.formatted(date: .abbreviated, time: .shortened)) }
                    if let last = record.lastReviewedAt { LabeledContent("前回の手入れ", value: last.formatted(date: .abbreviated, time: .shortened)) }
                    Text("予定時刻を過ぎ、前回から24時間以上経った復習で段階が進みます。早めの復習は色彩を回復させます。").font(.footnote).foregroundStyle(.secondary)
                    Button("今すぐ復習（3問）") { launch = ReviewLaunch(questions: store.reviewQuestions(for: [plant])) }.disabled(!record.hasBloomed)
                }
                Section {
                    Toggle("お気に入りとして中央庭園に固定", isOn: Binding(get: { store.state.records[plant.id]?.favorite ?? false }, set: { value in store.update { $0.records[plant.id, default: StudyRecord()].favorite = value; $0.records[plant.id]?.plantID = plant.id } }))
                    NavigationLink("図鑑詳細へ") { PlantDetail(plant: plant) }
                }
            }
        }.navigationTitle(plant.latin).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
}
