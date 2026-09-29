import Foundation

struct BackupArchive: Codable {
    var formatVersion = 1
    var createdAt = Date()
    var state: AppState
    var images: [String: Data]
    func validate(knownPlants: Set<String>) throws {
        guard formatVersion == 1, state.schemaVersion == 1 else { throw StorageError.unsupportedVersion }
        let plantKeys = Set(state.records.keys).union(state.photos.keys).union(state.locations.keys).union(state.unlocked)
        guard plantKeys.isSubset(of: knownPlants),
              state.locations.values.allSatisfy(\.valid),
              state.dailyCounts.values.allSatisfy({ $0 >= 0 }),
              state.rangeFrom >= 1, state.rangeTo >= state.rangeFrom, state.rangeTo <= knownPlants.count else { throw BackupError.invalid }
        for record in state.records.values {
            guard record.accuracy.values.allSatisfy({ $0.correct >= 0 && $0.total >= $0.correct }) else { throw BackupError.invalid }
        }
        var photoIDs = Set<UUID>()
        var filenames = Set<String>()
        for photo in state.photos.values.flatMap({ $0 }) {
            guard photo.filename == photo.id.uuidString + ".jpg", photoIDs.insert(photo.id).inserted,
                  let bytes = images[photo.filename], !bytes.isEmpty,
                  photo.location?.valid ?? true else { throw BackupError.invalid }
            filenames.insert(photo.filename)
        }
        guard Set(images.keys) == filenames else { throw BackupError.invalid }
    }
}
enum BackupError: LocalizedError {
    case invalid
    var errorDescription: String? { "バックアップの形式・植物ID・写真データが不正です。復元を中止しました。" }
}
