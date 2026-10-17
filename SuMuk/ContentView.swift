import SwiftUI
import SwiftData

/// Root: 그리기(수식 → 그림) · 읽기(사진 → 수식) · 갤러리. Liquid Glass tab bar, vermilion seal tint.
struct ContentView: View {
    @State private var model = EditorModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("그리기", systemImage: "scribble.variable", value: 0) {
                DrawTabView()
            }
            Tab("읽기", systemImage: "photo.on.rectangle.angled", value: 1) {
                ReadTabView(selectedTab: $selectedTab)
            }
            Tab("갤러리", systemImage: "square.grid.2x2", value: 2) {
                GalleryTabView(selectedTab: $selectedTab)
            }
        }
        .tint(.vermilion)
        .environment(model)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedArtwork.self, inMemory: true)
}
