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
    @State private var destination: String?
    @State private var appreciate = false
    @State private var exitVisible = false
    @State private var welcome = false
    @State private var important: GardenNotice?
    var body: some View {
        ZStack(alignment: .bottom) {
            LivingGarden(layout: store.state.garden.layout ?? GardenLayout(), onZone: { destination = $0 })
            VStack {
                HStack {
                    Text("開花 \(store.bloomed) / 307").font(.caption)
                    Spacer()
                    Button { appreciate = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.accessibilityLabel("全画面鑑賞")
                }.padding(12).background(GardenPalette.paper.opacity(0.94))
                if let notice = store.state.garden.layout?.pendingEvents.first {
                    NavigationLink { GardenEventsView() } label: { Text(notice.systemText).font(.caption).padding(8).background(GardenPalette.paper) }
                }
                Spacer()
                NavigationLink { StudyHome() } label: { Label("咲かせる", systemImage: "leaf").padding(.horizontal, 32).padding(.vertical, 8) }
                    .buttonStyle(.borderedProminent).padding(.bottom, 20)
            }
        }.navigationTitle("千花之恋図鑑").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(get: { destination != nil }, set: { if !$0 { destination = nil } })) {
                if destination == "nursery" { NurseryView() }
                else if let area = GardenArea.all.first(where: { $0.id == destination }) { ZoneObservationView(area: area) }
            }
            .onAppear { store.refreshGarden(); welcome = !store.state.character.seenEvents.contains("welcome-v1"); if !welcome { important = store.state.garden.layout?.pendingEvents.first(where: { $0.priority == 3 }) } }
            .onChange(of: scenePhase) { _, value in if value == .active { store.refreshGarden() } }
            .sheet(isPresented: $welcome) {
                VStack(spacing: 20) {
                    Image(systemName: "leaf.circle").font(.system(size: 60)).foregroundStyle(GardenPalette.foliage)
                    Text("千花之恋図鑑").font(.largeTitle).fontDesign(.serif)
                    Text("Garden of memory").font(.subheadline).fontDesign(.serif)
                    Text("ここは中央庭園です。咲かせる、から植物を学べます。図鑑はいつでも開けます。").multilineTextAlignment(.center)
                    Text("人物と会話は制作中の仮素材です。").font(.caption).foregroundStyle(.secondary)
                    Button("庭へ") { if store.update({ $0.character.seenEvents.insert("welcome-v1") }) { welcome = false } }.buttonStyle(.borderedProminent)
                }.padding(32).interactiveDismissDisabled()
            }
            .alert("庭の出来事", isPresented: Binding(get: { important != nil && !welcome }, set: { if !$0 { important = nil } })) {
                Button("確認しました") { if let notice = important { store.update { $0.character.seenEvents.insert(notice.id); $0.garden.layout?.pendingEvents.removeAll { $0.id == notice.id } } }; important = nil }
            } message: { Text(important?.systemText ?? "") }
            .fullScreenCover(isPresented: $appreciate) {
                ZStack(alignment: .topTrailing) {
                    LivingGarden(layout: store.state.garden.layout ?? GardenLayout(), mode: .appreciation, appreciationTap: { exitVisible = true }).ignoresSafeArea()
                    if exitVisible { Button("鑑賞を終える") { appreciate = false }.padding().background(.regularMaterial).padding() }
                }.statusBarHidden()
                    .task(id: exitVisible) { if exitVisible { try? await Task.sleep(for: .seconds(4)); if !Task.isCancelled { exitVisible = false } } }
                    .accessibilityAction(named: "鑑賞を終える") { appreciate = false }
            }
    }
}

struct GardenAtlas: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section("中央庭園") { ForEach(GardenArea.centralAreas) { area in NavigationLink(area.title) { ZoneObservationView(area: area) } } }
            Section { NavigationLink("未所属の植物") { UnplacedView() }; NavigationLink("最近の出来事") { GardenEventsView() } }
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
        }.navigationTitle("庭園").onAppear { store.refreshGarden() }
    }
}

enum TrayFilter: String, CaseIterable { case reserve = "控え", suitable = "適性あり", all = "すべて", favorite = "お気に入り", current = "表示中" }
struct ZoneObservationView: View {
    @EnvironmentObject private var store: AppStore
    let area: GardenArea
    @State private var selected: String?
    @State private var editing = false
    @State private var draft = GardenLayout()
    @State private var initial = GardenLayout()
    @State private var discard = false
    @State private var trayFilter = TrayFilter.reserve
    @State private var launch: ReviewLaunch?
    @State private var advice = "植物を選択できます。拡大はピンチ、移動は2本指です。"
    @State private var replacement: PendingReplacement?
    private var layout: GardenLayout { editing ? draft : store.state.garden.layout ?? GardenLayout() }
    private var tray: [Plant] {
        store.plants.filter { p in
            guard store.state.records[p.id]?.hasBloomed == true else { return false }
            switch trayFilter {
            case .all: return true
            case .reserve: return draft.placements[p.id] == nil
            case .current: return draft.placements[p.id]?.zoneID == area.id
            case .favorite: return store.state.records[p.id]?.favorite == true
            case .suitable: return area.central || (store.habitats[p.id]?.habitatScores[area.id] ?? 0) >= 0.5
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            LivingGarden(layout: layout, area: area, selected: selected, mode: editing ? .editing : .observation,
                         onPlant: { selected = $0 }, onDrop: place)
            if editing {
                Text(advice).font(.caption).padding(6)
                Picker("作業トレイ", selection: $trayFilter) { ForEach(TrayFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(tray) { plant in
                            Button { selected = plant.id } label: {
                                VStack {
                                    MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: 1).frame(width: 54, height: 58)
                                    Text(store.isProtected(plant.id) ? "保護中" : plant.latin).font(.caption2)
                                    Text(store.habitats[plant.id]?.gardenAttributes.defaultSizeClass ?? "M").font(.caption2)
                                }.padding(5).background(selected == plant.id ? Color.white : .clear)
                            }.buttonStyle(.plain).draggable(plant.id)
                        }
                    }.padding(8)
                }.frame(height: 110)
                if let selected, draft.placements[selected] != nil {
                    Button("控え植栽に戻す") { draft.placements.removeValue(forKey: selected) }.font(.caption).padding(4)
                }
            } else if let selected, let plant = store.plants.first(where: { $0.id == selected }), let r = store.state.records[selected] {
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.isProtected(selected) ? "手入れ対象の植物" : plant.latin).font(.headline)
                    Text(MemoryAppearance.of(ReviewEngine.freshness(r, at: Date())).rawValue)
                    if let due = r.nextReviewAt { Text("次回：\(due.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                    HStack {
                        Button("今すぐ復習") { launch = ReviewLaunch(questions: store.reviewQuestions(for: [plant])) }
                        NavigationLink("図鑑へ") { PlantDetail(plant: plant) }
                        Button("閉じる") { self.selected = nil }
                    }.font(.subheadline)
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(GardenPalette.paper)
            }
        }.background(GardenPalette.paper).navigationTitle(area.title)
            .navigationBarBackButtonHidden(editing)
            .toolbar {
                if editing {
                    ToolbarItem(placement: .cancellationAction) { Button("戻る") { if draft != initial { discard = true } else { editing = false } } }
                    ToolbarItem(placement: .confirmationAction) { Button("完了") { if store.setLayout(draft) { editing = false; selected = nil } } }
                } else {
                    ToolbarItem(placement: .primaryAction) { Button("植栽編集") { initial = layout; draft = layout; selected = nil; editing = true; advice = "トレイで植物を選び、空きスポットをタップ。植えた植物は長押しで移動できます。" } }
                    ToolbarItem(placement: .bottomBar) {
                        if let until = store.layoutUndoUntil, until > Date() { Button("配置を元に戻す") { store.undoLayout() } }
                    }
                }
            }
            .confirmationDialog("変更を破棄して戻りますか？", isPresented: $discard, titleVisibility: .visible) { Button("変更を破棄", role: .destructive) { editing = false; selected = nil } }
            .confirmationDialog("この場所の植物を控えへ戻して入れ替えますか？", isPresented: Binding(get: { replacement != nil }, set: { if !$0 { replacement = nil } }), titleVisibility: .visible) {
                Button("入れ替える") { if let r = replacement { var next = draft; next.placements.removeValue(forKey: r.old); if GardenEngine.place(r.new, area: area, spot: r.spot, control: .manual, attributes: store.habitats, layout: &next) { draft = next } }; replacement = nil }
            }
            .onAppear { store.update { state in if state.garden.layout?.visitedGardens == nil { state.garden.layout?.visitedGardens = [] }; state.garden.layout?.visitedGardens?.insert(area.id) } }
            .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
    private func place(_ id: String, _ spot: PlantingSpot) -> Bool {
        guard editing, store.state.records[id]?.hasBloomed == true, let attr = store.habitats[id] else { return false }
        guard GardenEngine.canPlace(attr, in: spot) else { advice = "サイズまたは植栽方式（水面・地植えなど）が合いません。"; return false }
        if let old = draft.placements.first(where: { $0.key != id && $0.value.spotID == spot.id })?.key { replacement = PendingReplacement(old: old, new: id, spot: spot); return false }
        if GardenEngine.place(id, area: area, spot: spot, control: .manual, attributes: store.habitats, layout: &draft) {
            advice = !area.central && attr.habitatScores[area.id, default: 0] < 0.5 ? "植えられますが、この庭の環境とは少し異なります。" : "配置しました。完了で保存します。"
            if store.preferences.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }; return true
        }
        advice = "庭の表示枠がいっぱいです。表示中の植物を控えへ戻せます。"; return false
    }
}
private struct PendingReplacement { var old: String; var new: String; var spot: PlantingSpot }

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
                        VStack { MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: 1).frame(width: 70, height: 70); Text(store.isProtected(plant.id) ? "手入れ対象の植物" : plant.latin).font(.caption) }
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
    private var plants: [Plant] { store.plants.filter { let r = store.state.records[$0.id] ?? StudyRecord(); return !r.hasBloomed && r.clearedCount > 0 }.sorted {
        let a = store.state.records[$0.id]!, b = store.state.records[$1.id]!
        return a.clearedCount == b.clearedCount ? (a.lastStudiedAt ?? .distantPast) > (b.lastStudiedAt ?? .distantPast) : a.clearedCount > b.clearedCount
    } }
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
        List(store.plants.filter { store.state.records[$0.id]?.hasBloomed == true && store.state.garden.layout?.memberships?[$0.id] == nil }) { plant in
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
                    ForEach(Array(plants.sorted { ReviewEngine.severity(store.state.records[$0.id]!, at: context.date) > ReviewEngine.severity(store.state.records[$1.id]!, at: context.date) }.prefix(Tuning.visibleLimit))) { plant in
                        NavigationLink { PlantMemoryDetail(plant: plant) } label: { GardenPlantCard(plant: plant, record: store.state.records[plant.id]!, definition: store.renderDefinition(for: plant.id), now: context.date) }
                    }
                }.padding()
                Text("ここにいるのは記憶の似姿です。元の植栽は動きません。").font(.footnote).padding()
            }.background(Color.gray.opacity(0.08))
        }.navigationTitle("曖昧の庭")
    }
}
