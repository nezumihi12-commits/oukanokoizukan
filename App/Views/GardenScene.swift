import SwiftUI
import UniformTypeIdentifiers

enum GardenPalette {
    static let paper = Color(red: 0.95, green: 0.93, blue: 0.87)
    static let soil = Color(red: 0.52, green: 0.42, blue: 0.31)
    static let foliage = Color(red: 0.30, green: 0.40, blue: 0.29)
}

struct GardenView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var launch: ReviewLaunch?
    @State private var currentNotice: GardenNotice?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Gauge(value: Double(store.bloomed), in: 0...Double(max(1, store.plants.count))) { Text("開花") } currentValueLabel: { Text("\(store.bloomed)") }.gaugeStyle(.accessoryCircular)
                    VStack(alignment: .leading) { Text("中央庭園").font(.title.bold()); Text("Garden of memory").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    NavigationLink { GardenAtlas() } label: { Label("庭園", systemImage: "map") }
                }
                if let currentNotice {
                    Button { dismissNotice() } label: {
                        HStack { Image(systemName: "person.crop.circle.dashed"); Text(currentNotice.systemText); Spacer(); Image(systemName: "xmark") }
                            .padding().background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityHint("タップして閉じる")
                }
                // A spatial overview: background paths are not edit targets.
                ZStack {
                    RoundedRectangle(cornerRadius: 36).fill(GardenPalette.foliage.opacity(0.16))
                    Path { path in path.move(to: CGPoint(x: 30, y: 100)); path.addCurve(to: CGPoint(x: 290, y: 420), control1: CGPoint(x: 300, y: 160), control2: CGPoint(x: 20, y: 340)) }
                        .stroke(GardenPalette.paper, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    VStack(spacing: 12) {
                        HStack { areaLink(GardenArea.centralAreas[5]); areaLink(GardenArea.centralAreas[2]) }
                        HStack { areaLink(GardenArea.centralAreas[0]); areaLink(GardenArea.centralAreas[1]) }
                        HStack { areaLink(GardenArea.centralAreas[3]); areaLink(GardenArea.centralAreas[4]) }
                        HStack {
                            areaLink(GardenArea.centralAreas[6])
                            VStack { Image(systemName: "person.crop.circle.dashed").font(.system(size: 38)); Text("庭の案内役").font(.caption) }.frame(maxWidth: .infinity)
                        }
                    }.padding(18)
                }
                HStack {
                    NavigationLink { StudyHome() } label: { Label("花を咲かせる", systemImage: "leaf") }
                    NavigationLink { ReviewQueueView() } label: { Label("庭を手入れする", systemImage: "drop") }
                }.buttonStyle(.borderedProminent).tint(GardenPalette.foliage)
                let recommended = store.recommendedPlants(at: Date())
                HStack {
                    Text(recommended.isEmpty ? "今日は特に手入れの必要はありません" : "おまかせ手入れ \(recommended.count) 属").font(.subheadline)
                    Spacer()
                    if !recommended.isEmpty { Button("始める") { launch = ReviewLaunch(questions: store.reviewQuestions(for: recommended)) } }
                }
                NavigationLink { NurseryView() } label: {
                    HStack { Label("育苗コーナー", systemImage: "leaf.circle"); Spacer(); Text("\(store.state.records.values.filter { !$0.hasBloomed && $0.clearedCount > 0 }.count) 属") }
                }
                NavigationLink { UnplacedView() } label: {
                    HStack { Label("未配置の植物", systemImage: "tray"); Spacer(); Text("\(unplacedCount) 属") }
                }
            }.padding(16)
        }.background(GardenPalette.paper).navigationTitle("千花之恋図鑑").navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refreshGarden(); showNextNotice() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshGarden(); showNextNotice() } }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in store.refreshGarden(); showNextNotice() }
        .task(id: currentNotice?.id) {
            guard let notice = currentNotice else { return }
            try? await Task.sleep(for: .seconds(notice.duration))
            if !Task.isCancelled && currentNotice?.id == notice.id { dismissNotice() }
        }
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
    private var unplacedCount: Int { store.state.records.filter { $0.value.hasBloomed && store.state.garden.layout?.placements[$0.key] == nil }.count }
    private func areaLink(_ area: GardenArea) -> some View {
        NavigationLink { ZoneObservationView(area: area) } label: {
            VStack(spacing: 0) {
                ZStack {
                    Ellipse().fill(area.id == "central_water" ? Color.blue.opacity(0.16) : GardenPalette.soil.opacity(0.18)).frame(height: 50).offset(y: 24)
                    HStack(spacing: -12) {
                        let ids = (store.state.garden.layout?.placements ?? [:]).filter { $0.value.zoneID == area.id }.keys.sorted()
                        ForEach(Array(ids.prefix(3)), id: \.self) { id in
                            MemoryPlantView(definition: store.renderDefinition(for: id), freshness: ReviewEngine.freshness(store.state.records[id] ?? StudyRecord(), at: Date())).frame(width: 55, height: 73)
                        }
                        if ids.isEmpty { Image(systemName: area.id == "central_water" ? "water.waves" : "leaf").font(.title).foregroundStyle(GardenPalette.foliage.opacity(0.4)) }
                    }
                }.frame(height: 78)
                Text(area.title).font(.caption).foregroundStyle(.primary).padding(.horizontal, 7).padding(.vertical, 4).background(GardenPalette.paper, in: RoundedRectangle(cornerRadius: 4))
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }
    private func showNextNotice() { if currentNotice == nil { currentNotice = store.state.garden.layout?.pendingEvents.first } }
    private func dismissNotice() {
        guard let notice = currentNotice else { return }
        guard store.update({ $0.garden.layout?.pendingEvents.removeAll { $0.id == notice.id }; $0.character.seenEvents.insert(notice.id) }) else { return }
        currentNotice = nil
        Task { try? await Task.sleep(for: .milliseconds(400)); showNextNotice() }
    }
}

struct GardenAtlas: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section("中央庭園") { ForEach(GardenArea.centralAreas) { area in NavigationLink(area.title) { ZoneObservationView(area: area) } } }
            Section("生態区画") {
                ForEach(GardenArea.habitats) { area in
                    if store.state.garden.layout?.unlockedZones.contains(area.id) == true {
                        NavigationLink(area.title) { ZoneObservationView(area: area) }
                    } else {
                        Label("\(area.title) · これから広がる庭", systemImage: "lock").foregroundStyle(.secondary)
                    }
                }
            }
            if store.state.garden.layout?.ambiguousUnlocked == true { NavigationLink("曖昧の庭") { AmbiguousGardenView() } }
        }.navigationTitle("庭園")
    }
}

struct ZoneObservationView: View {
    @EnvironmentObject private var store: AppStore
    let area: GardenArea
    @State private var selected: String?
    @State private var editing = false
    @State private var launch: ReviewLaunch?
    @State private var guideArrived = false
    private var layout: GardenLayout { store.state.garden.layout ?? GardenLayout() }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GardenSpotCanvas(area: area, layout: layout, selected: selected, editing: false, select: { selected = $0 }, drop: { _, _ in false })
                HStack(alignment: .top) {
                    Image(systemName: "person.crop.circle.dashed").font(.system(size: 38)).opacity(guideArrived ? 1 : 0)
                    VStack(alignment: .leading, spacing: 8) {
                        if let selected, let plant = store.plants.first(where: { $0.id == selected }), let r = store.state.records[selected] {
                            Text(plant.latin).font(.title2)
                            Text(MemoryAppearance.of(ReviewEngine.freshness(r, at: Date())).rawValue)
                            if let due = r.nextReviewAt { Text("次回手入れ：\(due.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                            Button("今すぐ復習") { launch = ReviewLaunch(questions: store.reviewQuestions(for: [plant])) }
                            NavigationLink("図鑑ページへ") { PlantDetail(plant: plant) }
                            Button(r.favorite ? "お気に入りを解除" : "お気に入りにする") { store.toggleFavorite(selected) }
                        } else { Text("植物を選んで、記憶の状態を確かめましょう。").foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding().background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let until = store.layoutUndoUntil, context.date < until { Button("配置を元に戻す") { store.undoLayout() } }
                }
                Button { editing = true } label: { Label("配置を編集する", systemImage: "wrench.and.screwdriver") }.buttonStyle(.bordered).tint(GardenPalette.soil)
            }.padding()
        }.background(GardenPalette.paper).navigationTitle(area.title)
        .task { try? await Task.sleep(for: .milliseconds(350)); if !Task.isCancelled { withAnimation { guideArrived = true } } }
        .sheet(isPresented: $editing) { NavigationStack { GardenEditor(area: area, initial: layout) }.environmentObject(store) }
        .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
}

struct GardenSpotCanvas: View {
    @EnvironmentObject private var store: AppStore
    let area: GardenArea
    let layout: GardenLayout
    let selected: String?
    let editing: Bool
    var select: (String) -> Void
    var drop: (String, PlantingSpot) -> Bool
    @State private var page = 0
    var body: some View {
        VStack {
            if area.spots.count > 9 {
                HStack {
                    Button("前の植栽") { page -= 1 }.disabled(page == 0)
                    Text("\(page + 1) / \((area.spots.count + 8) / 9)").font(.caption)
                    Button("次の植栽") { page += 1 }.disabled((page + 1) * 9 >= area.spots.count)
                }
            }
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 32).fill(GardenPalette.foliage.opacity(0.13))
                Ellipse().fill(GardenPalette.soil.opacity(0.13)).padding(12).scaleEffect(y: 0.8)
                ForEach(Array(area.spots.dropFirst(page * 9).prefix(9))) { spot in
                    let id = layout.placements.first { $0.value.spotID == spot.id }?.key
                    VStack(spacing: 1) {
                        if let id {
                            MemoryPlantView(definition: store.renderDefinition(for: id), freshness: ReviewEngine.freshness(store.state.records[id] ?? StudyRecord(), at: Date()))
                                .frame(width: spot.size == "XL" ? 112 : 86, height: spot.size == "XL" ? 135 : 100)
                                .opacity(selected == nil || selected == id ? 1 : 0.2)
                                .background(selected == id ? Color.white.opacity(0.5) : .clear, in: Ellipse())
                                .onTapGesture { select(id) }
                                .onDrag { editing ? NSItemProvider(object: id as NSString) : NSItemProvider() }
                                .accessibilityLabel("植栽 \(id)")
                        } else {
                            Button { if let selected, editing { _ = drop(selected, spot) } } label: {
                                Ellipse().strokeBorder(GardenPalette.soil.opacity(editing ? 0.6 : 0.12), style: StrokeStyle(lineWidth: 1, dash: [4])).frame(width: 65, height: 38)
                                    .overlay { if editing { Text(spot.size).font(.caption) } }
                            }.disabled(!editing)
                        }
                        if editing { Text(spot.id.components(separatedBy: "-").last ?? "").font(.caption2).foregroundStyle(.secondary) }
                    }.frame(width: geometry.size.width / 3, height: 120)
                        .position(x: geometry.size.width * spot.x, y: geometry.size.height * spot.y + 25)
                        .dropDestination(for: String.self) { items, _ in guard editing, let id = items.first else { return false }; return drop(id, spot) }
                }
            }
        }.frame(height: area.spots.count > 6 ? 440 : 340)
        }
    }
}

struct GardenEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let area: GardenArea
    let initial: GardenLayout
    @State private var draft: GardenLayout
    @State private var selected: String?
    @State private var discard = false
    @State private var advice = "植物を長押しして運び、植栽スポットで離してください。タップ選択→空きスポットでも配置できます。"
    init(area: GardenArea, initial: GardenLayout, selected: String? = nil) {
        self.area = area; self.initial = initial; _draft = State(initialValue: initial); _selected = State(initialValue: selected)
    }
    var body: some View {
        VStack(spacing: 8) {
            ScrollView { GardenSpotCanvas(area: area, layout: draft, selected: selected, editing: true, select: { selected = $0 }, drop: place).padding() }
            HStack { Image(systemName: "person.crop.circle.dashed"); Text(advice).font(.footnote) }.padding(.horizontal)
            Text("作業トレイ · 未配置の開花済み植物").font(.caption.bold())
            ScrollView(.horizontal) {
                HStack {
                    ForEach(store.plants.filter { store.state.records[$0.id]?.hasBloomed == true && draft.placements[$0.id] == nil }) { plant in
                        VStack { MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: 1).frame(width: 70, height: 70); Text(plant.latin).font(.caption) }
                            .padding(6).background(selected == plant.id ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .onTapGesture { selected = plant.id }.draggable(plant.id)
                    }
                }.padding(10)
            }.frame(height: 118).background(GardenPalette.soil.opacity(0.15))
                .dropDestination(for: String.self) { ids, _ in
                    guard let id = ids.first, draft.placements[id] != nil else { return false }
                    draft.placements.removeValue(forKey: id); draft.awaitingDelegation.remove(id); selected = id; return true
                }
            if let selected, draft.placements[selected] != nil {
                Button("選択した植物を未配置へ") { draft.placements.removeValue(forKey: selected); draft.awaitingDelegation.remove(selected) }
            }
        }.background(GardenPalette.paper).navigationTitle("\(area.title)の編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("戻る") { if draft != initial { discard = true } else { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("完了") { if store.setLayout(draft) { dismiss() } } }
        }.interactiveDismissDisabled(draft != initial)
        .confirmationDialog("変更を破棄して戻りますか？", isPresented: $discard, titleVisibility: .visible) { Button("変更を破棄", role: .destructive) { dismiss() } }
    }
    private func place(_ id: String, _ spot: PlantingSpot) -> Bool {
        guard store.state.records[id]?.hasBloomed == true else { return false }
        let result = GardenEngine.place(id, area: area, spot: spot, control: .manual, attributes: store.habitats, layout: &draft)
        if result {
            selected = id
            advice = !area.central && (store.habitats[id]?.habitatScores[area.id] ?? 0) < 0.5 ? "配置できますが、この区画の環境はあまり適していません。" : "配置しました。完了を押すと保存します。"
        } else { advice = "サイズ・水面などの条件が合わないか、別の植物がある場所です。" }
        return result
    }
}

struct NurseryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var page = 0
    private var plants: [Plant] { store.plants.filter { let r = store.state.records[$0.id] ?? StudyRecord(); return !r.hasBloomed && r.clearedCount > 0 } }
    var body: some View {
        VStack {
            Text("育苗は開花前の植物です。表示は6鉢ずつ。学べる属数の制限はありません。").font(.footnote).padding()
            List(Array(plants.dropFirst(page * 6).prefix(6))) { plant in
                NavigationLink { PlantDetail(plant: plant) } label: {
                    Label("\(plant.latin) · \((store.state.records[plant.id]?.clearedCount ?? 0) == 1 ? "芽" : "成長")", systemImage: "leaf")
                }
            }
            HStack { Button("前へ") { page -= 1 }.disabled(page == 0); Text("\(page + 1) / \(max(1, (plants.count + 5) / 6))"); Button("次へ") { page += 1 }.disabled((page + 1) * 6 >= plants.count) }.padding()
            NavigationLink("開花学習へ") { StudyHome() }.padding()
        }.navigationTitle("育苗コーナー")
    }
}
struct UnplacedView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: Plant?
    var body: some View {
        List(store.plants.filter { store.state.records[$0.id]?.hasBloomed == true && store.state.garden.layout?.placements[$0.id] == nil }) { plant in
            Button(plant.latin) { selected = plant }
        }.navigationTitle("未配置の植物")
            .sheet(item: $selected) { plant in BloomPlacementView(plant: plant).environmentObject(store) }
    }
}
struct AmbiguousGardenView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let plants = store.plants.filter { let r = store.state.records[$0.id] ?? StudyRecord(); return r.hasBloomed && ReviewEngine.freshness(r, at: context.date) < 0.4 }
            ScrollView {
                if plants.isEmpty { ContentUnavailableView("静かな庭", systemImage: "cloud.fog", description: Text("薄れていた記憶に色が戻りました。")) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
                    ForEach(plants) { plant in
                        NavigationLink { PlantMemoryDetail(plant: plant) } label: { GardenPlantCard(plant: plant, record: store.state.records[plant.id]!, definition: store.renderDefinition(for: plant.id), now: context.date) }
                    }
                }.padding()
                Text("ここにいるのは記憶の似姿です。元の植栽は動きません。").font(.footnote).padding()
            }.background(Color.gray.opacity(0.08))
        }.navigationTitle("曖昧の庭")
    }
}
