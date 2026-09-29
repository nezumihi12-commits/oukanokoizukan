import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state = AppState()
    @Published private(set) var plants: [Plant] = []
    @Published private(set) var japanese: [String: JapaneseAnswer] = [:]
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
            let disk = try DiskRepository()
            repository = disk
            state = try disk.load()
            try FileManager.default.createDirectory(at: disk.directory.appendingPathComponent("Photos"), withIntermediateDirectories: true)
            ready = true
        } catch { self.error = "読み込みに失敗しました。保存データは上書きしません。\n\(error.localizedDescription)" }
    }
    @discardableResult
    func update(_ edit: (inout AppState) -> Void) -> Bool {
        guard ready, let repository else { return false }
        var next = state
        edit(&next)
        do {
            try repository.save(next)
            state = next
            return true
        } catch { self.error = "保存できませんでした。再試行してください。\n\(error.localizedDescription)"; return false }
    }
    var memorized: Int { state.records.values.filter(\.memorized).count }
    var weak: Int { state.records.values.filter(\.weak).count }
    var today: Int { state.dailyCounts[AppState.dayKey(Date()), default: 0] }
    var photographed: Int { state.photos.values.filter { !$0.isEmpty }.count }
    func photoURL(_ photo: PhotoRecord) -> URL? { photoDirectory?.appendingPathComponent(photo.filename) }
    func record(_ question: Question, grade: Grade) -> Bool {
        update { $0.answer(plant: question.plant.id, mode: question.mode, correct: grade.fullCorrect, date: Date()) }
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
        // New file IDs protect current photos until the state file commits atomically.
        var next = archive.state
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
        for photo in oldPhotos { try? FileManager.default.removeItem(at: directory.appendingPathComponent(photo.filename)) }
    }
}
