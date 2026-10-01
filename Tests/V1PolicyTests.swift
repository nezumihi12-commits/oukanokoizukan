import XCTest
@testable import Hanazukan

final class V1PolicyTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    let day = ReviewEngine.day
    func record(stage: Int = 0) -> StudyRecord {
        var r = StudyRecord()
        for mode in QuizMode.core { r.record(mode: mode, correct: true, date: start) }
        ReviewEngine.bloom(&r, at: start)
        r.reviewStage = stage; r.nextReviewAt = start.addingTimeInterval(Double(ReviewEngine.intervals[stage]) * day)
        return r
    }
    func testPracticeNeverBloomsOrReschedules() {
        var state = AppState()
        for mode in QuizMode.core { state.answer(plant: "Acer", mode: mode, correct: true, date: start, review: .deferred) }
        XCTAssertEqual(state.records["Acer"]!.clearedCount, 0)
        XCTAssertFalse(state.records["Acer"]!.hasBloomed)
        XCTAssertEqual(state.records["Acer"]!.practiceAccuracy.count, 3)
        state.records["Acer"] = record()
        let due = state.records["Acer"]!.nextReviewAt
        state.answer(plant: "Acer", mode: .latin2family, correct: true, date: due!, review: .deferred)
        XCTAssertEqual(state.records["Acer"]!.nextReviewAt, due)
        XCTAssertEqual(state.records["Acer"]!.reviewStage, 0)
        XCTAssertNotNil(state.records["Acer"]!.relearnedAt)
    }
    func testNoDecayBeforeDeadlineAndActualCycleWindow() {
        let r = record(stage: 6), due = r.nextReviewAt!
        XCTAssertEqual(ReviewEngine.freshness(r, at: due.addingTimeInterval(-1)), 1)
        XCTAssertEqual(ReviewEngine.severity(r, at: due.addingTimeInterval(15 * day)), 0.5, accuracy: 0.000001)
        let short = record()
        XCTAssertEqual(ReviewEngine.severity(short, at: short.nextReviewAt!.addingTimeInterval(day)), 0.5)
        XCTAssertTrue(short.hasBloomed)
    }
    func testWrongRecoveryAtEveryStage() {
        let expected: [Double] = [1,1,2,5,10.5,22,45]
        for stage in 0...6 {
            var r = record(stage: stage); let now = r.nextReviewAt!.addingTimeInterval(day * 3)
            ReviewEngine.review(&r, result: .incorrect, at: now)
            XCTAssertEqual(r.reviewStage, max(0, stage-1))
            XCTAssertEqual(r.nextReviewAt!.timeIntervalSince(now), expected[stage] * day)
            XCTAssertEqual(ReviewEngine.freshness(r, at: now), 1)
        }
    }
    func testCloseUsesSameFullStageInterval() {
        var r = record(stage: 4); let now = r.nextReviewAt!
        ReviewEngine.review(&r, result: .partial, at: now)
        XCTAssertEqual(r.reviewStage, 4)
        XCTAssertEqual(r.nextReviewAt!.timeIntervalSince(now), 30 * day)
    }
    func testEarlyBonusOnlyOncePerStageAndCloseDoesNothing() {
        var r = record(stage: 2); let now = start.addingTimeInterval(day)
        let due = r.nextReviewAt!
        ReviewEngine.review(&r, result: .correct, at: now)
        XCTAssertEqual(r.nextReviewAt!.timeIntervalSince(due), 0.6 * day, accuracy: 0.000001)
        let extended = r.nextReviewAt
        ReviewEngine.review(&r, result: .correct, at: now.addingTimeInterval(3600))
        ReviewEngine.review(&r, result: .partial, at: now.addingTimeInterval(7200))
        XCTAssertEqual(r.nextReviewAt, extended)
        XCTAssertEqual(r.reviewStage, 2)
        ReviewEngine.review(&r, result: .correct, at: extended!)
        XCTAssertEqual(r.reviewStage, 3); XCTAssertNil(r.earlyBonusStage)
    }
    func testEarlyWrongNeverPostpones() {
        var r = record(stage: 6); let due = r.nextReviewAt!
        ReviewEngine.review(&r, result: .incorrect, at: due.addingTimeInterval(-day))
        XCTAssertEqual(r.nextReviewAt, due); XCTAssertEqual(r.reviewStage, 5)
    }
    func testProtectionEightHoursAndTwentyFourHours() {
        let one = record(), long = record(stage: 3)
        XCTAssertFalse(ReviewEngine.protected(one, at: one.nextReviewAt!.addingTimeInterval(-8 * 3600 - 1)))
        XCTAssertTrue(ReviewEngine.protected(one, at: one.nextReviewAt!.addingTimeInterval(-8 * 3600)))
        XCTAssertTrue(ReviewEngine.protected(long, at: long.nextReviewAt!.addingTimeInterval(-day)))
    }
    func testRelearnGenusWideLockPreservesEverythingUntil24Hours() {
        var r = record(stage: 3); let now = r.nextReviewAt!.addingTimeInterval(day)
        ReviewEngine.expose(&r, modes: [.latin2family], at: now)
        XCTAssertFalse(ReviewEngine.recallAllowed(r, mode: .jp2latin, at: now))
        let due = r.nextReviewAt, last = r.lastFormalReviewAt, severity = ReviewEngine.severity(r, at: now)
        for result in [ReviewResult.correct, .partial, .incorrect] { ReviewEngine.review(&r, result: result, at: now) }
        XCTAssertEqual(r.nextReviewAt, due); XCTAssertEqual(r.lastFormalReviewAt, last)
        XCTAssertEqual(ReviewEngine.severity(r, at: now), severity)
        ReviewEngine.review(&r, result: .correct, at: now.addingTimeInterval(day))
        XCTAssertEqual(r.reviewStage, 4)
    }
    func testViewingOutsideProtectionDoesNotLockAndFormalFeedbackDoesNotLock() {
        var r = record(stage: 4)
        ReviewEngine.expose(&r, modes: QuizMode.core, at: start)
        XCTAssertNil(r.relearnedAt)
        var state = AppState(); state.records["Acer"] = r
        state.answer(plant: "Acer", mode: .jp2latin, correct: false, date: r.nextReviewAt!, review: .completed(.incorrect))
        XCTAssertNil(state.records["Acer"]!.relearnedAt)
        XCTAssertEqual(state.records["Acer"]!.reviewAccuracy["jp2latin"]?.total, 1)
    }
    func testRecommendationsEarliestDeadlineExcludeRelearnAndCapFive() {
        var state = AppState(); let now = start.addingTimeInterval(20 * day)
        for i in 0..<8 { var r = record(); r.nextReviewAt = start.addingTimeInterval(Double(i) * day); state.records["P\(i)"] = r }
        state.records["P0"]!.relearnedAt = now
        XCTAssertEqual(ReviewEngine.recommendedIDs(in: state, at: now), ["P1","P2","P3","P4","P5"])
        XCTAssertEqual(ReviewEngine.dueIDs(in: state, at: now).count, 8)
        XCTAssertEqual(ReviewEngine.dueIDs(in: state, at: now.addingTimeInterval(1000 * day)).count, 8)
    }
    func testPhotoBonusExactlyOnceOnActualInterval() {
        var r = record(); let now = r.nextReviewAt!
        ReviewEngine.review(&r, result: .correct, at: now)
        ReviewEngine.photoBonus(&r, at: now)
        XCTAssertEqual(r.nextReviewAt!.timeIntervalSince(now), 3 * day * 1.05, accuracy: 0.00001)
        let due = r.nextReviewAt
        ReviewEngine.photoBonus(&r, at: now.addingTimeInterval(1)); XCTAssertEqual(r.nextReviewAt, due)
    }
    func testMigrationKeepsHistoryAndDoesNotConvertOldCatalogExposure() throws {
        var s = AppState(); s.schemaVersion = 2; var r = record(stage: 4)
        r.favorite = true; r.lastExposure = ["jp2latin": start]
        s.records["Acer"] = r; s.dailyCounts = ["2026-10-01": 24]
        try s.migrateToV2(at: start)
        XCTAssertEqual(s.schemaVersion, 3); XCTAssertNil(s.records["Acer"]!.relearnedAt)
        XCTAssertEqual(s.records["Acer"]!.nextReviewAt, r.nextReviewAt)
        XCTAssertEqual(s.records["Acer"]!.accuracy, r.accuracy)
        XCTAssertTrue(s.records["Acer"]!.favorite); XCTAssertEqual(s.dailyCounts["2026-10-01"], 24)
        let bytes = try JSONEncoder().encode(s); try s.migrateToV2(at: start.addingTimeInterval(day))
        let copy = try JSONDecoder().decode(AppState.self, from: bytes)
        XCTAssertEqual(copy.records["Acer"]!.nextReviewAt, s.records["Acer"]!.nextReviewAt)
    }
    func testReserveMembershipAndManualAuthoritySurviveCapacity() {
        var s = AppState(); var layout = GardenLayout()
        let area = GardenArea.habitats[0]; layout.unlockedZones.insert(area.id)
        for i in 0..<20 { let id = "P\(i)"; s.records[id] = record(); layout.placements[id] = PlantPlacement(zoneID: area.id, spotID: area.spots[i].id, control: .manual) }
        s.garden.layout = layout; GardenEngine.migrateMembership(&s)
        XCTAssertEqual(s.garden.layout!.memberships!.count, 20)
        XCTAssertEqual(s.garden.layout!.placements.count, Tuning.visibleLimit)
        XCTAssertTrue(s.garden.layout!.memberships!.values.allSatisfy { $0.placementAuthority == .manual && $0.assignedGardenID == area.id })
    }
    func testShortStringsDoNotGetOneCharacterFreePass() {
        XCTAssertEqual(QuizEngine.spell("Acr", "Acer"), 0)
        XCTAssertEqual(QuizEngine.spell("Hydrange", "Hydrangea"), 0.5)
        XCTAssertEqual(QuizEngine.stripSuffix("科アジサイ科", "科"), "科アジサイ")
    }
    func testSafeBoundaryRequiredForGardenUnlock() throws {
        let bundle = Bundle(for: AppStore.self)
        let data = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "habitatAttributes", withExtension: "json")))
        let attrs = try JSONDecoder().decode([GardenAttribute].self, from: data)
        let map = Dictionary(uniqueKeysWithValues: attrs.map { ($0.latin, $0) })
        var s = AppState(); s.garden.layout = GardenLayout()
        for a in attrs { s.records[a.latin] = record() }
        GardenEngine.reconcile(&s, attributes: map, at: start)
        XCTAssertTrue(s.garden.layout!.unlockedZones.isEmpty)
        XCTAssertFalse(s.garden.layout!.pendingUnlocks!.isEmpty)
        GardenEngine.reconcile(&s, attributes: map, at: start, safeBoundary: true)
        XCTAssertEqual(s.garden.layout!.unlockedZones.count, 1)
    }
}
