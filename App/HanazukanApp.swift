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
            .tint(GardenPalette.foliage)
            .alert("お知らせ", isPresented: Binding(get: { store.error != nil && store.ready }, set: { if !$0 { store.error = nil } })) {
                Button("閉じる", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { GardenView() }.tabItem { Label("ホーム", systemImage: "sun.max") }
            NavigationStack { GardenAtlas() }.tabItem { Label("庭園", systemImage: "map") }
            NavigationStack { CatalogView() }.tabItem { Label("図鑑", systemImage: "books.vertical") }
            NavigationStack { StatisticsView() }.tabItem { Label("記録", systemImage: "chart.bar") }
        }
    }
}
