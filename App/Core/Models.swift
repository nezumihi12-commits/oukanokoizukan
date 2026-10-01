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
    var plantID = ""
    var clearedLatinToFamily = false
    var clearedJapaneseToLatin = false
    var clearedLatinToJapanese = false
    var hasBloomed = false
    var firstBloomedAt: Date?
    var reviewStage = 0
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var lastReviewResult: ReviewResult?
    // Freshness at freshnessUpdatedAt; the displayed value is derived for the current time.
    var memoryFreshness = 1.0
    var freshnessUpdatedAt: Date?
    var favorite = false
    var lastExposure: [String: Date] = [:]
    var lastSuccessfulRecallAt: Date?
    var lastExposureRecoveryAt: Date?
    var clearedCount: Int { [clearedLatinToFamily, clearedJapaneseToLatin, clearedLatinToJapanese].filter { $0 }.count }
    func cleared(_ mode: QuizMode) -> Bool {
        switch mode { case .latin2family: return clearedLatinToFamily; case .jp2latin: return clearedJapaneseToLatin; case .latin2jp: return clearedLatinToJapanese; default: return false }
    }

    init() {}
    enum CodingKeys: String, CodingKey {
        case lastExposure, lastSuccessfulRecallAt, lastExposureRecoveryAt
        case accuracy, lastStudiedAt, plantID, clearedLatinToFamily, clearedJapaneseToLatin
        case clearedLatinToJapanese, hasBloomed, firstBloomedAt, reviewStage, lastReviewedAt
        case nextReviewAt, lastReviewResult, memoryFreshness, freshnessUpdatedAt, favorite
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accuracy = try c.decodeIfPresent([String: Accuracy].self, forKey: .accuracy) ?? [:]
        lastStudiedAt = try c.decodeIfPresent(Date.self, forKey: .lastStudiedAt)
        plantID = try c.decodeIfPresent(String.self, forKey: .plantID) ?? ""
        clearedLatinToFamily = try c.decodeIfPresent(Bool.self, forKey: .clearedLatinToFamily) ?? ((accuracy["latin2family"]?.correct ?? 0) > 0)
        clearedJapaneseToLatin = try c.decodeIfPresent(Bool.self, forKey: .clearedJapaneseToLatin) ?? ((accuracy["jp2latin"]?.correct ?? 0) > 0)
        clearedLatinToJapanese = try c.decodeIfPresent(Bool.self, forKey: .clearedLatinToJapanese) ?? ((accuracy["latin2jp"]?.correct ?? 0) > 0)
        hasBloomed = try c.decodeIfPresent(Bool.self, forKey: .hasBloomed) ?? false
        firstBloomedAt = try c.decodeIfPresent(Date.self, forKey: .firstBloomedAt)
        reviewStage = try c.decodeIfPresent(Int.self, forKey: .reviewStage) ?? 0
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        nextReviewAt = try c.decodeIfPresent(Date.self, forKey: .nextReviewAt)
        lastReviewResult = try c.decodeIfPresent(ReviewResult.self, forKey: .lastReviewResult)
        memoryFreshness = try c.decodeIfPresent(Double.self, forKey: .memoryFreshness) ?? 1
        freshnessUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .freshnessUpdatedAt)
        lastExposure = try c.decodeIfPresent([String: Date].self, forKey: .lastExposure) ?? [:]
        lastSuccessfulRecallAt = try c.decodeIfPresent(Date.self, forKey: .lastSuccessfulRecallAt)
        lastExposureRecoveryAt = try c.decodeIfPresent(Date.self, forKey: .lastExposureRecoveryAt)
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
    }
    var clearedAll: Bool { clearedLatinToFamily && clearedJapaneseToLatin && clearedLatinToJapanese }
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
        if correct {
            switch mode {
            case .latin2family: clearedLatinToFamily = true
            case .jp2latin: clearedJapaneseToLatin = true
            case .latin2jp: clearedLatinToJapanese = true
            default: break
            }
        }
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
    var gardenReview: Bool? = nil
}

struct GardenState: Codable {
    var unlockedPlants: Set<String> = []
    var points = 0
    var furniture: [String] = []
    var layout: GardenLayout? = nil
    var plantZones: [String: String]? = nil
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
    var schemaVersion = 2
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
    mutating func answer(plant: String, mode: QuizMode, correct: Bool, date: Date, points: Double = 0, review: ReviewPolicy = .automatic) {
        var record = records[plant, default: StudyRecord()]
        record.plantID = plant
        let alreadyBloomed = record.hasBloomed
        record.record(mode: mode, correct: correct, date: date)
        if !alreadyBloomed && record.clearedAll {
            ReviewEngine.bloom(&record, at: date)
        } else if alreadyBloomed && QuizMode.core.contains(mode) {
            switch review {
            case .automatic: ReviewEngine.review(&record, result: correct ? .correct : points > 0 ? .partial : .incorrect, at: date, recallFraction: ReviewEngine.recallAllowed(record, mode: mode, at: date) ? 1 : 0)
            case .deferred: break
            case .completed(let result, let fraction): ReviewEngine.review(&record, result: result, at: date, recallFraction: fraction)
            }
        }
        records[plant] = record
        if record.hasBloomed {
            garden.unlockedPlants.insert(plant)
            if garden.plantZones == nil { garden.plantZones = [:] }
            if garden.plantZones?[plant] == nil { garden.plantZones?[plant] = GardenZone.central.id }
        }
        dailyCounts[Self.dayKey(date), default: 0] += 1
    }
    mutating func migrateToV2(at date: Date = Date()) throws {
        guard (1...2).contains(schemaVersion) else { throw StorageError.unsupportedVersion }
        for id in Array(records.keys) {
            guard var record = records[id] else { continue }
            record.plantID = id
            record.clearedLatinToFamily = record.clearedLatinToFamily || (record.accuracy["latin2family"]?.correct ?? 0) > 0
            record.clearedJapaneseToLatin = record.clearedJapaneseToLatin || (record.accuracy["jp2latin"]?.correct ?? 0) > 0
            record.clearedLatinToJapanese = record.clearedLatinToJapanese || (record.accuracy["latin2jp"]?.correct ?? 0) > 0
            if !record.hasBloomed && record.clearedAll { ReviewEngine.bloom(&record, at: date) }
            if record.hasBloomed {
                garden.unlockedPlants.insert(id)
                if garden.plantZones == nil { garden.plantZones = [:] }
                if garden.plantZones?[id] == nil { garden.plantZones?[id] = GardenZone.central.id }
            }
            records[id] = record
        }
        schemaVersion = 2
    }
}
