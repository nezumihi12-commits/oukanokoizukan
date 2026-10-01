import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state = AppState()
    @Published private(set) var plants: [Plant] = []
    @Published private(set) var japanese: [String: JapaneseAnswer] = [:]
    @Published private(set) var renderCatalog = PlantRenderCatalog(version: 1, isPlaceholder: true, definitions: [:])
    @Published private(set) var appearances = AppearanceCatalog(version: 1, variants: [:])
    @Published private(set) var habitats: [String: GardenAttribute] = [:]
    @Published var hiddenCatalogFields: Set<CatalogField> = []
    @Published var revealedCatalogID: String?
    var preferences: AppPreferences { state.preferences ?? AppPreferences() }
    func isProtected(_ id: String) -> Bool { ReviewEngine.protected(state.records[id] ?? StudyRecord(), at: Date()) }
    func ask(_ id: String) { if expose(id, modes: QuizMode.core) { revealedCatalogID = id } }
    func saveMasks() { update { $0.preferences = preferences; $0.preferences?.hiddenFields = Set(hiddenCatalogFields.map(\.rawValue)) } }
    func setPreferences(_ edit: (inout AppPreferences) -> Void) {
        var p = preferences; edit(&p); if update({ $0.preferences = p }) { Task { await CareNotifications.refresh(state) } }
    }
    @Published private(set) var layoutUndoUntil: Date?
    private var previousLayout: GardenLayout?
    @Published var error: String?
    @Published private(set) var ready = false
    private var repository: DiskRepository?
    var photoDirectory: URL? { repository?.directory.appendingPathComponent("Photos", isDirectory: true) }
    init() {
        do {
            guard let plantsURL = Bundle.main.url(forResource: "genera", withExtension: "json"),
                  let answersURL = Bundle.main.url(forResource: "japaneseAnswers", withExtension: "json") else { throw StorageError.unavailable }
            plants = try JSONDecoder().decode([Plant].self, from: Data(contentsOf: plantsURL))
            japanese = try JSONDecoder().decode([String: JapaneseAnswer].self, from: Data(contentsOf: answersURL))
            if let renderURL = Bundle.main.url(forResource: "plantRenderDefinitions", withExtension: "json") {
                renderCatalog = try JSONDecoder().decode(PlantRenderCatalog.self, from: Data(contentsOf: renderURL))
            }
            guard let habitatURL = Bundle.main.url(forResource: "habitatAttributes", withExtension: "json") else { throw StorageError.unavailable }
            let attributes = try JSONDecoder().decode([GardenAttribute].self, from: Data(contentsOf: habitatURL))
            habitats = Dictionary(uniqueKeysWithValues: attributes.map { ($0.latin, $0) })
            if let url = Bundle.main.url(forResource: "appearanceVariants", withExtension: "json") {
                appearances = try JSONDecoder().decode(AppearanceCatalog.self, from: Data(contentsOf: url))
            }
            let disk = try DiskRepository()
            repository = disk
            state = try disk.load()
            hiddenCatalogFields = Set((state.preferences?.hiddenFields ?? []).compactMap(CatalogField.init(rawValue:)))
            if let layout = state.garden.layout { try GardenEngine.validate(layout, records: state.records) }
            GardenEngine.migrateMembership(&state)
            if state.garden.layout == nil {
                if FileManager.default.fileExists(atPath: disk.stateURL.path) {
                    let backup = disk.directory.appendingPathComponent("state-before-garden-layout.json")
                    if !FileManager.default.fileExists(atPath: backup.path) { try Data(contentsOf: disk.stateURL).write(to: backup, options: .atomic) }
                }
                GardenEngine.reconcile(&state, attributes: habitats, at: Date())
                try disk.save(state)
            }
            try disk.save(state)
            try FileManager.default.createDirectory(at: disk.directory.appendingPathComponent("Photos"), withIntermediateDirectories: true)
            ready = true
        } catch { self.error = "読み込みに失敗しました。保存データは上書きしません。\n\(error.localizedDescription)" }
    }
    @discardableResult
    func update(_ edit: (inout AppState) -> Void) -> Bool {
        guard ready, let repository else { return false }
        var next = state
        edit(&next)
        GardenEngine.reconcile(&next, attributes: habitats, at: Date())
        do {
            try repository.save(next)
            state = next
            Task { await CareNotifications.refresh(next) }
            return true
        } catch { self.error = "保存できませんでした。再試行してください。\n\(error.localizedDescription)"; return false }
    }
    @discardableResult
    func expose(_ id: String, modes: [QuizMode]) -> Bool {
        guard !modes.isEmpty else { return false }
        return update { state in
            var record = state.records[id] ?? StudyRecord()
            record.plantID = id
            ReviewEngine.expose(&record, modes: modes, at: Date())
            state.records[id] = record
        }
    }
    func setLayout(_ layout: GardenLayout) -> Bool {
        let previous = state.garden.layout
        guard update({ state in
            if state.garden.layout == nil { state.garden.layout = GardenLayout() }
            state.garden.layout?.placements = layout.placements
            state.garden.layout?.awaitingDelegation = layout.awaitingDelegation
            state.garden.layout?.memberships = layout.memberships
        }) else { return false }
        previousLayout = previous; layoutUndoUntil = Date().addingTimeInterval(10)
        return true
    }
    func undoLayout() {
        guard let until = layoutUndoUntil, Date() <= until, let previousLayout else { return }
        if update({ state in
            state.garden.layout?.placements = previousLayout.placements
            state.garden.layout?.awaitingDelegation = previousLayout.awaitingDelegation
            state.garden.layout?.memberships = previousLayout.memberships
        }) { self.previousLayout = nil; layoutUndoUntil = nil }
    }
    func refreshGarden() {
        var next = state
        GardenEngine.reconcile(&next, attributes: habitats, at: Date(), safeBoundary: true)
        if next.garden.layout != state.garden.layout { _ = update { $0.garden.layout = next.garden.layout } }
    }
    func recommendedPlants(at date: Date) -> [Plant] {
        ReviewEngine.recommendedIDs(in: state, at: date).compactMap { id in plants.first { $0.id == id } }
    }
    var memorized: Int { state.records.values.filter(\.memorized).count }
    var weak: Int { state.records.values.filter(\.weak).count }
    var today: Int { state.dailyCounts[AppState.dayKey(Date()), default: 0] }
    var photographed: Int { state.photos.values.filter { !$0.isEmpty }.count }
    var bloomed: Int { state.records.values.filter(\.hasBloomed).count }
    func renderDefinition(for id: String) -> PlantRenderDefinition {
        if let selected = preferences.appearanceVariants[id],
           let variant = appearances.variants[id]?.first(where: { $0.id == selected && $0.minimumPhotoCount <= (state.photos[id]?.count ?? 0) }) { return variant.renderDefinition }
        return renderCatalog.definitions[id] ?? PlantRenderCatalog.fallback
    }
    func duePlants(at date: Date) -> [Plant] {
        let byID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        return ReviewEngine.dueIDs(in: state, at: date).compactMap { byID[$0] }
    }
    func reviewQuestions(for selected: [Plant]) -> [Question] {
        selected.map { plant in
            QuizEngine.question(plant, mode: ReviewEngine.mode(for: state.records[plant.id] ?? StudyRecord()), all: plants, japanese: japanese)
        }
    }
    func toggleFavorite(_ plantID: String) {
        update { $0.records[plantID, default: StudyRecord()].favorite.toggle(); $0.records[plantID]?.plantID = plantID }
    }
    func photoURL(_ photo: PhotoRecord) -> URL? { photoDirectory?.appendingPathComponent(photo.filename) }
    func record(_ question: Question, grade: Grade, review: ReviewPolicy = .automatic) -> Bool {
        update { $0.answer(plant: question.plant.id, mode: question.mode, correct: grade.fullCorrect, date: Date(), points: grade.points, review: review) }
    }
    func addPhoto(data: Data, plant: String, useMetadata: Bool) async {
        guard ready, let directory = photoDirectory else { return }
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try PhotoService.prepare(data, useMetadata: useMetadata)
            }.value
            let id = UUID()
            let filename = id.uuidString + ".jpg"
            let url = directory.appendingPathComponent(filename)
            try prepared.jpeg.write(to: url, options: .atomic)
            let photo = PhotoRecord(id: id, filename: filename, capturedAt: prepared.capturedAt, location: prepared.location, addedAt: Date())
            if !update({
                $0.photos[plant, default: []].append(photo)
                $0.unlocked.insert(plant)
                if let point = photo.location { $0.locations[plant] = point }
            }) { try? FileManager.default.removeItem(at: url) }
        } catch { self.error = "写真を登録できませんでした。\n\(error.localizedDescription)" }
    }
    func deletePhoto(_ photo: PhotoRecord, plant: String) {
        if update({ $0.photos[plant]?.removeAll { $0.id == photo.id } }), let url = photoURL(photo) {
            do { try FileManager.default.removeItem(at: url) }
            catch { self.error = "写真の記録は削除しましたが、画像ファイルの削除に失敗しました。" }
        }
    }
    func exportProgress() throws -> URL {
        guard let repository else { throw StorageError.unavailable }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Hanazukan-progress.json")
        try Data(contentsOf: repository.stateURL).write(to: url, options: .atomic)
        return url
    }
    func exportBackup() async throws -> URL {
        guard ready, let directory = photoDirectory else { throw StorageError.unavailable }
        let snapshot = state
        return try await Task.detached(priority: .userInitiated) {
            var images: [String: Data] = [:]
            for photo in snapshot.photos.values.flatMap({ $0 }) {
                images[photo.filename] = try Data(contentsOf: directory.appendingPathComponent(photo.filename))
            }
            let archive = BackupArchive(state: snapshot, images: images)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Hanazukan-backup.json")
            try JSONEncoder().encode(archive).write(to: url, options: .atomic)
            return url
        }.value
    }
    func readBackup(_ url: URL) async throws -> BackupArchive {
        let known = Set(plants.map(\.id))
        return try await Task.detached(priority: .userInitiated) {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let archive = try JSONDecoder().decode(BackupArchive.self, from: Data(contentsOf: url))
            try archive.validate(knownPlants: known)
            return archive
        }.value
    }
    func restore(_ archive: BackupArchive) throws {
        guard ready, let directory = photoDirectory, let repository else { throw StorageError.unavailable }
        try archive.validate(knownPlants: Set(plants.map(\.id)))
        // Preserve both state and actual photos before any restore can replace references.
        var oldImages: [String: Data] = [:]
        for photo in state.photos.values.flatMap({ $0 }) { oldImages[photo.filename] = try Data(contentsOf: directory.appendingPathComponent(photo.filename)) }
        try JSONEncoder().encode(BackupArchive(state: state, images: oldImages)).write(to: repository.directory.appendingPathComponent("backup-before-restore.json"), options: .atomic)
        // New file IDs protect current photos until the state file commits atomically.
        var next = archive.state
        try next.migrateToV2()
        GardenEngine.migrateMembership(&next)
        GardenEngine.reconcile(&next, attributes: habitats, at: Date())
        var written: [URL] = []
        do {
            for (plant, photos) in archive.state.photos {
                next.photos[plant] = try photos.map { photo in
                    let id = UUID()
                    let filename = id.uuidString + ".jpg"
                    let url = directory.appendingPathComponent(filename)
                    try archive.images[photo.filename]!.write(to: url, options: .atomic)
                    written.append(url)
                    return PhotoRecord(id: id, filename: filename, capturedAt: photo.capturedAt, location: photo.location, addedAt: photo.addedAt)
                }
            }
            try repository.save(next)
        } catch {
            for url in written { try? FileManager.default.removeItem(at: url) }
            throw error
        }
        let oldPhotos = state.photos.values.flatMap { $0 }
        state = next
        hiddenCatalogFields = Set((next.preferences?.hiddenFields ?? []).compactMap(CatalogField.init(rawValue:)))
        revealedCatalogID = nil
        Task { await CareNotifications.refresh(next) }
        for photo in oldPhotos { try? FileManager.default.removeItem(at: directory.appendingPathComponent(photo.filename)) }
    }
}
