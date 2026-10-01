import Foundation

enum LearningStyle: String, CaseIterable, Identifiable {
    case bloom = "咲かせる", practice = "演習"
    var id: String { rawValue }
}
enum CatalogField: String, CaseIterable, Identifiable {
    case latin = "属名", family = "科名", japanese = "和名", note = "代表種・備考"
    var id: String { rawValue }
    var exposedModes: [QuizMode] {
        switch self {
        case .latin: return [.jp2latin]
        case .family: return [.latin2family]
        case .japanese, .note: return [.latin2jp]
        }
    }
}
enum LearningPlan {
    static func questions(pool: [Plant], count: Int, style: LearningStyle, modes: Set<QuizMode>, state: AppState,
                          all: [Plant], japanese: [String: JapaneseAnswer]) -> [Question] {
        let candidates = pool.filter { plant in
            if style == .bloom { return QuizMode.core.contains { !(state.records[plant.id]?.cleared($0) ?? false) && modes.contains($0) } }
            return modes.contains { $0 != .mixed && ($0 != .photo || !(state.photos[plant.id] ?? []).isEmpty) }
        }
        return candidates.shuffled().prefix(count).flatMap { plant -> [Question] in
            let record = state.records[plant.id] ?? StudyRecord()
            let available = QuizMode.allCases.filter {
                modes.contains($0) && $0 != .mixed && ($0 != .photo || !(state.photos[plant.id] ?? []).isEmpty)
                    && (style != .bloom || (QuizMode.core.contains($0) && !record.cleared($0)))
            }
            let selected = available
            return selected.map { QuizEngine.question(plant, mode: $0, all: all, japanese: japanese) }
        }
    }
}
