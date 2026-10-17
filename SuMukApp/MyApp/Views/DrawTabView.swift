import SwiftUI
import UIKit
import SwiftData

/// 그리기 탭 — paper canvas card, dynamic-variable panel, script editor card (Stitch "Literati Ink" / "Ink & Glass").
struct DrawTabView: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var showPresets = false
    @State private var showSaveDialog = false
    @State private var saveTitle = ""
    @State private var savedToast = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: SuMukSpacing.sm) {
                canvasCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                variablePanel
                ScriptEditorCard(text: $model.script)
                    .id(model.scriptVersion)
                    .frame(height: 268)
            }
            .padding(.horizontal, SuMukSpacing.md)
            .padding(.top, SuMukSpacing.xs)
            .padding(.bottom, SuMukSpacing.xs)
            .background(Color.chrome.ignoresSafeArea())
            .navigationTitle("수묵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPresets) {
                PresetDrawerView(currentScript: model.script) { preset in
                    model.replaceScript(preset.script)
                    showPresets = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("갤러리에 저장", isPresented: $showSaveDialog) {
                TextField("제목", text: $saveTitle)
                Button("저장") { save() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("스크립트 원문이 저장되고, 썸네일은 언제든 다시 그려집니다.")
            }
            .overlay(alignment: .top) {
                if savedToast {
                    StatusCapsuleView(text: "갤러리에 저장했습니다", dot: .celadon)
                        .padding(.top, 52)   // below the render-status capsule
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .tint(.vermilion)
    }

    // MARK: - canvas

    private var canvasCard: some View {
        FamilyCanvasView(artwork: model.rendered, grain: true)
            .paperFrame()
            .overlay(alignment: .topLeading) {
                StatusCapsuleView(text: model.summary.isEmpty ? "준비 중" : model.summary, isComputing: model.isParsing,
                                  dot: model.errorMessage == nil ? .vermilion : .errorInk)
                    .padding(SuMukSpacing.sm)
                    .accessibilityLabel("렌더 상태: \(model.summary)")
            }
            .overlay(alignment: .bottomTrailing) {
                SealStampView(size: 34).padding(SuMukSpacing.sm)
            }
            .overlay(alignment: .bottomLeading) {
                if let message = model.errorMessage {
                    MarginErrorBanner(message: message)
                        .padding(SuMukSpacing.sm).padding(.trailing, 56)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.errorMessage)
    }

    // MARK: - variables

    @ViewBuilder private var variablePanel: some View {
        if model.errorMessage == nil, let lets = model.artwork?.lets, !lets.isEmpty {
            VStack(spacing: 6) {
                CardHeader(icon: "slider.horizontal.3", "동적 매개변수") { Text("\(lets.count) 변수 연결됨") }
                ForEach(lets) { variable in
                    LetSliderRow(variable: variable)
                }
            }
            .sectionCard(padding: SuMukSpacing.sm)
        }
    }

    // MARK: - toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo).accessibilityLabel("실행 취소")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo).accessibilityLabel("다시 실행")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showPresets = true } label: { Image(systemName: "square.grid.2x2") }
                .accessibilityLabel("프리셋")
            ShareLink(item: model.script, subject: Text("SuMuk Script")) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("스크립트 공유")
            Button {
                saveTitle = defaultTitle
                showSaveDialog = true
            } label: { Label("인각", systemImage: "tray.and.arrow.down") }
                .buttonStyle(.glassProminent)
                .disabled(model.artwork == nil)
                .accessibilityLabel("갤러리에 저장")
        }
    }

    private var defaultTitle: String {
        if let first = model.script.split(separator: "\n").first, first.hasPrefix("//") {
            let body = first.dropFirst(2).trimmingCharacters(in: .whitespaces)
            let short = body.components(separatedBy: CharacterSet(charactersIn: "—(:")).first?.trimmingCharacters(in: .whitespaces) ?? body
            return short.isEmpty ? "작품" : String(short.prefix(24))
        }
        return "작품"
    }

    private func save() {
        guard let rendered = model.rendered else { return }
        let renderer = ImageRenderer(content: FamilyCanvasView(artwork: rendered).frame(width: 600, height: 600))
        renderer.scale = 1
        let data = renderer.uiImage?.pngData()
        let saved = SavedArtwork(title: saveTitle.isEmpty ? "작품" : saveTitle, script: model.script, elementCount: rendered.elementCount, thumbnail: data)
        context.insert(saved)
        try? context.save()
        withAnimation { savedToast = true }
        Task { try? await Task.sleep(for: .seconds(1.6)); withAnimation { savedToast = false } }
    }
}

/// Slider bound to a `let` variable: drags rewrite the literal in the script (one undo step per drag).
struct LetSliderRow: View {
    @Environment(EditorModel.self) private var model
    let variable: LetVariable
    @State private var local: Double = 0
    @State private var editing = false

    var body: some View {
        let isInteger = variable.value == variable.value.rounded() && variable.range.lowerBound == variable.range.lowerBound.rounded()
            && variable.range.upperBound == variable.range.upperBound.rounded() && (variable.range.upperBound - variable.range.lowerBound) >= 2
        ThemedSliderRow(name: variable.name, value: EditorModel.format(editing ? local : variable.value)) {
            Slider(value: Binding(get: { editing ? local : variable.value }, set: { v in
                let snapped = isInteger ? v.rounded() : v
                local = snapped; model.setLetValue(variable.name, to: snapped, recordUndo: false)
            }), in: variable.range, step: isInteger ? 1 : (variable.range.upperBound - variable.range.lowerBound) / 1000) { started in
                if started { local = variable.value; model.pushUndo() }
                editing = started
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("변수 \(variable.name)")
        .accessibilityValue(EditorModel.format(variable.value))
    }
}

/// Script editor card: header (file name + convergence status), monospaced editor, symbol keys + recompute.
struct ScriptEditorCard: View {
    @Environment(EditorModel.self) private var model
    @Binding var text: String
    @FocusState private var focused: Bool
    private let symbols = ["π", "θ", "δ", "·", "^", "√", "|", "sin(", "cos(", "exp(", "(", ")", "…"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.vermilion)
                Text(model.scriptName).font(.suMono(12, weight: .semibold)).foregroundStyle(Color.inkText).lineLimit(1)
                Spacer()
                statusLabel
                Button { model.reparseNow() } label: {
                    Label("재계산", systemImage: "play.fill").font(.caption.bold()).labelStyle(.titleAndIcon)
                }
                .foregroundStyle(Color.vermilion)
                .accessibilityLabel("수식 다시 계산")
            }
            .padding(.horizontal, SuMukSpacing.sm).padding(.vertical, 10)
            Rectangle().fill(Color.inkWash.opacity(0.6)).frame(height: 0.5)
            TextEditor(text: $text)
                .font(.suMonoScript)
                .lineSpacing(3)
                .foregroundStyle(Color.inkText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 6)
                .accessibilityLabel("SuMuk Script 편집기")
            Rectangle().fill(Color.inkWash.opacity(0.6)).frame(height: 0.5)
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(symbols, id: \.self) { s in
                            Button(s) { text.append(s) }
                                .font(.suMono(13, weight: .medium))
                                .foregroundStyle(Color.inkText)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.inkWash.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityLabel("기호 \(s) 입력")
                        }
                    }
                    .padding(.trailing, 4)
                }
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.92), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
                if focused {
                    Button("완료") { focused = false }.font(.caption.bold()).foregroundStyle(Color.inkText)
                }
            }
            .padding(.horizontal, SuMukSpacing.sm).padding(.vertical, 8)
        }
        .background(Color.paperDeep, in: RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous).stroke(Color.inkWash.opacity(0.6), lineWidth: 0.5))
    }

    @ViewBuilder private var statusLabel: some View {
        if model.isParsing {
            HStack(spacing: 5) { ProgressView().controlSize(.mini); Text("연산 중").font(.suMonoCaption).foregroundStyle(Color.inkSoft) }
        } else if model.errorMessage != nil {
            HStack(spacing: 5) { Circle().fill(Color.errorInk).frame(width: 6, height: 6); Text("오류").font(.suMonoCaption).foregroundStyle(Color.errorInk) }
        } else {
            HStack(spacing: 5) { Circle().fill(Color.celadon).frame(width: 6, height: 6); Text("수렴 연산됨").font(.suMonoCaption).foregroundStyle(Color.inkSoft) }
        }
    }
}

/// 프리셋 서랍 — paper thumbnails with seal, current badge, meta chips.
struct PresetDrawerView: View {
    let currentScript: String
    let onSelect: (Preset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Presets.all) { preset in
                        let isCurrent = preset.script == currentScript
                        Button { onSelect(preset) } label: {
                            HStack(spacing: 14) {
                                PresetThumbnail(preset: preset)
                                    .frame(width: 64, height: 64)
                                    .overlay(alignment: .bottomTrailing) { SealStampView(text: "墨", size: 14).padding(4) }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(preset.title).font(.headline).foregroundStyle(Color.inkText)
                                        if isCurrent {
                                            Text("현재 적용됨").font(.caption2.bold()).foregroundStyle(Color.vermilion)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.vermilion.opacity(0.15), in: Capsule())
                                        }
                                    }
                                    Text(preset.subtitle).font(.footnote).foregroundStyle(Color.inkSoft).lineLimit(2)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: isCurrent ? "checkmark.circle.fill" : "chevron.right")
                                    .font(isCurrent ? .title3 : .caption.bold())
                                    .foregroundStyle(isCurrent ? Color.vermilion : Color.inkSoft)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(preset.title) 프리셋 열기\(isCurrent ? ", 현재 적용됨" : "")")
                    }
                } footer: {
                    Label("프리셋을 선택하면 현재 캔버스에 수식과 렌더링이 즉시 반영됩니다.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.chrome)
            .navigationTitle("프리셋 서랍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
        .tint(.vermilion)
    }
}

/// Renders a preset once, off the main actor, for the drawer list.
struct PresetThumbnail: View {
    let preset: Preset
    @State private var rendered: RenderedArtwork?

    var body: some View {
        FamilyCanvasView(artwork: rendered)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.inkDrawing.opacity(0.08), lineWidth: 0.5))
            .task(id: preset.id) {
                let script = preset.script
                rendered = await Task.detached(priority: .utility) {
                    guard let art = try? FamilyParser.parse(script) else { return nil }
                    return try? FamilyEvaluator.evaluate(art)
                }.value
            }
    }
}
