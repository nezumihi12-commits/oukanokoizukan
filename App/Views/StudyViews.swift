import SwiftUI

struct StudyHome: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode = QuizMode.latin2family
    @State private var target = QuizTarget.all
    @State private var from = 1
    @State private var to = 5
    @State private var count = 20
    @State private var practiceLaunch: ReviewLaunch?
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                HStack(spacing: 24) {
                    ZStack {
                        Circle().stroke(.green.opacity(0.15), lineWidth: 9)
                        Circle().trim(from: 0, to: CGFloat(store.memorized) / CGFloat(max(1, store.plants.count))).stroke(.green, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack { Text("\(store.memorized)").font(.largeTitle.bold()); Text("/ \(store.plants.count) 属").font(.caption) }
                    }.frame(width: 108, height: 108).accessibilityLabel("記憶済み \(store.memorized) 属")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("学びを、ひとつずつ。 ").font(.headline)
                        Text("写真登録 \(store.photographed) 属")
                        TimelineView(.periodic(from: .now, by: 30)) { _ in Text("今日の回答 \(store.today) 問") }
                    }.font(.subheadline)
                }.padding(.vertical, 8)
            }
            Section("練習を選ぶ") {
                Picker("出題形式", selection: $mode) { ForEach(QuizMode.allCases) { Text($0.title).tag($0) } }
                Picker("対象", selection: $target) { ForEach(QuizTarget.allCases) { Text($0.rawValue).tag($0) } }
                if target == .range {
                    Stepper("開始：\(from)  \(store.plants[from - 1].latin)", value: $from, in: 1...store.plants.count)
                    Stepper("終了：\(to)  \(store.plants[to - 1].latin)", value: $to, in: from...max(from, store.plants.count))
                }
                Picker("問題数", selection: $count) { Text("1問").tag(1); Text("5問").tag(5); Text("20問").tag(20) }
                Button(action: start) { Label("練習を始める", systemImage: "play.fill").frame(maxWidth: .infinity).padding(6) }.buttonStyle(.borderedProminent)
            }
            Section("判定について") {
                Text("3つの基本形式すべてで1回以上正解すると初開花。中央庭園に植物が現れ、翌日から復習が始まります。苦手・習熟度の集計はこれまでと同じです。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("花図鑑")
        .onAppear { from = max(1, min(store.plants.count, store.state.rangeFrom)); to = max(from, min(store.plants.count, store.state.rangeTo)) }
        .onChange(of: from) { _, value in if to < value { to = value } }
        .fullScreenCover(item: $practiceLaunch) { session in NavigationStack { QuizView(questions: session.questions, mode: mode) }.environmentObject(store) }
        .alert("出題対象", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
    private func start() {
        var pool = QuizEngine.pool(plants: store.plants, state: store.state, target: target, from: from, to: to)
        if mode == .photo { pool = pool.filter { !(store.state.photos[$0.id] ?? []).isEmpty } }
        guard !pool.isEmpty else { message = "条件に合う属がありません。対象を変更するか、写真を登録してください。"; return }
        guard store.update({ $0.rangeFrom = from; $0.rangeTo = to }) else { return }
        let questions = pool.shuffled().prefix(count).map {
            QuizEngine.question($0, mode: mode == .mixed ? QuizMode.core.randomElement()! : mode, all: store.plants, japanese: store.japanese)
        }
        practiceLaunch = ReviewLaunch(questions: questions)
    }
}

struct QuizView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let questions: [Question]
    let mode: QuizMode
    var gardenReview = false
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
    @State private var reviewScores: [Double] = []
    @State private var bloomPlant: Plant?
    @State private var reviewedPlant: Plant?
    @FocusState private var focused: Int?
    private var question: Question { questions[index] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if ended {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 58)).foregroundStyle(.green)
                    Text("\(answered)問、お疲れさまでした").font(.title.bold())
                    Text("完全正解 \(correct) 問 ／ \(points, specifier: "%.1f") 点")
                    Text("今日の回答：\(store.today) 問")
                    Button("学習画面へ") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    ProgressView(value: Double(index), total: Double(questions.count))
                    Text("\(index + 1) / \(questions.count)　\(question.mode.title)").font(.subheadline).foregroundStyle(.secondary)
                    if gardenReview { Text("庭の手入れ：\(index / 3 + 1) / \(questions.count / 3) 属 · 基本3形式で復習").font(.caption).foregroundStyle(.secondary) }
                    Text(question.prompt).font(.largeTitle.bold()).textSelection(.enabled)
                    if let photos = store.state.photos[question.plant.id], !photos.isEmpty {
                        PhotoStrip(photos: photos, concealMetadata: true)
                    }
                    if hint || question.mode == .family2genus || question.mode == .latin2jp { Text(question.hint).font(.footnote).foregroundStyle(.secondary) }
                    else { Button("ヒントを見る") { hint = true } }
                    ForEach(Array(question.fields.enumerated()), id: \.offset) { i, field in
                        VStack(alignment: .leading) {
                            Text(field.label).font(.headline)
                            TextField("回答を入力", text: $values[i], axis: .vertical)
                                .textFieldStyle(.roundedBorder).lineLimit(1...8)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: i).disabled(grade != nil)
                        }
                    }
                    if let grade {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(grade.fullCorrect ? "正解！" : grade.points > 0 ? "部分正解" : "もう一度覚えよう").font(.title2.bold())
                            ForEach(Array(grade.feedback.enumerated()), id: \.offset) { _, text in Text(text) }
                            Text("\(grade.points, specifier: "%.2f") / 1 点")
                            Text(question.plant.note).font(.footnote)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        if let reviewedPlant, let record = store.state.records[reviewedPlant.id] {
                            HStack {
                                MemoryPlantView(definition: store.renderDefinition(for: reviewedPlant.id), freshness: ReviewEngine.freshness(record, at: Date())).frame(width: 70, height: 85)
                                VStack(alignment: .leading) {
                                    Text("記憶の色彩を更新しました").font(.headline)
                                    Text("Stage \(record.reviewStage) · \(MemoryAppearance.of(ReviewEngine.freshness(record, at: Date())).rawValue)").font(.caption)
                                    if let next = record.nextReviewAt { Text("次回：\(next.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                                }
                            }
                        }
                    }
                    Button(grade == nil ? "答え合わせ" : index + 1 == questions.count ? "結果を見る" : "次の問題") { action() }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                }
            }.padding(24)
        }
        .navigationTitle(ended ? "練習結果" : gardenReview ? "庭の手入れ" : "練習")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if !ended { ToolbarItem(placement: .cancellationAction) { Button("終了") { confirmExit = true } } } }
        .confirmationDialog("練習を終了しますか？回答済みの成績は保存されます。", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("終了する", role: .destructive) { if finish(completed: false) { dismiss() } }
        }
        .interactiveDismissDisabled()
        .sheet(item: $bloomPlant) { plant in
            BloomCelebration(plant: plant, definition: store.renderDefinition(for: plant.id))
        }
        .alert("保存のお知らせ", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private func action() {
        focused = nil
        if grade == nil {
            let result = QuizEngine.grade(question, values: values)
            let wasBloomed = store.state.records[question.plant.id]?.hasBloomed == true
            let scores = reviewScores + [result.points]
            let completedPlant = gardenReview && index % 3 == 2
            let policy: ReviewPolicy = gardenReview ? (completedPlant ? .completed(ReviewEngine.result(for: scores)) : .deferred) : .automatic
            guard store.record(question, grade: result, review: policy) else { return }
            if gardenReview { reviewScores = completedPlant ? [] : scores }
            if !wasBloomed && store.state.records[question.plant.id]?.hasBloomed == true { bloomPlant = question.plant }
            if wasBloomed && (completedPlant || (!gardenReview && QuizMode.core.contains(question.mode))) { reviewedPlant = question.plant }
            grade = result; answered += 1; points += result.points
            if result.fullCorrect { correct += 1 }
        } else if index + 1 == questions.count {
            if finish(completed: true) { ended = true }
        } else { index += 1; values = ["", ""]; grade = nil; hint = false; reviewedPlant = nil }
    }
    private func finish(completed: Bool) -> Bool {
        guard !sessionSaved, answered > 0 else { return true }
        let session = SessionRecord(startedAt: startedAt, endedAt: Date(), mode: mode, answered: answered, planned: questions.count, correct: correct, points: points, completed: completed, gardenReview: gardenReview)
        let saved = store.update { $0.sessions.insert(session, at: 0) }
        sessionSaved = saved
        return saved
    }
}
