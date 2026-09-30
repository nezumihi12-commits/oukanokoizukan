import XCTest
import UIKit
@testable import Hanazukan

final class ReviewTests: XCTestCase {
    let origin = Date(timeIntervalSince1970: 1_790_000_000)
    func bloomed() -> StudyRecord {
        var record = StudyRecord()
        record.plantID = "Acer"
        record.clearedLatinToFamily = true
        record.clearedJapaneseToLatin = true
        record.clearedLatinToJapanese = true
        ReviewEngine.bloom(&record, at: origin)
        return record
    }
    func testThreeDistinctFormatsBloomExactlyOnce() {
        var state = AppState()
        state.answer(plant: "Acer", mode: .latin2family, correct: true, date: origin)
        state.answer(plant: "Acer", mode: .latin2family, correct: true, date: origin)
        state.answer(plant: "Acer", mode: .photo, correct: true, date: origin)
        XCTAssertFalse(state.records["Acer"]!.hasBloomed)
        state.answer(plant: "Acer", mode: .jp2latin, correct: true, date: origin)
        state.answer(plant: "Acer", mode: .latin2jp, correct: false, date: origin, points: 0.5)
        XCTAssertFalse(state.records["Acer"]!.hasBloomed)
        state.answer(plant: "Acer", mode: .latin2jp, correct: true, date: origin)
        XCTAssertTrue(state.records["Acer"]!.hasBloomed)
        XCTAssertEqual(state.records["Acer"]!.firstBloomedAt, origin)
        XCTAssertEqual(state.records["Acer"]!.nextReviewAt, origin.addingTimeInterval(86_400))
        XCTAssertEqual(state.garden.unlockedPlants, ["Acer"])
        state.answer(plant: "Acer", mode: .latin2jp, correct: false, date: origin.addingTimeInterval(200_000))
        XCTAssertTrue(state.records["Acer"]!.hasBloomed)
        XCTAssertEqual(state.records["Acer"]!.firstBloomedAt, origin)
    }
    func testStagesReachAndStayAt120Days() {
        var record = bloomed()
        for expected in [1, 2, 3, 4, 5, 6, 6] {
            let now = record.nextReviewAt!
            ReviewEngine.review(&record, result: .correct, at: now)
            XCTAssertEqual(record.reviewStage, expected)
            XCTAssertEqual(record.nextReviewAt!.timeIntervalSince(now), Double(ReviewEngine.intervals[expected]) * 86_400)
        }
    }
    func testEarlyAndSameDayReviewsDoNotFarmStagesOrPostponeDueDate() {
        var record = bloomed()
        let firstDue = record.nextReviewAt
        ReviewEngine.review(&record, result: .correct, at: origin.addingTimeInterval(60))
        XCTAssertEqual(record.reviewStage, 0)
        XCTAssertEqual(record.nextReviewAt, firstDue)
        ReviewEngine.review(&record, result: .correct, at: origin.addingTimeInterval(86_400))
        XCTAssertEqual(record.reviewStage, 0, "24 hours must pass since the most recent review")
        let eligible = origin.addingTimeInterval(2 * 86_400)
        ReviewEngine.review(&record, result: .correct, at: eligible)
        XCTAssertEqual(record.reviewStage, 1)
        let next = record.nextReviewAt
        for i in 1...20 { ReviewEngine.review(&record, result: .correct, at: eligible.addingTimeInterval(Double(i))) }
        XCTAssertEqual(record.reviewStage, 1)
        XCTAssertEqual(record.nextReviewAt, next)
    }
    func testPartialAndFailureRecoverButDoNotExtendStage() {
        var base = bloomed()
        base.reviewStage = 3
        base.nextReviewAt = origin.addingTimeInterval(14 * 86_400)
        let now = origin.addingTimeInterval(60 * 86_400)
        let before = ReviewEngine.freshness(base, at: now)
        var partial = base, wrong = base
        ReviewEngine.review(&partial, result: .partial, at: now)
        ReviewEngine.review(&wrong, result: .incorrect, at: now)
        XCTAssertEqual(partial.reviewStage, 3)
        XCTAssertEqual(wrong.reviewStage, 2)
        XCTAssertEqual(partial.nextReviewAt, now.addingTimeInterval(3 * 86_400))
        XCTAssertEqual(wrong.nextReviewAt, now.addingTimeInterval(86_400))
        XCTAssertGreaterThan(wrong.memoryFreshness, before)
        XCTAssertGreaterThan(partial.memoryFreshness, wrong.memoryFreshness)
        XCTAssertTrue(wrong.hasBloomed)
        XCTAssertEqual(wrong.lastReviewedAt, now)
    }
    func testFreshnessBandsAndClockReversal() {
        var record = bloomed()
        let expected: [MemoryAppearance] = [.vivid, .fading, .sepia, .monochrome, .translucent]
        for i in 0...4 {
            XCTAssertEqual(MemoryAppearance.of(ReviewEngine.freshness(record, at: origin.addingTimeInterval(Double(i) * 86_400))), expected[i])
        }
        ReviewEngine.review(&record, result: .incorrect, at: origin.addingTimeInterval(-500))
        XCTAssertEqual(record.lastReviewedAt, origin)
        XCTAssertEqual(record.memoryFreshness, 1)
        XCTAssertEqual(ReviewEngine.freshness(record, at: origin.addingTimeInterval(-500)), 1)
    }
    func testRecommendationPriorityAndNoFivePlantLimit() {
        var state = AppState()
        let now = origin.addingTimeInterval(10 * 86_400)
        for i in 0..<8 {
            var record = bloomed()
            record.plantID = "P\(i)"
            record.reviewStage = 6
            record.nextReviewAt = origin
            state.records[record.plantID] = record
        }
        state.records["P7"]!.reviewStage = 0 // Closest to forgetting.
        state.records["P6"]!.lastReviewResult = .incorrect
        state.records["P5"]!.nextReviewAt = origin.addingTimeInterval(-86_400)
        let queue = ReviewEngine.dueIDs(in: state, at: now)
        XCTAssertEqual(queue.count, 8)
        XCTAssertEqual(Array(queue.prefix(3)), ["P7", "P6", "P5"])
        XCTAssertEqual(queue.prefix(5).count, 5)
    }
    func testGardenSessionAppliesOnlyOneReviewAfterThreeAnswers() {
        var state = AppState()
        state.records["Acer"] = bloomed()
        let now = origin.addingTimeInterval(86_400)
        state.answer(plant: "Acer", mode: .latin2family, correct: true, date: now, review: .deferred)
        state.answer(plant: "Acer", mode: .jp2latin, correct: true, date: now, review: .deferred)
        XCTAssertEqual(state.records["Acer"]!.lastReviewedAt, origin)
        state.answer(plant: "Acer", mode: .latin2jp, correct: true, date: now, review: .completed(.correct))
        XCTAssertEqual(state.records["Acer"]!.reviewStage, 1)
        XCTAssertEqual(state.records["Acer"]!.lastReviewedAt, now)
        XCTAssertEqual(state.dailyCounts[AppState.dayKey(now)], 3)
        XCTAssertEqual(ReviewEngine.result(for: [1, 1, 1]), .correct)
        XCTAssertEqual(ReviewEngine.result(for: [1, 0.5, 0]), .partial)
        XCTAssertEqual(ReviewEngine.result(for: [1, 0, 0]), .incorrect)
    }
    func testPhotoAndEnumerationDoNotRefreshMemory() {
        var state = AppState()
        state.records["Acer"] = bloomed()
        for mode in [QuizMode.photo, .family2genus] {
            state.answer(plant: "Acer", mode: mode, correct: true, date: origin.addingTimeInterval(200_000))
        }
        XCTAssertEqual(state.records["Acer"]!.lastReviewedAt, origin)
        XCTAssertEqual(state.records["Acer"]!.reviewStage, 0)
    }
    func testV1RecordDecodingAndMigrationIsIdempotent() throws {
        let legacy = Data(#"{"accuracy":{"latin2family":{"correct":1,"total":2},"jp2latin":{"correct":1,"total":1},"latin2jp":{"correct":1,"total":3}}}"#.utf8)
        var state = AppState()
        state.schemaVersion = 1
        state.records["Acer"] = try JSONDecoder().decode(StudyRecord.self, from: legacy)
        state.dailyCounts["2026-09-29"] = 6
        try state.migrateToV2(at: origin)
        XCTAssertEqual(state.schemaVersion, 2)
        XCTAssertTrue(state.records["Acer"]!.hasBloomed)
        XCTAssertEqual(state.records["Acer"]!.plantID, "Acer")
        XCTAssertEqual(state.records["Acer"]!.accuracy["latin2jp"]?.total, 3)
        XCTAssertEqual(state.dailyCounts["2026-09-29"], 6)
        let originalBloom = state.records["Acer"]!.firstBloomedAt
        state.records["Acer"]!.favorite = true
        try state.migrateToV2(at: origin.addingTimeInterval(86_400))
        XCTAssertEqual(state.records["Acer"]!.firstBloomedAt, originalBloom)
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.records["Acer"]!.favorite)
    }
    func testDiskMigrationRetainsOriginalAndNewState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try DiskRepository(directory: directory)
        var state = AppState()
        state.schemaVersion = 1
        let bytes = try JSONEncoder().encode(state)
        try bytes.write(to: repository.stateURL)
        XCTAssertEqual(try repository.load().schemaVersion, 2)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("state-v1-before-v2.json")), bytes)
        XCTAssertEqual(try repository.load().schemaVersion, 2)
    }
    func testRenderDefinitionsCover307AndAssetsExist() throws {
        let bundle = Bundle(for: AppStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "plantRenderDefinitions", withExtension: "json"))
        let catalog = try JSONDecoder().decode(PlantRenderCatalog.self, from: Data(contentsOf: url))
        XCTAssertEqual(catalog.definitions.count, 307)
        for definition in catalog.definitions.values {
            for name in [definition.skeleton, definition.leaf, definition.flower, definition.inflorescence] where name != "none" {
                XCTAssertNotNil(UIImage(named: name, in: bundle, compatibleWith: nil), name)
            }
        }
    }
}
