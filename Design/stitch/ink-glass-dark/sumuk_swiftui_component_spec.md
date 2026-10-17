# 수묵(SuMuk · 數墨) SwiftUI 컴포넌트 구현 명세서

> **버전**: 1.0.0  
> **대상 플랫폼**: iOS 26 / iOS 27 (SwiftUI 전용)  
> **기준 기기**: iPhone 16 (393 × 852 pt, @3x)  
> **연계 문서**: `Stitch-UI-Brief.md`, `SuMuk_Design_Tokens.json`  
> **디자인 시스템**: `SuMuk Ink & Glass` (Dark) & `Literati Ink` (Light)

---

## 1. 컴포넌트 아키텍처 개요

수묵(SuMuk)의 SwiftUI 뷰 계층은 전통 동양화의 **화선지 캔버스(Content/Paper)**와 최신 iOS의 **Liquid Glass 크롬(Control/Chrome)**이라는 2-레이어 철학을 따릅니다.

```
┌─────────────────────────────────────────────────────────────┐
│ UI Chrome: NavigationBar, Liquid Glass Toolbar, TabBar      │  <- 모드별 반전 (#141414 <-> #F5F5F7)
├─────────────────────────────────────────────────────────────┤
│ Floating Overlays: StatusCapsule, MarginErrorBanner         │  <- Liquid Glass 머티리얼 (배경 블러 16-24pt)
├─────────────────────────────────────────────────────────────┤
│ Hero Canvas: RicePaperView (#FAF7F0 고정, Paper Texture)    │  <- 다크 모드에서도 불변 (밝은 종이색 유지)
│ Ink Render: Metal/Vector Path (Ink #141414 + Alpha Wash)    │
├─────────────────────────────────────────────────────────────┤
│ Panels & Sheets: VariableSliderPanel, PipelineStepperCard   │  <- PaperDeep 서피스
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 핵심 컴포넌트별 상세 명세

### 2.1 플로팅 상태 칩 (`StatusCapsuleView`)
캔버스 상단 좌측에 떠서 수식 렌더링 계열 수, 선분/원 개수, 컴파일 레이턴시를 실시간 표시하는 컴포넌트.

| 속성 | 규격 및 값 |
|---|---|
| **치수 (Dimensions)** | 높이 28pt 고정, 수평 패딩 12pt, 최소 너비 자동 (`huggingPriority .high`) |
| **코너 반경 (Radius)** | Capsule (`.clipShape(Capsule())` / `9999pt`) |
| **머티리얼 (Surface)** | Ultra-thin Liquid Glass (`.ultraThinMaterial` / `blur: 16pt`) |
| **배경색 (Background)** | Light: `rgba(255, 255, 255, 0.72)` / Dark: `rgba(30, 30, 32, 0.75)` |
| **테두리 (Border)** | Light: `rgba(255, 255, 255, 0.5)` 0.5pt / Dark: `rgba(255, 255, 255, 0.15)` 0.5pt |
| **타이포그래피** | Font: `SF Mono` (`.font(.system(size: 11, weight: .medium, design: .monospaced))`) |
| **텍스트 색상** | Light: `Color.inkSoft (#6E6E73)` / Dark: `Color.inkSoft (#98989D)` |
| **하위 요소** | - 상태 인디케이터 점 (`circle 4×4pt`, 색상: `.vermilion` 또는 `.secondary`)<br>- 인디케이터 스피너 (파싱 상태일 때 8×8pt `ProgressView`) |
| **SwiftUI 예시** |
```swift
struct StatusCapsuleView: View {
    let text: String
    var isComputing: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isComputing {
                ProgressView().scaleEffect(0.6)
            } else {
                Circle()
                    .fill(Color.vermilion)
                    .frame(width: 4, height: 4)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
```

---

### 2.2 화선지 여백 오류 배너 (`MarginErrorBanner`)
스크립트 오류 발생 시 캔버스 하단 좌측에 정렬되는 배너. 모달 팝업이 아닌 "화선지 귀퉁이에 교정 메모를 붙여둔 감각"을 부여.

| 속성 | 규격 및 값 |
|---|---|
| **배치 (Layout)** | 캔버스 내부 `alignment: .bottomLeading`, 좌/하단 패딩 12pt, 우측 마진 32pt 확보 |
| **코너 반경 (Radius)** | `10pt` (`ContinuousRoundedRectangle`) |
| **배경색 (Background)** | Light: `#FDE8E8` / Dark: `rgba(186, 26, 26, 0.16)` (에러 틴트) |
| **테두리 (Border)** | Light: `rgba(186, 26, 26, 0.2)` 0.5pt / Dark: `rgba(255, 180, 171, 0.3)` 0.5pt |
| **아이콘 (SF Symbol)** | `exclamationmark.triangle.fill` (12pt, 틴트: `Color.errorInk`) |
| **타이포그래피** | `SF Pro` Footnote (`size: 12pt, weight: .semibold`), 자간 -0.1pt |
| **텍스트 색상** | Light: `Color.errorInk (#BA1A1A)` / Dark: `Color.errorInkLight (#FFB4AB)` |
| **상태 애니메이션** | 스크립트 유효성 검사 통과 시 자동 디스미스 (`.transition(.move(edge: .bottom).combined(with: .opacity))`) |

---

### 2.3 let 동적 변수 슬라이더 행 (`VariableSliderRow`)
스크립트의 `let` 선언문(`let notch = 0.24 in [0, 0.5]`)을 감지하여 캔버스 하단에 동적으로 렌더링되는 파라미터 제어 스트립.

| 구성 요소 | 규격 | 디자인 속성 |
|---|---|---|
| **컨테이너** | 세로 높이 36pt, 수평 패딩 16pt | `Color.paperDeep` 서피스 또는 Glass Strip |
| **변수명 라벨 (Leading)** | 고정 폭 60~72pt, 좌측 정렬 | `SF Mono` 13pt bold, `Color.ink` |
| **슬라이더 트랙 (Center)** | 높이 4pt, 가로 유동 (`Spacer` 대응) | 활성 트랙: `Color.vermilion`, 비활성 트랙: `Color.inkWash` |
| **슬라이더 섬 (Thumb)** | 지름 20pt 원형 | White + 부드러운 그림자 (`shadow radius: 3`) |
| **수치 인디케이터 (Trailing)** | 폭 44pt, 우측 정렬 | `SF Mono` 12pt medium (`tabular-nums`), 박스 배경 4pt 패딩 |

---

### 2.4 프리셋 행 & 카드 셀 (`PresetCardCell`)
화면 3 프리셋 서랍 및 갤러리 그리드에서 사용되는 프리셋/작품 카드.

| 항목 | 프리셋 서랍 (시트 리스트형) | 갤러리 (2열 적응형 그리드형) |
|---|---|---|
| **전체 카드 크기** | 가로 full width, 높이 76pt | 가로 ~174pt (화면비 2열), 세로 높이 ~220pt |
| **썸네일 프레임** | 64 × 64 pt 고정, 코너 반경 10pt | 174 × 174 pt 정사각형 (1:1), 코너 반경 12pt |
| **썸네일 배경** | **`#FAF7F0` 고정 (화선지 질감)** | **`#FAF7F0` 고정 (화선지 질감)** |
| **낙관 인장** | 우측 하단 14×14pt 붉은 사각 낙관 ('墨') | 우측 하단 18×18pt 붉은 사각 낙관 ('數墨') |
| **제목 텍스트** | SF Pro Headline 16pt bold | SF Pro Headline 15pt bold |
| **부제 / 메타 텍스트** | SF Pro Footnote 12pt regular (계열 및 선분 수) | SF Mono Caption 11pt regular (요소수 · 일시) |
| **우측 액션 인디케이터** | 활성 시: 체크원(`checkmark.circle.fill`) / 비활성 시: 꺾쇠(`chevron.right`) | 우측 상단 핀/즐겨찾기 옵션 캡슐 |

---

### 2.5 파이프라인 수직 스테퍼 행 (`PipelineStepRow`)
화면 5(읽기 탭 분석 결과)에서 사진이 수식으로 변환되는 5단계(0~4) 과정을 안내하는 인터페이스.

```
  [0] ─── 방향      회전 90° · 수평 3.2° 보정           79 ms
   │
  [1] ─── 업스케일   1.0× → 3024 × 4032                  0 ms
   │
  [2] ─── 누끼      원본 사용 — 시뮬레이터 미지원        32 ms
   │
  [3] ─── 윤곽      12개 (실루엣 0)                     251 ms
   │
  [4] ─── 농담      DCT 220항 (27×36)                   62 ms
```

| 속성 | 규격 및 값 |
|---|---|
| **스텝 인덱스 번호 원** | 20 × 20 pt 원형 뱃지, 테두리 1pt, 내부 텍스트 SF Mono 10pt bold |
| **수직 연결선** | 두께 1pt 점선 또는 실선 (`Color.inkWash`), 상하 연결 간격 16pt |
| **단계명 (Step Title)** | SF Pro Subheadline 14pt bold, 폭 56pt 좌측 정렬 |
| **상세 내용 (Detail)** | SF Pro Footnote 12pt regular, `Color.inkSoft` |
| **소요 시간 (Elapsed)** | SF Mono Caption 11pt medium (`tabular-nums`), 우측 정렬, `Color.inkSoft` |

---

### 2.6 윤곽 선택 캡슐 칩 (`ContourChipView`)
사진 분석 결과에서 분리된 피사체의 각 윤곽을 켜고 끌 수 있는 가로 스크롤 필터 칩.

- **기본 크기**: 높이 30pt, 수평 패딩 12pt, 원형 캡슐 (`CornerRadius 9999pt`)
- **비선택 상태 (Normal)**:
  - 배경: `Color.paperDeep` (다크: `rgba(255, 255, 255, 0.08)`)
  - 테두리: `Color.inkWash` 0.5pt
  - 텍스트: `SF Mono 12pt`, `Color.inkSoft`
- **선택 상태 (Selected)**:
  - 배경: `Color.vermilion.opacity(0.18)`
  - 테두리: `Color.vermilion` 1pt
  - 텍스트: `SF Mono 12pt bold`, `Color.vermilion`
- **실루엣 속성 (Silhouette)**:
  - 좌측에 `Image(systemName: "person.crop.square")` (11pt) 아이콘 동반

---

### 2.7 주홍 전각 인장 CTA 버튼 (`VermilionActionButton`)
앱 내 최상위 액션(시작하기, 스크립트로 열기, 저장하기 등)을 수행하는 시그니처 버튼.

| 속성 | 규격 및 값 |
|---|---|
| **치수 (Dimensions)** | 가로 `infinity` (전폭), 세로 고정 52pt (`controlSize: .large`) |
| **코너 반경 (Radius)** | `14pt` (`ContinuousRoundedRectangle`) |
| **배경색 (Background)** | 활성: `Color.vermilion` (Light: `#C2412B`, Dark: `#D94E36`)<br>비활성: Light `#E8E4DA`, Dark `#2A2A2C` |
| **텍스트/아이콘 색상**| 활성: `Color.white` / 비활성: `Color.inkSoft` |
| **타이포그래피** | `SF Pro Headline 16pt bold`, 자간 -0.2pt |
| **터치 인터랙션** | `.scaleEffect(configuration.isPressed ? 0.98 : 1.0)` |
| **햅틱 피드백** | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` |

---

## 3. SF Symbols 명세 사전

수묵의 모든 아이콘은 iOS 표준 **SF Symbols 6 (iOS 26/27)**을 기반으로 렌더링되며, 굵기는 `.medium`을 기본으로 합니다.

| 식별자 (Symbol Name) | 용도 및 위치 | 상태 규칙 |
|---|---|---|
| `pencil.tip.crop.circle` | 하단 탭 바 (그리기 탭) | 활성 시 vermilion 틴트, 비활성 시 inkSoft |
| `photo.on.rectangle.angled` | 하단 탭 바 (읽기 탭) | 활성 시 vermilion 틴트 |
| `square.grid.2x2` | 하단 탭 바 (갤러리 탭) & 툴바 프리셋 버튼 | 표준 아웃라인 |
| `arrow.uturn.backward` | 상단 툴바 실행 취소(Undo) | 스크립트 수정/에러/사진 임포트 시 활성화 |
| `arrow.uturn.forward` | 상단 툴바 다시 실행(Redo) | 복구 스택 존재 시 활성화 |
| `square.and.arrow.up` | 공유(Share) 시트 호출 | 표준 툴바 아이콘 |
| `tray.and.arrow.down` | 갤러리에 저장(Save) 액션 | 드로잉 완료 시 활성화 |
| `trash` | 작품 상세 화면 삭제 버튼 | destructive 틴트 지원 |
| `exclamationmark.triangle.fill` | 오류 배너 (`MarginErrorBanner`) | errorInk 전용 틴트 |
| `pencil.and.outline` | '스크립트로 열기' 버튼 접두 아이콘 | 액션 버튼 내 흰색 아웃라인 |
| `person.crop.square` | 실루엣 윤곽 분리 칩 | 인물 피사체 감지 시 노출 |
| `rotate.left` / `rotate.right` | 사진 방향 90도 회전 버튼 | 보더 박스형 아이콘 버튼 |
| `checkmark.circle.fill` | 적용된 프리셋 체크마크 | 주홍 또는 검정 인장 틴트 |

---

## 4. 컴포넌트 간격 및 그리드 규칙

```swift
enum SuMukSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat  = 8
    static let sm: CGFloat  = 12   // 갤러리 그리드 거터 (Grid Gutter)
    static let md: CGFloat  = 16   // 화면 수평 패딩 (Screen Edge Padding)
    static let lg: CGFloat  = 24   // 섹션 간 상하 마진
    static let xl: CGFloat  = 32   // 주요 그룹 간 구분 마진
    static let safeTop: CGFloat = 59    // iPhone 16 Dynamic Island safe area
    static let safeBottom: CGFloat = 34 // Home Indicator safe area
}
```

---

## 5. SwiftUI View 구조 템플릿 예시

```swift
// MARK: - SuMuk Rice Paper Container View Template
struct RicePaperCanvas<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // 다크 모드에서도 밝은 한지 질감 유지
            Color(hex: "FAF7F0")
                .overlay(
                    Image("RicePaperTexture")
                        .resizable(resizingMode: .tile)
                        .opacity(0.04)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            
            content
        }
    }
}
```
