# TASKS — 수묵 (SuMuk)

범례: `[x]` 완료 · `[ ]` 미착수 · `[~]` 부분 완료/확인 필요
근거 문서: `Docs/PRD-SuMuk.md` (FR 번호는 PRD와 동일)
참고 프로젝트: `Desktop/MathSketch` — MathEngine·PixelFormula·SwiftData·`FitContext` 패턴 이식

## Phase 0 — 프로젝트 셋업 (2026-10-17 문서 작업 완료, 코드 미착수)

- [x] T0.1 저장소 폴더 `Desktop/SuMuk` 생성, `LICENSE`(Apache 2.0), `.gitignore`(Xcode), `.gitattributes`, `Docs/`, `Media/` 준비, `git init`.
- [x] T0.2 기술 PRD(`Docs/PRD-SuMuk.md`)·태스크 문서(이 파일)·`README.md` 작성.
- [x] T0.3 수묵 원작 샘플 5종 설계·렌더(`Media/src/render_samples.py` 렌더 헬퍼, `originals.py`, `make_readme_images.py`), README 이미지(배너·그리드·수식 카드·파이프라인 SVG). 처음에 함께 만들었던 Yeganeh 공식 재현 렌더 5종은 사용자 결정(외부 이미지·공식 미사용)으로 저장소·문서에서 제거.
- [~] T0.4 Xcode 프로젝트(2026-10-17 저녁): `PRODUCT_NAME = SuMuk`, `PRODUCT_BUNDLE_IDENTIFIER = com.coulson.SuMuk`, `CFBundleDisplayName = 수묵`, `TARGETED_DEVICE_FAMILY = 1`, `SUPPORTED_PLATFORMS = iphoneos iphonesimulator` 적용. **타깃 이름은 아직 `MyApp`**(도구로 개명 불가). 프로젝트 본체는 여전히 Xcode의 `UntitledProjects/Untitled Project`에 있고, 저장소에는 `SuMukApp/`(xcuserdata 제외 rsync 스냅샷, `SuMuk.xcodeproj`로 개명)로 복사. Xcode에서 File ▸ Save로 `Desktop/SuMuk/SuMukApp`에 저장하면 스냅샷이 본체가 된다.
- [~] T0.5 그룹 구조: `MathEngine/ Script/ Family/ Render/ Structuring/ Presets/ Model/ Persistence/ Views/` 생성. `Assistant/ Resources/`와 테스트 타깃 `SuMukTests`는 미생성.
- [x] T0.6 첫 커밋 + GitHub 공개 저장소(kimminung/SuMuk) 푸시.

## Phase 1 — MathEngine 이식 + SuMuk Script 파서 (FR-1)

- [x] T1.1 MathSketch `MathLexer/MathAST/MathEvaluator` 이식(`nonisolated`), 행·열 포함 `MathSyntaxError`. 평가기는 트리 워킹 대신 **`ExpressionCompiler`(슬롯 배열 위 클로저, 사용자 함수 인라인, 정수 거듭제곱 `ipow`)** 로 교체 — 프리셋 3,500원 평가 25 ms.
- [x] T1.2 렉서: `· × − π √ … ∈ | ²³⁷`, `#RRGGBB`, `//` 주석, 줄바꿈 토큰, 지수 표기 `1e-5`. π·τ·√는 항상 한 글자 식별자(`2πk` = 2·π·k), 위첨자는 `^n`으로 분해. (Σ·⌊⌋·아래첨자 `_{…}`는 미지원)
- [x] T1.3 `FamilyParser`: canvas · ink · let … in [a,b] · segments · circles · curve … samples · where(함수·상수 정의) · 가족별 ink. 병치 곱셈(·와 같은 우선순위, 좌결합), `sin^7(x)`(뒤에 `(`가 올 때만), `|x|`, `√x`, `sin k`, 줄 연속 규칙(연산자로 끝/시작하면 다음 줄 계속). **미지원**: `pixel`(오류 메시지), `animate`, 복소수 표기.
- [ ] T1.4 `ScriptFormatter`: 미착수.
- [x] T1.5 자유 변수(가족 변수·let·상수·where 매개변수만 허용)·인자 수·상한(가족 20, 요소 1,000,000, 50,000자) 검증, 오류에 가족/정의의 행 번호 포함.
- 설계 메모: 사용자 함수 이름 수집은 "줄 시작의 `이름(…) =`" 패턴 선스캔 → 그래서 `x1(2πk/600)`은 호출, `k(2π…)`는 곱셈. 정의 이름과 매개변수 이름이 겹치면(`x(k)` 정의 + `top(x)` 매개변수) 혼동되므로 프리셋에서는 `px(k)`로 회피했고, 파서도 `x^2` 뒤에 `(`가 없으면 거듭제곱으로 읽는다.
- [ ] T1.6 `CaptionImporter`(영어 캡션 문장 → Script), `LaTeXImporter`(PixelFormula 전처리기 확장), 입력 종류 판별(`ScriptKindDetector`: Script / 캡션 / LaTeX / 픽셀).
- [ ] T1.7 테스트: 원작 프리셋 5종 파싱 → 특정 k에서 끝점·중심·반지름이 numpy 생성기(`Media/src/originals.py`)와 1e-9 내 일치(값은 Python으로 생성해 픽스처로 저장), 캡션 임포트(합성 문장 5종), 오류 사례 10종, 왕복.

## Phase 2 — 평가기 + Canvas 렌더 + 프리셋 (FR-2, FR-3 일부)

- [x] T2.1 `ExpressionCompiler`(클로저 트리, `where` 인라인 깊이 ≤ 16). 바이트코드·vDSP 벡터화는 Metal 단계(Phase 4)에서 함께.
- [x] T2.2 `FamilyEvaluator`: 가족별 k 루프, NaN/∞ 요소 제외, 평가 시간 기록. 측정(시뮬레이터): 은행잎 820선분 4 ms · 달항아리 4,400원 18 ms · 매화 3,561원 21 ms · 잉어 2,760선분 5 ms · 학 2,760선분 8 ms.
- [x] T2.3 `FitContext` + `FamilyRenderer`(SwiftUI Canvas, 선분·원(외곽/채움)·폴리라인, 먹색·두께·알파, 화선지 배경, `canvas` 지정 시 사진 비율 프레임, 오버레이용 padding 0).
- [x] T2.4 프리셋 5종을 Swift 문자열 Script로 이식(`Presets.swift`; JSON은 나중). 매화는 5꽃잎을 `floor((k−1)/700)`로 한 가족에, 학의 다리 2개는 `mod`/`floor`로 한 가족에 합침. 학 목의 법선은 `np.gradient` 대신 닫힌형 도함수.
- [x] T2.5 `DrawTabView` + 프리셋 서랍(썸네일 즉석 렌더). iPhone 16 시뮬레이터에서 5종 육안 확인, 스크린샷 `Media/Screenshots/app-*.png`.

## Phase 3 — 에디터 UX (FR-4)

- [x] T3.1 `EditorModel(@Observable)`: 120 ms `Task.sleep` 디바운스 → `Task.detached` 파싱/평가 → 마지막 성공 렌더 유지 + 오류 배너(행·열). 오류 중에는 let 슬라이더 숨김.
- [~] T3.2 키보드 액세서리(`π · ^ ( ) √ | sin( cos( exp( …`)만. 하이라이팅 미착수.
- [ ] T3.3 숫자 스크러빙 미착수.
- [~] T3.4 `let` 슬라이더 완료(드래그 1회 = undo 1단계, 정수 범위면 정수 스텝 — δ·wing). `animate`는 미착수.
- [x] T3.5 Undo/Redo(최대 100). 전체 지우기는 "빈 시작" 프리셋으로 대체.
- [~] T3.6 프리셋 서랍 완료, 수식 카드 미리보기 미착수. 스크립트 교체·undo 시 에디터가 끝으로 스크롤되던 문제는 `scriptVersion` id로 해결.
- QA에서 잡은 버그(2026-10-17): (1) 렉서가 `πk`를 한 식별자로 읽어 프리셋 4종 실패 → π·τ·√ 단독 토큰화. (2) `k²`의 위첨자가 `isNumber`라 식별자/숫자에 섞임 → 위첨자 우선 분기. (3) `canvas 993 × 1000`을 식으로 파싱해 곱해 버림 → 숫자 토큰만 허용. (4) `x(k)` 정의가 있으면 `top(x)`의 `x^2`를 `x^2(…)` 함수 표기로 오인 → `(` 선행 확인. (5) 검증 오류 위치가 항상 1행 1열 → 가족/정의 행 추적.

## Phase 4 — Metal 대형 렌더 + 내보내기 (FR-2 GPU, FR-3)

- [ ] T4.1 `MetalShaderTranspiler` 일반화(가족 식 → 컴퓨트 커널, 끝점/중심/반지름 버퍼), `mathMode = .safe`, `dispatchThreadgroups` + 밴드 분할.
- [ ] T4.2 `MetalFamilyRenderer`: 인스턴스드 쿼드 + SDF(선분 두께·끝 모양, 원 외곽선/채움), MSAA 또는 SDF AA, 뷰 변환(핀치/드래그).
- [ ] T4.3 경로 자동 선택(요소 ≤ 5,000 Canvas, 초과 Metal), Metal 불가 시 폴백 + 안내.
- [ ] T4.4 벤치: 1,000,000 선분 1024px ≤ 1.0s, 100,000 원 ≤ 16ms(실기기 측정값 기록).
- [ ] T4.5 `Exporter`: PNG(1024/2048/4096, 투명 옵션), SVG(≤ 20,000 요소), 수식 카드 PNG(그림 + 조판 수식 + 출처), Script/LaTeX 텍스트, `ShareLink`.
- [ ] T4.6 시뮬레이터에서 Metal 경로 실제 실행 확인(MathSketch 교훈: Mac 호스트 GPU에서 되는 것과 별개).

## Phase 5 — 그림 → 수식 Tier A (FR-5)

- [~] T5.1 입력: `PhotosPicker` 완료. `fileImporter`·PencilKit·카메라 미착수.
- [~] T5.2 `ContourStructurer.extractContours`: `VNDetectContoursRequest`(darkOnLight 토글, 1024px), 면적(신발끈 공식) 순 12개, 수학 좌표 정규화. RDP ε 슬라이더 미착수.
- [~] T5.3 윤곽 선택: 칩(#id · 점 수) 탭 토글, 기본 최대 윤곽 1개. 색 구분 오버레이 미착수.
- [x] T5.4 `FourierCurve`: 호 길이 재매개변수화(512샘플) → 실수 DFT(조화 2~64) → 소수 4자리 계수 → `where` 정의 문자열.
- [~] T5.5 합성 3종(`curve` / 현 가족 `let δ` 기본 100 / 붓 원 가족). 해칭 가족 미착수.
- [~] T5.6 평균 오차(%)·문자 수 표시. 최대 오차·오버레이 3모드 미착수.
- [~] T5.7 `ReadTabView`: 사진 → 윤곽 칩 → 변환 세그먼트·조화 슬라이더 → 오버레이(사진 비율, padding 0) → "스크립트로 열기"(그리기 탭 전환). 시뮬레이터 샘플 사진(하트 윤곽)으로 왕복 확인: 윤곽 2개 57~69 ms, 평균 오차 0.15%, 현 가족 600선분 3 ms.
- [ ] T5.8 테스트: 합성 도형(원·별·하트 폴리라인)의 푸리에 재구성 오차 < 0.5%, 현 가족 Script가 파서로 다시 읽히고 요소 수 일치, 1024px 사진 전체 파이프라인 ≤ 1.5s(실기기).

### Phase 5 2차 (2026-10-17 저녁, 사용자 피드백 "누끼가 약하다 · 곡선과 점만")

- [x] T5.8 전처리: Core Image Lanczos 업스케일(긴 변 2048, 최대 4×, 배율 표시) + 언샤프 마스크(반경 2, 강도 0.4) 후 인식.
- [x] T5.9 누끼: `VNGenerateForegroundInstanceMaskRequest`(사진 앱 피사체 들어올리기 모델) → 마스크 → `CIBlendWithMask`로 배경 흰색화. 실루엣 윤곽은 마스크 이미지에서 따로 추출해 "실루엣" 표식과 함께 1순위 선택. 피사체가 없으면 원본으로 폴백하고 UI에 알림.
- [x] T5.10 출력 단위를 **곡선 + 점**으로 축소: 현 계열·붓 원 계열 모드 제거. 새 `points` 계열(`at` · `size?` · `when?`)과 비교 연산자(`> < ≥ ≤`, 1/0)를 파서·평가기·렌더러에 추가. 농담은 36행 DCT 급수 `D(x,y)`(3×3 블러 후 상위 220항)를 `where`에 그대로 써 넣고, Vogel 나선 위 점 N개를 **확률적 스티플** `when (D^gamma > mod(0.618034·k, 1))·(D > 0.08)·(|X|<a)·(|Y|<1)`로 남긴다 — 점 밀도 ∝ 농담^γ(`let gamma` 슬라이더, 점 개수 슬라이더). 처음 시도한 고정 임계값(`D > dots`)은 중간 톤이 넓은 사진에서 점이 균일하게 깔려 명암이 안 보였다(QA에서 확인). 윤곽은 선택적으로 `points k { at (x1(2πk/m), y1(2πk/m)) }` 점선으로도 출력. 합성 이미지(원반) 검증: 윤곽 오차 0.0004, 스크립트 9.9 KB, 파싱+평가 0.48 s.
- [x] T5.11 읽기 탭 UI: 단계 표(업스케일 배율·누끼 여부·윤곽 수·DCT 항 수, 각 ms), 누끼/원본 미리보기 토글, 곡선·점 토글, 조화·점 개수·임계 슬라이더. `UIImage` 회전 메타데이터를 픽셀에 구워 Vision과 오버레이의 위쪽을 맞춤.
- 함정: `CGBitmapContext` 메모리의 0번째 행이 이미지의 **위쪽**이다(뒤집으면 농담이 상하 반전). DCT 절단은 깁스 링잉으로 흰 영역에 ±0.2의 가짜 농담을 만들므로 블러 후 절단. 선 그림은 36행 그리드에서 획이 0.1 수준으로 희석되므로 98퍼센타일을 1로 늘리는 대비 스트레치 적용.
- **크래시 수정**: 220항 급수가 왼쪽 깊은 덧셈 트리로 파싱되어 `ExpressionCompiler`가 220단계 재귀 → 협력 스레드(512 KB 스택) 오버플로. 덧셈·뺄셈 사슬을 평탄화해 항 배열을 반복문으로 합산(1,000항 검증).
- **시뮬레이터 한계**: `VNGenerateForegroundInstanceMaskRequest`는 시뮬레이터에서 "Could not create inference context"로 실패(모든 사진). UI에 "시뮬레이터 미지원 (실기기에서 동작)"으로 표시하고 원본으로 폴백. 마스크 요청은 1536px 축소본에서 수행(큰 RGBA 버퍼 -6680 오류 회피). **실기기 검증 필요(T11.1)**.
- 성능 메모: 점 12,000개 × D(220항) 평가 2.95 s, 6,000개 약 1.5 s. Phase 4(Metal/vDSP)에서 D를 그리드로 미리 계산하거나 GPU로 옮길 것. 슬라이더는 150 ms 디바운스 + 최신 결과만 반영.

### Phase 5 3차 (2026-10-17 저녁, 사진 방향 재정비)

- [x] T5.12 방향 단계(0번) 추가: 시계/반시계 90° 회전 버튼(EXIF 없이 옆으로 저장된 사진용) + `VNDetectHorizonRequest` 수평선 각도 표시와 자동 수평 보정 토글(|각도| 0.3°~45°일 때 중심 회전, 바깥은 흰색). 스크립트 머리말에 "회전 90° → 수평 보정 3.2° →"로 기록.
- [x] T5.13 윤곽 "모두 선택 / 해제" 버튼, 모두 선택 상태는 재분석(회전·수평·대비) 후에도 유지.
- [x] T5.14 편의점 진열대 사진(4032×3024, EXIF 방향 없음, 옆으로 저장)으로 QA: 회전 전 선반이 세로 → ↻ 90° 후 가로·간판 바로 섬, 수평선 3.2° 보정, 윤곽 12개 모두 선택 시 곡선 12 + 스티플 2,202점, 스크립트 26 KB, 그리기 탭에서 2.9 s 렌더. 스크린샷 `Media/Screenshots/app-shelf-orientation.png`.
- [x] T5.15 성능: 복잡한 사진에서 윤곽 단계가 20~34 s 걸린 원인은 `VNDetectContoursRequest.perform` 자체였다 — 인쇄 글자·포장 질감이 수천 개의 미세 윤곽을 만들어 추적이 느려진다(Mac 호스트 측정: 1024px 그레이 블러 없음 20.6 s/3,216개, 768px 6.0 s, 512px 0.9 s; **1024px + 가우시안 블러 1.5 → 0.17 s/539개, 60점 이상 161개**). 윤곽 요청 입력을 "CoreGraphics 8비트 그레이스케일 1024px + 블러 1.5"로 통일(실루엣 마스크 윤곽은 블러 없이 그레이). 점 배열 변환은 pointCount 순위 상위 60개만 수행.
- 메모: 수평선 검출은 ±45° 범위의 기울기만 잡고 90° 단위 회전은 알 수 없으므로 수동 버튼이 필요하다. 추후 후보: 텍스트 방향(`VNRecognizeTextRequest`)으로 90° 회전 자동 제안.

## Phase 3b — Stitch UI 테마 적용 (2026-10-17 저녁)

디자인팀이 Stitch로 만든 두 세트(라이트 "Literati Ink", 다크 "SuMuk Ink & Glass")와 토큰 JSON·컴포넌트 명세를 받아 반영. 원본은 `Design/stitch/`.

- [x] T3b.1 `Theme/SuMukTheme.swift`: 색 토큰(paper 고정 #FAF7F0, paperDeep·inkText·inkSoft·inkWash·vermilion·errorInk·celadon 라이트/다크 쌍, `nonisolated` UIColor 동적 프로바이더), 모노 폰트, 간격·반경 상수, 공용 컴포넌트(SealStampView 낙관, StatusCapsuleView, MarginErrorBanner, VermilionButtonStyle, SquareChromeButtonStyle, SectionCard/paperFrame, CardHeader, ChipView, ThemedSliderRow).
- [x] T3b.2 그리기 탭: 화선지 카드(점 결 텍스처 `drawPaperGrain`, 낙관 數墨, 상태 캡슐, 여백 오류 메모), "동적 매개변수" 카드, 스크립트 에디터 카드(파일명 "은행잎.smk", 수렴/오류/연산 중 상태 점, 기호 키 행, 재계산 버튼), 저장 버튼 "인각"(glassProminent), 프리셋 서랍(낙관 썸네일·현재 적용됨 배지·체크).
- [x] T3b.3 읽기 탭: 미리보기 카드(분석 완료 캡슐, 누끼/원본 세그먼트, 낙관), "수식 변환 파이프라인" 수직 스테퍼(총 ms), 방향 카드, 윤곽 선택 칩(체크 표시·N개 활성), "변환 레시피 설정" 카드(아이콘 토글·범위 표시 슬라이더), 결과 스크립트 카드, 주홍 CTA + 안내문.
- [x] T3b.4 갤러리: paperDeep 카드 셀 + 낙관, 상세의 CTA/공유/삭제 행, 제원 스트립(계열·요소·연산 시간·글자 수), "전체 복사".
- [x] T3b.5 탭 아이콘 `scribble.variable`, 전역 틴트 vermilion. 미적용: 아이콘(화면 9), 온보딩 카드, 에디터 구문 강조(TextEditor 속성 문자열 바인딩은 후속), 갤러리 검색·필터 칩(기능 없음).
- [x] T3b.6 QA(라이트/다크 전 화면)에서 잡은 문제: 다크에서 결과 스크립트 글자가 종이색 카드 위에 밝게 찍혀 안 보임 → 종이 위 텍스트는 항상 `inkDrawing`; 다크에서 사진 미리보기 워시가 사라짐 → 사진 뒤 배경을 paper로 고정; 타이핑이 undo 단계로 안 잡혀 한 번에 프리셋까지 되돌아감 → 1.5 s 묶음 타이핑 스냅샷(`captureTypingUndo`); 갤러리 상세 첫 3 s 빈 캔버스 → 로딩 표시; 기호 키 행이 버튼에 가려 "s"만 남음 → 재계산 버튼을 헤더로 옮기고 페이드 마스크; 18pt 낙관 판독 불가 → 24pt 한 글자; 가져온 스크립트의 기본 제목/파일명이 주석 전체 → "(" 앞까지만.

## Phase 6 — 그림 → 수식 Tier B 가족 적합 (FR-6, 실험, 시간 박스 2일)

- [ ] T6.1 템플릿 정의(항 수 J ≤ 4, p ∈ {1,2,3,5,7}, ω 1~12), 파라미터 벡터 ↔ Script 변환.
- [ ] T6.2 손실: 양방향 Chamfer(포락선 샘플 ↔ 목표 윤곽, KD-트리 또는 그리드 해시) + 길이 패널티.
- [ ] T6.3 최적화: 이산 격자/빔 탐색(ω, p) × 연속(진폭·위상) Nelder–Mead/Adam(Accelerate), 시간 예산·진행률·취소.
- [ ] T6.4 UI: "실험" 배지, Tier A와 나란히 비교, 임계값(평균 오차 > 6%) 초과 시 Tier A 기본 유지.
- [ ] T6.5 평가 리포트: 손그림 10장(새·물고기·잎·하트·배 등)에 대한 Tier A/B 오차·길이 표를 `Docs/TierB-Report.md`에 기록. 결과에 따라 2차 범위 결정.

## Phase 6b — 온디바이스 경로 + RL 미세조정 (FR-11, FR-12) — 프로토타입 완료 2026-10-17

- [x] T6b.1 Python 프로토타입: `Media/src/sumuk_core.py`(DCT 급수·경계 추적·푸리에·가족 합성·래스터·지표), `portrait_pipeline.py`(M1~M5 + 합성 + Script 출력), `vision_ondevice.swift`(Vision 랜드마크·인물 마스크·윤곽 → JSON), `portrait_ondevice.py`(Vision 구조 → 가족, 비교 지표), `portrait_rl.py`(MLX REINFORCE), `make_portrait_figures.py`. 결과 `Media/Portrait/`, 보고서 `Docs/Portrait-Sample-Report.md`. 원본 사진은 `Media/Portrait/input/`(gitignore).
- [ ] T6b.2 Swift 이식: `Structuring/OnDevice/` — `VNDetectFaceLandmarksRequest`·`VNGeneratePersonSegmentationRequest`·`VNDetectContoursRequest` 래퍼, 랜드마크 부위별 가족 스타일 테이블(눈·입 = 현 가족, 얼굴 윤곽 = 붓 원 가족, 눈썹·코 = 곡선), 실루엣 마스크 경계 추적.
- [ ] T6b.3 비교 뷰: 고전 vs 온디바이스 나란히 + 지표 표(Chamfer·톤 손실·가족·계수·시간), 층 섞기(톤/구조 선택) 후 저장.
- [ ] T6b.4 RL 단계 Swift 이식: 환경(저해상도 Metal 렌더 → 톤 손실·Chamfer), 가우시안 정책 + REINFORCE(파라미터 14개, 수동 그래디언트 또는 MLX Swift), 진행률·보상 곡선·중단·채택 UI, λ 슬라이더. 실기기 예산 ≤ 20초 측정.
- [ ] T6b.5 테스트: 보상 함수 결정성, 정책 업데이트 방향(합성 보상에서 평균이 올라가는지), Vision 결과 JSON 픽스처로 변환 왕복, 비인물 사진 폴백.
- [ ] T6b.6 프로토타입 개선 메모: 온디바이스 경로의 Vision 윤곽 가족이 얼굴을 가로지르는 큰 고리를 만들 때가 있음(윤곽 중첩 제거 필요). RL 정책 σ가 수렴하지 않고 탐색을 유지함(엔트로피 보너스·lr 재조정, 또는 최종 채택을 "정책 평균" 대신 "최선 샘플"로 — 현재 구현).

## Phase 7 — 픽셀 수식 양방향 (FR-7)

- [ ] T7.1 MathSketch `PixelFormula/` 이식(토크나이저·파서·CPU 평가기·트랜스파일러·렌더러·예시·테스트 17개), `pixel` 가족으로 통합(배경 레이어, 1/4 미리보기 → 전체).
- [ ] T7.2 `DCTPixelFitter`: 축소(기본 400×240) → 채널별 2D DCT → 상위 T항(16~512) → Script 생성(`F_c(m,n)` 정의 + `rgb(...)`), PSNR·길이 표시.
- [ ] T7.3 왕복 테스트: 생성 Script를 PixelFormula 렌더러로 그린 결과가 피터(fitter)의 자체 재구성과 픽셀 단위 일치(허용 ±1).
- [ ] T7.4 ReadTab에 "픽셀 수식로 변환" 모드 추가, 길이 경고(> 20KB), Σ 축약 표기 옵션.

## Phase 8 — 영속성·갤러리 (FR-8)

- [~] T8.1 SwiftData `SavedArtwork`(title · script · createdAt · elementCount · sourceNote · 썸네일 externalStorage). 드래프트 자동 저장·sourceImage 미착수.
- [~] T8.2 `GalleryTabView`(`@Query` 그리드) + 상세(렌더·스크립트로 열기·공유·삭제 확인). 복제·지표 미착수. 썸네일은 `ImageRenderer`(600px).
- [ ] T8.3 재실행 복원(드래프트) 시뮬레이터 QA(앱 스와이프 종료 → 콜드 스타트).

## Phase 9 — FoundationModels 보조 (FR-9, 선택)

- [ ] T9.1 가용성 게이트(`SystemLanguageModel.default.availability`), 비가용 시 UI 숨김.
- [ ] T9.2 설명/제목 제안(`LanguageModelSession`, 한국어 지시문), Script 수정 초안(`@Generable` 구조 → 파서 검증 → 미리보기 → 수락).
- [ ] T9.3 실기기(Apple Intelligence 지원 기기)에서 응답 확인, 시뮬레이터 비가용 경로 확인.

## Phase 10 — 접근성·현지화·아이콘 (FR-10)

- [ ] T10.1 `accessibilityLabel/Value/Hint` 전수(에디터 토큰·슬라이더·윤곽 선택·갤러리), 미리보기 가족 요약 라벨.
- [ ] T10.2 Dynamic Type(에디터 모노스페이스 스케일), 모션 감소, 고대비 먹색 확인.
- [ ] T10.3 String Catalog(ko 기본, en), 오류 메시지 포함.
- [x] T10.4 앱 아이콘(2026-10-17): `Media/src/make_app_icons.py`가 학 프리셋 선분 + 낙관 墨으로 iOS(라이트·다크·틴티드 1024)·macOS(16~1024)·visionOS(`AppIcon.solidimagestack` 뒤/중간/앞) 아이콘을 생성해 `Assets.xcassets`에 기록. `ASSETCATALOG_COMPILER_APPICON_NAME`은 도구가 거부해 pbxproj 두 구성에 직접 삽입(Xcode가 재로드하며 빌드 1회 취소됨, 이후 빌드 성공). 틴티드 아이콘의 낙관은 글자를 투명하게 뚫어 틴트 후에도 읽히게 함.

## Phase 11 — 검증·문서·공개

- [ ] T11.1 Swift Testing ≥ 100개 전체 통과(`RunAllTests`), 실기기 빌드·설치·실행(무료 개인 팀 서명, 역-DNS 번들 ID).
- [ ] T11.2 iPhone 16 시뮬레이터 수동 QA 시나리오 6종(PRD §3) 체크리스트 수행, 발견 버그 기록·수정.
- [ ] T11.3 실제 스크린샷 → `Media/Screenshots/`, README의 "앱 화면" 섹션을 실제 캡처로 교체, 소개 GIF/MP4(선택).
- [ ] T11.4 README 배지(테스트 수)·알려진 제한사항 갱신, 커밋 로그 정리, GitHub 푸시(GitHub Desktop).

## Phase 12 — 이후(비목표에서 승격 후보)

- [ ] iPad 멀티컬럼(에디터 | 미리보기), Apple Pencil 호버 스크러빙.
- [ ] macOS(Catalyst 아님, 네이티브) · visionOS 볼륨에서 가족 애니메이션.
- [ ] 원작 프리셋 추가(대나무 · 소나무 · 파도 · 나비 · 연꽃). 파도는 2026-10-17 시도(트로코이드 현 가족)가 형태를 못 만들어 보류.
- [ ] MP4 애니메이션 내보내기(`AVAssetWriter`), 라이브 월페이퍼용 짧은 루프.
- [ ] 사용자 프리셋 공유(.sumuk 텍스트 파일 UTType 등록, 파일 앱/AirDrop).

---

## 설계 메모

- **UI 용어(2026-10-17)**: 사용자 결정으로 화면 문자열의 "가족"을 "계열"로 통일했다(상태 칩 "계열 2 · 선분 820", 오류 "계열 3에 정의되지 않은 이름", 변환 모드 "현 계열"/"붓 원 계열", 프리셋 주석). 타입 이름 `Family`와 문서의 수학 용어 "가족(family)"은 그대로.

- **Script가 진실**: 스크러빙·슬라이더·FoundationModels 초안·임포터는 모두 "텍스트를 바꾸는 행위"다. 모델이 텍스트와 별도의 상태를 갖지 않게 해 undo·저장·공유가 한 경로로 모인다.
- **스타일 ≠ 수학**: `ink`/`canvas`는 Script에 있지만 수식 카드와 LaTeX 내보내기에서는 제외한다(MathSketch "색상 ≠ 수식" 원칙 계승).
- **Combine 미사용**: 프로젝트 지침에 따라 디바운스는 `Task` + `Task.sleep` 취소 패턴, 스트림은 `AsyncStream`. MathSketch의 Combine 디바운스는 이식하지 않는다.
- **Metal 교훈 이식**: `dispatchThreads` 대신 `dispatchThreadgroups`(시뮬레이터 비균일 스레드그룹 미지원), 밴드 분할로 GPU 워치독 회피, 시뮬레이터에서 반드시 1회 실행.
- **외부 이미지·공식 미사용(2026-10-17 사용자 결정)**: 웹에서 가져온 이미지와 타인 작품의 공식 전사본은 저장소·앱·문서 어디에도 싣지 않는다. Yeganeh는 기법의 영감으로 이름과 링크만 언급. 새 프리셋은 Python 생성기로 먼저 설계·렌더해 확인한 뒤 Script로 옮긴다.
- **이름**: 수묵(水墨/數墨) — 먹의 농담 = 원 반지름·선 밀도의 변조. 번들 원작 샘플은 의도적으로 수묵 모티프(달항아리·은행잎·매화·잉어·학)로 설계해 앱 정체성을 만든다.
