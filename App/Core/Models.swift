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
    var relearnedAt: Date?
    var lastFormalReviewAt: Date?
    var earlyBonusStage: Int?
    var photoBonusAt: Date?
    var practiceAccuracy: [String: Accuracy] = [:]
    var reviewAccuracy: [String: Accuracy] = [:]
    var formatReviewedAt: [String: Date] = [:]
    var answerHistory: [AnswerEvent] = []
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
        case relearnedAt, lastFormalReviewAt, earlyBonusStage, photoBonusAt, practiceAccuracy, reviewAccuracy, formatReviewedAt, answerHistory
        case lastExposure, lastSuccessfulRecallAt, lastExposureRecoveryAt
        case accuracy, lastStudiedAt, plantID, clearedLatinToFamily, clearedJapaneseToLatin
        case clearedLatinToJapanese, hasBloomed, firstBloomedAt, reviewStage, lastReviewedAt
        case nextReviewAt, lastReviewResult, memoryFreshness, freshnessUpdatedAt, favorite
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relearnedAt = try c.decodeIfPresent(Date.self, forKey: .relearnedAt)
        lastFormalReviewAt = try c.decodeIfPresent(Date.self, forKey: .lastFormalReviewAt)
        earlyBonusStage = try c.decodeIfPresent(Int.self, forKey: .earlyBonusStage)
        photoBonusAt = try c.decodeIfPresent(Date.self, forKey: .photoBonusAt)
        practiceAccuracy = try c.decodeIfPresent([String: Accuracy].self, forKey: .practiceAccuracy) ?? [:]
        reviewAccuracy = try c.decodeIfPresent([String: Accuracy].self, forKey: .reviewAccuracy) ?? [:]
        formatReviewedAt = try c.decodeIfPresent([String: Date].self, forKey: .formatReviewedAt) ?? [:]
        answerHistory = try c.decodeIfPresent([AnswerEvent].self, forKey: .answerHistory) ?? []
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
    var memorized: Bool { hasBloomed || clearedAll }
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
    var schemaVersion = 3
    var preferences: AppPreferences? = nil
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
        let result: ReviewResult = correct ? .correct : points > 0 ? .partial : .incorrect
        let purpose: AnswerPurpose
        switch review {
        case .automatic: purpose = .learning
        case .deferred: purpose = .practice
        case .completed: purpose = ReviewEngine.isRelearnLocked(record, at: date) ? .practice : .review
        }
        let oldFlags = (record.clearedLatinToFamily, record.clearedJapaneseToLatin, record.clearedLatinToJapanese)
        record.record(mode: mode, correct: correct, date: date)
        if purpose != .learning {
            (record.clearedLatinToFamily, record.clearedJapaneseToLatin, record.clearedLatinToJapanese) = oldFlags
        }
        if purpose == .practice { record.practiceAccuracy[mode.rawValue, default: Accuracy()].total += 1
            if correct { record.practiceAccuracy[mode.rawValue, default: Accuracy()].correct += 1 }
        }
        if purpose == .review {
            record.reviewAccuracy[mode.rawValue, default: Accuracy()].total += 1
            if correct { record.reviewAccuracy[mode.rawValue, default: Accuracy()].correct += 1 }
            record.formatReviewedAt[mode.rawValue] = date
        }
        record.answerHistory.append(AnswerEvent(date: date, mode: mode, purpose: purpose, result: result))
        if !alreadyBloomed && purpose == .learning && record.clearedAll { ReviewEngine.bloom(&record, at: date) }
        if alreadyBloomed, case .completed(let result, let fraction) = review {
            ReviewEngine.review(&record, result: result, at: date, recallFraction: fraction)
        }
        // Feedback in practice is explicit answer exposure; formal feedback never locks the next review.
        if purpose == .practice { ReviewEngine.expose(&record, modes: QuizMode.core, at: date) }
        records[plant] = record
        if record.hasBloomed && !alreadyBloomed {
            if garden.layout == nil { garden.layout = GardenLayout() }
            NoticeQueue.enqueue(GardenNotice(id: "bloom-" + plant, priority: 1, systemText: "植物が開花しました"), into: &garden.layout!.pendingEvents)
            if !character.seenEvents.contains("first-bloom") {
                NoticeQueue.enqueue(GardenNotice(id: "first-bloom", priority: 3, systemText: "初めての開花。3形式を覚えた実績は消えません。明日から手入れが始まります。"), into: &garden.layout!.pendingEvents)
            }
        }
        if purpose == .review && !character.seenEvents.contains("first-review") {
            if garden.layout == nil { garden.layout = GardenLayout() }
            NoticeQueue.enqueue(GardenNotice(id: "first-review", priority: 3, systemText: "正式復習を記録しました。1属につき1形式を、時間を空けて思い出します。"), into: &garden.layout!.pendingEvents)
        }
        if record.hasBloomed {
            garden.unlockedPlants.insert(plant)
            if garden.plantZones == nil { garden.plantZones = [:] }
            if garden.plantZones?[plant] == nil { garden.plantZones?[plant] = GardenZone.central.id }
        }
        dailyCounts[Self.dayKey(date), default: 0] += 1
    }
    mutating func migrateToV2(at date: Date = Date()) throws {
        guard (1...3).contains(schemaVersion) else { throw StorageError.unsupportedVersion }
        guard schemaVersion < 3 else { return }
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
            record.lastFormalReviewAt = record.lastReviewedAt ?? record.firstBloomedAt
            records[id] = record
        }
        schemaVersion = 3
    }
}
