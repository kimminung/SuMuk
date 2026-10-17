import SwiftUI
import UIKit
import PhotosUI

/// 읽기 탭 — photo → upscale → subject cut-out → contours → curves (+ dots for tone) → SuMuk Script.
struct ReadTabView: View {
    @Environment(EditorModel.self) private var model
    @Binding var selectedTab: Int

    @State private var pickerItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var prepared: PreparedPhoto?
    @State private var selected: Set<Int> = []
    @State private var harmonics = 16
    @State private var includeCurves = true
    @State private var includeOutlineDots = false
    @State private var outlineDotCount = 300.0
    @State private var includeToneDots = true
    @State private var toneDotCount = 6000.0
    @State private var toneGamma = 1.0
    @State private var darkOnLight = true
    @State private var showCutout = true
    @State private var preview: RenderedArtwork?
    @State private var script = ""
    @State private var meanError = 0.0
    @State private var busy = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    previewArea
                    if prepared != nil { pipelineSteps }
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
            .onChange(of: selected) { _, _ in regenerate() }
            .onChange(of: includeCurves) { _, _ in regenerate() }
            .onChange(of: includeOutlineDots) { _, _ in regenerate() }
            .onChange(of: outlineDotCount) { _, _ in regenerate() }
            .onChange(of: includeToneDots) { _, _ in regenerate() }
            .onChange(of: toneDotCount) { _, _ in regenerate() }
            .onChange(of: toneGamma) { _, _ in regenerate() }
            .onChange(of: darkOnLight) { _, _ in Task { await prepare() } }
        }
    }

    // MARK: - preview

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
            if let prepared, showCutout {
                Image(decorative: prepared.image, scale: 1).resizable().scaledToFit().opacity(preview == nil ? 1 : 0.45)
            } else if let original {
                Image(uiImage: original).resizable().scaledToFit().opacity(preview == nil ? 1 : 0.45)
            }
            if let preview, let prepared {
                FamilyCanvasView(artwork: preview, paper: .clear, padding: 0).aspectRatio(prepared.aspect, contentMode: .fit)
            }
            if original == nil {
                ContentUnavailableView("사진 없음", systemImage: "photo.on.rectangle.angled",
                                       description: Text("사진을 고르면 업스케일 → 누끼 → 윤곽 → 곡선과 점 수식으로 바꿉니다."))
            }
            if busy {
                VStack(spacing: 8) { ProgressView().controlSize(.large); Text("분석 중…").font(.caption) }
                    .padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else if regenerating {
                HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("수식 다시 계산 중…").font(.caption2) }
                    .padding(8).background(.thinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 10)
            }
        }
        .frame(height: 380)
        .overlay(alignment: .topTrailing) {
            if prepared?.subjectFound == true {
                Toggle(isOn: $showCutout) { Text(showCutout ? "누끼" : "원본").font(.caption2) }
                    .toggleStyle(.button).controlSize(.mini).padding(8)
                    .accessibilityLabel("누끼와 원본 전환")
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle").font(.caption2).padding(6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6)).padding(6)
            }
        }
    }

    private var pipelineSteps: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let p = prepared {
                stepRow("1", "업스케일", String(format: "%.1f× → %d × %d", p.upscale, Int(p.size.width), Int(p.size.height)), ms(p, "업스케일"))
                stepRow("2", "누끼", p.subjectFound ? "피사체 분리됨 (배경 흰색)" : "원본 사용 — \(cutoutFailureText(p.subjectError))", ms(p, "누끼"))
                stepRow("3", "윤곽", "\(p.contours.count)개 (실루엣 \(p.contours.filter(\.isSilhouette).count))", ms(p, "윤곽"))
                stepRow("4", "농담", "DCT \(p.darkness.c.count)항 (\(p.darkness.w)×\(p.darkness.h))", ms(p, "농담"))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func cutoutFailureText(_ error: String?) -> String {
        guard let error else { return "피사체 없음" }
        // The foreground-mask model needs the Neural Engine/GPU runtime: it fails on the simulator with
        // "Could not create inference context" but works on a real iPhone.
        if error.contains("inference context") { return "시뮬레이터 미지원 (실기기에서 동작)" }
        return error
    }

    private func ms(_ p: PreparedPhoto, _ name: String) -> String {
        guard let t = p.timings.first(where: { $0.0 == name })?.1 else { return "" }
        return String(format: "%.0f ms", t)
    }

    private func stepRow(_ n: String, _ title: String, _ detail: String, _ time: String) -> some View {
        HStack(spacing: 8) {
            Text(n).font(.caption2.bold()).frame(width: 18, height: 18).background(Color.accentColor.opacity(0.15), in: Circle())
            Text(title).font(.caption.bold()).frame(width: 52, alignment: .leading)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Text(time).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let p = prepared, !p.contours.isEmpty {
                Text("윤곽 선택").font(.subheadline.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(p.contours) { c in
                            let on = selected.contains(c.id)
                            Button {
                                if on { selected.remove(c.id) } else { selected.insert(c.id) }
                            } label: {
                                HStack(spacing: 4) {
                                    if c.isSilhouette { Image(systemName: "person.crop.square").font(.caption2) }
                                    Text("\(c.points.count)점").font(.caption.monospacedDigit())
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(on ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                                .overlay(Capsule().stroke(on ? Color.accentColor : .clear))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(c.isSilhouette ? "실루엣 " : "")윤곽, 점 \(c.points.count)개")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            Toggle(isOn: $includeCurves) { Label("곡선 — 윤곽을 푸리에 곡선으로", systemImage: "scribble.variable") }.font(.subheadline)
            if includeCurves {
                HStack {
                    Text("조화 \(harmonics)").font(.caption.monospacedDigit()).frame(width: 64, alignment: .leading)
                    Slider(value: Binding(get: { Double(harmonics) }, set: { harmonics = Int($0) }), in: 2...64, step: 1)
                        .accessibilityLabel("푸리에 조화 수").accessibilityValue("\(harmonics)")
                }
            }
            Toggle(isOn: $includeOutlineDots) { Label("점 — 윤곽을 점선으로", systemImage: "ellipsis.circle") }.font(.subheadline)
            if includeOutlineDots {
                HStack {
                    Text("윤곽당 \(Int(outlineDotCount))").font(.caption.monospacedDigit()).frame(width: 72, alignment: .leading)
                    Slider(value: $outlineDotCount, in: 50...1000, step: 50).accessibilityLabel("윤곽당 점 개수").accessibilityValue("\(Int(outlineDotCount))")
                }
            }
            Toggle(isOn: $includeToneDots) { Label("점 — 농담을 밀도로 (스티플)", systemImage: "circle.grid.3x3.fill") }.font(.subheadline)
            if includeToneDots {
                HStack {
                    Text("점 \(Int(toneDotCount))").font(.caption.monospacedDigit()).frame(width: 72, alignment: .leading)
                    Slider(value: $toneDotCount, in: 1000...12000, step: 500).accessibilityLabel("농담 점 개수").accessibilityValue("\(Int(toneDotCount))")
                }
                HStack {
                    Text(String(format: "감마 %.2f", toneGamma)).font(.caption.monospacedDigit()).frame(width: 72, alignment: .leading)
                    Slider(value: $toneGamma, in: 0.3...3).accessibilityLabel("농담 감마 (작을수록 점이 많음)").accessibilityValue(String(format: "%.2f", toneGamma))
                }
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
                Text(String(format: "윤곽 오차 %.2f%% · %d자", meanError * 50, script.count)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(script.prefix(1400) + (script.count > 1400 ? "\n…" : ""))
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
        original = ui
        await prepare()
    }

    private func prepare() async {
        guard let ui = original, let cg = ui.cgImage?.orientedUp(ui.imageOrientation) else { return }
        busy = true; failure = nil; preview = nil; script = ""
        defer { busy = false }
        var options = PhotoStructurer.Options(); options.detectsDarkOnLight = darkOnLight
        let result = await Task.detached(priority: .userInitiated) { () -> Result<PreparedPhoto, Error> in
            do { return .success(try PhotoStructurer.prepare(cg, options: options)) } catch { return .failure(error) }
        }.value
        switch result {
        case .success(let p):
            prepared = p
            // default selection: every silhouette, else the largest contour
            let sil = p.contours.filter(\.isSilhouette).map(\.id)
            selected = Set(sil.isEmpty ? p.contours.prefix(1).map(\.id) : sil)
            regenerate()
        case .failure(let error):
            failure = "분석 실패: \(error)"
        }
    }

    @State private var regenerateTask: Task<Void, Never>?
    @State private var regenerating = false

    /// Debounced: slider drags fire many changes; only the last one is rendered (stale results are dropped).
    private func regenerate() {
        guard let p = prepared else { return }
        let chosen = p.contours.filter { selected.contains($0.id) }
        let wantCurves = includeCurves, outline: Int? = includeOutlineDots ? Int(outlineDotCount) : nil
        let tone = includeToneDots ? PhotoStructurer.ToneDots(count: Int(toneDotCount), gamma: toneGamma) : nil
        guard (!chosen.isEmpty && (wantCurves || outline != nil)) || tone != nil else { script = ""; preview = nil; return }
        let n = harmonics
        regenerateTask?.cancel()
        regenerating = true
        regenerateTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            let out = await Task.detached(priority: .userInitiated) { () -> (String, Double, RenderedArtwork?, String?) in
                let (s, err) = PhotoStructurer.script(photo: p, contours: (wantCurves || outline != nil) ? chosen : [], harmonics: n, curves: wantCurves, outlineDots: outline, tone: tone)
                do {
                    let art = try FamilyParser.parse(s)
                    return (s, err, try FamilyEvaluator.evaluate(art), nil)
                } catch {
                    return (s, err, nil, String(describing: error))
                }
            }.value
            if Task.isCancelled { return }
            script = out.0; meanError = out.1; preview = out.2; failure = out.3
            regenerating = false
        }
    }
}

private extension CGImage {
    /// Bakes the UIImage orientation into the pixels so Vision and the overlay agree on up.
    func orientedUp(_ orientation: UIImage.Orientation) -> CGImage? {
        guard orientation != .up else { return self }
        let ui = UIImage(cgImage: self, scale: 1, orientation: orientation)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let img = UIGraphicsImageRenderer(size: ui.size, format: format).image { _ in ui.draw(in: CGRect(origin: .zero, size: ui.size)) }
        return img.cgImage
    }
}
