# 수묵(SuMuk) UI 디자인 요청서 — Stitch 프롬프트 패키지

작성일: 2026-10-17 · 대상: 디자인팀 (Google Stitch) · 구현: SwiftUI, iOS 27, iPhone 전용(1차)
현재 구현 스크린샷: `Media/Screenshots/app-overview.png`, `app-shelf-orientation.png` (기능은 모두 동작하는 상태이며, 디자인만 바꾼다)

이 문서는 세 부분이다.
1. **디자인팀에게 드리는 안내** — 무엇을 바꿔도 되고 무엇은 유지해야 하는지, 어떤 형식으로 돌려주면 바로 SwiftUI에 반영할 수 있는지.
2. **Stitch 프로젝트 프롬프트(영문)** — Stitch 프로젝트를 만들 때 처음 넣는 전역 프롬프트. 브랜드·토큰·공통 규칙.
3. **화면별 프롬프트(영문) 9개** — Stitch는 한 번에 한 화면을 잘 만들므로, 화면마다 따로 넣는다. 각 프롬프트는 전역 프롬프트 뒤에 이어서 쓴다.

---

## 1. 디자인팀 안내

### 앱 한 줄 요약
수묵(數墨)은 **수식을 넣으면 그림이 되고, 사진이나 손그림을 넣으면 그것을 이루는 수식이 되는** iPhone 앱이다. 수천 개의 선분·원·점이 짧은 수식 하나에서 태어나고(선분 가족, 원 가족, 점 계열), 사진은 윤곽(곡선)과 농담(점)으로 구조화된다. 정체성은 먹과 화선지 — 검은 먹 한 가지 색의 농담으로 그림을 만드는 동양화의 감각이다.

### 반드시 유지할 것 (정보 구조와 기능)
- 탭 3개와 순서: **그리기**(수식 → 그림) · **읽기**(사진 → 수식) · **갤러리**.
- 그리기 탭의 핵심 레이아웃 원리: 위에 **캔버스 미리보기**, 아래에 **스크립트 편집기**. 스크립트 텍스트가 유일한 진실이라 편집기는 항상 접근 가능해야 한다(접을 수는 있어도 없앨 수는 없다).
- 화면의 모든 문구는 **한국어**, 현재 문구를 그대로 쓴다(아래 화면별 프롬프트에 그대로 적었다). 단위 용어는 "계열"(선분 계열·원 계열·곡선·점).
- 수식 자체는 **모노스페이스**로, 수학 기호(π · √ ² θ δ)가 깨지지 않아야 한다.
- 표준 컨트롤 사용: iOS 26/27의 **Liquid Glass** 탭 바·툴바·시트를 그대로 쓴다. 커스텀 글래스 효과는 캔버스 위 떠 있는 상태 칩과 변수 슬라이더 패널 정도에만 쓴다(HIG: 콘텐츠 레이어에는 글래스를 쓰지 않는다).
- 접근성: Dynamic Type(본문 기준 최대 접근성 3단계까지 레이아웃 유지), 대비 4.5:1 이상, 모든 아이콘 버튼에 라벨. 모션 감소 설정 시 애니메이션 없음.
- 다크 모드 필수. 캔버스의 "화선지" 배경은 다크 모드에서도 밝은 종이색을 유지한다(먹그림은 밝은 종이 위에 있어야 한다). UI 크롬만 어두워진다.

### 바꿔도 되는 것 (디자인 재량)
- 색상 토큰·타이포 위계·여백·코너 반경·아이콘 선택(SF Symbols 안에서)·일러스트·빈 상태·온보딩·앱 아이콘·시트와 서랍의 구성·상태 칩과 배너의 모양.
- 그리기 탭 편집기의 접기/펼치기 방식, 변수 슬라이더 패널의 배치(캔버스 하단 오버레이 vs 별도 행).
- 읽기 탭의 단계 표(0 방향 ~ 4 농담)를 "진행 스텝퍼"처럼 더 시각적으로 바꾸는 것.

### 돌려주실 때 필요한 형식 (이 형식이면 바로 반영됩니다)
1. **Stitch 프로젝트 링크 + Figma 내보내기**(Stitch → Figma).
2. **화면 PNG** @3x, iPhone 16(393×852 pt) 기준, 라이트/다크 각 1장, 아래 9개 화면 전부.
3. **디자인 토큰 JSON** 1개: 색(라이트/다크 쌍, hex), 타이포(스타일 이름 → SF Pro 텍스트 스타일 또는 크기/굵기/행간), 간격 스케일, 코너 반경, 그림자/글래스 사용 위치. 토큰 이름은 아래 "토큰 이름표"를 따라 주시면 SwiftUI `Color`/`Font` 확장과 1:1로 대응됩니다.
4. **SF Symbols 이름 목록**: 버튼·탭·상태마다 사용한 심볼의 정확한 이름(예: `pencil.tip.crop.circle`). 커스텀 아이콘이 있으면 SVG(단색, 24pt 그리드).
5. **컴포넌트 명세** 1장: 상태 칩, 오류 배너, 변수 슬라이더 행, 윤곽 칩(선택/비선택/실루엣), 단계 행, 프리셋 셀, 갤러리 셀의 크기·여백·상태(기본/눌림/비활성/선택).
6. Stitch가 생성한 HTML/CSS는 참고용으로만 받습니다(SwiftUI로 직접 옮깁니다).

### 토큰 이름표 (SwiftUI에서 쓸 이름)
| 토큰 | 의미 | 현재 값(참고) |
| --- | --- | --- |
| `paper` | 캔버스 화선지 배경 | #FAF7F0 |
| `paperDeep` | 종이의 어두운 톤(그림자·가장자리) | #EFE9DC |
| `ink` | 먹색(그림·주요 텍스트) | #141414 |
| `inkSoft` | 옅은 먹(보조 텍스트) | #6E6E73 |
| `inkWash` | 아주 옅은 먹(구분선·비활성) | #D9D4C8 |
| `vermilion` | 낙관(인장) 색 — 강조·선택·활성 1색 | 제안: #C2412B 계열 |
| `errorInk` | 오류 배너 | 붉은 계열(접근성 대비 확인) |
| `chromeLight` / `chromeDark` | UI 크롬 배경(탭 바 뒤) | 시스템 배경 |
| 타이포 | `title`(화면 제목), `body`, `caption`, `mono`(스크립트), `monoCaption`(상태 칩·수치) | SF Pro / SF Mono |

---

## 2. Stitch 프로젝트 전역 프롬프트 (영문 — 그대로 붙여넣기)

```
PROJECT: SuMuk (수묵 · 數墨) — iPhone app, iOS 26/27, SwiftUI, Korean UI.

WHAT THE APP DOES
SuMuk turns formulas into pictures and pictures back into formulas. A short script defines
"families": thousands of line segments, circles or dots generated from one parameter k
(e.g. 700 segments whose endpoints are trigonometric functions of k form a ginkgo leaf).
The "Read" tab takes a photo, lifts the subject, finds contours and tone, and writes a script
of curves (Fourier series) and dots (stipple whose density follows darkness).

BRAND & MOOD
East-Asian ink-wash painting (sumuk-hwa) made of mathematics. One ink colour on rice paper;
depth comes from density and dilution, never from colour. Calm, precise, scholarly, slightly
warm. Think: a quiet studio desk — paper, ink stone, a single vermilion seal stamp.
Avoid: neon gradients, glassmorphism in content areas, playful rounded blobs, stock "AI" purple.

VISUAL LANGUAGE
- Canvas ("paper"): warm off-white #FAF7F0, stays light even in dark mode. Drawings are ink
  #141414 with alpha for wash. The canvas is the hero on every screen that has one.
- UI chrome: native iOS 26 Liquid Glass tab bar, toolbars and sheets (do not restyle them).
  Use glass only for small floating elements over the canvas (a status chip, a variable
  slider panel). Content areas use flat paper/neutral surfaces.
- Accent: a single vermilion "seal" red (≈ #C2412B) used sparingly: selected states, the
  primary action button, the active tab tint. Everything else is ink greys.
- Typography: SF Pro for UI (Korean text renders in Apple SD Gothic Neo automatically).
  All formulas and the script editor in SF Mono. Math glyphs π · √ ² θ δ must render.
- Icons: SF Symbols only. Prefer outline weights; filled variants for selected states.
- Corners: 12–16 pt on cards and sheets, capsules for chips. Hairline separators in inkWash.
- Spacing scale: 4 / 8 / 12 / 16 / 24 / 32.
- Dark mode: chrome becomes dark neutral (#111 / #1C1C1E), paper canvas stays light,
  ink stays dark on paper, text on chrome becomes light.
- Accessibility: WCAG AA contrast on all text, Dynamic Type friendly (no fixed-height text
  containers), 44 pt hit targets, every icon button has a Korean label.

LAYOUT FRAME
iPhone 16, 393 × 852 pt, safe areas. Floating Liquid Glass tab bar with three tabs:
그리기 (pencil.tip.crop.circle) · 읽기 (photo.on.rectangle.angled) · 갤러리 (square.grid.2x2).
Navigation bar with inline title and toolbar buttons (glass).

ALL UI TEXT IS KOREAN. Use the exact strings given in each screen prompt. Numbers use
tabular (monospaced) digits. Do not invent English labels.

DELIVERABLES PER SCREEN: light + dark variant, default state plus the listed states.
```

---

## 3. 화면별 프롬프트 (영문)

### 화면 1 — 그리기 탭 기본 (Draw tab, default)

```
SCREEN: 그리기 (Draw) — the main screen.

Structure, top to bottom:
1. Navigation bar, inline title "수묵". Leading toolbar group: undo (arrow.uturn.backward),
   redo (arrow.uturn.forward), both disabled in this state. Trailing group: presets
   (square.grid.2x2), share (square.and.arrow.up), save to gallery (tray.and.arrow.down).
2. CANVAS — the hero, fills most of the height. Paper #FAF7F0 with a subtle paper texture
   (optional, very low contrast). On it an ink drawing: a ginkgo leaf made of ~820 thin line
   segments fanning from a stem to a wavy edge (use the reference image
   Media/Samples/sumuk-ginkgo.png). Top-left floating status chip (glass capsule, caption,
   monospaced digits): "계열 2 · 선분 820 · 4 ms".
3. VARIABLE PANEL — a compact strip under the canvas with two slider rows, each:
   monospaced name on the left ("notch", "ripple"), system slider, monospaced value on the
   right ("0.24", "0.03"). This panel appears only when the script declares `let` variables.
4. SCRIPT EDITOR — bottom ~35% of the screen. Monospaced text, left aligned, line height
   1.45, paper-tinted or neutral surface. Show this exact text:

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

   Light syntax tinting is welcome: keywords (segments, circles, curve, points, where, let,
   from, to, at, when) in inkSoft, numbers in ink, comments in inkWash-dark. Keep it subtle.
5. Floating Liquid Glass tab bar, 그리기 selected (tint vermilion).

States to deliver:
A. Default (above).
B. Editor focused: the keyboard is up, and a glass accessory bar above the keyboard with
   monospaced symbol keys "π · ^ ( ) √ | sin( cos( exp( …" and a trailing "완료" button.
   The canvas shrinks but stays visible.
C. Parsing: the status chip shows a tiny spinner before the text.
```

### 화면 2 — 그리기 탭 오류 상태 (Draw tab, error banner)

```
SCREEN: 그리기 — script error.

Same as screen 1, but the user typed an invalid line. The LAST GOOD drawing stays on the
canvas (we never blank it). At the bottom edge of the canvas, a red error banner (rounded
10 pt, white text, exclamationmark.triangle.fill icon) with the exact text:
"3행 25열: 한 줄에는 문장 하나만 쓸 수 있습니다"
The variable panel is hidden while an error is shown. Undo becomes enabled.
Design the banner so it reads as "a note on the margin of the paper", not a system alert:
small, left-aligned, dismisses itself when the script becomes valid.
```

### 화면 3 — 프리셋 서랍 (Presets sheet)

```
SCREEN: 프리셋 — a sheet presented from the Draw tab.

Navigation title "프리셋", trailing "닫기". A list of six rows; each row has a 64×64 pt
square thumbnail (the app renders the preset live on paper), a bold title and a caption:
1. 은행잎 — "선분 820개 · 잎자루에서 물결치는 가장자리로"   (thumbnail: Media/Samples/sumuk-ginkgo.png)
2. 달항아리 — "원 4,400개 · 중심은 항아리 윤곽, 반지름은 붓 압력" (sumuk-moon-jar.png)
3. 매화 — "원 3,561개 · 꽃잎 5장 × 700 + 수술 60"            (sumuk-plum-blossom.png)
4. 잉어 — "선분 2,760개 · 교차 해칭 몸통 + 부채꼴 꼬리"        (sumuk-carp.png)
5. 학 — "선분 2,760개 · sin⁷ 날개 + S자 목"                   (sumuk-crane.png)
6. 빈 시작 — "선분 계열 하나로 시작"                          (a single bird-like segment family)
Consider a 2-column card grid instead of a list if it reads better; thumbnails are the point.
Tapping a row loads it and dismisses. Deliver: sheet at medium detent and at large detent.
```

### 화면 4 — 읽기 탭 빈 상태 (Read tab, empty)

```
SCREEN: 읽기 · 사진 → 수식 — empty state before a photo is chosen.

Navigation bar inline title "읽기 · 사진 → 수식", trailing toolbar button "사진" (photo icon)
labelled "사진 고르기". Content scrolls:
1. A 380 pt tall preview card (rounded 14 pt, neutral surface) with an empty-state
   illustration in ink-line style (a photo frame turning into contour lines and dots) and
   the text: title "사진 없음", body "사진을 고르면 업스케일 → 누끼 → 윤곽 → 곡선과 점 수식으로 바꿉니다."
2. Controls (all present but inert until a photo exists):
   - Toggle row with icon scribble.variable: "곡선 — 윤곽을 푸리에 곡선으로" (on)
     · under it a slider row "조화 16" (range 2–64)
   - Toggle row with icon ellipsis.circle: "점 — 윤곽을 점선으로" (off)
   - Toggle row with icon circle.grid.3x3.fill: "점 — 농담을 밀도로 (스티플)" (on)
     · slider rows "점 6,000" (1,000–12,000) and "감마 1.00" (0.3–3)
   - Toggle "어두운 윤곽 (밝은 배경)" (on)
   - Primary button, full width, vermilion: "스크립트로 열기" with pencil.and.outline, disabled.
Make the toggles read as a short "recipe" list: icon, label, and the dependent sliders
indented beneath. Deliver light/dark.
```

### 화면 5 — 읽기 탭 분석 결과 (Read tab, result)

```
SCREEN: 읽기 — after choosing a photo (a convenience-store snack shelf, rotated upright).

1. Preview card: the photo dimmed to ~45% with an ink overlay drawn exactly on top of it:
   12 thin contour curves along shelf edges and boxes, plus a field of small ink dots whose
   density follows darkness (dense on dark packaging, sparse on bright labels). Top-right
   inside the card: a tiny glass toggle button "누끼" / "원본" (only when a subject was cut
   out). Top-centre transient chip "수식 다시 계산 중…" with a mini spinner (state B).
2. PIPELINE STEPS card — five compact rows, each: a small numbered circle, a bold step name,
   a detail, and a right-aligned monospaced time. Exact rows:
   0  방향    회전 90° · 수평선 3.2° 보정됨                 79 ms
   1  업스케일 1.0× → 3024 × 4032                          0 ms
   2  누끼    원본 사용 — 시뮬레이터 미지원 (실기기에서 동작)  32 ms
   3  윤곽    12개 (실루엣 0)                               251 ms
   4  농담    DCT 220항 (27×36)                             62 ms
   Design this as a vertical stepper with a thin ink line connecting the numbers. Step 2
   should be able to show a success variant: "피사체 분리됨 (배경 흰색)".
3. ORIENTATION row: label "방향", two small bordered icon buttons rotate.left / rotate.right,
   a monospaced angle "90°", and a mini toggle "수평 자동 보정".
4. CONTOUR CHIPS: header "윤곽 선택 (면적순)" with two small buttons on the right
   "모두 선택" / "해제"; below, a horizontally scrolling row of capsule chips showing point
   counts: "7,141점" "1,887점" "1,337점" "1,384점" "679점" "539점" … Selected chips are tinted
   vermilion at 20% with a vermilion outline; silhouette chips carry a person.crop.square icon.
5. The same toggles/sliders as screen 4, now active.
6. Result card: header "결과 스크립트" with a right-aligned caption "윤곽 오차 0.37% · 26221자",
   then a monospaced preview of the first lines of the script:
   // 사진 → 수식 (회전 90° → 수평 보정 3.2° → 업스케일 1.0× → Vision 윤곽 → 푸리에 16조화 → 곡선 + 농담 점)
   canvas 750 × 1000
   ink #141414 width 0.5 alpha 0.8
   let gamma = 1 in [0.3, 3]
7. Primary button "스크립트로 열기" (enabled).

States: A result (above) · B recomputing chip · C analysing overlay: a glass panel centred on
the preview with a large spinner and "분석 중…" · D failure note at the bottom-left of the
preview: small glass label with exclamationmark.triangle "분석 실패: …".
```

### 화면 6 — 그리기 탭, 가져온 사진 결과 (Draw tab with imported photo script)

```
SCREEN: 그리기 — after "스크립트로 열기" from the Read tab.

Canvas shows a portrait-format paper (the script declares `canvas 750 × 1000`, so the drawing
area is a 3:4 rectangle centred on the paper) with 12 fine contour curves and ~2,200 stipple
dots forming the shelf picture. Status chip: "계열 13 · 곡선 9600 · 점 2202 · 2775 ms".
Variable panel shows one row: "gamma" slider with value "1". Script editor shows the
imported script (first line "// 사진 → 수식 (회전 90° → …"). Undo enabled.
```

### 화면 7 — 갤러리 그리드 (Gallery)

```
SCREEN: 갤러리 — large title "갤러리".

Adaptive grid, 2 columns on iPhone, 12 pt gutters. Each cell: a square paper thumbnail with
the ink drawing (rounded 12 pt), a bold single-line title ("학", "달항아리", "초상 — 진열대"),
and a caption "요소 2,760 · 2026. 10. 17. 오후 1:52". Empty state: tray icon, title
"저장된 작품 없음", body "그리기 탭에서 저장하면 여기에 모입니다." Deliver both the populated
grid (6 cells) and the empty state.
```

### 화면 8 — 작품 상세 (Saved artwork detail)

```
SCREEN: 작품 상세 — pushed from the gallery, inline title is the artwork title ("학").

1. A 360 pt tall paper canvas with the drawing (rounded 14 pt).
2. Action row: primary vermilion button "스크립트로 열기" (pencil.and.outline) taking most of
   the width, then bordered "공유" (square.and.arrow.up) and a bordered trash button.
3. Section header "스크립트", then the full script in a monospaced block on a neutral
   surface, selectable text.
State B: destructive confirmation alert "이 작품을 삭제할까요?" with "삭제" (destructive) and
"취소".
State C (save flow, from the Draw tab): alert titled "갤러리에 저장" with a text field
prefilled "학", message "스크립트 원문이 저장되고, 썸네일은 언제든 다시 그려집니다.", buttons
"저장" / "취소"; afterwards a small glass toast at the top of the canvas "갤러리에 저장했습니다".
```

### 화면 9 — 앱 아이콘과 온보딩 카드 (App icon + first-launch)

```
APP ICON: iOS 26 layered icon. Background: rice-paper off-white with a faint ink wash
gradient. Foreground: a crane drawn as ~40 thin ink segments whose envelope forms the wing
(reference Media/Samples/sumuk-crane.png, simplified for 1024 px), and a small vermilion seal
square in the lower-right corner containing the character 墨 in white. Provide light, dark
and tinted variants per Apple's icon guidance; the seal is the only colour.

FIRST LAUNCH (optional, single screen, skippable): three short cards on paper —
"수식은 그림으로" (a bird made of segments), "그림은 수식으로" (a photo turning into contour
lines and dots), "하나의 먹색, 농담으로" (dots dense to sparse) — with a vermilion button
"시작하기". Korean copy exactly as given.
```

---

## 4. 참고 이미지 (프롬프트에 첨부하면 좋은 것)

| 파일 | 용도 |
| --- | --- |
| `Media/banner.png` | 브랜드 톤(제목 서체 느낌, 종이색, 학·달항아리) |
| `Media/Samples/sumuk-*.png` | 프리셋 썸네일 5종 원본 렌더 |
| `Media/Screenshots/app-overview.png` | 현재 구현 전 화면(정보 구조 기준) |
| `Media/Screenshots/app-shelf-orientation.png` | 읽기 탭 회전 전/후와 그리기 결과 |
| `Media/formula-card.png` | 수식 조판의 참고(STIX 이탤릭 느낌은 카드용, 앱 본문은 SF Mono) |

## 5. 받은 뒤 반영 계획 (개발 측)

1. 토큰 JSON → `Resources/Colors.xcassets`(라이트/다크 쌍) + `Theme.swift`(`Color.paper`, `.ink`, `.vermilion`, `Font.mono` …).
2. 화면별 PNG를 기준으로 `DrawTabView`·`ReadTabView`·`GalleryTabView`·`PresetDrawerView`·`SavedArtworkDetailView`의 레이아웃·간격·컴포넌트 스타일을 교체. 기능 코드(`EditorModel`, 파서, 렌더러, 구조화 파이프라인)는 건드리지 않는다.
3. 아이콘: 1024 PNG(라이트·다크·틴티드) → `AppIcon.appiconset`.
4. 반영 후 iPhone 16 시뮬레이터에서 라이트/다크, Dynamic Type 접근성 3단계, VoiceOver 라벨을 다시 검증하고 스크린샷을 갱신한다.
