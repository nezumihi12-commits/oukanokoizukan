import Foundation

extension AppStore {
    func publishCompanion(_ stateID: YuukaStateID? = nil) {
        let now = Date()
        let records = state.records.values.filter { $0.hasBloomed }
        let due = records.filter { ReviewEngine.isDue($0, at: now) }
        let late = due.filter { ReviewEngine.bucket($0, at: now) != .due }.count
        CompanionStorage.save(CompanionSnapshot(generatedAt: now,
            dueDates: records.compactMap(\.nextReviewAt), overdueCount: late,
            stateID: stateID ?? (late > 0 ? .overdue : due.isEmpty ? .idle : .review_due)))
    }
}
