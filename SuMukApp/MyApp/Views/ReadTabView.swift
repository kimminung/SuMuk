import SwiftUI
import UIKit
import PhotosUI

/// 읽기 탭 — photo → Vision contours → Fourier → family script, with overlay preview.
struct ReadTabView: View {
    @Environment(EditorModel.self) private var model
    @Binding var selectedTab: Int

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var contours: [ExtractedContour] = []
    @State private var aspect: Double = 1
    @State private var selected: Set<Int> = []
    @State private var harmonics = 16
    @State private var mode: ContourStructurer.Mode = .chords
    @State private var darkOnLight = true
    @State private var preview: RenderedArtwork?
    @State private var script = ""
    @State private var meanError = 0.0
    @State private var status = "사진이나 손그림을 고르면 윤곽을 찾아 수식으로 바꿉니다."
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    previewArea
                    controls
                    if !script.isEmpty { scriptPreview }
                }
                .padding()
            }
            .navigationTitle("읽기 · 사진 → 수식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pickerItem, matching: .images) { Label("사진", systemImage: "photo") }
                        .accessibilityLabel("사진 고르기")
                }
            }
            .onChange(of: pickerItem) { _, item in Task { await load(item) } }
            .onChange(of: harmonics) { _, _ in regenerate() }
            .onChange(of: mode) { _, _ in regenerate() }
            .onChange(of: selected) { _, _ in regenerate() }
            .onChange(of: darkOnLight) { _, _ in Task { await extract() } }
        }
    }

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
            if let image {
                Image(uiImage: image).resizable().scaledToFit().opacity(preview == nil ? 1 : 0.5)
            }
            if let preview {
                // same aspect as the photo and no padding, so the overlay lands exactly on the photo
                FamilyCanvasView(artwork: preview, paper: .clear, padding: 0).aspectRatio(aspect, contentMode: .fit)
            }
            if image == nil {
                ContentUnavailableView("사진 없음", systemImage: "photo.on.rectangle.angled", description: Text(status))
            }
            if busy { ProgressView().controlSize(.large) }
        }
        .frame(height: 360)
        .overlay(alignment: .bottomLeading) {
            if image != nil {
                Text(status).font(.caption2).padding(6).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6)).padding(6)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !contours.isEmpty {
                Text("윤곽 선택 (면적 순)").font(.subheadline.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(contours) { c in
                            let on = selected.contains(c.id)
                            Button {
                                if on { selected.remove(c.id) } else { selected.insert(c.id) }
                            } label: {
                                Text("#\(c.id) · \(c.points.count)점")
                                    .font(.caption.monospacedDigit())
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(on ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                                    .overlay(Capsule().stroke(on ? Color.accentColor : .clear))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("윤곽 \(c.id), 점 \(c.points.count)개")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            Picker("변환", selection: $mode) {
                ForEach(ContourStructurer.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("조화 \(harmonics)").font(.caption.monospacedDigit()).frame(width: 64, alignment: .leading)
                Slider(value: Binding(get: { Double(harmonics) }, set: { harmonics = Int($0) }), in: 2...64, step: 1)
                    .accessibilityLabel("푸리에 조화 수").accessibilityValue("\(harmonics)")
            }
            Toggle("어두운 윤곽 (밝은 배경)", isOn: $darkOnLight).font(.subheadline)
            Button {
                model.replaceScript(script)
                selectedTab = 0
            } label: {
                Label("스크립트로 열기", systemImage: "pencil.and.outline").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(script.isEmpty)
        }
    }

    private var scriptPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("결과 스크립트").font(.subheadline.bold())
                Spacer()
                Text(String(format: "평균 오차 %.2f%% · %d자", meanError * 50, script.count)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(script.prefix(1200) + (script.count > 1200 ? "\n…" : ""))
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - pipeline

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else { return }
        image = ui
        await extract()
    }

    private func extract() async {
        guard let cg = image?.cgImage else { return }
        busy = true; defer { busy = false }
        let start = Date()
        var options = ContourStructurer.Options(); options.detectsDarkOnLight = darkOnLight
        let result = await Task.detached(priority: .userInitiated) { try? ContourStructurer.extractContours(from: cg, options: options) }.value
        guard let result else { status = "윤곽을 찾지 못했습니다"; return }
        contours = result.contours; aspect = result.aspect
        selected = Set(contours.prefix(1).map(\.id))
        status = String(format: "윤곽 %d개 · %.0f ms", contours.count, Date().timeIntervalSince(start) * 1000)
        regenerate()
    }

    private func regenerate() {
        let chosen = contours.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { script = ""; preview = nil; return }
        let n = harmonics, m = mode, a = aspect
        Task {
            let out = await Task.detached(priority: .userInitiated) { () -> (String, Double, RenderedArtwork?) in
                let (s, err) = ContourStructurer.script(for: chosen, aspect: a, harmonics: n, mode: m)
                let rendered = (try? FamilyParser.parse(s)).flatMap { try? FamilyEvaluator.evaluate($0) }
                return (s, err, rendered)
            }.value
            script = out.0; meanError = out.1; preview = out.2
        }
    }
}
