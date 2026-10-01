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
    @State private var selection = 1
    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { CatalogView() }.tabItem { Label("図鑑", systemImage: "books.vertical") }.tag(0)
            NavigationStack { GardenView() }.tabItem { Label("ホーム", systemImage: "sun.max") }.tag(1)
            NavigationStack { GardenAtlas() }.tabItem { Label("庭園", systemImage: "map") }.tag(2)
            NavigationStack { CareHub() }.tabItem { Label("手入れ", systemImage: "drop") }.tag(3)
        }.preferredColorScheme(.light)
    }
}
