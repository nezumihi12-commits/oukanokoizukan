import XCTest
@testable import Hanazukan

final class CoreTests: XCTestCase {
    let acer = Plant(latin: "Acer", read: "エイサー", family: "ムクロジ科", oldFamily: "カエデ科", jpName: "カエデ属", note: "イロハモミジ")
    func testSpelling() {
        XCTAssertEqual(QuizEngine.spell(" acer ", "Acer"), 1)
        XCTAssertEqual(QuizEngine.spell("Acr", "Acer"), 0.5)
        XCTAssertEqual(QuizEngine.spell("", "Acer"), 0)
        XCTAssertEqual(QuizEngine.spell("Rose", "Acer"), 0)
    }
    func testFamilyAndSuffixes() {
        let q = QuizEngine.question(acer, mode: .latin2family, all: [acer], japanese: [:])
        for answer in ["ムクロジ科", "ムクロジ", "カエデ", "カエデ科"] {
            XCTAssertTrue(QuizEngine.grade(q, values: [answer]).fullCorrect)
        }
        XCTAssertFalse(QuizEngine.grade(q, values: [""]).fullCorrect)
    }
    func testPartialPhotoIsNotFullyCorrect() {
        let q = QuizEngine.question(acer, mode: .photo, all: [acer], japanese: [:])
        let grade = QuizEngine.grade(q, values: ["Acr", "カエデ科"])
        XCTAssertEqual(grade.points, 0.75)
        XCTAssertFalse(grade.fullCorrect)
    }
    func testEnumerationDoesNotReuseTokenOrCountTypoAsFull() {
        let p = Plant(latin: "Acers", read: "", family: acer.family, oldFamily: "", jpName: "", note: "")
        let q = QuizEngine.question(acer, mode: .family2genus, all: [acer, p], japanese: [:])
        XCTAssertEqual(QuizEngine.grade(q, values: ["Acer"]).points, 0.5)
        XCTAssertTrue(QuizEngine.grade(q, values: ["Acer、Acers"]).fullCorrect)
        XCTAssertFalse(QuizEngine.grade(q, values: ["Acer、Acerss"]).fullCorrect)
    }
    func testMeanOfModesAndMemorizedAreDifferent() {
        var record = StudyRecord()
        record.accuracy = ["latin2family": Accuracy(correct: 8, total: 10), "jp2latin": Accuracy(correct: 0, total: 1)]
        XCTAssertEqual(record.average!, 0.4, accuracy: 0.000001)
        XCTAssertTrue(record.weak)
        XCTAssertEqual(record.mastery, 1)
        XCTAssertFalse(record.memorized)
        record.accuracy["jp2latin"] = Accuracy(correct: 1, total: 1)
        record.accuracy["latin2jp"] = Accuracy(correct: 1, total: 1)
        XCTAssertTrue(record.memorized)
        XCTAssertEqual(record.mastery, 3)
        XCTAssertFalse(StudyRecord().weak)
    }
    func testMasteryThresholds() {
        for (correct, expected) in [(0, 0), (3, 1), (6, 2), (8, 3)] {
            var record = StudyRecord()
            record.accuracy["latin2family"] = Accuracy(correct: correct, total: 10)
            XCTAssertEqual(record.mastery, expected)
        }
    }
    func testEmptyFiltersAndRange() {
        XCTAssertTrue(QuizEngine.pool(plants: [acer], state: AppState(), target: .weak, from: 1, to: 1).isEmpty)
        XCTAssertTrue(QuizEngine.pool(plants: [acer], state: AppState(), target: .photo, from: 1, to: 1).isEmpty)
        XCTAssertEqual(QuizEngine.pool(plants: [acer], state: AppState(), target: .range, from: -1, to: 999).count, 1)
    }
    func testMidnightKey() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let date = ISO8601DateFormatter().date(from: "2026-09-29T14:59:59Z")!
        XCTAssertEqual(AppState.dayKey(date, calendar: calendar), "2026-09-29")
        XCTAssertEqual(AppState.dayKey(date.addingTimeInterval(2), calendar: calendar), "2026-09-30")
    }
    func testPersistenceRoundTripAndCorruption() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try DiskRepository(directory: directory)
        var state = try repository.load()
        state.answer(plant: "Acer", mode: .latin2family, correct: true, date: Date())
        try repository.save(state)
        XCTAssertEqual(try repository.load().records["Acer"]?.accuracy["latin2family"]?.correct, 1)
        try Data("broken".utf8).write(to: repository.stateURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try String(contentsOf: repository.stateURL, encoding: .utf8), "broken")
    }
    func testBundledData() throws {
        let bundle = Bundle(for: AppStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "genera", withExtension: "json"))
        let plants = try JSONDecoder().decode([Plant].self, from: Data(contentsOf: url))
        XCTAssertEqual(plants.count, 307)
        XCTAssertEqual(Set(plants.map(\.id)).count, 307)
        XCTAssertTrue(plants[0].matches("abelia"))
        let jpURL = try XCTUnwrap(bundle.url(forResource: "japaneseAnswers", withExtension: "json"))
        let answers = try JSONDecoder().decode([String: JapaneseAnswer].self, from: Data(contentsOf: jpURL))
        for plant in plants {
            for mode in QuizMode.core {
                let q = QuizEngine.question(plant, mode: mode, all: plants, japanese: answers)
                XCTAssertTrue(QuizEngine.grade(q, values: [q.fields[0].answers[0]]).fullCorrect, "\(plant.id): \(mode)")
            }
        }
    }
    func testBackupRejectsUnsafePathsAndUnknownGenera() throws {
        let id = UUID()
        var state = AppState()
        state.rangeTo = 1
        state.photos["Acer"] = [PhotoRecord(id: id, filename: "../state.json", capturedAt: nil, location: nil, addedAt: Date())]
        let invalid = BackupArchive(state: state, images: ["../state.json": Data([1])])
        XCTAssertThrowsError(try invalid.validate(knownPlants: ["Acer"]))
        state.photos = [:]
        state.records["Unknown"] = StudyRecord()
        XCTAssertThrowsError(try BackupArchive(state: state, images: [:]).validate(knownPlants: ["Acer"]))
    }
    func testBackupRoundTripWithPhotoAndLocation() throws {
        let id = UUID()
        let filename = id.uuidString + ".jpg"
        var state = AppState()
        state.rangeTo = 1
        let point = GeoPoint(latitude: 0, longitude: 0, recordedAt: Date(), source: "EXIF")
        state.photos["Acer"] = [PhotoRecord(id: id, filename: filename, capturedAt: nil, location: point, addedAt: Date())]
        let archive = BackupArchive(state: state, images: [filename: Data([1, 2, 3])])
        let decoded = try JSONDecoder().decode(BackupArchive.self, from: JSONEncoder().encode(archive))
        XCTAssertNoThrow(try decoded.validate(knownPlants: ["Acer"]))
        XCTAssertEqual(decoded.images[filename], Data([1, 2, 3]))
    }
}
