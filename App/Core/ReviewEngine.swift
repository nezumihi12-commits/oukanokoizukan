import Foundation

enum ReviewResult: String, Codable { case correct, partial, incorrect }
enum ReviewPolicy { case automatic, deferred, completed(ReviewResult, recallFraction: Double = 1) }
enum MemoryAppearance: String, CaseIterable {
    case vivid = "安定", fading = "手入れどき", sepia = "乾き始め", monochrome = "色褪せ", translucent = "かなり曖昧"
    static func of(_ freshness: Double) -> Self {
        if freshness >= 1 { return .vivid }
        if freshness > 1 - Tuning.severity("care_time_max", fallback: 0.2) { return .fading }
        if freshness > 1 - Tuning.severity("drying_max", fallback: 0.45) { return .sepia }
        if freshness > 1 - Tuning.severity("faded_max", fallback: 0.75) { return .monochrome }
        return .translucent
    }
}
enum ReviewBucket: String, CaseIterable, Identifiable {
    case due = "手入れどき", late = "乾き始め", thin = "記憶がかなり薄い"
    var id: String { rawValue }
}
enum ReviewEngine {
    static var intervals: [Int] { Tuning.intervals }
    static let day: TimeInterval = 86_400
    static func bloom(_ record: inout StudyRecord, at date: Date) {
        guard !record.hasBloomed else { return }
        record.hasBloomed = true; record.firstBloomedAt = date; record.reviewStage = 0
        record.lastReviewedAt = date; record.lastFormalReviewAt = date
        record.nextReviewAt = date.addingTimeInterval(Double(intervals[0]) * day)
        record.memoryFreshness = 1; record.freshnessUpdatedAt = date
    }
    static func scheduledInterval(_ r: StudyRecord) -> TimeInterval {
        guard let due = r.nextReviewAt, let last = r.lastFormalReviewAt ?? r.lastReviewedAt ?? r.firstBloomedAt else {
            return Double(intervals[max(0, min(intervals.count - 1, r.reviewStage))]) * day
        }
        return max(1, due.timeIntervalSince(last))
    }
    static func severity(_ r: StudyRecord, at date: Date) -> Double {
        guard r.hasBloomed, let due = r.nextReviewAt else { return 0 }
        let window = min(30 * day, max(2 * day, scheduledInterval(r) * 0.5))
        return max(0, date.timeIntervalSince(due)) / window
    }
    static func freshness(_ r: StudyRecord, at date: Date) -> Double { max(0, 1 - severity(r, at: date)) }
    static func protected(_ r: StudyRecord, at date: Date) -> Bool {
        guard r.hasBloomed, let due = r.nextReviewAt else { return false }
        return date >= due.addingTimeInterval(-min(day, scheduledInterval(r) / 3))
    }
    static func isRelearnLocked(_ r: StudyRecord, at date: Date) -> Bool {
        r.relearnedAt.map { date.timeIntervalSince($0) < Tuning.number("review", "relearn_lock_hours", fallback: 24) * 3600 } ?? false
    }
    static func review(_ r: inout StudyRecord, result: ReviewResult, at date: Date, recallFraction: Double = 1) {
        guard r.hasBloomed, !isRelearnLocked(r, at: date), recallFraction >= 1,
              date >= (r.lastReviewedAt ?? r.lastFormalReviewAt ?? r.firstBloomedAt ?? .distantPast), let due = r.nextReviewAt else { return }
        let stage = max(0, min(intervals.count - 1, r.reviewStage))
        let early = date < due
        switch result {
        case .correct:
            if early {
                if r.earlyBonusStage != stage {
                    r.nextReviewAt = due.addingTimeInterval(due.timeIntervalSince(date) * Tuning.number("review", "early_correct_extension_rate_of_remaining_time", fallback: 0.1))
                    r.earlyBonusStage = stage
                }
            } else {
                r.reviewStage = min(intervals.count - 1, stage + 1)
                if r.reviewStage != stage { r.earlyBonusStage = nil }
                r.nextReviewAt = date.addingTimeInterval(Double(intervals[r.reviewStage]) * day)
                r.lastFormalReviewAt = date
            }
            r.lastSuccessfulRecallAt = date
        case .partial:
            if !early { r.nextReviewAt = date.addingTimeInterval(Double(intervals[stage]) * day); r.lastFormalReviewAt = date }
        case .incorrect:
            r.reviewStage = max(0, stage - 1)
            if r.reviewStage != stage { r.earlyBonusStage = nil }
            let recovery = Double(intervals[max(0, stage - 1)] + intervals[max(0, stage - 2)]) / 2 * day
            let next = date.addingTimeInterval(max(day, recovery))
            r.nextReviewAt = early ? min(due, next) : next
            r.lastFormalReviewAt = date
        }
        r.lastReviewedAt = date; r.lastReviewResult = result
        r.memoryFreshness = freshness(r, at: date); r.freshnessUpdatedAt = date
    }
    static func photoBonus(_ r: inout StudyRecord, at date: Date) {
        guard !isRelearnLocked(r, at: date), let last = r.lastFormalReviewAt,
              let due = r.nextReviewAt, r.lastReviewedAt == last, r.photoBonusAt != last, date.timeIntervalSince(last) >= 0,
              date.timeIntervalSince(last) < 3600 else { return }
        r.nextReviewAt = due.addingTimeInterval(scheduledInterval(r) * Tuning.number("review", "photo_bonus_next_interval_rate", fallback: 0.05))
        r.photoBonusAt = last
    }
    static func recallAllowed(_ r: StudyRecord, mode: QuizMode, at date: Date) -> Bool { !isRelearnLocked(r, at: date) }
    // Only explicit answer reveal calls this. Catalog navigation must never call it.
    static func expose(_ r: inout StudyRecord, modes: [QuizMode], at date: Date) {
        guard !modes.isEmpty, protected(r, at: date) else { return }
        r.relearnedAt = max(r.relearnedAt ?? .distantPast, date)
    }
    static func mode(for r: StudyRecord) -> QuizMode {
        QuizMode.core.sorted { a, b in
            let x = r.formatReviewedAt[a.rawValue] ?? .distantPast, y = r.formatReviewedAt[b.rawValue] ?? .distantPast
            if x != y { return x < y }
            let ax = r.reviewAccuracy[a.rawValue]?.rate ?? r.accuracy[a.rawValue]?.rate ?? 0
            let by = r.reviewAccuracy[b.rawValue]?.rate ?? r.accuracy[b.rawValue]?.rate ?? 0
            return ax == by ? a.rawValue < b.rawValue : ax < by
        }.first!
    }
    static func recommendedIDs(in state: AppState, at date: Date) -> [String] {
        state.records.keys.filter { id in
            let r = state.records[id]!
            return r.hasBloomed && !isRelearnLocked(r, at: date) && (r.nextReviewAt ?? .distantFuture) <= date.addingTimeInterval(6 * 3600)
        }.sorted { a, b in
            let x = state.records[a]!.nextReviewAt!, y = state.records[b]!.nextReviewAt!
            return x == y ? a < b : x < y
        }.prefix(Int(Tuning.number("review", "auto_review_max_genera_per_set", fallback: 5))).map { $0 }
    }
    static func result(for points: [Double]) -> ReviewResult {
        guard !points.isEmpty else { return .incorrect }
        let average = points.reduce(0, +) / Double(points.count)
        return average >= 1 - 0.000001 ? .correct : average >= 0.5 ? .partial : .incorrect
    }
    static func isDue(_ r: StudyRecord, at date: Date) -> Bool { r.hasBloomed && (r.nextReviewAt.map { $0 <= date } ?? false) }
    static func bucket(_ r: StudyRecord, at date: Date) -> ReviewBucket {
        let s = severity(r, at: date); return s >= 0.45 ? .thin : s >= 0.2 ? .late : .due
    }
    static func dueIDs(in state: AppState, at date: Date) -> [String] {
        state.records.keys.filter { isDue(state.records[$0]!, at: date) }.sorted {
            let a = state.records[$0]!.nextReviewAt!, b = state.records[$1]!.nextReviewAt!
            return a == b ? $0 < $1 : a < b
        }
    }
}
