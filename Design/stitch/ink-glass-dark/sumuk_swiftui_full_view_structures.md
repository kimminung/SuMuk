# 수묵(SuMuk · 數墨) SwiftUI 전체 View 구조체 구현 코드

> **버전**: 1.0.0  
> **대상 플랫폼**: iOS 26 / iOS 27 (SwiftUI 전용)  
> **연계 문서**: `SuMuk_Design_Tokens.json`, `SuMuk_SwiftUI_Component_Spec.md`, `Stitch-UI-Brief.md`

이 문서는 수묵(SuMuk) 앱의 테마 확장, 공유 컴포넌트, 3대 핵심 탭(`DrawTabView`, `ReadTabView`, `GalleryTabView`), 모달 시트(`PresetDrawerView`), 상세 뷰(`SavedArtworkDetailView`)의 실제 SwiftUI 전체 구조체 코드 구현 예시입니다.

---

## 1. 테마 확장 및 컬러/폰트 토큰 (`Theme+SuMuk.swift`)

```swift
import SwiftUI

// MARK: - SuMuk Color Tokens
extension Color {
    // 캔버스 화선지 배경 (다크 모드에서도 밝은 한지 톤 유지)
    static let suMukPaper = Color(hex: "FAF7F0")
    
    // 종이의 어두운 톤 (컨테이너 및 서피스)
    static let suMukPaperDeep = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0) // #2C2C2E
                : UIColor(red: 0.94, green: 0.91, blue: 0.86, alpha: 1.0) // #EFE9DC
        }
    )
    
    // 순수 먹색 (캔버스 드로잉은 항상 #141414, UI 텍스트는 모드별 반전)
    static let suMukInkDrawing = Color(hex: "141414")
    static let suMukInkText = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0) // #F5F5F7
                : UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0) // #141414
        }
    )
    
    // 옅은 먹 (보조 설명, 키워드)
    static let suMukInkSoft = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "98989D") : UIColor(hex: "6E6E73")
        }
    )
    
    // 아주 옅은 먹 (구분선, 비활성 트랙)
    static let suMukInkWash = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "3A3A3C") : UIColor(hex: "D9D4C8")
        }
    )
    
    // 전각 낙관 인장 레드 (CTA 및 액센트)
    static let suMukVermilion = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "D94E36") : UIColor(hex: "C2412B")
        }
    )
    
    // 스크립트 오류 인디케이터
    static let suMukErrorInk = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "FFB4AB") : UIColor(hex: "BA1A1A")
        }
    )
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        if scanner.scanHexInt64(&hexNumber) {
            let r = Double((hexNumber & 0xff0000) >> 16) / 255
            let g = Double((hexNumber & 0x00ff00) >> 8) / 255
            let b = Double(hexNumber & 0x0000ff) / 255
            self.init(red: r, green: g, blue: b)
            return
        }
        self.init(white: 0.5)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000ff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
```

---

## 2. 최상위 탭 뷰 구조체 (`MainTabView.swift`)

```swift
import SwiftUI

enum SuMukTab: Int, CaseIterable {
    case draw = 0
    case read = 1
    case gallery = 2
}

struct MainTabView: View {
    @State private var selectedTab: SuMukTab = .draw
    @StateObject private var sharedModel = SuMukSharedModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DrawTabView(sharedModel: sharedModel)
                .tabItem {
                    Label("그리기", systemImage: "pencil.tip.crop.circle")
                }
                .tag(SuMukTab.draw)
            
            ReadTabView(sharedModel: sharedModel, onOpenInScript: {
                selectedTab = .draw
            })
            .tabItem {
                Label("읽기", systemImage: "photo.on.rectangle.angled")
            }
            .tag(SuMukTab.read)
            
            GalleryTabView(sharedModel: sharedModel, onSelectArtwork: { artwork in
                sharedModel.loadArtwork(artwork)
                selectedTab = .draw
            })
            .tabItem {
                Label("갤러리", systemImage: "square.grid.2x2")
            }
            .tag(SuMukTab.gallery)
        }
        .tint(.suMukVermilion) // 전각 낙관 틴트 적용
    }
}
```

---

## 3. 화면 1, 2: 그리기 탭 전체 구조체 (`DrawTabView.swift`)

```swift
import SwiftUI

struct DrawTabView: View {
    @ObservedObject var sharedModel: SuMukSharedModel
    @State private var isPresetPresented: Bool = false
    @State private var notchValue: Double = 0.24
    @State private var rippleValue: Double = 0.03
    @State private var scriptText: String = """
    // 은행잎 — 잎자루에서 가장자리로 펼쳐지는 부채
    ink #141414 width 0.5 alpha 0.45
    let notch = 0.24 in [0, 0.5]
    let ripple = 0.03 in [0, 0.1]

    segments k = 1 ... 700 {
      from ( 0.05·sin(2π·s(k))·sin^2(π·s(k)),  −1 + 0.22·sin^6(π·s(k)) )
      to   ( r(k)·cos(θ(k)),  r(k)·sin(θ(k)) − 0.25 )
    }
    where
      s(k) = k/700
      θ(k) = π/2 + 1.3·(s(k) − 1/2)
    """
    
    @State private var errorMessage: String? = nil // "3행 25열: 한 줄에는 문장 하나만 쓸 수 있습니다"
    @State private var canUndo: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 화선지 캔버스 영역 (Hero Canvas)
                ZStack(alignment: .topLeading) {
                    // 화선지 질감 배경 (다크 모드에서도 밝은 톤 유지)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.suMukPaper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.suMukInkWash.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    
                    // 수묵 벡터/수식 렌더링 뷰 (은행잎)
                    GinkgoInkCanvasView(notch: notchValue, ripple: rippleValue)
                        .padding(16)
                    
                    // 우측 하단: 전각 인장 낙관
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            SealStampView(text: "數墨")
                                .padding(12)
                        }
                    }
                    
                    // 좌측 상단: 플로팅 상태 캡슐
                    StatusCapsuleView(text: "계열 2 · 선분 820 · 4 ms", isComputing: false)
                        .padding(12)
                    
                    // 좌측 하단: 여백 오류 메모 배너 (오류 존재 시 노출)
                    if let error = errorMessage {
                        VStack {
                            Spacer()
                            MarginErrorBanner(message: error)
                                .padding(.leading, 12)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(maxHeight: .infinity)
                
                // 2. 동적 let 변수 제어 슬라이더 패널 (오류 시 숨김)
                if errorMessage == nil {
                    VStack(spacing: 8) {
                        VariableSliderRow(name: "notch", value: $notchValue, range: 0...0.5, step: 0.01)
                        VariableSliderRow(name: "ripple", value: $rippleValue, range: 0...0.1, step: 0.005)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.suMukPaperDeep.opacity(0.4))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // 3. 하단 SF Mono 스크립트 에디터
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ginkgo_leaf.smk")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.suMukInkSoft)
                        Spacer()
                        Text("26,221자")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.suMukInkSoft)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    TextEditor(text: $scriptText)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }
                .frame(height: 240)
                .background(Color.suMukPaperDeep)
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("수묵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { /* undo */ }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!canUndo)
                    
                    Button(action: { /* redo */ }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(true)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { isPresetPresented = true }) {
                        Image(systemName: "square.grid.2x2")
                    }
                    Button(action: { /* share */ }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: { /* save */ }) {
                        Image(systemName: "tray.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $isPresetPresented) {
                PresetDrawerView(onSelect: { preset in
                    // 프리셋 반영
                    isPresetPresented = false
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}
```

---

## 4. 화면 3: 프리셋 서랍 시트 (`PresetDrawerView.swift`)

```swift
import SwiftUI

struct SuMukPresetItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let meta: String
    let imageName: String
    var isCurrent: Bool = false
}

struct PresetDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (SuMukPresetItem) -> Void
    
    let presets: [SuMukPresetItem] = [
        SuMukPresetItem(title: "은행잎", subtitle: "선분 820개 · 잎자루에서 물결치는 가장자리로", meta: "선분 계열 2", imageName: "ginkgo", isCurrent: true),
        SuMukPresetItem(title: "달항아리 · 月壺", subtitle: "원 4,400개 · 중심은 항아리 윤곽, 반지름은 붓 압력", meta: "원 계열 1", imageName: "moon_jar"),
        SuMukPresetItem(title: "매화 · 梅花", subtitle: "원 3,561개 · 꽃잎 5장 × 700 + 수술 60", meta: "사군자 계열", imageName: "plum"),
        SuMukPresetItem(title: "잉어 · 鯉", subtitle: "선분 2,760개 · 교차 해칭 몸통 + 부채꼴 꼬리", meta: "비늘 해칭", imageName: "carp"),
        SuMukPresetItem(title: "학 · 鶴", subtitle: "선분 2,760개 · sin⁷ 날개 + S자 목", meta: "sin⁷ envelope", imageName: "crane"),
        SuMukPresetItem(title: "빈 시작 · 新構想", subtitle: "선분 계열 하나로 시작하는 순수 캔버스", meta: "기본 템플릿", imageName: "blank")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(presets) { preset in
                        Button(action: {
                            onSelect(preset)
                            dismiss()
                        }) {
                            HStack(spacing: 14) {
                                // 64x64 화선지 썸네일
                                ZStack(alignment: .bottomTrailing) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.suMukPaper)
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "scribble")
                                        .foregroundColor(.suMukInkDrawing)
                                    
                                    SealStampView(text: "墨", size: 14)
                                        .padding(4)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(preset.title)
                                            .font(.headline)
                                            .foregroundColor(.suMukInkText)
                                        
                                        if preset.isCurrent {
                                            Text("현재 적용됨")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.suMukVermilion.opacity(0.15))
                                                .foregroundColor(.suMukVermilion)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    Text(preset.subtitle)
                                        .font(.footnote)
                                        .foregroundColor(.suMukInkSoft)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                if preset.isCurrent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.suMukVermilion)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.suMukInkSoft)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } footer: {
                    Text("프리셋을 선택하면 현재 캔버스에 수식과 렌더링이 즉시 반영됩니다.")
                        .font(.caption)
                        .foregroundColor(.suMukInkSoft)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("프리셋 서랍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }
}
```

---

## 5. 화면 4, 5: 읽기 탭 (사진 → 수식) 구조체 (`ReadTabView.swift`)

```swift
import SwiftUI

struct PipelineStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let elapsed: String
}

struct ReadTabView: View {
    @ObservedObject var sharedModel: SuMukSharedModel
    var onOpenInScript: () -> Void
    
    @State private var hasPhoto: Bool = true
    @State private var isSegmented: Bool = true
    @State private var harmonicCount: Double = 16
    @State private var stippleDots: Double = 6000
    @State private var gammaValue: Double = 1.0
    
    let pipelineSteps: [PipelineStep] = [
        PipelineStep(id: 0, title: "방향", detail: "회전 90° · 수평 3.2° 보정", elapsed: "79 ms"),
        PipelineStep(id: 1, title: "업스케일", detail: "1.0× → 3024 × 4032", elapsed: "0 ms"),
        PipelineStep(id: 2, title: "누끼", detail: "원본 사용 — 시뮬레이터 미지원", elapsed: "32 ms"),
        PipelineStep(id: 3, title: "윤곽", detail: "12개 (실루엣 0)", elapsed: "251 ms"),
        PipelineStep(id: 4, title: "농담", detail: "DCT 220항 (27×36)", elapsed: "62 ms")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 프리뷰 카드 (사진 + 윤곽선/스티플 오버레이)
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.suMukPaperDeep)
                            .frame(height: 380)
                        
                        if hasPhoto {
                            // 원본 사진 딤 + 푸리에 윤곽선/스티플 오버레이
                            PhotoInkOverlayView()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            // 우측 상단 누끼/원본 글래스 스위치
                            Button(action: { isSegmented.toggle() }) {
                                Text(isSegmented ? "누끼" : "원본")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .padding(12)
                        } else {
                            // 빈 상태 일러스트레이션
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 44))
                                    .foregroundColor(.suMukInkSoft)
                                Text("사진 없음")
                                    .font(.headline)
                                Text("사진을 고르면 업스케일 → 누끼 → 윤곽 → 곡선과 점 수식으로 바꿉니다.")
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.suMukInkSoft)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    if hasPhoto {
                        // 2. 파이프라인 수직 스테퍼 카드
                        VStack(alignment: .leading, spacing: 12) {
                            Text("변환 파이프라인")
                                .font(.subheadline.bold())
                                .foregroundColor(.suMukInkSoft)
                            
                            ForEach(pipelineSteps) { step in
                                HStack(spacing: 12) {
                                    // 스텝 번호 뱃지
                                    Text("\(step.id)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .frame(width: 20, height: 20)
                                        .background(Circle().stroke(Color.suMukInkWash, lineWidth: 1))
                                    
                                    Text(step.title)
                                        .font(.subheadline.bold())
                                        .frame(width: 56, alignment: .leading)
                                    
                                    Text(step.detail)
                                        .font(.footnote)
                                        .foregroundColor(.suMukInkSoft)
                                    
                                    Spacer()
                                    
                                    Text(step.elapsed)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.suMukInkSoft)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.suMukPaperDeep)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // 3. vermilion 전폭 CTA 버튼
                    VermilionActionButton(
                        title: "스크립트로 열기",
                        systemImage: "pencil.and.outline",
                        isEnabled: hasPhoto,
                        action: {
                            onOpenInScript()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .navigationTitle("읽기 · 사진 → 수식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* 사진 피커 */ }) {
                        Label("사진 고르기", systemImage: "photo")
                    }
                }
            }
        }
    }
}
```

---

## 6. 화면 7: 갤러리 그리드 구조체 (`GalleryTabView.swift`)

```swift
import SwiftUI

struct SuMukArtwork: Identifiable {
    let id = UUID()
    let title: String
    let elementCount: Int
    let dateString: String
    let script: String
}

struct GalleryTabView: View {
    @ObservedObject var sharedModel: SuMukSharedModel
    var onSelectArtwork: (SuMukArtwork) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sharedModel.savedArtworks) { artwork in
                        NavigationLink(destination: SavedArtworkDetailView(artwork: artwork, onOpenScript: {
                            onSelectArtwork(artwork)
                        })) {
                            VStack(alignment: .leading, spacing: 8) {
                                // 1:1 정사각형 화선지 썸네일
                                ZStack(alignment: .bottomTrailing) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.suMukPaper)
                                        .aspectRatio(1, contentMode: .fit)
                                    
                                    Image(systemName: "scribble")
                                        .font(.largeTitle)
                                        .foregroundColor(.suMukInkDrawing)
                                    
                                    SealStampView(text: "數墨", size: 16)
                                        .padding(8)
                                }
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                
                                Text(artwork.title)
                                    .font(.headline)
                                    .foregroundColor(.suMukInkText)
                                    .lineLimit(1)
                                
                                Text("요소 \(artwork.elementCount) · \(artwork.dateString)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.suMukInkSoft)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .navigationTitle("갤러리")
        }
    }
}
```

---

## 7. 화면 8: 작품 상세 구조체 (`SavedArtworkDetailView.swift`)

```swift
import SwiftUI

struct SavedArtworkDetailView: View {
    let artwork: SuMukArtwork
    var onOpenScript: () -> Void
    @State private var isDeleteAlertPresented: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. 360pt 화선지 캔버스
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.suMukPaper)
                        .frame(height: 360)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    
                    SealStampView(text: "鶴", size: 24)
                        .padding(16)
                }
                .padding(.horizontal, 16)
                
                // 2. 액션 버튼 행
                HStack(spacing: 12) {
                    VermilionActionButton(
                        title: "스크립트로 열기",
                        systemImage: "pencil.and.outline",
                        isEnabled: true,
                        action: onOpenScript
                    )
                    
                    Button(action: { /* 공유 액션 */ }) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 52, height: 52)
                            .background(Color.suMukPaperDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Button(action: { isDeleteAlertPresented = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 52, height: 52)
                            .background(Color.suMukPaperDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 16)
                
                // 3. 스크립트 코드 블록
                VStack(alignment: .leading, spacing: 8) {
                    Text("스크립트")
                        .font(.headline)
                    
                    Text(artwork.script)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.suMukPaperDeep)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        }
        .navigationTitle(artwork.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("이 작품을 삭제할까요?", isPresented: $isDeleteAlertPresented) {
            Button("삭제", role: .destructive) { /* 삭제 로직 */ }
            Button("취소", role: .cancel) { }
        }
    }
}
```

---

## 8. 공통 UI 컴포넌트 구조체 모음 (`SuMukComponents.swift`)

```swift
import SwiftUI

// MARK: - 전각 낙관 인장 뷰 (Seal Stamp)
struct SealStampView: View {
    let text: String
    var size: CGFloat = 18
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                .fill(Color.suMukVermilion)
                .frame(width: size, height: size)
            
            Text(text)
                .font(.system(size: size * 0.58, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 여백 오류 메모 배너 (Margin Error Banner)
struct MarginErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.suMukErrorInk)
            
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.suMukErrorInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.suMukErrorInk.opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.suMukErrorInk.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - 플로팅 상태 캡슐 (Status Capsule)
struct StatusCapsuleView: View {
    let text: String
    var isComputing: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isComputing {
                ProgressView().scaleEffect(0.6)
            } else {
                Circle()
                    .fill(Color.suMukVermilion)
                    .frame(width: 4, height: 4)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.suMukInkSoft)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - 동적 슬라이더 행 (Variable Slider Row)
struct VariableSliderRow: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.suMukInkText)
                .frame(width: 60, alignment: .leading)
            
            Slider(value: $value, in: range, step: step)
                .tint(.suMukVermilion)
            
            Text(String(format: "%.2f", value))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.suMukInkSoft)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 36)
    }
}

// MARK: - 주홍 전각 인장 액션 버튼 (Vermilion Action Button)
struct VermilionActionButton: View {
    let title: String
    let systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(.white)
            .background(isEnabled ? Color.suMukVermilion : Color.suMukInkWash)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled)
    }
}

// MARK: - 더미 캔버스 및 공유 상태 모델
struct GinkgoInkCanvasView: View {
    let notch: Double
    let ripple: Double
    
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width
                let h = proxy.size.height
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.95))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
            }
            .stroke(Color.suMukInkDrawing, lineWidth: 1.5)
        }
    }
}

struct PhotoInkOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            Image(systemName: "waveform.path")
                .font(.system(size: 80))
                .foregroundColor(.suMukInkDrawing)
        }
    }
}

class SuMukSharedModel: ObservableObject {
    @Published var savedArtworks: [SuMukArtwork] = [
        SuMukArtwork(title: "학 · 鶴", elementCount: 2760, dateString: "2026. 10. 17. 오후 1:52", script: "canvas 750 × 1000\nink #141414 width 0.5\nsegments k = 1 ... 2760..."),
        SuMukArtwork(title: "달항아리", elementCount: 4400, dateString: "2026. 10. 16. 오전 11:30", script: "canvas 800 × 800\ncircles k = 1 ... 4400..."),
        SuMukArtwork(title: "초상 — 진열대", elementCount: 2202, dateString: "2026. 10. 15. 오후 4:10", script: "canvas 750 × 1000\ncurve k = 1 ... 12...")
    ]
    
    func loadArtwork(_ artwork: SuMukArtwork) {
        // 아크워크 데이터 로드
    }
}
```
