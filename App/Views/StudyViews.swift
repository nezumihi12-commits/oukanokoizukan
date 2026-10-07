import SwiftUI

struct StudyHome: View {
    @EnvironmentObject private var store: AppStore
    var initialStyle: LearningStyle = .bloom
    var selectedPlants: [Plant]? = nil
    @State private var style = LearningStyle.bloom
    @State private var includeProtected = false
    @State private var rapid = false
    @State private var preview: ReviewLaunch?
    @State private var pendingLaunch: ReviewLaunch?
    @State private var target = QuizTarget.all
    @State private var from = 1
    @State private var to = 5
    @State private var count = 5
    @State private var seconds = 10
    @State private var modes = Set(QuizMode.core)
    @State private var launch: ReviewLaunch?
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Text(style.rawValue).font(.largeTitle.bold())
                Text("開花 \(store.bloomed) / \(store.plants.count) 属 · 今日の回答 \(store.today) 問")
                Picker("学び方", selection: $style) { ForEach(LearningStyle.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                Text(style == .bloom ? "未クリアの形式を順番に学びます。3形式そろうと開花します。" : "演習は成績だけを記録します。開花や正式復習の間隔は進めません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("学ぶ範囲") {
                Picker("属数", selection: $count) { ForEach([1,3,5,10,20], id: \.self) { Text("\($0) 属").tag($0) } }.pickerStyle(.wheel).frame(height: 110)
                Picker("対象", selection: $target) { ForEach(QuizTarget.allCases) { Text($0.rawValue).tag($0) } }
                if target == .range && !store.plants.isEmpty {
                    Stepper("開始：\(from)", value: $from, in: 1...store.plants.count)
                    Stepper("終了：\(to)", value: $to, in: from...max(from, store.plants.count))
                }
                if style == .practice {
                    Toggle("即答オプション", isOn: $rapid)
                    Toggle("復習が近い属を含める", isOn: $includeProtected)
                    if includeProtected { Text("保護中に答えを確認すると、正式復習の効果は24時間お休みします。").font(.caption) }
                    Picker("制限時間", selection: $seconds) { ForEach([5,10,15], id: \.self) { Text("\($0) 秒").tag($0) } } }
            }
            Section("回答形式（複数選択）") {
                ForEach(style == .bloom ? QuizMode.core : QuizMode.allCases.filter { $0 != .mixed }) { mode in
                    Toggle(mode.title, isOn: Binding(get: { modes.contains(mode) }, set: { if $0 { modes.insert(mode) } else { modes.remove(mode) } }))
                }
            }
            Section {
                Button("学習を始める", action: start).disabled(modes.isEmpty)
                NavigationLink("庭を手入れする・自由復習") { ReviewQueueView() }
            }
        }.navigationTitle("学習")
        .onAppear { style = initialStyle; from = max(1, min(store.plants.count, store.state.rangeFrom)); to = max(from, min(store.plants.count, store.state.rangeTo)) }
        .onChange(of: from) { _, value in if to < value { to = value } }
        .fullScreenCover(item: $launch) { item in NavigationStack { QuizView(questions: item.questions, mode: .mixed, timeLimit: style == .practice && rapid ? seconds : nil, learning: style == .bloom) }.environmentObject(store) }
        .sheet(item: $preview, onDismiss: { launch = pendingLaunch; pendingLaunch = nil }) { item in
            NavigationStack { StudyPreview(questions: item.questions) { pendingLaunch = item; preview = nil } }
        }
        .alert("出題対象", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
    private func start() {
        let pool = QuizEngine.pool(plants: selectedPlants ?? store.plants, state: store.state, target: target, from: from, to: to).filter { style == .bloom || includeProtected || !store.isProtected($0.id) }
        let questions = LearningPlan.questions(pool: pool, count: count, style: style, modes: modes, state: store.state, all: store.plants, japanese: store.japanese)
        guard !questions.isEmpty else { message = "条件に合う問題がありません。対象・形式を変更するか、写真を登録してください。"; return }
        guard store.update({ $0.rangeFrom = from; $0.rangeTo = to }) else { return }
        if style == .bloom { preview = ReviewLaunch(questions: questions) } else { launch = ReviewLaunch(questions: questions) }
    }
}

struct QuizView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let questions: [Question]
    let mode: QuizMode
    var gardenReview = false
    var timeLimit: Int? = nil
    var learning = false
    @State private var padVisible = true
    @State private var bonus: ReviewLaunch?
    @State private var index = 0
    @State private var values = ["", ""]
    @State private var grade: Grade?
    @State private var hint = false
    @State private var answered = 0
    @State private var correct = 0
    @State private var points = 0.0
    @State private var startedAt = Date()
    @State private var ended = false
    @State private var confirmExit = false
    @State private var sessionSaved = false
    @State private var initialized = false
    @State private var activeField = 0
    @State private var questionStarted = Date()
    @State private var timedOut = false
    @State private var initialClearCounts: [String: Int] = [:]
    @State private var initialFreshness: [String: Double] = [:]
    @State private var cleanModes: [String: Set<QuizMode>] = [:]
    @State private var bloomPlant: Plant?
    @State private var reviewedPlant: Plant?
    @FocusState private var focused: Int?
    private var sessionPlants: [Plant] { questions.map(\.plant).reduce(into: [Plant]()) { result, plant in if !result.contains(plant) { result.append(plant) } } }
    private var question: Question { questions[index] }
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if ended {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 58)).foregroundStyle(.green)
                    Text("\(answered)問、お疲れさまでした").font(.title.bold())
                    Text("完全正解 \(correct) 問 ／ \(points, specifier: "%.1f") 点")
                    Text("今日の回答：\(store.today) 問")
                    ForEach(sessionPlants) { plant in
                        let r = store.state.records[plant.id] ?? StudyRecord()
                        if r.clearedCount > initialClearCounts[plant.id, default: 0] {
                            Text("\(plant.latin)：\(r.hasBloomed ? "開花" : r.clearedCount == 2 ? "成長" : "芽吹き")")
                        } else if r.hasBloomed && ReviewEngine.freshness(r, at: Date()) > initialFreshness[plant.id, default: 1] + 0.01 {
                            Text("\(plant.latin)：記憶の色が戻りました")
                        }
                    }
                    if gardenReview { NavigationLink("もう少し続ける") { CarePreview() }.disabled(store.recommendedPlants(at: Date()).isEmpty) }
                    Button(gardenReview ? "今日はここまで" : "戻る") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    ProgressView(value: Double(index), total: Double(questions.count))
                    Text("\(index + 1) / \(questions.count)　\(question.mode.title)").font(.subheadline).foregroundStyle(.secondary)
                    if gardenReview { Text("庭の手入れ：\(index + 1) / \(questions.count) 属 · 1属1形式").font(.caption).foregroundStyle(.secondary) }
                    Text(question.prompt).font(.largeTitle.bold()).textSelection(.enabled)
                    if question.mode == .photo, let photos = store.state.photos[question.plant.id], !photos.isEmpty {
                        PhotoStrip(photos: photos, concealMetadata: true)
                    }
                    if hint || question.mode == .family2genus || question.mode == .latin2jp { Text(question.hint).font(.footnote).foregroundStyle(.secondary) }
                    else { Button("ヒントを見る") { hint = true; store.expose(question.plant.id, modes: question.mode == .jp2latin ? [.latin2family] : [.jp2latin]); cleanModes[question.plant.id]?.remove(question.mode == .jp2latin ? .latin2family : .jp2latin) } }
                    if timeLimit != nil { TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, Int(context.date.timeIntervalSince(questionStarted)))
                        Text(timeLimit.map { "残り \(max(0, $0 - elapsed)) 秒" } ?? "回答時間 \(elapsed) 秒").font(.caption).monospacedDigit()
                    } }
                    answerInputs
                    if let grade {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(timedOut ? "時間切れ" : grade.fullCorrect ? "正解！" : grade.points > 0 ? "惜しい" : "もう一度覚えよう").font(.title2.bold())
                            Group {
                                ForEach(Array((grade.feedback).enumerated()), id: \.offset) { _, text in Text(text) }
                                Text(question.plant.note).font(.footnote)
                            }
                            Text("\(grade.points, specifier: "%.2f") / 1 点")
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        if let reviewedPlant, let record = store.state.records[reviewedPlant.id] {
                            if gardenReview && !ReviewEngine.isRelearnLocked(record, at: Date()) && !(store.state.photos[reviewedPlant.id] ?? []).isEmpty {
                                NavigationLink("写真問題に挑戦（間隔 +5%）") { PhotoBonusView(plant: reviewedPlant) }
                            }
                            HStack {
                                MemoryPlantView(definition: store.renderDefinition(for: reviewedPlant.id), freshness: ReviewEngine.freshness(record, at: Date())).frame(width: 70, height: 85)
                                VStack(alignment: .leading) {
                                    Text(ReviewEngine.isRelearnLocked(record, at: Date()) ? "確認したばかりのため演習として記録" : "手入れを記録しました").font(.headline)
                                    Text("Stage \(record.reviewStage) · \(MemoryAppearance.of(ReviewEngine.freshness(record, at: Date())).rawValue)").font(.caption)
                                    if let next = record.nextReviewAt { Text("次回：\(next.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                                }
                            }
                        }
                    }
                    if learning, let grade, !grade.fullCorrect {
                        Button("この形式をもう一度確認する") { self.grade = nil; hint = false; resetInputs() }
                    }
                    Button(grade == nil ? "答え合わせ" : index + 1 == questions.count ? "結果を見る" : "次の問題") { action() }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                }
            }.padding(24)
        }
        .onChange(of: activeField) { _, value in withAnimation { proxy.scrollTo(value, anchor: .center) } }
        }
        .safeAreaInset(edge: .bottom) { if !ended && grade == nil && padVisible { answerKeyboard } }
        .navigationTitle(ended ? "練習結果" : gardenReview ? "手入れ" : learning ? "咲かせる" : "演習")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if !ended { ToolbarItem(placement: .cancellationAction) { Button("終了") { confirmExit = true } } } }
        .confirmationDialog("練習を終了しますか？回答済みの成績は保存されます。", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("終了する", role: .destructive) { if finish(completed: false) { dismiss() } }
        }
        .toolbar(.hidden, for: .tabBar)
        .interactiveDismissDisabled()
        .onAppear {
            guard !initialized else { return }; initialized = true
            resetInputs()
            if gardenReview { store.publishCompanion(.studying) }
            for plant in questions.map(\.plant) {
                let r = store.state.records[plant.id] ?? StudyRecord()
                initialClearCounts[plant.id] = r.clearedCount
                initialFreshness[plant.id] = ReviewEngine.freshness(r, at: Date())
            }
            captureRecall()
        }
        .onDisappear { if gardenReview { store.publishCompanion() } }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { now in
            if let timeLimit, !ended, grade == nil, !confirmExit, bloomPlant == nil, now.timeIntervalSince(questionStarted) >= Double(timeLimit) {
                timedOut = true; action()
            }
        }
        .sheet(item: $bloomPlant) { plant in
            BloomPlacementView(plant: plant)
        }
        .alert("保存のお知らせ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private var answerInputs: some View {
        VStack(spacing: 10) {
                    ForEach(0..<inputCount, id: \.self) { i in
                        Button { activeField = i; padVisible = true } label: {
                            HStack {
                                Text(question.mode == .family2genus ? "属名 \(i + 1)" : question.fields[min(i, question.fields.count - 1)].label).font(.caption)
                                Text(i < values.count && !values[i].isEmpty ? values[i] : "タップして入力").frame(maxWidth: .infinity, alignment: .leading)
                                if question.fields[min(i, question.fields.count - 1)].kind == .family { Text("科").foregroundStyle(.secondary) }
                                if question.mode == .latin2jp && store.japanese[question.plant.id]?.suffix == "属" { Text("属").foregroundStyle(.secondary) }
                            }.padding(12).background(activeField == i ? Color.green.opacity(0.12) : Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).disabled(grade != nil).id(i)
                    }

        }
    }
    private var answerKeyboard: some View {
        AnswerPad(text: Binding(get: { activeField < values.count ? values[activeField] : "" }, set: { if activeField < values.count { values[activeField] = $0 } }),
                  latin: question.mode == .family2genus || question.fields[min(activeField, question.fields.count - 1)].kind == .latin,
                  canPrevious: activeField > 0, canNext: activeField + 1 < inputCount,
                  previous: { activeField = max(0, activeField - 1) },
                  next: { if activeField + 1 < inputCount { activeField += 1 } else { padVisible = false } })
    }
    private var inputCount: Int { question.mode == .family2genus ? question.fields[0].answers.count : question.fields.count }
    private func resetInputs() { values = Array(repeating: "", count: max(1, inputCount)); activeField = 0; padVisible = true; questionStarted = Date(); timedOut = false }
    private func captureRecall() {
        guard cleanModes[question.plant.id] == nil else { return }
        let r = store.state.records[question.plant.id] ?? StudyRecord()
        cleanModes[question.plant.id] = Set(QuizMode.core.filter { ReviewEngine.recallAllowed(r, mode: $0, at: Date()) })
    }
    private func action() {
        focused = nil
        if grade == nil {
            let raw = QuizEngine.grade(question, values: question.mode == .family2genus ? [values.joined(separator: " ")] : values)
            let result = timedOut ? Grade(points: 0, fullCorrect: false, feedback: raw.feedback.map { "時間切れ・正答：" + $0.components(separatedBy: "：").dropFirst().joined(separator: "：") }) : raw
            let wasBloomed = store.state.records[question.plant.id]?.hasBloomed == true
            let policy: ReviewPolicy = gardenReview ? .completed(ReviewEngine.result(for: [result.points])) : learning ? .automatic : .deferred
            guard store.record(question, grade: result, review: policy) else { return }
            if !wasBloomed && store.state.records[question.plant.id]?.hasBloomed == true { bloomPlant = question.plant }
            if wasBloomed && gardenReview { reviewedPlant = question.plant }
            grade = result; answered += 1; points += result.points
            if result.fullCorrect { correct += 1 }
        } else if index + 1 == questions.count {
            if finish(completed: true) { ended = true }
        } else { index += 1; grade = nil; hint = false; reviewedPlant = nil; resetInputs(); captureRecall() }
    }
    private func finish(completed: Bool) -> Bool {
        guard !sessionSaved, answered > 0 else { return true }
        let session = SessionRecord(startedAt: startedAt, endedAt: Date(), mode: mode, answered: answered, planned: questions.count, correct: correct, points: points, completed: completed, gardenReview: gardenReview)
        let saved = store.update { $0.sessions.insert(session, at: 0) }
        if saved { store.refreshGarden(); if gardenReview { store.publishCompanion(completed ? .completed : nil) } }
        sessionSaved = saved
        return saved
    }
}
