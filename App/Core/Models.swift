import Foundation

struct Plant: Codable, Identifiable, Hashable {
    let latin: String
    let read: String
    let family: String
    let oldFamily: String
    let jpName: String
    let note: String
    var id: String { latin }
    func matches(_ query: String) -> Bool {
        query.isEmpty || [latin, read, family, oldFamily, jpName, note].contains {
            $0.localizedStandardContains(query)
        }
    }
}

struct JapaneseAnswer: Codable {
    let pattern: String
    let jpName: String
    let answers: [String]
    let suffix: String
    var prompt: String { pattern == "B" ? answers[1] : answers[0] + suffix }
}

enum QuizMode: String, Codable, CaseIterable, Identifiable {
    case latin2family, jp2latin, latin2jp, family2genus, photo, mixed
    var id: String { rawValue }
    static let core: [QuizMode] = [.latin2family, .jp2latin, .latin2jp]
    var title: String {
        switch self {
        case .latin2family: return "属名 → 科名"
        case .jp2latin: return "和名 → ラテン語属名"
        case .latin2jp: return "属名 → 和名・代表種名"
        case .family2genus: return "科名 → 属名列挙"
        case .photo: return "写真 → 属名・科名"
        case .mixed: return "3形式ランダム"
        }
    }
}

struct Accuracy: Codable, Equatable {
    var correct = 0
    var total = 0
    var rate: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

struct StudyRecord: Codable {
    var accuracy: [String: Accuracy] = [:]
    var lastStudiedAt: Date?
    var average: Double? {
        let tried = QuizMode.core.compactMap { accuracy[$0.rawValue] }.filter { $0.total > 0 }
        return tried.isEmpty ? nil : tried.map(\.rate).reduce(0, +) / Double(tried.count)
    }
    var weak: Bool { average.map { $0 < 0.5 } ?? false }
    var memorized: Bool { QuizMode.core.allSatisfy { (accuracy[$0.rawValue]?.correct ?? 0) > 0 } }
    var mastery: Int {
        guard let average else { return 0 }
        return average >= 0.8 ? 3 : average >= 0.6 ? 2 : average >= 0.3 ? 1 : 0
    }
    mutating func record(mode: QuizMode, correct: Bool, date: Date) {
        var value = accuracy[mode.rawValue, default: Accuracy()]
        value.total += 1
        if correct { value.correct += 1 }
        accuracy[mode.rawValue] = value
        lastStudiedAt = date
    }
}

struct GeoPoint: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var recordedAt: Date
    var source: String
    var valid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
}

struct PhotoRecord: Codable, Identifiable {
    let id: UUID
    let filename: String
    var capturedAt: Date?
    var location: GeoPoint?
    let addedAt: Date
}

struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var mode: QuizMode
    var answered: Int
    var planned: Int
    var correct: Int
    var points: Double
    var completed: Bool
}

struct GardenState: Codable {
    var unlockedPlants: Set<String> = []
    var points = 0
    var furniture: [String] = []
}
struct CharacterState: Codable {
    var characterID = "placeholder"
    var seenEvents: Set<String> = []
    var lastInteraction: Date?
}
enum EventCondition: Codable {
    case memorizedCount(Int)
    case month(Int)
    case daysSinceStudy(Int)
}

struct AppState: Codable {
    var schemaVersion = 1
    var records: [String: StudyRecord] = [:]
    var photos: [String: [PhotoRecord]] = [:]
    var locations: [String: GeoPoint] = [:]
    var unlocked: Set<String> = []
    var sessions: [SessionRecord] = []
    var dailyCounts: [String: Int] = [:]
    var rangeFrom = 1
    var rangeTo = 5
    var garden = GardenState()
    var character = CharacterState()
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    mutating func answer(plant: String, mode: QuizMode, correct: Bool, date: Date) {
        records[plant, default: StudyRecord()].record(mode: mode, correct: correct, date: date)
        dailyCounts[Self.dayKey(date), default: 0] += 1
    }
}
