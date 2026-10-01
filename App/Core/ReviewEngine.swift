import Foundation

enum ReviewResult: String, Codable { case correct, partial, incorrect }
enum ReviewPolicy { case automatic, deferred, completed(ReviewResult, recallFraction: Double = 1) }
enum MemoryAppearance: String, CaseIterable {
    case vivid = "鮮明", fading = "少し退色", sepia = "セピア寄り", monochrome = "モノクロ", translucent = "薄い投影"
    static func of(_ freshness: Double) -> Self {
        if freshness >= 0.8 { return .vivid }
        if freshness >= 0.6 { return .fading }
        if freshness >= 0.4 { return .sepia }
        if freshness >= 0.2 { return .monochrome }
        return .translucent
    }
}
enum ReviewBucket: String, CaseIterable, Identifiable {
    case due = "復習時期", late = "少し遅れ", thin = "記憶がかなり薄い"
    var id: String { rawValue }
}

enum ReviewEngine {
    static let intervals = [1, 3, 7, 14, 30, 60, 120]
    static let day: TimeInterval = 86_400
    static func bloom(_ record: inout StudyRecord, at date: Date) {
        guard !record.hasBloomed else { return }
        record.hasBloomed = true
        record.firstBloomedAt = date
        record.reviewStage = 0
        record.lastReviewedAt = date
        record.nextReviewAt = date.addingTimeInterval(day)
        record.memoryFreshness = 1
        record.freshnessUpdatedAt = date
    }
    static func freshness(_ record: StudyRecord, at date: Date) -> Double {
        guard record.hasBloomed else { return 0 }
        let anchor = record.freshnessUpdatedAt ?? record.lastReviewedAt ?? record.firstBloomedAt ?? date
        let elapsed = max(0, date.timeIntervalSince(anchor))
        let interval = Double(intervals[max(0, min(6, record.reviewStage))]) * day
        return max(0, min(1, record.memoryFreshness * pow(0.65, elapsed / interval)))
    }
    static func review(_ record: inout StudyRecord, result: ReviewResult, at date: Date, recallFraction: Double = 1) {
        guard record.hasBloomed else { return }
        let previous = record.lastReviewedAt ?? record.firstBloomedAt ?? date
        // Ignore a backwards clock rather than moving anchors or due dates into the past.
        guard date >= previous else { return }
        let oldDue = record.nextReviewAt ?? date
        let eligible = date >= oldDue && date.timeIntervalSince(previous) >= day && recallFraction >= 1
        let current = freshness(record, at: date)
        switch result {
        case .correct:
            record.memoryFreshness = recallFraction >= 1 ? 1 : min(1, current + 0.10 * max(0, recallFraction) + 0.05)
            if recallFraction >= 1 { record.lastSuccessfulRecallAt = date }
            if eligible {
                record.reviewStage = min(6, record.reviewStage + 1)
                record.nextReviewAt = date.addingTimeInterval(Double(intervals[record.reviewStage]) * day)
            }
        case .partial:
            record.memoryFreshness = min(1, current + (recallFraction >= 1 ? 0.45 : 0.10))
            if eligible { record.nextReviewAt = date.addingTimeInterval(Double(min(3, intervals[record.reviewStage])) * day) }
        case .incorrect:
            record.memoryFreshness = min(1, current + 0.15)
            if eligible { record.reviewStage = max(0, record.reviewStage - 1) }
            // One-day retry; early reviews may shorten but never extend an existing schedule.
            record.nextReviewAt = eligible ? date.addingTimeInterval(day) : min(oldDue, date.addingTimeInterval(day))
        }
        record.lastReviewedAt = date
        record.lastReviewResult = result
        record.freshnessUpdatedAt = date
    }
    static func recallAllowed(_ record: StudyRecord, mode: QuizMode, at date: Date) -> Bool {
        record.lastExposure[mode.rawValue].map { date.timeIntervalSince($0) >= day } ?? true
    }
    static func expose(_ record: inout StudyRecord, modes: [QuizMode], at date: Date) {
        for mode in modes where QuizMode.core.contains(mode) {
            record.lastExposure[mode.rawValue] = max(record.lastExposure[mode.rawValue] ?? .distantPast, date)
        }
        guard !modes.isEmpty, record.hasBloomed,
              date.timeIntervalSince(record.lastExposureRecoveryAt ?? .distantPast) >= day,
              date >= (record.freshnessUpdatedAt ?? .distantPast) else { return }
        // At most one small observation recovery per rolling day, without moving the due date.
        record.memoryFreshness = min(1, freshness(record, at: date) + 0.05)
        record.freshnessUpdatedAt = date
        record.lastExposureRecoveryAt = date
    }
    static func recommendedIDs(in state: AppState, at date: Date) -> [String] {
        let due = dueIDs(in: state, at: date)
        let soon = state.records.keys.filter { id in
            guard let r = state.records[id], r.hasBloomed, let next = r.nextReviewAt else { return false }
            return next > date && next <= date.addingTimeInterval(6 * 3600)
        }.sorted { state.records[$0]!.nextReviewAt! < state.records[$1]!.nextReviewAt! }
        return Array((due + soon).prefix(5))
    }
    static func result(for points: [Double]) -> ReviewResult {
        guard !points.isEmpty else { return .incorrect }
        let average = points.reduce(0, +) / Double(points.count)
        return average >= 1 - 0.000001 ? .correct : average >= 0.5 ? .partial : .incorrect
    }
    static func isDue(_ record: StudyRecord, at date: Date) -> Bool {
        record.hasBloomed && (record.nextReviewAt.map { $0 <= date } ?? false)
    }
    static func bucket(_ record: StudyRecord, at date: Date) -> ReviewBucket {
        if freshness(record, at: date) < 0.4 { return .thin }
        if let due = record.nextReviewAt, date.timeIntervalSince(due) >= day { return .late }
        return .due
    }
    static func dueIDs(in state: AppState, at date: Date) -> [String] {
        state.records.keys.filter { isDue(state.records[$0]!, at: date) }.sorted { left, right in
            let a = state.records[left]!, b = state.records[right]!
            let fadingA = freshness(a, at: date) < 0.2, fadingB = freshness(b, at: date) < 0.2
            if fadingA != fadingB { return fadingA }
            let failedA = a.lastReviewResult == .incorrect, failedB = b.lastReviewResult == .incorrect
            if failedA != failedB { return failedA }
            let dueA = a.nextReviewAt ?? date, dueB = b.nextReviewAt ?? date
            if dueA != dueB { return dueA < dueB }
            return left < right
        }
    }
}
