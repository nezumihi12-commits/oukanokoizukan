import SwiftUI

@main
struct HanazukanApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            Group {
                if store.ready { RootView() }
                else {
                    ContentUnavailableView("データを読み込めません", systemImage: "externaldrive.badge.exclamationmark", description: Text(store.error ?? "アプリを再起動してください。"))
                }
            }
            .environmentObject(store)
            .tint(.green)
            .alert("お知らせ", isPresented: Binding(get: { store.error != nil && store.ready }, set: { if !$0 { store.error = nil } })) {
                Button("閉じる", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { StudyHome() }.tabItem { Label("学習", systemImage: "leaf") }
            NavigationStack { CatalogView() }.tabItem { Label("図鑑", systemImage: "books.vertical") }
            NavigationStack { StatisticsView() }.tabItem { Label("記録", systemImage: "chart.bar") }
            NavigationStack { GardenView() }.tabItem { Label("庭", systemImage: "sun.max") }
        }
    }
}
