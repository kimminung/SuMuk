import SwiftUI
import SwiftData

@main struct SuMukApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedArtwork.self)
    }
}
