import SwiftUI
import UIKit
import PhotosUI

/// 읽기 탭 — photo → orientation → upscale → subject cut-out → contours → curves (+ dots) → SuMuk Script.
/// Styled after the Stitch "Read tab" screens: preview card, pipeline stepper, recipe card, vermilion CTA.
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
    @State private var quarterTurns = 0
    @State private var selectAll = false   // remembered across re-analysis (rotation, levelling, contrast)
    @State private var autoLevel = true
    @State private var showCutout = true
    @State private var preview: RenderedArtwork?
    @State private var script = ""
    @State private var meanError = 0.0
    @State private var busy = false
    @State private var failure: String?
    @State private var regenerateTask: Task<Void, Never>?
    @State private var regenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SuMukSpacing.md) {
                    previewCard
                    if prepared != nil { pipelineCard; orientationCard; contourCard }
                    recipeCard
                    if !script.isEmpty { scriptCard }
                    ctaBlock
                }
                .padding(SuMukSpacing.md)
            }
            .background(Color.chrome.ignoresSafeArea())
            .navigationTitle("읽기 · 사진 → 수식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pickerItem, matching: .images) { Label("사진 고르기", systemImage: "photo.badge.plus") }
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
            .onChange(of: quarterTurns) { _, _ in Task { await prepare() } }
            .onChange(of: autoLevel) { _, _ in Task { await prepare() } }
        }
        .tint(.vermilion)
    }

    // MARK: - preview

    private var drawnDots: Int {
        preview?.families.reduce(0) { acc, f in if case .points(let p, _, _) = f { return acc + p.count } else { return acc } } ?? 0
    }

    private var previewCard: some View {
        ZStack {
            // paper behind the photo so the dimmed photo reads as an ink wash in dark mode too
            RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous).fill(original == nil ? Color.paperDeep : Color.paper)
            if let prepared, showCutout {
                Image(decorative: prepared.image, scale: 1).resizable().scaledToFit().opacity(preview == nil ? 1 : 0.45)
            } else if let original {
                Image(uiImage: original).resizable().scaledToFit().opacity(preview == nil ? 1 : 0.45)
            }
            if let preview, let prepared {
                FamilyCanvasView(artwork: preview, paper: .clear, padding: 0).aspectRatio(prepared.aspect, contentMode: .fit)
            }
            if original == nil { emptyState }
            if busy {
                VStack(spacing: 8) { ProgressView().controlSize(.large); Text("분석 중…").font(.caption).foregroundStyle(Color.inkText) }
                    .padding(SuMukSpacing.md).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SuMukRadius.card, style: .continuous).stroke(Color.inkWash.opacity(0.6), lineWidth: 0.5))
        .overlay(alignment: .topLeading) {
            if let p = prepared {
                StatusCapsuleView(text: regenerating ? "수식 다시 계산 중…" : "분석 완료 · \(p.contours.count)개 윤곽 · \(drawnDots.formatted())점",
                                  isComputing: regenerating, dot: .celadon)
                    .padding(SuMukSpacing.sm)
            }
        }
        .overlay(alignment: .topTrailing) {
            if prepared?.subjectFound == true {
                HStack(spacing: 0) {
                    segment("누끼", on: showCutout) { showCutout = true }
                    segment("원본", on: !showCutout) { showCutout = false }
                }
                .background(.ultraThinMaterial, in: Capsule())
                .padding(SuMukSpacing.sm)
                .accessibilityElement(children: .contain)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if prepared != nil { SealStampView(size: 30).padding(SuMukSpacing.sm) }
        }
        .overlay(alignment: .bottomLeading) {
            if let failure { MarginErrorBanner(message: failure).padding(SuMukSpacing.sm).padding(.trailing, 48) }
        }
    }

    private func segment(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption2.bold())
                .foregroundStyle(on ? Color.white : Color.inkText)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(on ? Color.vermilion : Color.clear, in: Capsule())
        }
        .accessibilityLabel("\(title) 보기").accessibilityAddTraits(on ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: SuMukSpacing.sm) {
            Image(systemName: "function").font(.system(size: 40, weight: .light)).foregroundStyle(Color.inkSoft)
            HStack(spacing: 6) { Circle().fill(Color.vermilion).frame(width: 6, height: 6); Text("사진 없음").font(.headline).foregroundStyle(Color.inkText) }
            Text("사진을 고르면 업스케일 → 누끼 → 윤곽 → 곡선과 점 수식으로 바꿉니다.")
                .font(.footnote).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center).padding(.horizontal, SuMukSpacing.lg)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("사진 보관함에서 선택", systemImage: "photo.badge.plus").font(.subheadline.bold()).foregroundStyle(Color.inkText)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.paper, in: Capsule())
                    .overlay(Capsule().stroke(Color.inkWash, lineWidth: 0.5))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - pipeline

    private var pipelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let p = prepared {
                CardHeader(icon: "list.number", "수식 변환 파이프라인") {
                    Text(String(format: "총 %.0f ms", p.timings.reduce(0) { $0 + $1.1 })).foregroundStyle(Color.vermilion)
                }
                stepRow(0, "방향", orientationText(p), ms(p, "방향"))
                stepRow(1, "업스케일", String(format: "%.1f× → %d × %d", p.upscale, Int(p.size.width), Int(p.size.height)), ms(p, "업스케일"))
                stepRow(2, "누끼", p.subjectFound ? "피사체 분리됨 (배경 화선지)" : "원본 사용 — \(cutoutFailureText(p.subjectError))", ms(p, "누끼"), ok: p.subjectFound)
                stepRow(3, "윤곽", "\(p.contours.count)개 (실루엣 \(p.contours.filter(\.isSilhouette).count))", ms(p, "윤곽"))
                stepRow(4, "농담", "DCT \(p.darkness.c.count)항 (\(p.darkness.w)×\(p.darkness.h))", ms(p, "농담"), last: true)
            }
        }
        .sectionCard()
    }

    private func stepRow(_ n: Int, _ title: String, _ detail: String, _ time: String, ok: Bool = true, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(ok ? Color.vermilion : Color.inkWash, lineWidth: 1).frame(width: 20, height: 20)
                    Text("\(n)").font(.suMono(10, weight: .bold)).foregroundStyle(ok ? Color.vermilion : Color.inkSoft)
                }
                if !last { Rectangle().fill(Color.inkWash).frame(width: 1).frame(maxHeight: .infinity).padding(.vertical, 2) }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Color.inkText)
                Text(detail).font(.footnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(time).font(.suMonoCaption).foregroundStyle(Color.inkSoft)
        }
        .frame(minHeight: 38)
        .accessibilityElement(children: .combine)
    }

    private func orientationText(_ p: PreparedPhoto) -> String {
        var parts: [String] = []
        parts.append(p.quarterTurns == 0 ? "회전 없음" : "회전 \(p.quarterTurns * 90)°")
        if let h = p.horizonDegrees {
            parts.append(String(format: "수평선 %.1f°%@", h, p.appliedLevelDegrees != 0 ? " 보정됨" : (abs(h) <= 0.3 ? "" : " (보정 끔)")))
        } else { parts.append("수평선 미검출") }
        return parts.joined(separator: " · ")
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

    // MARK: - orientation & contours

    private var orientationCard: some View {
        HStack(spacing: 10) {
            Text("방향").font(.subheadline.bold()).foregroundStyle(Color.inkText)
            Text("\(quarterTurns * 90)°").font(.suMono(12, weight: .bold)).foregroundStyle(Color.inkText)
                .padding(.horizontal, 8).padding(.vertical, 4).background(Color.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Button { quarterTurns = (quarterTurns + 3) % 4 } label: { Image(systemName: "rotate.left") }
                .buttonStyle(.bordered).controlSize(.small).accessibilityLabel("반시계 방향으로 90도 회전")
            Button { quarterTurns = (quarterTurns + 1) % 4 } label: { Image(systemName: "rotate.right") }
                .buttonStyle(.bordered).controlSize(.small).accessibilityLabel("시계 방향으로 90도 회전")
            Spacer()
            Toggle(isOn: $autoLevel) {
                Text(prepared?.horizonDegrees.map { String(format: "수평 자동 보정 (%.1f°)", $0) } ?? "수평 자동 보정").font(.caption).foregroundStyle(Color.inkText)
            }
            .toggleStyle(.switch).controlSize(.mini).tint(.vermilion)
        }
        .sectionCard(padding: SuMukSpacing.sm)
    }

    @ViewBuilder private var contourCard: some View {
        if let p = prepared, !p.contours.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("윤곽 선택").font(.subheadline.bold()).foregroundStyle(Color.inkText)
                    Text("(면적순)").font(.caption).foregroundStyle(Color.vermilion)
                    Text("\(selected.count)개 활성").font(.caption).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Button("모두 선택") { selectAll = true; selected = Set(p.contours.map(\.id)) }
                        .font(.caption.bold()).foregroundStyle(Color.vermilion).accessibilityLabel("윤곽 모두 선택")
                    Button("해제") { selectAll = false; selected = [] }
                        .font(.caption).foregroundStyle(Color.inkSoft).accessibilityLabel("윤곽 선택 해제")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(p.contours) { c in
                            let on = selected.contains(c.id)
                            Button {
                                if on { selected.remove(c.id) } else { selected.insert(c.id) }
                            } label: {
                                ChipView(label: "\(c.points.count.formatted())점", icon: c.isSilhouette ? "person.crop.square" : nil, selected: on)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(c.isSilhouette ? "실루엣 " : "")윤곽, 점 \(c.points.count)개")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            .sectionCard(padding: SuMukSpacing.sm)
        }
    }

    // MARK: - recipe

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "slider.horizontal.3", "변환 레시피 설정") { Text(prepared == nil ? "비활성 (사진 필요)" : "즉시 연산") }
            recipeToggle("곡선 — 윤곽을 푸리에 곡선으로", icon: "scribble.variable", isOn: $includeCurves)
            if includeCurves {
                recipeSlider("조화", value: Binding(get: { Double(harmonics) }, set: { harmonics = Int($0) }), range: 2...64, step: 1, text: "\(harmonics)", bounds: "2 – 64", a11y: "푸리에 조화 수")
            }
            divider
            recipeToggle("점 — 윤곽을 점선으로", icon: "ellipsis.circle", isOn: $includeOutlineDots)
            if includeOutlineDots {
                recipeSlider("윤곽당", value: $outlineDotCount, range: 50...1000, step: 50, text: "\(Int(outlineDotCount))", bounds: "50 – 1,000", a11y: "윤곽당 점 개수")
            }
            divider
            recipeToggle("점 — 농담을 밀도로 (스티플)", icon: "circle.grid.3x3.fill", isOn: $includeToneDots)
            if includeToneDots {
                recipeSlider("점", value: $toneDotCount, range: 1000...12000, step: 500, text: Int(toneDotCount).formatted(), bounds: "1,000 – 12,000", a11y: "농담 점 개수")
                recipeSlider("감마", value: $toneGamma, range: 0.3...3, step: nil, text: String(format: "%.2f", toneGamma), bounds: "0.3 – 3.0", a11y: "농담 감마 (작을수록 점이 많음)")
            }
            divider
            recipeToggle("어두운 윤곽 (밝은 배경)", icon: "circle.lefthalf.filled", isOn: $darkOnLight)
        }
        .sectionCard(padding: SuMukSpacing.sm)
        .disabled(prepared == nil)
        .opacity(prepared == nil ? 0.6 : 1)
    }

    private var divider: some View { Rectangle().fill(Color.inkWash.opacity(0.6)).frame(height: 0.5) }

    private func recipeToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.inkSoft)
                    .frame(width: 28, height: 28).background(Color.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title).font(.subheadline).foregroundStyle(Color.inkText)
            }
        }
        .tint(.vermilion)
    }

    private func recipeSlider(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double?, text: String, bounds: String, a11y: String) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text("\(name) \(text)").font(.suMono(12, weight: .medium)).foregroundStyle(Color.inkText)
                Spacer()
                Text(bounds).font(.suMono(11)).foregroundStyle(Color.inkSoft)
            }
            Group {
                if let step { Slider(value: value, in: range, step: step) } else { Slider(value: value, in: range) }
            }
            .tint(.vermilion)
            .accessibilityLabel(a11y).accessibilityValue(text)
        }
        .padding(.leading, 38)
    }

    // MARK: - script & CTA

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: SuMukSpacing.xs) {
            CardHeader(icon: "terminal", "결과 스크립트") {
                Text(String(format: "윤곽 오차 %.2f%% · %@자", meanError * 50, script.count.formatted()))
            }
            Text(script.prefix(1400) + (script.count > 1400 ? "\n…" : ""))
                .font(.suMono(12)).foregroundStyle(Color.inkDrawing)   // always dark: this block sits on paper in both modes
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sectionCard(padding: SuMukSpacing.sm)
    }

    private var ctaBlock: some View {
        VStack(spacing: 8) {
            Button {
                model.replaceScript(script)
                selectedTab = 0
            } label: {
                Label("스크립트로 열기", systemImage: "pencil.and.outline")
            }
            .buttonStyle(VermilionButtonStyle())
            .disabled(script.isEmpty)
            Text(script.isEmpty ? "사진을 불러온 후 수식 변환 결과를 스크립트로 열 수 있습니다." : "그리기 탭으로 스크립트를 전달하여 즉시 캔버스에서 연산합니다.")
                .font(.caption).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
        }
        .padding(.bottom, SuMukSpacing.lg)
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
        options.quarterTurns = quarterTurns; options.autoLevel = autoLevel
        let result = await Task.detached(priority: .userInitiated) { () -> Result<PreparedPhoto, Error> in
            do { return .success(try PhotoStructurer.prepare(cg, options: options)) } catch { return .failure(error) }
        }.value
        switch result {
        case .success(let p):
            prepared = p
            // default selection: everything if the user chose 모두 선택 before; else every silhouette, else the largest contour
            if selectAll {
                selected = Set(p.contours.map(\.id))
            } else {
                let sil = p.contours.filter(\.isSilhouette).map(\.id)
                selected = Set(sil.isEmpty ? p.contours.prefix(1).map(\.id) : sil)
            }
            regenerate()
        case .failure(let error):
            failure = "분석 실패: \(error)"
        }
    }

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
