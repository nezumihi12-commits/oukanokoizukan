import SwiftUI

// Learning uses app-owned keys, so IME history and predictive suggestions cannot reveal answers.
struct AnswerPad: View {
    @Binding var text: String
    var latin: Bool
    var previous: () -> Void
    var next: () -> Void
    private let kana = ["あいうえお", "かきくけこ", "さしすせそ", "たちつてと", "なにぬねの", "はひふへほ", "まみむめも", "や ゆ よ", "らりるれろ", "わをんー"]
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Button("↑ 前へ", action: previous)
                Spacer()
                Button("↓ 次へ", action: next)
                Button { if !text.isEmpty { text.removeLast() } } label: { Image(systemName: "delete.left") }.accessibilityLabel("1文字削除")
            }.font(.subheadline)
            if latin {
                ForEach(["qwertyuiop", "asdfghjkl", "zxcvbnm"], id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(Array(row).map(String.init), id: \.self) { key in
                            Button(key) { text += key }.frame(maxWidth: .infinity, minHeight: 40).background(.background, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(kana, id: \.self) { row in
                        FlickKey(characters: row) { text += $0 }
                    }
                    Button("゛゜小") { modifyKana() }.frame(maxWidth: .infinity, minHeight: 46).background(.background, in: RoundedRectangle(cornerRadius: 6))
                    Button("ー") { text += "ー" }.frame(maxWidth: .infinity, minHeight: 46).background(.background, in: RoundedRectangle(cornerRadius: 6))
                }
                Text("中央をタップ、左・上・右・下へフリック。長押しで候補を選択できます。").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(10).background(Color(red: 0.88, green: 0.86, blue: 0.81), in: RoundedRectangle(cornerRadius: 12))
    }
    private func modifyKana() {
        guard let last = text.last else { return }
        let groups = ["あぁ", "いぃ", "うぅゔ", "えぇ", "おぉ", "かが", "きぎ", "くぐ", "けげ", "こご", "さざ", "しじ", "すず", "せぜ", "そぞ", "ただ", "ちぢ", "つっづ", "てで", "とど", "はばぱ", "ひびぴ", "ふぶぷ", "へべぺ", "ほぼぽ", "やゃ", "ゆゅ", "よょ", "わゎ"]
        for group in groups {
            let chars = Array(group)
            if let index = chars.firstIndex(of: last) { text.removeLast(); text.append(chars[(index + 1) % chars.count]); return }
        }
    }
}
private struct FlickKey: View {
    let characters: String
    var insert: (String) -> Void
    private var chars: [String] { Array(characters).map(String.init) }
    var body: some View {
        Text(chars[0]).font(.title3).frame(maxWidth: .infinity, minHeight: 46)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                let t = value.translation
                let index = max(abs(t.width), abs(t.height)) < 15 ? 0 : abs(t.width) > abs(t.height) ? (t.width < 0 ? 1 : 3) : (t.height < 0 ? 2 : 4)
                if index < chars.count && chars[index] != " " { insert(chars[index]) }
            })
            .contextMenu { ForEach(chars.filter { $0 != " " }, id: \.self) { key in Button(key) { insert(key) } } }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(chars.filter { $0 != " " }.joined(separator: "、"))
            .accessibilityAction { insert(chars[0]) }
    }
}
