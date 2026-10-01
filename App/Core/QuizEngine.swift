import Foundation

enum FieldKind { case latin, family, japanese, enumeration }
struct AnswerField {
    let label: String
    let kind: FieldKind
    let answers: [String]
}
struct Question: Identifiable {
    let id = UUID()
    let plant: Plant
    let mode: QuizMode
    let prompt: String
    let hint: String
    let fields: [AnswerField]
}
struct Grade {
    let points: Double
    let fullCorrect: Bool
    let feedback: [String]
}
enum QuizTarget: String, CaseIterable, Identifiable {
    case all = "すべて", range = "番号範囲", weak = "苦手のみ", photo = "写真あり"
    var id: String { rawValue }
}

enum QuizEngine {
    static func pool(plants: [Plant], state: AppState, target: QuizTarget, from: Int, to: Int) -> [Plant] {
        switch target {
        case .all: return plants
        case .range:
            guard !plants.isEmpty else { return [] }
            let lower = max(1, min(plants.count, from))
            let upper = max(lower, min(plants.count, to))
            return Array(plants[(lower - 1)..<upper])
        case .weak: return plants.filter { state.records[$0.id]?.weak == true }
        case .photo: return plants.filter { !(state.photos[$0.id] ?? []).isEmpty }
        }
    }
    static func question(_ g: Plant, mode: QuizMode, all: [Plant], japanese: [String: JapaneseAnswer]) -> Question {
        let jp = japanese[g.id]
        let family = AnswerField(label: "科名（旧科名も可）", kind: .family, answers: [g.family, g.oldFamily].filter { !$0.isEmpty })
        let latin = AnswerField(label: "属名（ラテン語）", kind: .latin, answers: [g.latin])
        switch mode {
        case .family2genus:
            let names = all.filter { $0.family == g.family }.map(\.latin)
            return Question(plant: g, mode: mode, prompt: g.family, hint: "全収録データで \(names.count) 属。空白・改行・読点で区切って入力", fields: [AnswerField(label: "この科の属名をすべて列挙", kind: .enumeration, answers: names)])
        case .jp2latin:
            return Question(plant: g, mode: mode, prompt: jp?.prompt ?? g.jpName, hint: "科名：\(g.family)", fields: [latin])
        case .latin2jp:
            return Question(plant: g, mode: mode, prompt: g.latin, hint: "属和名または登録された代表種名", fields: [AnswerField(label: "和名", kind: .japanese, answers: jp?.answers ?? [g.jpName])])
        case .photo:
            return Question(plant: g, mode: mode, prompt: "写真の植物は？", hint: "属名と科名の両方を答えます", fields: [latin, family])
        default:
            return Question(plant: g, mode: .latin2family, prompt: g.latin, hint: "読み：\(g.read)", fields: [family])
        }
    }
    static func distance(_ left: String, _ right: String) -> Int {
        let a = Array(left), b = Array(right)
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var row = [i + 1]
            for (j, y) in b.enumerated() {
                row.append(min(row[j] + 1, previous[j + 1] + 1, previous[j] + (x == y ? 0 : 1)))
            }
            previous = row
        }
        return previous[b.count]
    }
    static func normalize(_ value: String) -> String {
        let width = value.folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return (width.applyingTransform(.hiraganaToKatakana, reverse: false) ?? width).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    static func spell(_ value: String, _ answer: String) -> Double {
        let a = normalize(value)
        guard !a.isEmpty else { return 0 }
        let b = normalize(answer)
        return a == b ? 1 : distance(a, b) <= Int(Double(b.count) * Tuning.number("review", "close_edit_distance_rate_initial", fallback: 0.2)) ? 0.5 : 0
    }
    static func stripSuffix(_ value: String, _ suffix: String) -> String { value.hasSuffix(suffix) ? String(value.dropLast(suffix.count)) : value }
    static func grade(_ question: Question, values: [String]) -> Grade {
        var points = 0.0
        var feedback: [String] = []
        for (index, field) in question.fields.enumerated() {
            let value = index < values.count ? values[index] : ""
            let score: Double
            switch field.kind {
            case .latin: score = spell(value, field.answers[0])
            case .family, .japanese:
                let suffix = field.kind == .family ? "科" : "属"
                let normalized = stripSuffix(normalize(value), suffix)
                score = field.answers.map { spell(normalized, stripSuffix(normalize($0), suffix)) }.max() ?? 0
            case .enumeration:
                var tokens = Array(Set(normalize(value).components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",、，"))).filter { !$0.isEmpty }))
                var remaining: [String] = []
                var sum = 0.0
                // Consume exact matches first; one token can never satisfy two genera.
                for answer in field.answers {
                    if let i = tokens.firstIndex(where: { spell($0, answer) == 1 }) {
                        sum += 1; tokens.remove(at: i)
                    } else { remaining.append(answer) }
                }
                for answer in remaining {
                    if let i = tokens.firstIndex(where: { spell($0, answer) == 0.5 }) {
                        sum += 0.5; tokens.remove(at: i)
                    }
                }
                score = sum / Double(max(1, field.answers.count))
            }
            points += score
            let label = score == 1 ? "正解" : score > 0 ? "惜しい" : "不正解"
            feedback.append("\(label)：\(field.answers.joined(separator: " / "))")
        }
        let normalized = points / Double(max(1, question.fields.count))
        return Grade(points: normalized, fullCorrect: normalized >= 1 - 0.000001, feedback: feedback)
    }
}
