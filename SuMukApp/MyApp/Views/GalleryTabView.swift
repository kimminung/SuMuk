import SwiftUI
import UIKit
import SwiftData

/// 갤러리 탭 — saved scripts with thumbnails; open back into the editor or delete.
struct GalleryTabView: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedArtwork.createdAt, order: .reverse) private var items: [SavedArtwork]
    @Binding var selectedTab: Int
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("저장된 작품 없음", systemImage: "tray", description: Text("그리기 탭에서 저장하면 여기에 모입니다."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(items) { item in
                                NavigationLink(value: item.persistentModelID) {
                                    GalleryCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("갤러리")
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let item = items.first(where: { $0.persistentModelID == id }) {
                    SavedArtworkDetailView(item: item) {
                        model.replaceScript(item.script)
                        selectedTab = 0
                    } onDelete: {
                        context.delete(item)
                        try? context.save()
                    }
                }
            }
        }
    }
}

struct GalleryCell: View {
    let item: SavedArtwork
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let data = item.thumbnail, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.title).font(.subheadline.bold()).lineLimit(1)
            Text("요소 \(item.elementCount) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), 요소 \(item.elementCount)개")
    }
}

struct SavedArtworkDetailView: View {
    let item: SavedArtwork
    let onOpen: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: RenderedArtwork?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FamilyCanvasView(artwork: rendered).frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    Button { onOpen() } label: { Label("스크립트로 열기", systemImage: "pencil.and.outline").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                    ShareLink(item: item.script) { Label("공유", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                    Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }.buttonStyle(.bordered)
                }
                Text("스크립트").font(.subheadline.bold())
                Text(item.script).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("이 작품을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { onDelete(); dismiss() }
            Button("취소", role: .cancel) {}
        }
        .task {
            let script = item.script
            rendered = await Task.detached { (try? FamilyParser.parse(script)).flatMap { try? FamilyEvaluator.evaluate($0) } }.value
        }
    }
}
