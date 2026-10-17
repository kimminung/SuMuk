import SwiftUI
import UIKit
import SwiftData

/// 갤러리 탭 — paper thumbnails with seal stamps; open back into the editor or delete.
struct GalleryTabView: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedArtwork.createdAt, order: .reverse) private var items: [SavedArtwork]
    @Binding var selectedTab: Int
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: SuMukSpacing.sm)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("저장된 작품 없음", systemImage: "tray")
                    } description: {
                        Text("그리기 탭에서 저장하면 여기에 모입니다.")
                    }
                } else {
                    ScrollView {
                        HStack {
                            Text("\(items.count)개의 수식 작품 보관됨").font(.footnote).foregroundStyle(Color.vermilion)
                            Spacer()
                        }
                        .padding(.horizontal, SuMukSpacing.md)
                        LazyVGrid(columns: columns, spacing: SuMukSpacing.md) {
                            ForEach(items) { item in
                                NavigationLink(value: item.persistentModelID) {
                                    GalleryCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, SuMukSpacing.md)
                        .padding(.bottom, SuMukSpacing.lg)
                    }
                }
            }
            .background(Color.chrome.ignoresSafeArea())
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
        .tint(.vermilion)
    }
}

struct GalleryCell: View {
    let item: SavedArtwork
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = item.thumbnail, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        Color.paper
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: SuMukRadius.thumbnail, style: .continuous))
                SealStampView(text: "墨", size: 24).padding(8)
            }
            .overlay(RoundedRectangle(cornerRadius: SuMukRadius.thumbnail, style: .continuous).stroke(Color.inkDrawing.opacity(0.08), lineWidth: 0.5))
            Text(item.title).font(.headline).foregroundStyle(Color.inkText).lineLimit(1)
            Text("요소 \(item.elementCount) · \(item.createdAt.formatted(date: .numeric, time: .omitted))")
                .font(.suMono(11)).foregroundStyle(Color.inkSoft).lineLimit(1)
        }
        .padding(10)
        .background(Color.paperDeep, in: RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous))
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
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuMukSpacing.md) {
                FamilyCanvasView(artwork: rendered, grain: true)
                    .frame(height: 360)
                    .paperFrame()
                    .overlay {
                        if rendered == nil {
                            VStack(spacing: 8) { ProgressView().controlSize(.large); Text("수식을 다시 그리는 중…").font(.caption).foregroundStyle(Color.inkSoft) }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        StatusCapsuleView(text: "요소 \(item.elementCount.formatted()) · \(item.createdAt.formatted(date: .numeric, time: .omitted))", dot: .celadon).padding(SuMukSpacing.sm)
                    }
                    .overlay(alignment: .bottomTrailing) { SealStampView(size: 40).padding(SuMukSpacing.md) }
                HStack(spacing: SuMukSpacing.sm) {
                    Button { onOpen() } label: { Label("스크립트로 열기", systemImage: "pencil.and.outline") }
                        .buttonStyle(VermilionButtonStyle())
                    ShareLink(item: item.script) { Image(systemName: "square.and.arrow.up") }
                        .buttonStyle(SquareChromeButtonStyle())
                        .accessibilityLabel("스크립트 공유")
                    Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                        .buttonStyle(SquareChromeButtonStyle(tint: .errorInk))
                        .accessibilityLabel("작품 삭제")
                }
                HStack {
                    stat("계열 수", rendered.map { "\($0.families.count)" } ?? "—")
                    stat("요소 수", item.elementCount.formatted())
                    stat("연산 시간", rendered.map { String(format: "%.0f ms", $0.evaluationSeconds * 1000) } ?? "—", tint: .celadon)
                    stat("글자 수", item.script.count.formatted())
                }
                .sectionCard(padding: SuMukSpacing.sm)
                VStack(alignment: .leading, spacing: SuMukSpacing.xs) {
                    CardHeader(icon: "terminal", "수묵 스크립트") {
                        Button {
                            UIPasteboard.general.string = item.script
                            withAnimation { copied = true }
                            Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { copied = false } }
                        } label: {
                            Label(copied ? "복사됨" : "전체 복사", systemImage: copied ? "checkmark" : "doc.on.doc").font(.caption.bold())
                        }
                        .foregroundStyle(Color.inkText)
                        .accessibilityLabel("스크립트 전체 복사")
                    }
                    Text(item.script).font(.suMonoScript).foregroundStyle(Color.inkText).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .sectionCard()
            }
            .padding(SuMukSpacing.md)
        }
        .background(Color.chrome.ignoresSafeArea())
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

    private func stat(_ title: String, _ value: String, tint: Color = .inkText) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(Color.inkSoft)
            Text(value).font(.suMono(13, weight: .bold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
