import Foundation
import UserNotifications
import Combine

protocol ReminderScheduling {
    func schedule(hour: Int, minute: Int) async throws
    func cancel()
}
struct LocalReminderService: ReminderScheduling {
    private let identifier = "study.daily"
    func schedule(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
        let content = UNMutableNotificationContent()
        content.title = "花図鑑"
        content.body = "今日の植物を復習しましょう。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
    func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier]) }
}
enum StudyRoute { case home, practice, plant(String) }
protocol StudyActionHandling {
    @MainActor func open(_ route: StudyRoute)
}
// App Intent adapters can call this router; no extension targets or entitlements required yet.
@MainActor
final class StudyRouter: ObservableObject, StudyActionHandling {
    @Published var route: StudyRoute = .home
    func open(_ route: StudyRoute) { self.route = route }
}
enum GardenEvents {
    static func matches(_ condition: EventCondition, state: AppState, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch condition {
        case .memorizedCount(let minimum): return state.records.values.filter(\.memorized).count >= minimum
        case .month(let month): return calendar.component(.month, from: now) == month
        case .daysSinceStudy(let days):
            guard let latest = state.records.values.compactMap(\.lastStudiedAt).max() else { return false }
            return (calendar.dateComponents([.day], from: latest, to: now).day ?? 0) >= days
        }
    }
}
