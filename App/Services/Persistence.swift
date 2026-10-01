import Foundation

protocol StateRepository {
    func load() throws -> AppState
    func save(_ state: AppState) throws
}
struct DiskRepository: StateRepository {
    let directory: URL
    var stateURL: URL { directory.appendingPathComponent("state.json") }
    init(directory: URL? = nil) throws {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Hanazukan", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }
    func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return AppState() }
        let original = try Data(contentsOf: stateURL)
        var value = try JSONDecoder().decode(AppState.self, from: original)
        guard (1...3).contains(value.schemaVersion) else { throw StorageError.unsupportedVersion }
        if value.schemaVersion < 3 {
            try value.migrateToV2()
            let backup = directory.appendingPathComponent("state-before-v3.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try original.write(to: backup, options: .atomic) }
            try save(value)
        }
        return value
    }
    func save(_ state: AppState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL, options: .atomic)
    }
}
enum StorageError: LocalizedError {
    case unsupportedVersion, unavailable
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "この保存データのバージョンには対応していません。元のデータは保持しています。"
        case .unavailable: return "保存領域を利用できません。"
        }
    }
}

// Future adapters should merge by stable Latin genus ID and explicit schema version.
protocol SyncService {
    func synchronize(_ state: AppState) async throws -> AppState
}
struct LocalOnlySync: SyncService {
    func synchronize(_ state: AppState) async throws -> AppState { state }
}
struct StudySnapshot: Codable {
    let generatedAt: Date
    let memorized: Int
    let weak: Int
    let todayCount: Int
}
protocol SnapshotPublishing { func publish(_ snapshot: StudySnapshot) throws }
struct FileSnapshotPublisher: SnapshotPublishing {
    let url: URL
    func publish(_ snapshot: StudySnapshot) throws {
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
