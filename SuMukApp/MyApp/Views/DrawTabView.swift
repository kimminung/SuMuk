import SwiftUI
import UIKit
import SwiftData

/// 그리기 탭 — live preview on top, script editor below, presets drawer, let-sliders, undo/redo, save/share.
struct DrawTabView: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var showPresets = false
    @State private var showSaveDialog = false
    @State private var saveTitle = ""
    @State private var editorHeight: CGFloat = 260
    @State private var savedToast = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                FamilyCanvasView(artwork: model.rendered)
                    .overlay(alignment: .topLeading) { statusChip }
                    .overlay(alignment: .bottom) { errorBanner }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                letSliders
                Divider()
                ScriptEditorView(text: $model.script)
                    .id(model.scriptVersion)
                    .frame(height: editorHeight)
            }
            .background(Color(.systemBackground))
            .navigationTitle("수묵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPresets) {
                PresetDrawerView { preset in
                    model.replaceScript(preset.script)
                    showPresets = false
                }
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
                    Text("갤러리에 저장했습니다").font(.footnote.bold()).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - pieces

    private var statusChip: some View {
        HStack(spacing: 6) {
            if model.isParsing { ProgressView().controlSize(.mini) }
            Text(model.summary).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
        .padding(8)
        .accessibilityLabel("렌더 상태: \(model.summary)")
    }

    @ViewBuilder private var errorBanner: some View {
        if let message = model.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                .padding(10)
                .accessibilityLabel("스크립트 오류: \(message)")
        }
    }

    @ViewBuilder private var letSliders: some View {
        if model.errorMessage == nil, let lets = model.artwork?.lets, !lets.isEmpty {
            VStack(spacing: 4) {
                ForEach(lets) { variable in
                    LetSliderRow(variable: variable)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
        }
    }

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
            } label: { Image(systemName: "tray.and.arrow.down") }
                .disabled(model.artwork == nil)
                .accessibilityLabel("갤러리에 저장")
        }
    }

    private var defaultTitle: String {
        if let first = model.script.split(separator: "\n").first, first.hasPrefix("//") {
            return first.dropFirst(2).trimmingCharacters(in: .whitespaces).components(separatedBy: " —").first ?? "작품"
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
        HStack(spacing: 10) {
            Text(variable.name).font(.caption.monospaced()).frame(width: 56, alignment: .leading)
            // integer-valued lets (e.g. a chord offset δ or a power) step by whole numbers
            let isInteger = variable.value == variable.value.rounded() && variable.range.lowerBound == variable.range.lowerBound.rounded()
                && variable.range.upperBound == variable.range.upperBound.rounded() && (variable.range.upperBound - variable.range.lowerBound) >= 2
            Slider(value: Binding(get: { editing ? local : variable.value }, set: { v in
                let snapped = isInteger ? v.rounded() : v
                local = snapped; model.setLetValue(variable.name, to: snapped, recordUndo: false)
            }), in: variable.range, step: isInteger ? 1 : (variable.range.upperBound - variable.range.lowerBound) / 1000) { started in
                if started { local = variable.value; model.pushUndo() }
                editing = started
            }
            Text(EditorModel.format(editing ? local : variable.value)).font(.caption.monospacedDigit()).frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("변수 \(variable.name)")
        .accessibilityValue(EditorModel.format(variable.value))
    }
}

/// Monospaced script editor with a small math keyboard accessory.
struct ScriptEditorView: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    private let symbols = ["π", "·", "^", "(", ")", "√", "|", "sin(", "cos(", "exp(", "…"]

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 6)
                .accessibilityLabel("SuMuk Script 편집기")
            if focused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(symbols, id: \.self) { s in
                            Button(s) { text.append(s) }
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        }
                        Button("완료") { focused = false }.padding(.horizontal, 10)
                    }
                    .padding(8)
                }
                .background(.bar)
            }
        }
    }
}

struct PresetDrawerView: View {
    let onSelect: (Preset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Presets.all) { preset in
                Button { onSelect(preset) } label: {
                    HStack(spacing: 12) {
                        PresetThumbnail(preset: preset).frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.title).font(.headline)
                            Text(preset.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.title) 프리셋 열기")
            }
            .navigationTitle("프리셋")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

/// Renders a preset once, off the main actor, for the drawer list.
struct PresetThumbnail: View {
    let preset: Preset
    @State private var rendered: RenderedArtwork?

    var body: some View {
        FamilyCanvasView(artwork: rendered)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .task(id: preset.id) {
                let script = preset.script
                rendered = await Task.detached(priority: .utility) {
                    guard let art = try? FamilyParser.parse(script) else { return nil }
                    return try? FamilyEvaluator.evaluate(art)
                }.value
            }
    }
}
