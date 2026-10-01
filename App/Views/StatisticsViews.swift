import SwiftUI
import UniformTypeIdentifiers

struct AccuracyRow: View {
    let title: String
    let accuracy: Accuracy
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(accuracy.total == 0 ? "未出題" : "\(Int(accuracy.rate * 100))% (\(accuracy.correct)/\(accuracy.total))").font(.caption).monospacedDigit()
            }
            ProgressView(value: accuracy.rate)
        }.padding(.vertical, 4)
    }
}
struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportURL: URL?
    @State private var busy = false
    @State private var importFile = false
    @State private var pendingBackup: BackupArchive?
    var body: some View {
        List {
            Section("学習の歩み") {
                LabeledContent("記憶済み", value: "\(store.memorized) / \(store.plants.count) 属")
                LabeledContent("開花実績", value: "\(store.bloomed) 属")
                LabeledContent("苦手", value: "\(store.weak) 属")
                LabeledContent("写真登録", value: "\(store.photographed) 属")
                TimelineView(.periodic(from: .now, by: 30)) { _ in LabeledContent("今日の回答", value: "\(store.today) 問") }
            }
            Section("正式復習の正答率（v1以降）") {
                ForEach(QuizMode.core) { mode in AccuracyRow(title: mode.title, accuracy: purposeAggregate(mode, review: true)) }
            }
            Section("演習の正答率（v1以降）") {
                ForEach(QuizMode.core) { mode in AccuracyRow(title: mode.title, accuracy: purposeAggregate(mode, review: false)) }
            }
            Section("総合正答率（旧記録を含む）") {
                ForEach(QuizMode.allCases.filter { $0 != .mixed }) { mode in
                    AccuracyRow(title: mode.title, accuracy: aggregate(mode))
                }
            }
            Section("最近の確定回答（v1以降）") {
                let answers = store.state.records.flatMap { id, record in record.answerHistory.map { (id, $0) } }.sorted { $0.1.date > $1.1.date }
                ForEach(Array(answers.prefix(50).enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading) {
                        Text(item.0 + " · " + (item.1.purpose == .review ? "正式復習" : item.1.purpose == .practice ? "演習" : "咲かせる"))
                        Text(item.1.mode.title + " · " + (item.1.result == .correct ? "正解" : item.1.result == .partial ? "惜しい" : "不正解")).font(.caption)
                        Text(item.1.date.formatted()).font(.caption2)
                    }
                }
            }
            Section("セッション履歴（旧記録を含む）") {
                if store.state.sessions.isEmpty { Text("練習を終了すると履歴が表示されます。").foregroundStyle(.secondary) }
                ForEach(store.state.sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        Text(session.gardenReview == true ? "庭の手入れ" : session.mode.title).font(.subheadline)
                        Text("\(session.answered)/\(session.planned)問 · 正解\(session.correct)問 · \(session.points, specifier: "%.1f")点 · \(Int(session.endedAt.timeIntervalSince(session.startedAt)))秒").font(.caption)
                        if !session.completed { Text("途中終了").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 3)
                }
            }
            Section {
                Button("写真を含むバックアップを作成") {
                    busy = true
                    Task {
                        defer { busy = false }
                        do { exportURL = try await store.exportBackup() }
                        catch { store.error = "バックアップに失敗しました。\(error.localizedDescription)" }
                    }
                }.disabled(busy)
                Button("バックアップを復元") { importFile = true }.disabled(busy)
                Button("学習データを書き出す") {
                    do { exportURL = try store.exportProgress() }
                    catch { store.error = "書き出しに失敗しました。\(error.localizedDescription)" }
                }
                if let exportURL { ShareLink("JSONを共有・保存", item: exportURL) }
                if busy { ProgressView("データを準備しています…") }
                Text("写真込みのバックアップは別の場所に保存してください。「学習データ」のみの書き出しは画像を含まず、復元には使えません。どちらも位置情報を含みます。").font(.caption).foregroundStyle(.secondary)
            } header: { Text("端末内データ") }
        }.navigationTitle("記録")
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                busy = true
                Task {
                    defer { busy = false }
                    do { pendingBackup = try await store.readBackup(url) }
                    catch { store.error = "復元データを読めません。\(error.localizedDescription)" }
                }
            case .failure(let error): store.error = error.localizedDescription
            }
        }
        .confirmationDialog("現在の学習記録と写真をバックアップの内容で置き換えます。先に現在のバックアップを保存してください。", isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }), titleVisibility: .visible) {
            Button("置き換えて復元", role: .destructive) {
                if let backup = pendingBackup {
                    do { try store.restore(backup) }
                    catch { store.error = "復元できませんでした。\(error.localizedDescription)" }
                }
                pendingBackup = nil
            }
        }
    }
    private func purposeAggregate(_ mode: QuizMode, review: Bool) -> Accuracy {
        store.state.records.values.reduce(into: Accuracy()) { result, record in
            let a = (review ? record.reviewAccuracy : record.practiceAccuracy)[mode.rawValue] ?? Accuracy()
            result.correct += a.correct; result.total += a.total
        }
    }
    private func aggregate(_ mode: QuizMode) -> Accuracy {
        store.state.records.values.reduce(Accuracy()) { total, record in
            let value = record.accuracy[mode.rawValue] ?? Accuracy()
            return Accuracy(correct: total.correct + value.correct, total: total.total + value.total)
        }
    }
}
