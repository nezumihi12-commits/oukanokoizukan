import Foundation

enum AnswerPurpose: String, Codable { case learning, practice, review }
struct AnswerEvent: Codable {
    var date: Date
    var mode: QuizMode
    var purpose: AnswerPurpose
    var result: ReviewResult
}
struct AppPreferences: Codable {
    var notifications = false
    var notificationHour = 19
    var notificationMinute = 0
    var haptics = true
    var reduceMotion = false
    var hiddenFields: Set<String> = []
    var appearanceVariants: [String: String] = [:]
}
// The supplied tuning file is the source of numeric defaults; extra optional keys may be added.
enum Tuning {
    static let data: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "tuning_parameters_v1", withExtension: "json"),
              let bytes = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return [:] }
        return object
    }()
    static func number(_ group: String, _ key: String, fallback: Double) -> Double {
        return ((data[group] as? [String: Any])?[key] as? Double) ?? fallback
    }
    static func severity(_ key: String, fallback: Double) -> Double {
        let values = (data["overdue_visual_state"] as? [String: Any])?["severity"] as? [String: Double]
        return values?[key] ?? fallback
    }
    static func threshold(_ id: String, fallback: Int) -> Int {
        let mapping = ["sunny_border": "sunny_bed", "woodland_shade": "shade", "dry_rock": "rock_garden"]
        let values = (data["garden_unlock"] as? [String: Any])?["base_candidate_thresholds"] as? [String: Int]
        return values?[mapping[id] ?? id] ?? fallback
    }
    static func rangeMidpoint(_ group: String, _ key: String, fallback: Double) -> Double {
        guard let a = (data[group] as? [String: Any])?[key] as? [Double], !a.isEmpty else { return fallback }
        return a.reduce(0, +) / Double(a.count)
    }
    static var intervals: [Int] { (data["review"] as? [String: Any])?["interval_days"] as? [Int] ?? [1,3,7,14,30,60,120] }
    static var visibleLimit: Int { Int(number("garden", "visible_genera_per_garden_nominal", fallback: 15)) }
}

struct AppearanceVariant: Codable, Identifiable {
    var id: String
    var title: String
    var renderDefinition: PlantRenderDefinition
    var minimumPhotoCount: Int
    var sourceNote: String
}
struct AppearanceCatalog: Codable {
    var version: Int
    var variants: [String: [AppearanceVariant]]
}
