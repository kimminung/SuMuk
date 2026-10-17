# 기술 PRD — 수묵 (SuMuk · 數墨)

버전: v0.1 (초안)
작성일: 2026-10-17
대상 플랫폼: iPhone (iOS 27+) 우선. iPad/macOS/visionOS는 후속.
참고: 「Mathematical Concepts Illustrated by Hamid Naderi Yeganeh」(AMS Mathematical Imagery), 참고 프로젝트 `Desktop/MathSketch`(MathEngine·PixelFormula·SwiftData 패턴)

---

## 1. 배경과 비전

Hamid Naderi Yeganeh의 수학 그림은 두 가지 아주 단순한 원리로 만들어진다.

1. **선분 가족(segment family)** — `k = 1 … N`에 대해 두 끝점 `(x₁(k), y₁(k))`, `(x₂(k), y₂(k))`를 삼각함수로 정의한 N개의 선분. 선분들의 **포락선(envelope)** 이 곡선처럼 보여 새의 날개, 하트, 돛단배가 나타난다.
2. **원 가족(circle family)** — `k`에 대해 중심 `(X(k), Y(k))`와 반지름 `R(k)`를 정의한 N개의 원. 반지름 변조로 농담(濃淡)과 질감이 생긴다.

여기에 Yeganeh가 최근 도입한 **픽셀 수식**(픽셀 `(m, n)`의 색을 직접 정의하는 함수망, MathSketch가 이미 FR-10으로 구현)이 더해진다.

**수묵(數墨)** 은 이 원리를 두 방향으로 쓰는 iPhone 앱이다.

- **수식 → 그림**: 가족 수식을 입력(또는 붙여넣기)하면 즉시 그려진다. 숫자를 문질러 바꾸면 그림이 실시간으로 변한다.
- **그림 → 수식**: 내가 그린 드로잉, 앱 안에서 만든 그림, 기기 사진 라이브러리의 사진을 가져오면, 그 윤곽을 **같은 종류의 가족 수식으로 구조화**해 돌려준다. 결과 수식은 다시 첫 번째 방향으로 그려져 원본과 겹쳐 비교된다.

MathSketch가 "도형 23종 조립 → 하나의 합성 수식"이었다면, 수묵은 **"수천 개의 선분·원이 하나의 짧은 수식에서 태어나는"** Yeganeh의 방식을 1급 시민으로 삼는다. 이름의 수묵(水墨)은 먹의 농담으로 그리는 동양화, 數墨은 "수(數)로 찍은 먹"이라는 중의다. 번들 샘플도 달항아리·은행잎·매화·잉어·학 같은 수묵 모티프로 직접 설계했다.

## 2. 목표 / 비목표

**목표**

- G1. **가족 수식 DSL(SuMuk Script)** 을 정의하고, 선분·원·곡선·픽셀 네 종류의 가족을 파싱·평가·렌더링한다. AMS 캡션의 "For each k=1,2,3,…,500 the endpoints of the k-th line segment are …" 문장과 LaTeX 부분집합(`\sin^7`, `\frac`, `\pi`)도 관대하게 받아들인다.
- G2. iPhone에서 **500~20,000개 요소는 60fps 라이브 편집**, 최대 **1,000,000개 선분 / 100,000개 원**은 Metal로 1초 내 미리보기(1024px)·수 초 내 4K 내보내기.
- G3. 숫자 리터럴 **스크러빙**(가로 드래그)과 변수 슬라이더로 수식을 "손으로 만지며" 탐색할 수 있다. 변수 `t`를 시간으로 쓰면 애니메이션이 된다.
- G4. **그림 → 수식 Tier A(결정적)**: 사진/드로잉 → Vision 윤곽 → 윤곽별 삼각급수(푸리에) `x(t), y(t)` → (a) 곡선 가족, (b) 현(chord) 가족(Yeganeh의 "Corridor/Star" 방식: 곡선 위 점 `A(k)`와 `A(k+δ)`를 잇는 선분), (c) 원 가족(붓 윤곽), (d) 해칭 가족(내부 채움) 중 선택해 **파싱 가능한 SuMuk Script**로 출력한다. 조화 수 `N`·현 간격 `δ` 슬라이더로 즉시 재적합되고, 원본 위에 오버레이로 오차가 보인다.
- G5. **그림 → 수식 Tier B(실험)**: Yeganeh형 템플릿(저차 삼각함수 거듭곱의 선형 결합)의 계수를 최적화해 윤곽을 **짧은 수식**으로 근사한다. 시간 예산 내 최선해를 "실험" 배지와 오차 수치와 함께 제시한다.
- G6. **픽셀 수식 양방향**: MathSketch의 LaTeX 픽셀 수식 모드(수식 → GPU 이미지)를 이식하고, 역방향으로 사진을 **절단된 2D DCT 급수**(항 수 T 조절) 형태의 픽셀 수식으로 구조화한다.
- G7. 작품은 **스크립트 원문**이 진실의 원천(source of truth)이며, 갤러리(SwiftData)·공유(PNG/SVG/수식 카드/텍스트)·재편집이 모두 스크립트로부터 이뤄진다.
- G8. 네트워크 없이 **모두 온디바이스**로 동작한다. 사진은 기기를 떠나지 않는다.
- G9. iPhone 16 시뮬레이터와 실기기에서 전 기능을 검증하고, Swift Testing으로 파서·평가기·적합기의 정확성을 고정한다.

**비목표(1차)**

- iPad 전용 멀티컬럼 레이아웃, macOS/visionOS 타깃(Phase 12 이후로 분리; 코드 공유는 염두에 둠).
- 클라우드 동기화·계정·협업.
- 임의 코드 실행, 외부 수식 라이브러리(자체 MathEngine만 사용).
- 사진의 **의미적** 인식(예: "이건 고양이")으로 수식을 고르는 기능. 수묵은 윤곽·색의 **기하적 구조화**만 약속한다. FoundationModels는 설명·제목·초안 보조에만 쓴다(FR-9).
- 타인의 작품 번들. Yeganeh의 이미지도, 그의 작품 공식 전사본도 포함하지 않는다. 기법만 응용하고, 프리셋은 전부 이 프로젝트의 원작이다(§8).

## 3. 사용자 시나리오

1. **붙여넣기 → 그림**: 사용자가 어디선가 복사한 영어 캡션 "This image shows N line segments. For each k=1,2,3,…,N the endpoints of the k-th line segment are: …" 를 그대로 붙여넣는다. 파서가 산문을 걷어내고 선분 가족으로 인식해 즉시 그린다. 사용자가 `sin^7`의 7을 문질러 5로 바꾸면 포락선이 두꺼워지고, 3으로 바꾸면 전혀 다른 형태가 된다. 프리셋 "학"에서도 같은 조작으로 날개 모양을 바꿔 볼 수 있다.
2. **프리셋 탐색**: 프리셋 서랍에서 "달항아리"를 고른다. 3,600개 원의 가족 수식 두 줄이 에디터에 들어오고, `brush` 변수 슬라이더로 붓 압력을 바꿔 본다. 마음에 들면 갤러리에 저장한다.
3. **손그림 → 수식**: "읽기" 탭에서 PencilKit 캔버스에 물고기를 그린다. 스트로크가 폴리라인으로 바로 들어가 푸리에 16조화 곡선 + 현 간격 37의 선분 가족으로 구조화되고, 원본 스트로크 위에 결과가 겹쳐 보인다. 조화 수를 8로 내리면 수식은 짧아지고 그림은 둥글어진다. "스크립트로 열기"를 누르면 그리기 탭에서 계속 편집할 수 있다.
4. **사진 → 수식**: 사진 라이브러리에서 은행잎 사진을 고른다. Vision이 잎의 바깥 윤곽(최대 N개 윤곽, 면적 순)을 찾고, 사용자가 쓸 윤곽을 탭으로 고른다. 원 가족(붓 윤곽) 모드로 구조화하면 먹으로 그린 듯한 은행잎이 되고, 결과 수식 카드(그림 + 수식 조판)를 공유한다.
5. **픽셀 수식**: MathSketch에서 쓰던 2000×1200 LaTeX 픽셀 수식을 붙여넣으면 Metal로 배경이 렌더링되고, 그 위에 선분 가족을 겹칠 수 있다. 반대로 사진을 "픽셀 수식(DCT 48항)"으로 변환하면 흐릿하지만 알아볼 수 있는 이미지와, 그 이미지를 완전히 기술하는 긴 수식이 함께 나온다.
6. **애니메이션**: `segments k = 1…500` 안에서 `π/3` 대신 변수 `t`를 쓰고 `t ∈ [0, 2π]`를 시간축으로 지정하면 새가 날갯짓한다. 재생/정지와 GIF가 아닌 **MP4 내보내기**(선택)가 가능하다.

## 4. SuMuk Script — 가족 수식 DSL

### 4.1 전체 구조

```
// 주석. 공백·줄바꿈 자유.
canvas 2000 × 1200                 // 선택. 생략 시 내용에 맞춰 자동 맞춤
ink #1C1C1E  width 0.6  alpha 0.9  // 선택. 스타일은 수식의 일부가 아님 (MathSketch와 같은 철학)

segments k = 1 ... 500 {
  from ( 3/2 · sin^7(2πk/500 + π/3),  1/4 · cos^2(6πk/500) )
  to   ( 1/5 · sin(6πk/500 + π/5),   −2/3 · sin^2(2πk/500 − π/3) )
}

circles k = -10000 ... 10000 {
  center ( A(k), B(k) )
  radius R(k)
}
where
  A(k) = 3k/20000 + sin(π/2 · (k/10000)^7) · cos^6(41πk/10000) + …
  B(k) = …
  R(k) = 1/50 + 1/10 · sin^2(41πk/10000) · sin^2(9πk/100000) + …

curve t ∈ [0, 2π] samples 1200 {      // 그림→수식 결과(푸리에)에 쓰는 연속 곡선
  x = a0 + Σ_{n=1}^{16} ( a_n cos(nt) + b_n sin(nt) )
  y = …
}

pixel 2000 × 1200 {                    // MathSketch 픽셀 수식 모드 호환(LaTeX 부분집합)
  rgb( F(H_0(…)), F(H_1(…)), F(H_2(…)) )
  where F(x) = … , H_v(x,y) = …
}
```

- 작품 = `canvas?` + `ink?` + **가족 블록 1개 이상**(순서가 z-순서). 각 가족 블록은 자신의 `ink`를 가질 수 있다.
- 가족 종류: `segments`(선분), `circles`(원), `curve`(연속 매개변수 곡선, 폴리라인으로 샘플링), `pixel`(픽셀 수식, 배경 레이어, 작품당 최대 1개).
- 범위: `k = a ... b` 정수 범위(음수 허용, 요소 수 상한 1,000,000), `t ∈ [a, b]` 실수 범위 + `samples N`.
- `where` 절: 가족 블록 뒤 또는 파일 끝에 보조 정의 `이름(매개변수…) = 식`. 아래첨자 매개변수(`L_{u,s}(x,y)`, `H_v`)는 PixelFormula 파서와 동일 규칙.
- **복소수 표기**(should): 끝점을 복소수 한 식으로 쓸 수 있다. `from z = (cos(6πk/2000) − i·cos(12πk/2000)) · e^(3πi/4)` — `i`는 허수 단위, `e^(iθ)` 회전. 실수부·허수부가 좌표가 된다(돛단배 공식 원문 그대로 입력 가능).

### 4.2 식(expression) 문법

- 숫자(정수·소수·분수 `3/2`), 상수 `π`/`pi`, `e`, 변수(가족 변수 `k`/`t`, `where` 매개변수, 스타일 변수), `+ − · * / ^`, 괄호, **병치 곱셈**(`2πk`, `sin(a)cos(b)`), 단항 `−`.
- 함수: `sin cos tan asin acos atan atan2 sinh cosh tanh exp ln log sqrt abs floor ceil sign min max mod`. **거듭제곱 함수 표기** `sin^7(x)` = `(sin x)^7`. `|x|`, `⌊x⌋`, `\sqrt{}`, `\frac{}{}`, `\sum_{s=a}^{b}`도 수용(LaTeX 전처리기 재사용).
- 조건식(should): `if(cond, a, b)`, 비교 `< ≤ > ≥ =` — 반쪽 그림(예: 윗날개만) 표현용.
- 파싱 실패 시 **열 번호 + 한국어 메시지**(MathSketch `MathSyntaxError` 패턴). 상한: 가족 20개, 스크립트 50,000자, 총 요소 1,000,000개.

### 4.3 관대한 입력(캡션/LaTeX 임포트)

입력 텍스트가 SuMuk Script 키워드로 시작하지 않으면 **임포터**가 먼저 시도한다.
- 영어 캡션 문장 패턴: `This image shows N line segments. For each k=…, the endpoints of the k-th line segment are: (…) and (…).` / `… the center of the k-th circle is (X(k), Y(k)) and the radius of the k-th circle is R(k), where X(k)=…`. 숫자 N, 변수명(`i`/`k`), 두 끝점 또는 중심·반지름, `where` 정의를 추출해 Script로 변환한 뒤 **변환 결과를 에디터에 보여 준다**(사용자가 수정 가능, 변환은 되돌릴 수 있음).
- LaTeX: `\sin^{7}\left(\frac{2\pi k}{500}+\frac{\pi}{3}\right)` 등은 PixelFormula의 `LaTeXTokenizer` 전처리기를 확장해 정규화.
- `rgb(`로 시작하거나 `m`, `n` 픽셀 변수를 쓰는 텍스트는 `pixel` 가족으로 라우팅(MathSketch `loadFromFormulaInput` 판별 로직 이식).

## 5. 기능 요구사항

### FR-1. 파서·모델 (FamilyParser / Artwork)
- `MathLexer`/`MathAST`/`MathParser`/`MathEvaluator`를 MathSketch에서 이식하고 다음을 확장: 범위 토큰(`...`, `∈`, `[`,`]`), 키워드(`segments circles curve pixel where canvas ink from to center radius samples`), 거듭제곱 함수 표기, 병치 곱셈 우선순위(함수 호출 > 거듭제곱 > 병치 > `·`/`/` > `+−`), 유니코드 연산자(`·`, `×`, `−`, `π`, `Σ`, `⌊⌋`, `| |`).
- 결과 모델: `Artwork { canvas: CanvasSpec?, families: [Family], definitions: [FunctionDefinition], sourceText }`, `Family = .segments(range, from: (Expr, Expr), to: (Expr, Expr), style) | .circles(range, center, radius, style) | .curve(range, samples, x, y, style) | .pixel(PixelFormulaProgram)`.
- **왕복 보장**: `ScriptFormatter`가 `Artwork`를 다시 정규화된 Script로 출력하며, `parse(format(parse(s))) == parse(s)`를 테스트로 고정한다. 캡션/LaTeX 임포트 결과도 같은 경로를 탄다.
- 자유 변수 검증: 가족 식은 자기 가족 변수와 `where` 정의·상수·스타일 변수만 참조할 수 있다. 미정의 이름은 열 번호와 함께 보고.

### FR-2. 평가 (FamilyEvaluator)
- 식을 **스택 바이트코드**로 컴파일해 `k` 배열 전체를 한 번에 평가(vDSP `vvsin` 등 Accelerate 벡터 함수). 500개는 0.1ms, 20,000개는 2ms 이내(iPhone 15/16 기준)를 목표.
- 요소 수가 50,000개를 넘으면 **Metal 컴퓨트**로 평가: `MetalShaderTranspiler`(MathSketch)를 일반 식에도 쓰도록 일반화해 `k`별 끝점/중심/반지름을 GPU 버퍼에 직접 쓴다(`mathMode = .safe`, NaN/∞ → 요소 제외).
- `where` 정의는 인라인(호출 깊이 ≤ 8, 재귀 금지) 또는 Metal 함수로 방출. `Σ`는 루프 헬퍼(상한 100,000회).
- 정수 거듭제곱은 반복 곱, 음수 밑의 홀수 거듭제곱은 부호 유지(`signedPow`) — MathSketch 설계 메모 그대로.

### FR-3. 렌더링 (FamilyRenderer)
- **Canvas 경로**(총 요소 ≤ 5,000): SwiftUI `Canvas`에 `Path`로 즉시 그리기. 편집 중 기본 경로.
- **Metal 경로**(그 이상): 선분은 인스턴스드 쿼드(두께·안티에일리어싱은 프래그먼트에서 SDF), 원은 인스턴스드 쿼드 + 원 SDF(외곽선 두께 `width`, `fill` 옵션). 100,000개 원을 16ms 내, 1,000,000개 선분을 1초 내(1024px 미리보기).
- 좌표 맞춤: 작품 바운딩 박스(또는 `canvas`)를 뷰에 맞추는 `FitContext`(MathSketch 패턴). 두 손가락 핀치/드래그로 확대·이동(수식은 바뀌지 않음, 뷰 변환만).
- 스타일: 먹색(`ink`)·선 두께·불투명도·배경(화선지 톤 프리셋 포함). **스타일은 Script에 남지만 수학이 아니다** — 수식 카드에는 수학 부분만 조판.
- 내보내기: PNG(1024/2048/4096px, 투명 배경 옵션), SVG(요소 ≤ 20,000개일 때), 수식 카드 PNG(그림 + 조판 수식 + 출처), Script 텍스트/LaTeX. 공유 시트(`ShareLink`).

### FR-4. 에디터 UX (그리기 탭)
- 상단 미리보기 + 하단 **스크립트 에디터**(`TextEditor` + 경량 하이라이팅: 키워드·함수·숫자·오류 밑줄). 파싱은 입력 후 120ms 디바운스(`Task` + `try await Task.sleep`, Combine 미사용), 성공 시 즉시 재렌더, 실패 시 마지막 성공 결과 유지 + 오류 배너.
- **숫자 스크러빙**: 숫자 토큰을 길게 누른 뒤 좌우 드래그하면 값이 변한다(자릿수에 따라 스텝 자동, 햅틱). 변경은 Script 텍스트에 그대로 반영된다(텍스트가 진실).
- **변수 슬라이더**: `let brush = 0.03 in [0, 0.1]`처럼 선언된 변수는 미리보기 아래 슬라이더로 노출. `t` 변수 + `animate t ∈ [0, 2π] duration 4s` 선언은 재생 컨트롤을 만든다.
- 되돌리기/다시 실행(텍스트 단위, 스크러빙 1회 = 1스냅샷), 프리셋 서랍(수묵 원작 5종 + 사용자 저장), 키보드 액세서리에 `π · ^ ( ) sin cos` 버튼.

### FR-5. 그림 → 수식 Tier A — 푸리에 구조화 (읽기 탭)
- **입력 3종**: `PhotosPicker`(사진 라이브러리), 카메라(`AVCapturePhotoOutput`, should), 파일(`fileImporter`, PNG/JPEG/HEIC/PDF 1쪽), **PencilKit 캔버스**(앱 안 드로잉; `PKDrawing.strokes` → 폴리라인 직접 사용, Vision 생략).
- **윤곽 추출**: `VNDetectContoursRequest`(contrastAdjustment·detectsDarkOnLight 토글, 최대 변 길이 1024px 다운샘플). 윤곽을 면적 순 정렬, 상위 12개를 색으로 구분해 오버레이 → 사용자가 탭으로 선택(기본: 최대 윤곽 1개). Ramer–Douglas–Peucker로 단순화(ε 슬라이더).
- **푸리에 급수**: 닫힌 윤곽을 호 길이로 재매개변수화해 `M` 균등 샘플 → 실수 DFT로 `x(t) = a₀ + Σ aₙ cos(nt) + bₙ sin(nt)`, `y(t)` 동일(조화 수 `N` 1~64, 기본 16). 계수는 유효숫자 4자리로 반올림해 Script에 **숫자 그대로** 기록(Σ 축약형 또는 전개형 선택).
- **가족 변환 4종**(결과는 모두 SuMuk Script):
  1. `curve` — 곡선 자체(가장 충실).
  2. **현 가족** `segments k = 1 … N_s { from (x(2πk/N_s), y(2πk/N_s)) to (x(2π(k+δ)/N_s), y(2π(k+δ)/N_s)) }` — Yeganeh의 Corridor/Star 패턴. `δ`가 커질수록 내부 포락선이 생기며 "스트링 아트"가 된다.
  3. **원 가족(붓 윤곽)** `circles k { center (x(θ_k), y(θ_k)) radius r₀ + r₁·|sin(mθ_k)|^p }` — 붓 압력 변조(달항아리 샘플과 같은 기법).
  4. **해칭 가족** — 윤곽의 상·하(또는 좌·우) 경계를 `t`로 잇는 선분(잉어 샘플의 몸통 기법). 내부 채움·농담 표현.
- **품질 지표**: 원본 윤곽 대비 재구성 곡선의 평균/최대 거리(px, 정규화 %)와 수식 길이(문자 수·항 수)를 함께 표시. 오버레이 토글(원본 / 결과 / 겹침).
- 다중 윤곽은 각각 별도 가족으로, `where`에 `x_1(t), y_1(t), x_2(t)…`로 정리.

### FR-6. 그림 → 수식 Tier B — 가족 적합 (실험)
- 목표: 푸리에 계수 수십 개 대신 **Yeganeh형 짧은 식**으로 윤곽을 근사. 템플릿 예: `x(k) = Σ_j c_j · sin^{p_j}(ω_j·2πk/N + φ_j)`, `y(k)` 동일(항 수 J ≤ 4, 거듭제곱 p ∈ {1,2,3,5,7}, 주파수 ω ∈ 정수 1~12).
- 손실: 렌더된 포락선 샘플 ↔ 목표 윤곽 간 **양방향 Chamfer 거리** + 수식 길이 패널티. 최적화: 주파수·거듭제곱은 이산 탐색(격자/빔), 진폭·위상은 Nelder–Mead 또는 Adam(Accelerate, 수치 미분). 시간 예산 2~5초, 진행률과 "실험" 배지 표시, 중단 가능.
- 결과는 Tier A와 같은 UI(오버레이 + 지표)로 비교되며, 사용자가 둘 중 하나를 고른다. 품질이 임계값(평균 오차 > 6%)보다 나쁘면 Tier A를 기본 선택으로 유지한다.

### FR-7. 픽셀 수식 양방향
- **수식 → 이미지**: MathSketch `PixelFormula/` 모듈(토크나이저·파서·CPU 평가기·Metal 트랜스파일러·렌더러·예시) 이식. `pixel` 가족으로 Artwork에 들어가고, 선분/원 가족이 그 위에 겹친다. 1/4 미리보기 → 전체 해상도, 64행 밴드 디스패치, `dispatchThreadgroups` 사용(시뮬레이터 비균일 스레드그룹 제약 교훈 반영).
- **이미지 → 픽셀 수식**: 입력 이미지를 `W×H`(기본 400×240)로 축소 → 채널별 2D DCT → 에너지 상위 `T`항(16~512) 선택 → `rgb(F_0(m,n), F_1(m,n), F_2(m,n))`, `F_c(m,n) = ⌊ clamp(Σ_t c_t · cos(π(2m+1)u_t/2W) · cos(π(2n+1)v_t/2H)) ⌋` 형태 Script 생성. 항 수에 따른 PSNR과 수식 길이 표시. 생성된 수식은 반대 방향 렌더러로 **그대로** 다시 그려져 일치해야 한다(테스트).

### FR-8. 영속성·갤러리
- SwiftData `@Model Artwork { id, title, script, createdAt, updatedAt, thumbnail(.externalStorage), sourceImage?(.externalStorage, 그림→수식 원본, 사용자 동의 시만), metrics? }`. 스크립트 원문이 진실이며 이미지는 항상 재렌더 가능.
- 편집 중 드래프트는 같은 스토어의 `isDraft` 작품 1개로 0.8초 디바운스 자동 저장(`Task` 기반). MathSketch의 Core Data+SwiftData 이중 구조는 쓰지 않는다 — 여기선 쓰기 빈도가 텍스트 편집 수준이라 단일 스토어로 충분.
- 갤러리 그리드(`@Query`), 상세(수식 전문·지표·출처 메모), "스크립트로 열기", 삭제, 복제. 프리셋은 번들 JSON(`Presets.json`: 제목·설명·Script, 원작 5종).

### FR-9. FoundationModels 보조 (선택, 가용성 확인)
- `SystemLanguageModel.default.availability`가 `.available`일 때만 노출. 기능: (a) 현재 Script를 한국어로 설명("sin⁷ 때문에 날개 끝이 뾰족…"), (b) 작품 제목 제안, (c) 자연어 요청("날개를 더 길게") → **Script 수정 초안** (`@Generable` 구조로 출력, 적용 전 파서가 검증·미리보기, 사용자가 수락). 모델 출력은 절대 자동 적용되지 않는다.
- 비가용 시 조용히 숨김. 네트워크 모델은 쓰지 않는다.

### FR-10. 접근성·현지화
- 모든 컨트롤에 `accessibilityLabel/Value/Hint`(예: "sin 거듭제곱 7, 스크러빙 가능"). 미리보기는 `accessibilityLabel`에 가족 요약("선분 500개 가족 1개, 원 3,600개 가족 1개").
- Dynamic Type(에디터는 모노스페이스 `.body` 기준 스케일), 고대비 먹색, 모션 감소 시 애니메이션 자동 재생 안 함.
- String Catalog: 한국어 기본, 영어 번역. 오류 메시지도 카탈로그.

## 6. 비기능 요구사항

| 항목 | 목표 |
| --- | --- |
| 라이브 편집 지연 | 입력 → 화면 갱신 ≤ 50ms (요소 ≤ 20,000, iPhone 15/16) |
| 대형 렌더 | 1,000,000 선분 1024px 미리보기 ≤ 1.0s, 4096px PNG ≤ 6s |
| 그림→수식 Tier A | 1024px 사진 입력 → 결과 표시 ≤ 1.5s |
| Tier B | 시간 예산 2~5s, 중단 가능, 진행률 표시 |
| 메모리 | 1,000,000 선분 버퍼 ≤ 64MB(끝점 float32 ×4) |
| 정확성 | 파서 왕복, 평가기 손계산 값, GPU/CPU 픽셀 일치(허용 불일치 ≤ 3/100), 원작 프리셋 5종의 특정 k에서의 끝점·중심·반지름이 Python 생성기 값과 일치 |
| 개인정보 | 네트워크 엔타이틀먼트 없음, 사진은 사용자 동의 시에만 작품에 보관 |
| 동시성 | Swift 6 언어 모드, 기본 MainActor 격리; 평가·적합·렌더는 `nonisolated` 순수 함수 + `Task.detached` |

## 7. 아키텍처 개요

```
SuMuk/
  MathEngine/              # MathSketch에서 이식: MathLexer · MathAST · MathParser · MathEvaluator
    PixelFormula/           # LaTeXTokenizer · PixelFormulaParser · Evaluator · MetalShaderTranspiler · Renderer · Samples
  Script/                  # SuMuk Script: ScriptLexer(확장 토큰) · FamilyParser · ScriptFormatter · CaptionImporter · LaTeXImporter
  Family/                  # Artwork · Family · RangeSpec · ExpressionCompiler(바이트코드) · FamilyEvaluator(vDSP) · MetalFamilyEvaluator
  Render/                  # FitContext · CanvasFamilyRenderer · MetalFamilyRenderer(인스턴싱 SDF) · Exporter(PNG/SVG/수식카드)
  Structuring/             # 그림→수식: ContourExtractor(Vision) · StrokeSource(PencilKit) · FourierFitter · FamilySynthesizer(4종) · TemplateFitter(Tier B) · DCTPixelFitter · Metrics
  Presets/                 # Presets.json (원작 5종) · PresetLoader
  Assistant/               # FoundationModels 보조(가용성 게이트, @Generable 초안)
  Model/                   # EditorModel(@Observable, 디바운스 Task, undo) · StructuringModel · GalleryModel
  Persistence/             # SwiftData Artwork · DraftStore
  Views/                   # DrawTab(에디터+미리보기+스크러빙) · ReadTab(입력·윤곽 선택·적합 패널) · GalleryTab · PresetDrawer · ShareSheet
  Resources/               # Localizable.xcstrings · 화선지 배경 · 앱 아이콘
SuMukTests/                # Swift Testing
Docs/  Media/  README.md  LICENSE
```

상태 관리는 `@Observable` + `.environment`, 바인딩은 `@Bindable`. Combine은 쓰지 않고 `AsyncStream`/`Task` 디바운스를 쓴다(프로젝트 지침). 무거운 작업(평가·적합·내보내기)은 `nonisolated` 값 타입 입력을 받아 `Task.detached(priority: .userInitiated)`에서 수행하고 결과만 메인으로 돌려준다.

## 8. 프리셋·영감·라이선스 원칙

- **외부 이미지·공식 미포함(2026-10-17 결정)**: 앱과 저장소에는 웹에서 가져온 이미지도, 타인의 작품 공식을 전사한 것도 싣지 않는다. Yeganeh의 작업은 **기법(선분 가족·원 가족·픽셀 수식)의 영감**으로만 참고하고, README·앱 내 "영감" 섹션에 이름과 AMS 갤러리 링크만 둔다.
- **번들 프리셋 = 수묵 원작 5종**: 달항아리(원 3,600) · 은행잎(선분 820) · 매화(원 3,561) · 잉어(선분 2,900) · 학(선분 2,500). 모두 이 프로젝트에서 설계했고 Apache 2.0으로 공개한다. 생성기·수식 원본은 `Media/src/originals.py`, Swift 이식 후에는 `Presets/Presets.json`이 진실.
- 사용자가 외부 공식을 **직접 붙여넣는 것**은 앱 기능(캡션·LaTeX 임포터)으로 지원하되, 그 결과물의 출처 표기는 사용자 몫이며 앱은 저장 시 "출처 메모" 필드를 제공한다.
- 프리셋은 계속 늘린다(후보: 대나무, 소나무, 파도, 나비, 연꽃). 추가 기준은 "닫힌형 식만으로 정의 · 가족 ≤ 8개 · 실기기 1초 내 렌더".

## 9. 리스크와 대응

- **Tier B 품질 불확실** — 사진 윤곽이 Yeganeh형 짧은 식으로 잘 안 맞을 수 있다. → Tier A를 항상 기본값으로, Tier B는 실험 배지·지표·중단 가능으로 격리. Phase 6을 시간 박스(2일)로 제한.
- **Metal 디바이스 제약** — 시뮬레이터/구형 GPU 패밀리에서 비균일 스레드그룹·대형 버퍼 문제. → `dispatchThreadgroups` + 밴드 분할, Metal 불가 시 Canvas/CPU 폴백(요소 수 제한 안내).
- **에디터 성능** — 50,000자 스크립트에 하이라이팅을 매 키 입력마다 하면 느리다. → 토큰 기반 경량 하이라이팅, 보이는 영역만, 디바운스.
- **캡션 임포터의 모호성** — 산문 변형이 많다. → 패턴 실패 시 "직접 Script로 변환" 템플릿 제공, 임포트 결과는 항상 사용자가 확인.
- **DCT 픽셀 수식의 길이** — 512항이면 수식이 수십 KB. → 항 수 기본 48, 길이 경고, Σ 축약 표기 옵션.

## 10. 성공 기준(1차 출시 내부 기준)

- 원작 프리셋 5종이 iPhone 16 시뮬레이터와 실기기에서 모두 1초 내 렌더되고, Python 생성기 렌더와 육안 일치.
- 손그림 물고기 → 현 가족 변환이 1.5초 내 완료되고 평균 오차 ≤ 3%.
- 사진 → 픽셀 수식(48항) 왕복 렌더가 생성 수식과 픽셀 단위 일치.
- Swift Testing 100개 이상 통과, 실기기 빌드·설치·실행 확인.

## 11. 라이선스

Apache 2.0 (MathSketch와 동일).
