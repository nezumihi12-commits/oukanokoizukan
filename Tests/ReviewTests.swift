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
        XCTAssertEqual(state.schemaVersion, 3)
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
        XCTAssertEqual(try repository.load().schemaVersion, 3)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("state-before-v3.json")), bytes)
        XCTAssertEqual(try repository.load().schemaVersion, 3)
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
