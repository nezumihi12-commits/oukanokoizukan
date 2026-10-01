import SwiftUI
import PhotosUI
import MapKit

enum CatalogFilter: String, CaseIterable, Identifiable {
    case all = "すべて", memorized = "記憶済み", weak = "苦手", photo = "写真あり", unlocked = "発見済み", locked = "未発見", nursery = "育苗中", bloomed = "開花済み", untouched = "未着手", favorite = "お気に入り", due = "手入れ待ち", noPhoto = "写真なし"
    var id: String { rawValue }
}
struct CatalogView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var family = "すべて"
    @State private var garden = "すべて"
    @State private var sort = "ラテン語順"
    @State private var filter = CatalogFilter.all
    private var filtered: [Plant] {
        store.plants.filter { plant in
            guard plant.matches(search), family == "すべて" || family == plant.family, garden == "すべて" || store.state.garden.layout?.memberships?[plant.id]?.assignedGardenID == garden else { return false }
            switch filter {
            case .nursery: return store.state.records[plant.id].map { !$0.hasBloomed && $0.clearedCount > 0 } ?? false
            case .bloomed: return store.state.records[plant.id]?.hasBloomed == true
            case .untouched: return (store.state.records[plant.id]?.clearedCount ?? 0) == 0
            case .favorite: return store.state.records[plant.id]?.favorite == true
            case .due: return store.state.records[plant.id].map { ReviewEngine.isDue($0, at: Date()) } ?? false
            case .noPhoto: return (store.state.photos[plant.id] ?? []).isEmpty
            case .all: return true
            case .memorized: return store.state.records[plant.id]?.memorized == true
            case .weak: return store.state.records[plant.id]?.weak == true
            case .photo: return !(store.state.photos[plant.id] ?? []).isEmpty
            case .unlocked: return store.state.unlocked.contains(plant.id)
            case .locked: return !store.state.unlocked.contains(plant.id)
            }
        }.sorted { a, b in
            switch sort {
            case "和名順": return a.jpName < b.jpName
            case "科名順": return a.family == b.family ? a.id < b.id : a.family < b.family
            case "開花順": return (store.state.records[a.id]?.firstBloomedAt ?? .distantPast) > (store.state.records[b.id]?.firstBloomedAt ?? .distantPast)
            default: return a.id < b.id
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("絞り込み", selection: $filter) { ForEach(CatalogFilter.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                HStack {
                    Picker("科", selection: $family) { Text("すべての科").tag("すべて"); ForEach(Array(Set(store.plants.map(\.family))).sorted(), id: \.self) { Text($0).tag($0) } }
                    Picker("所属", selection: $garden) { Text("すべての庭").tag("すべて"); Text("中央庭園").tag("central"); ForEach(GardenArea.habitats.filter { store.state.garden.layout?.unlockedZones.contains($0.id) == true }) { Text($0.title).tag($0.id) } }
                    Picker("並び順", selection: $sort) { ForEach(["ラテン語順","和名順","科名順","開花順"], id: \.self) { Text($0).tag($0) } }
                }.font(.caption)
                Text("\(filtered.count) / \(store.plants.count) 属").font(.caption).foregroundStyle(.secondary)
                if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { plant in
                        NavigationLink { PlantDetail(plant: plant) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: (store.state.photos[plant.id] ?? []).isEmpty ? "leaf" : "camera.fill")
                                    Spacer()
                                    Text("\((store.plants.firstIndex(of: plant) ?? 0) + 1)").font(.caption2).monospacedDigit()
                                }.foregroundStyle(.green)
                                CatalogValue(plant: plant, field: .latin, text: plant.latin).font(.headline)
                                CatalogValue(plant: plant, field: .japanese, text: plant.jpName).font(.caption)
                                CatalogValue(plant: plant, field: .family, text: plant.family).font(.caption2)
                                let record = store.state.records[plant.id] ?? StudyRecord()
                                Label(record.memorized ? "記憶済み" : "習熟度 \(record.mastery)/3", systemImage: record.memorized ? "checkmark.seal.fill" : "circle.dotted").font(.caption2)
                            }.frame(maxWidth: .infinity, minHeight: 125, alignment: .leading).padding(14)
                                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding()
        }
        .navigationTitle("図鑑")
        .searchable(text: $search, prompt: "属名・読み・科名・和名")
        .toolbar { NavigationLink("演習") { StudyHome(initialStyle: .practice, selectedPlants: filtered) }; CatalogMaskMenu(); NavigationLink { ObservationMap() } label: { Label("観察地図", systemImage: "map") } }
    }
}

struct PlantDetail: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var locator = LocationService()
    let plant: Plant
    @State private var items: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var useMetadata = false
    @State private var photoToDelete: PhotoRecord?
    @State private var deleteLocation = false
    var photos: [PhotoRecord] { store.state.photos[plant.id] ?? [] }
    var body: some View {
        List {
            if store.isProtected(plant.id) && store.revealedCatalogID != plant.id {
                Section { Text("手入れが近いため、暗記情報を伏せています。").font(.footnote)
                    Button("幽香に訊く") { store.ask(plant.id) }
                }
            }
            Section {
                CatalogValue(plant: plant, field: .latin, text: plant.latin + " / " + plant.read).font(.title)
                CatalogValue(plant: plant, field: .japanese, text: plant.jpName)
                CatalogValue(plant: plant, field: .family, text: plant.family + (plant.oldFamily.isEmpty ? "" : "（旧：" + plant.oldFamily + "）"))
                if !plant.note.isEmpty { CatalogValue(plant: plant, field: .note, text: plant.note).font(.subheadline) }
            }
            Section("学ぶ") {
                NavigationLink("この属を演習") { StudyHome(initialStyle: .practice, selectedPlants: [plant]) }
                if store.state.records[plant.id]?.hasBloomed != true { NavigationLink("この属を咲かせる") { StudyHome(selectedPlants: [plant]) } }
                Button(store.state.records[plant.id]?.favorite == true ? "お気に入りを解除" : "お気に入りにする") { store.toggleFavorite(plant.id) }
            }
            Section("学習記録") {
                let record = store.state.records[plant.id] ?? StudyRecord()
                if record.hasBloomed { NavigationLink("庭の記憶・復習予定を見る") { PlantMemoryDetail(plant: plant) } }
                LabeledContent("属名 → 科名", value: record.clearedLatinToFamily ? "クリア" : "未クリア")
                LabeledContent("和名 → 属名", value: record.clearedJapaneseToLatin ? "クリア" : "未クリア")
                LabeledContent("属名 → 和名", value: record.clearedLatinToJapanese ? "クリア" : "未クリア")
                LabeledContent("習熟度", value: "\(record.mastery) / 3")
                LabeledContent("記憶済み", value: record.memorized ? "はい" : "基本3形式の正解を集めましょう")
                ForEach(QuizMode.allCases.filter { $0 != .mixed }) { mode in
                    AccuracyRow(title: mode.title, accuracy: record.accuracy[mode.rawValue] ?? Accuracy())
                }
            }
            Section {
                if photos.isEmpty { Text("まだ写真がありません").foregroundStyle(.secondary) }
                else {
                    PhotoStrip(photos: photos)
                    ForEach(photos) { photo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(photo.capturedAt == nil ? "撮影日時なし" : photo.capturedAt!.formatted(date: .abbreviated, time: .shortened))
                                Text(photo.location == nil ? "写真の位置情報なし" : "写真の位置情報あり").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { photoToDelete = photo } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel("この写真を削除")
                        }
                    }
                }
                Toggle("撮影日時・位置情報も保存", isOn: $useMetadata).disabled(importing)
                PhotosPicker(selection: $items, maxSelectionCount: 10, matching: .images, preferredItemEncoding: .current) { Label("写真を登録", systemImage: "photo.badge.plus") }.disabled(importing)
                if importing { ProgressView("写真を読み込んでいます…") }
            } header: { Text("観察写真") } footer: { Text("選択した写真だけ端末内に保存します。写真によっては撮影日時・GPSが含まれません。撮影日時にタイムゾーンがない場合は端末の時刻設定で解釈します。") }
            Section("庭の外観") {
                Text(photos.isEmpty ? "写真を登録すると観察済みになります" : "観察済み")
                let available = (store.appearances.variants[plant.id] ?? []).filter { $0.minimumPhotoCount <= photos.count }
                if available.isEmpty { Text("外観差分は制作中です。現在は基本の仮素材を表示しています。").font(.caption).foregroundStyle(.secondary) }
                else {
                    Picker("外観", selection: Binding(get: { store.preferences.appearanceVariants[plant.id] ?? "default" }, set: { v in store.setPreferences { $0.appearanceVariants[plant.id] = v } })) {
                        Text("基本").tag("default")
                        ForEach(available) { Text($0.title).tag($0.id) }
                    }
                }
            }
            Section("観察場所") {
                if let point = store.state.locations[plant.id] {
                    Map {
                        Marker("観察場所", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
                    }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("\(point.latitude, specifier: "%.5f"), \(point.longitude, specifier: "%.5f") · \(point.source)").font(.caption)
                    Button("場所の記録を削除", role: .destructive) { deleteLocation = true }
                }
                Button { recordLocation() } label: { Label(locator.busy ? "現在地を取得中…" : "現在地を記録", systemImage: "location") }.disabled(locator.busy)
            }
        }
        .navigationTitle("図鑑詳細").navigationBarTitleDisplayMode(.inline)
        .onAppear { store.revealedCatalogID = nil }
        .onDisappear { store.revealedCatalogID = nil }
        .toolbar { CatalogMaskMenu() }
        .onChange(of: items) { _, selected in
            guard !selected.isEmpty, !importing else { return }
            importing = true
            let metadata = useMetadata
            Task {
                for item in selected {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoError.invalid }
                        await store.addPhoto(data: data, plant: plant.id, useMetadata: metadata)
                    } catch { store.error = "写真の取得に失敗しました。\(error.localizedDescription)" }
                }
                items = []; importing = false
            }
        }
        .confirmationDialog("この写真を削除しますか？", isPresented: Binding(get: { photoToDelete != nil }, set: { if !$0 { photoToDelete = nil } }), titleVisibility: .visible) {
            Button("削除", role: .destructive) { if let photo = photoToDelete { store.deletePhoto(photo, plant: plant.id) }; photoToDelete = nil }
        }
        .confirmationDialog("この属と登録写真の位置情報を削除しますか？", isPresented: $deleteLocation, titleVisibility: .visible) {
            Button("位置情報を削除", role: .destructive) {
                store.update { state in
                    state.locations.removeValue(forKey: plant.id)
                    if let list = state.photos[plant.id] { state.photos[plant.id] = list.map { var copy = $0; copy.location = nil; return copy } }
                }
            }
        }
    }
    private func recordLocation() {
        locator.request { result in
            switch result {
            case .success(let point): store.update { $0.locations[plant.id] = point }
            case .failure(let error): store.error = error.localizedDescription
            }
        }
    }
}

struct PhotoStrip: View {
    @EnvironmentObject private var store: AppStore
    let photos: [PhotoRecord]
    var concealMetadata = false
    @State private var enlarged: PhotoRecord?
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(photos) { photo in
                    Button { enlarged = photo } label: {
                        LocalPhoto(url: store.photoURL(photo)).frame(width: 235, height: 180).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel("写真を拡大")
                }
            }
        }
        .sheet(item: $enlarged) { photo in
            NavigationStack {
                LocalPhoto(url: store.photoURL(photo)).padding()
                    .navigationTitle("観察写真").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("閉じる") { enlarged = nil } }
            }
        }
    }
}
struct LocalPhoto: View {
    let url: URL?
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }.task(id: url) {
            guard let url else { return }
            let data = await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
            image = data.flatMap { UIImage(data: $0) }
        }
    }
}
struct ObservationMap: View {
    @EnvironmentObject private var store: AppStore
    private var located: [Plant] { store.plants.filter { store.state.locations[$0.id]?.valid == true } }
    var body: some View {
        Group {
            if located.isEmpty { ContentUnavailableView("観察場所がありません", systemImage: "map", description: Text("図鑑の詳細画面から現在地や写真の位置情報を登録できます。")) }
            else {
                Map {
                    ForEach(located) { plant in
                        if let point = store.state.locations[plant.id] {
                            Annotation(plant.jpName, coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                                NavigationLink { PlantDetail(plant: plant) } label: { Image(systemName: "leaf.circle.fill").font(.title).foregroundStyle(.green).background(.background, in: Circle()) }
                            }
                        }
                    }
                }
            }
        }.navigationTitle("観察地図")
    }
}

struct CatalogMaskMenu: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Menu {
            ForEach(CatalogField.allCases) { field in
                Toggle("\(field.rawValue)を隠す", isOn: Binding(get: { store.hiddenCatalogFields.contains(field) }, set: { if $0 { store.hiddenCatalogFields.insert(field) } else { store.hiddenCatalogFields.remove(field) }; store.saveMasks() }))
            }
        } label: { Label("情報を隠す", systemImage: "eye.slash") }
    }
}
struct CatalogValue: View {
    @EnvironmentObject private var store: AppStore
    let plant: Plant
    let field: CatalogField
    let text: String
    @State private var revealed = false
    private var protected: Bool { store.isProtected(plant.id) && store.revealedCatalogID != plant.id }
    private var hidden: Bool { protected || (store.hiddenCatalogFields.contains(field) && !revealed) }
    var body: some View {
        Group {
            if protected { Text("••••").accessibilityLabel("復習保護中") }
            else if hidden { Button("\(field.rawValue)を表示") { revealed = true }.buttonStyle(.borderless) }
            else { Text(text) }
        }
        .onChange(of: store.hiddenCatalogFields) { _, _ in revealed = false }
    }
}
