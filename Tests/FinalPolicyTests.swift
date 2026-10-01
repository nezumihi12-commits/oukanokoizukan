import XCTest
@testable import Hanazukan

final class FinalPolicyTests: XCTestCase {
    let origin = Date(timeIntervalSince1970: 1_790_000_000)
    func record() -> StudyRecord {
        var value = StudyRecord()
        for mode in QuizMode.core { value.record(mode: mode, correct: true, date: origin) }
        ReviewEngine.bloom(&value, at: origin)
        return value
    }
    func attributes() throws -> [String: GardenAttribute] {
        let url = try XCTUnwrap(Bundle(for: AppStore.self).url(forResource: "habitatAttributes", withExtension: "json"))
        let list = try JSONDecoder().decode([GardenAttribute].self, from: Data(contentsOf: url))
        return Dictionary(uniqueKeysWithValues: list.map { ($0.latin, $0) })
    }
    func testExposureIsFormatSpecificAndUsesElapsedHours() {
        var r = record()
        ReviewEngine.expose(&r, modes: [.latin2family], at: origin)
        XCTAssertFalse(ReviewEngine.recallAllowed(r, mode: .latin2family, at: origin.addingTimeInterval(86_399)))
        XCTAssertTrue(ReviewEngine.recallAllowed(r, mode: .jp2latin, at: origin))
        XCTAssertTrue(ReviewEngine.recallAllowed(r, mode: .latin2family, at: origin.addingTimeInterval(86_400)))
    }
    func testObservationCannotFarmFreshnessOrExtendDueDate() {
        var r = record()
        let now = origin.addingTimeInterval(8 * 86_400)
        let due = r.nextReviewAt
        ReviewEngine.expose(&r, modes: [.latin2family], at: now)
        let freshness = r.memoryFreshness
        for _ in 0..<30 { ReviewEngine.expose(&r, modes: QuizMode.core, at: now) }
        XCTAssertEqual(r.memoryFreshness, freshness)
        XCTAssertEqual(r.nextReviewAt, due)
        ReviewEngine.review(&r, result: .correct, at: now, recallFraction: 0)
        XCTAssertEqual(r.reviewStage, 0)
        XCTAssertEqual(r.nextReviewAt, due)
        XCTAssertLessThan(r.memoryFreshness, 0.2)
    }
    func testUnaffectedAutomaticFormatCanAdvance() {
        var state = AppState(); var r = record()
        let now = origin.addingTimeInterval(2 * 86_400)
        ReviewEngine.expose(&r, modes: [.latin2family], at: now)
        state.records["Acer"] = r
        state.answer(plant: "Acer", mode: .jp2latin, correct: true, date: now)
        XCTAssertEqual(state.records["Acer"]?.reviewStage, 1)
    }
    func testLegacyRecordAndLayoutRoundTrip() throws {
        let old = Data(#"{"accuracy":{},"hasBloomed":false}"#.utf8)
        let r = try JSONDecoder().decode(StudyRecord.self, from: old)
        XCTAssertTrue(r.lastExposure.isEmpty)
        var state = AppState(); state.garden.layout = GardenLayout()
        state.garden.layout?.awaitingDelegation = ["Acer"]
        let copy = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(copy.garden.layout, state.garden.layout)
    }
    func testNormalizationAndDuplicateEnumeration() {
        XCTAssertEqual(QuizEngine.spell(" ＨＹＤＲＡＮＧＥＡ ", "Hydrangea"), 1)
        XCTAssertEqual(QuizEngine.normalize("あじさい"), QuizEngine.normalize("アジサイ"))
        let plant = Plant(latin: "Abelia", read: "", family: "", oldFamily: "", jpName: "", note: "")
        let q = Question(plant: plant, mode: .family2genus, prompt: "", hint: "", fields: [.init(label: "", kind: .enumeration, answers: ["Abelia", "Abeli"] )])
        XCTAssertEqual(QuizEngine.grade(q, values: ["Abelia abelia ＡＢＥＬＩＡ"]).points, 0.5)
    }
    func testBloomPlanOnlyAsksUnclearedFormats() {
        let plant = Plant(latin: "Acer", read: "", family: "ムクロジ科", oldFamily: "", jpName: "カエデ属", note: "")
        var state = AppState()
        state.answer(plant: plant.id, mode: .latin2family, correct: true, date: origin)
        let questions = LearningPlan.questions(pool: [plant], count: 20, style: .bloom, modes: Set(QuizMode.core), state: state, all: [plant], japanese: [:])
        XCTAssertEqual(Set(questions.map(\.mode)), [.jp2latin, .latin2jp])
    }
    func testAquaticCannotEnterDrySpotAndNoOccupantEviction() throws {
        let data = try attributes()
        var layout = GardenLayout()
        let dry = GardenArea.centralAreas[0]
        XCTAssertFalse(GardenEngine.place("Nymphaea", area: dry, spot: dry.spots[0], control: .manual, attributes: data, layout: &layout))
        let water = GardenArea.centralAreas[2]
        XCTAssertTrue(GardenEngine.place("Nymphaea", area: water, spot: water.spots[0], control: .manual, attributes: data, layout: &layout))
        XCTAssertFalse(GardenEngine.place("Nelumbo", area: water, spot: water.spots[0], control: .manual, attributes: data, layout: &layout))
        XCTAssertEqual(layout.placements["Nymphaea"]?.control, .manual)
    }
    func testUnlockPacingAndManualPlacementSurvives() throws {
        let data = try attributes()
        let candidates = data.values.filter { $0.recommendedZones.contains("sunny_border") && $0.habitatScores["sunny_border", default: 0] >= 0.5 }.map(\.latin).sorted()
        var state = AppState(); state.garden.layout = GardenLayout()
        for id in candidates.prefix(9) { state.records[id] = record() }
        GardenEngine.reconcile(&state, attributes: data, at: origin)
        XCTAssertTrue(state.garden.layout!.unlockedZones.isEmpty)
        state.records[candidates[9]] = record()
        GardenEngine.reconcile(&state, attributes: data, at: origin)
        XCTAssertEqual(state.garden.layout!.unlockedZones.count, 1)
        for id in candidates.prefix(17) { state.records[id] = record() }
        GardenEngine.reconcile(&state, attributes: data, at: origin)
        XCTAssertEqual(state.garden.layout!.unlockedZones.count, 1)
        state.records["Acer"] = record()
        let area = GardenArea.centralAreas[5]
        XCTAssertTrue(GardenEngine.place("Acer", area: area, spot: area.spots[0], control: .manual, attributes: data, layout: &state.garden.layout!))
        let previous = state.garden.layout!.placements["Acer"]
        GardenEngine.reconcile(&state, attributes: data, at: origin)
        XCTAssertEqual(state.garden.layout!.placements["Acer"], previous)
    }
    func testAmbiguousGardenPermanentAndDoesNotMovePlants() throws {
        let data = try attributes()
        var state = AppState(); state.garden.layout = GardenLayout()
        for id in ["Acer", "Rosa", "Lilium"] { state.records[id] = record() }
        GardenEngine.reconcile(&state, attributes: data, at: origin.addingTimeInterval(5 * 86_400))
        XCTAssertTrue(state.garden.layout!.ambiguousUnlocked)
        XCTAssertTrue(state.garden.layout!.placements.isEmpty)
        GardenEngine.reconcile(&state, attributes: data, at: origin)
        XCTAssertTrue(state.garden.layout!.ambiguousUnlocked)
    }
    func testImportantNoticesSurviveAmbientCoalescing() {
        var queue: [GardenNotice] = []
        NoticeQueue.enqueue(.init(id: "unlock", priority: 3, systemText: ""), into: &queue)
        for _ in 0..<30 { NoticeQueue.enqueue(.init(id: "density", priority: 1, systemText: ""), into: &queue) }
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.first?.id, "unlock")
    }
    func testRecommendationsIncludeOnlyDueAndNextSixHours() {
        var state = AppState()
        for i in 0..<8 { state.records["P\(i)"] = record() }
        XCTAssertEqual(ReviewEngine.recommendedIDs(in: state, at: origin).count, 0)
        XCTAssertEqual(ReviewEngine.recommendedIDs(in: state, at: origin.addingTimeInterval(20 * 3600)).count, 5)
    }
    func testBackupRejectsDuplicateSpot() throws {
        var layout = GardenLayout()
        let area = GardenArea.centralAreas[5]
        let placement = PlantPlacement(zoneID: area.id, spotID: area.spots[0].id, control: .manual)
        layout.placements = ["Acer": placement, "Abies": placement]
        XCTAssertThrowsError(try GardenEngine.validate(layout, records: ["Acer": record(), "Abies": record()]))
    }
}
