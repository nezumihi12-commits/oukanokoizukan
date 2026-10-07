import XCTest
@testable import Hanazukan

final class CompanionTests: XCTestCase {
    func testDueCountAdvancesWithoutOpeningApp() {
        let now = Date(timeIntervalSince1970: 10000)
        let snapshot = CompanionSnapshot(generatedAt: now, dueDates: [now, now.addingTimeInterval(60)], overdueCount: 0, stateID: .idle)
        XCTAssertEqual(snapshot.count(at: now), 1)
        XCTAssertEqual(snapshot.count(at: now.addingTimeInterval(60)), 2)
        XCTAssertEqual(snapshot.displayState(at: now), .review_due)
    }
    func testTransientStateExpiresAndFallsBackToDue() {
        let now = Date(timeIntervalSince1970: 10000)
        let snapshot = CompanionSnapshot(generatedAt: now, dueDates: [now], overdueCount: 1, stateID: .studying)
        XCTAssertEqual(snapshot.displayState(at: now), .studying)
        XCTAssertEqual(snapshot.displayState(at: now.addingTimeInterval(3601)), .overdue)
    }
    func testSnapshotRoundTripAndStableIDs() throws {
        let snapshot = CompanionSnapshot(generatedAt: Date(), dueDates: [], overdueCount: 0, stateID: .completed)
        let decoded = try JSONDecoder().decode(CompanionSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.stateID.rawValue, "completed")
        XCTAssertEqual(Set(YuukaStateID.allCases.map(\.rawValue)).count, 6)
    }
}
