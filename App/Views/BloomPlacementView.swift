import SwiftUI

struct BloomPlacementView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let plant: Plant
    @State private var chooseArea = false
    @State private var manualPlantID: String?
    @State private var centralFull = false
    @State private var displaced: String?
    @State private var message: String?
    private var layout: GardenLayout { store.state.garden.layout ?? GardenLayout() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MemoryPlantView(definition: store.renderDefinition(for: plant.id), freshness: 1).frame(width: 190, height: 190)
                    Text("\(plant.latin)を庭へ").font(.title2.bold())
                    Text("開花の実績は永久に残ります。植える場所を選びましょう。").font(.subheadline)
                    Button("幽香に任せる") { delegate() }.buttonStyle(.borderedProminent)
                    Button("中央庭園に置く") { placeCentral() }.buttonStyle(.bordered)
                    Button("自分で植える") { manualPlantID = plant.id; chooseArea = true }.buttonStyle(.bordered)
                    if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    if centralFull {
                        Text("中央庭園に条件の合う空きがありません").font(.headline)
                        Text("入れ替える植物を選ぶか、配置を編集できます。").font(.footnote)
                        ForEach(store.plants.filter { p in
                            guard let placement = layout.placements[p.id] else { return false }
                            return GardenArea.centralAreas.contains { $0.id == placement.zoneID } && p.id != plant.id
                        }) { old in
                            Button("\(old.latin)と入れ替える") { replace(old.id) }
                        }
                        Button("配置を編集する") { manualPlantID = plant.id; chooseArea = true }
                    }
                    if chooseArea {
                        Text("植える区画を選択").font(.headline)
                        ForEach(GardenEngine.availableAreas(layout)) { area in
                            NavigationLink(area.title) { GardenEditor(area: area, initial: layout, selected: manualPlantID ?? plant.id) }
                        }
                    }
                    Button("後で配置する") { dismiss() }.font(.footnote)
                }.padding(24)
            }.background(GardenPalette.paper).navigationTitle("開花・配置")
                .toolbar { Button("閉じる") { dismiss() } }
                .confirmationDialog("入れ替えた植物の行き先", isPresented: Binding(get: { displaced != nil }, set: { if !$0 { displaced = nil } }), titleVisibility: .visible) {
                    Button("幽香に任せる") { if let id = displaced { delegate(id) }; displaced = nil }
                    Button("自分で植える") { manualPlantID = displaced; chooseArea = true; displaced = nil }
                    Button("未配置へ") { displaced = nil }
                }
        }
    }
    private func delegate(_ id: String? = nil) {
        let target = id ?? plant.id
        var next = layout
        let placed = GardenEngine.autoPlace(target, attributes: store.habitats, layout: &next)
        if !placed { next.awaitingDelegation.insert(target) }
        guard store.setLayout(next) else { return }
        if id == nil {
            if placed { dismiss() }
            else { message = "条件の合う場所が空くまで配置を預かります。区画が開いた時に自動で植えます。未配置一覧から自分で選ぶこともできます。" }
        }
    }
    private func placeCentral() {
        var next = layout
        if GardenEngine.autoPlace(plant.id, attributes: store.habitats, layout: &next, centralOnly: true) {
            if store.setLayout(next) { dismiss() }
        } else { centralFull = true }
    }
    private func replace(_ old: String) {
        var next = layout
        guard let previous = next.placements[old], let area = GardenArea.centralAreas.first(where: { $0.id == previous.zoneID }), let spot = area.spots.first(where: { $0.id == previous.spotID }) else { return }
        next.placements.removeValue(forKey: old)
        guard GardenEngine.place(plant.id, area: area, spot: spot, control: .central, attributes: store.habitats, layout: &next) else { message = "その場所にはサイズや水分条件が合いません。別の植物か編集を選んでください。"; return }
        if store.setLayout(next) { displaced = old; centralFull = false; message = "入れ替えました。元の植物は未配置一覧からも植えられます。" }
    }
}
