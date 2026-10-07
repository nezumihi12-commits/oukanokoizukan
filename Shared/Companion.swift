import SwiftUI
import WidgetKit

enum YuukaStateID: String, Codable, CaseIterable {
    case idle, review_due, overdue, studying, completed, struggling
}
struct CompanionSnapshot: Codable {
    var generatedAt: Date
    var dueDates: [Date]
    var overdueCount: Int
    var stateID: YuukaStateID
    func count(at date: Date) -> Int { dueDates.filter { $0 <= date }.count }
    func displayState(at date: Date) -> YuukaStateID {
        if stateID == .studying && date.timeIntervalSince(generatedAt) < 3600 { return .studying }
        if stateID == .completed && date.timeIntervalSince(generatedAt) < 900 { return .completed }
        if overdueCount > 0 { return .overdue }
        return count(at: date) > 0 ? .review_due : .idle
    }
    static let empty = Self(generatedAt: Date(), dueDates: [], overdueCount: 0, stateID: .idle)
}
enum CompanionStorage {
    static let group = "group.io.github.nezumihi12.hanazukan"
    static let key = "companion.snapshot.v1"
    static func load() -> CompanionSnapshot? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CompanionSnapshot.self, from: data)
    }
    static func save(_ snapshot: CompanionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: group)?.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "YuukaReview")
    }
}
// Vector placeholder: replace this view with named assets without changing state IDs.
struct YuukaPortrait: View {
    let state: YuukaStateID
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 160, geometry.size.height / 200)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 38, y: 82))
                    p.addCurve(to: CGPoint(x: 122, y: 82), control1: CGPoint(x: 9, y: -12), control2: CGPoint(x: 155, y: -12))
                    p.addLine(to: CGPoint(x: 115, y: 96))
                    p.addLine(to: CGPoint(x: 134, y: 183))
                    p.addQuadCurve(to: CGPoint(x: 26, y: 183), control: CGPoint(x: 80, y: 209))
                    p.addLine(to: CGPoint(x: 45, y: 96)); p.closeSubpath()
                }.fill(Color(red: 0.12, green: 0.22, blue: 0.19))
                // Face has only a dark red mouth; open mouth is solid.
                if state == .review_due || state == .struggling {
                    Ellipse().fill(Color(red: 0.43, green: 0.08, blue: 0.12))
                        .frame(width: 11, height: 8).position(x: 80, y: 69)
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: 74, y: 68))
                        p.addQuadCurve(to: CGPoint(x: 86, y: 68), control: CGPoint(x: 80, y: state == .completed ? 76 : 70))
                    }.stroke(Color(red: 0.43, green: 0.08, blue: 0.12), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }.frame(width: 160, height: 200).scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.accessibilityLabel("幽香：\(state.rawValue)")
    }
}
