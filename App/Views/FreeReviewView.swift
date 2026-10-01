import SwiftUI

struct FreeReviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: Set<String> = []
    @State private var search = ""
    @State private var launch: ReviewLaunch?
    private var plants: [Plant] { store.plants.filter { store.state.records[$0.id]?.hasBloomed == true && $0.matches(search) } }
    var body: some View {
        List {
            Section {
                Text("好きな属を、何件でも復習できます。早い復習や答えを見た直後は、間隔を延ばしません。").font(.footnote)
                Button("選んだ\(selected.count)属を復習") {
                    launch = ReviewLaunch(questions: store.reviewQuestions(for: store.plants.filter { selected.contains($0.id) }))
                }.disabled(selected.isEmpty)
                Button("表示中をすべて選択") { selected.formUnion(plants.map(\.id)) }
                Button("選択解除") { selected.removeAll() }
            }
            ForEach(plants) { plant in
                Toggle(plant.latin, isOn: Binding(get: { selected.contains(plant.id) }, set: { if $0 { selected.insert(plant.id) } else { selected.remove(plant.id) } }))
            }
        }.navigationTitle("自由復習").searchable(text: $search, prompt: "属を検索")
            .fullScreenCover(item: $launch) { session in NavigationStack { QuizView(questions: session.questions, mode: .mixed, gardenReview: true) }.environmentObject(store) }
    }
}
