# TASKS — 수묵 (SuMuk)

범례: `[x]` 완료 · `[ ]` 미착수 · `[~]` 부분 완료/확인 필요
근거 문서: `Docs/PRD-SuMuk.md` (FR 번호는 PRD와 동일)
참고 프로젝트: `Desktop/MathSketch` — MathEngine·PixelFormula·SwiftData·`FitContext` 패턴 이식

## Phase 0 — 프로젝트 셋업 (2026-10-17 문서 작업 완료, 코드 미착수)

- [x] T0.1 저장소 폴더 `Desktop/SuMuk` 생성, `LICENSE`(Apache 2.0), `.gitignore`(Xcode), `.gitattributes`, `Docs/`, `Media/` 준비, `git init`.
- [x] T0.2 기술 PRD(`Docs/PRD-SuMuk.md`)·태스크 문서(이 파일)·`README.md` 작성.
- [x] T0.3 수묵 원작 샘플 5종 설계·렌더(`Media/src/render_samples.py` 렌더 헬퍼, `originals.py`, `make_readme_images.py`), README 이미지(배너·그리드·수식 카드·파이프라인 SVG). 처음에 함께 만들었던 Yeganeh 공식 재현 렌더 5종은 사용자 결정(외부 이미지·공식 미사용)으로 저장소·문서에서 제거.
- [ ] T0.4 Xcode 프로젝트: `Untitled Project/MyApp`를 `SuMuk`로 개명(타깃·스킴·Product Name), `PRODUCT_BUNDLE_IDENTIFIER = com.coulson.SuMuk`(placeholder `devplaceholder.*` 금지 — MathSketch 실기기 교훈), `TARGETED_DEVICE_FAMILY = 1`(iPhone 우선), `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`, `Desktop/SuMuk/SuMuk.xcodeproj`로 이동.
- [ ] T0.5 그룹 구조 선셋업: `MathEngine/`, `Script/`, `Family/`, `Render/`, `Structuring/`, `Presets/`, `Assistant/`, `Model/`, `Persistence/`, `Views/`, `Resources/`, 테스트 타깃 `SuMukTests`(Swift Testing).
- [ ] T0.6 첫 커밋(문서 + 미디어 + 빈 앱 골격).

## Phase 1 — MathEngine 이식 + SuMuk Script 파서 (FR-1)

- [ ] T1.1 MathSketch `MathLexer/MathAST/MathParser/MathEvaluator` 이식(`nonisolated` 유지). `MathSyntaxError` 열 번호 메시지 유지.
- [ ] T1.2 `ScriptLexer`: 유니코드 연산자(`· × − π Σ ⌊ ⌋ | ∈`), 범위 `...`, 키워드, 주석(`//`), 아래첨자(`_`, `_{…}`), 거듭제곱 함수 표기 `sin^7(`.
- [ ] T1.3 `FamilyParser`: `canvas`/`ink`/`segments`/`circles`/`curve`/`pixel`/`where`/`let … in [a,b]`/`animate`. 병치 곱셈 우선순위, 복소수 표기(`i`, `e^(iθ)`) → 실수부/허수부 분해.
- [ ] T1.4 `ScriptFormatter`: 정규화 출력(들여쓰기·연산자 통일·숫자 포맷), 왕복 테스트.
- [ ] T1.5 자유 변수·인자 수·상한(가족 20, 요소 1,000,000, 50,000자) 검증, 한국어 오류.
- [ ] T1.6 `CaptionImporter`(영어 캡션 문장 → Script), `LaTeXImporter`(PixelFormula 전처리기 확장), 입력 종류 판별(`ScriptKindDetector`: Script / 캡션 / LaTeX / 픽셀).
- [ ] T1.7 테스트: 원작 프리셋 5종 파싱 → 특정 k에서 끝점·중심·반지름이 numpy 생성기(`Media/src/originals.py`)와 1e-9 내 일치(값은 Python으로 생성해 픽스처로 저장), 캡션 임포트(합성 문장 5종), 오류 사례 10종, 왕복.

## Phase 2 — 평가기 + Canvas 렌더 + 프리셋 (FR-2, FR-3 일부)

- [ ] T2.1 `ExpressionCompiler`: AST → 스택 바이트코드, 상수 접기, `where` 인라인(깊이 ≤ 8).
- [ ] T2.2 `FamilyEvaluator`(vDSP): `k` 배열 벌크 평가, `signedPow`, NaN/∞ 제외 마스크. 벤치: 20,000개 ≤ 2ms.
- [ ] T2.3 `FitContext` 이식 + `CanvasFamilyRenderer`(선분·원·곡선, 두께·불투명도·먹색), 화선지 배경 프리셋.
- [ ] T2.4 `Presets.json`(원작 5종: Script·제목·설명) + `PresetLoader`. `originals.py`의 수식을 Script로 옮겨 적고 Python 렌더와 비교.
- [ ] T2.5 최소 `DrawTab`: 프리셋 선택 → 미리보기(읽기 전용 Script 표시). iPhone 16 시뮬레이터에서 프리셋 5종 육안 확인, 스크린샷 → `Media/Screenshots/phase2-*.png`.

## Phase 3 — 에디터 UX (FR-4)

- [ ] T3.1 `EditorModel(@Observable)`: 텍스트 → 120ms 디바운스(`Task.sleep`) → 파싱/평가/렌더 파이프라인, 마지막 성공 결과 유지, 오류 배너.
- [ ] T3.2 경량 하이라이팅(토큰 기반 `AttributedString`, 보이는 범위만), 키보드 액세서리(`π · ^ ( ) sin cos`).
- [ ] T3.3 숫자 스크러빙: 숫자 토큰 롱프레스 + 가로 드래그, 자릿수 기반 스텝, 햅틱, 텍스트 치환(선택 범위 유지).
- [ ] T3.4 `let x = v in [a, b]` 변수 슬라이더, `animate t ∈ [a,b] duration s` 재생 컨트롤(`TimelineView`), 모션 감소 존중.
- [ ] T3.5 Undo/Redo(텍스트 스냅샷, 스크러빙 1회 = 1스냅샷, 최대 100), 전체 지우기 확인.
- [ ] T3.6 프리셋 서랍(시트), 수식 카드 미리보기.

## Phase 4 — Metal 대형 렌더 + 내보내기 (FR-2 GPU, FR-3)

- [ ] T4.1 `MetalShaderTranspiler` 일반화(가족 식 → 컴퓨트 커널, 끝점/중심/반지름 버퍼), `mathMode = .safe`, `dispatchThreadgroups` + 밴드 분할.
- [ ] T4.2 `MetalFamilyRenderer`: 인스턴스드 쿼드 + SDF(선분 두께·끝 모양, 원 외곽선/채움), MSAA 또는 SDF AA, 뷰 변환(핀치/드래그).
- [ ] T4.3 경로 자동 선택(요소 ≤ 5,000 Canvas, 초과 Metal), Metal 불가 시 폴백 + 안내.
- [ ] T4.4 벤치: 1,000,000 선분 1024px ≤ 1.0s, 100,000 원 ≤ 16ms(실기기 측정값 기록).
- [ ] T4.5 `Exporter`: PNG(1024/2048/4096, 투명 옵션), SVG(≤ 20,000 요소), 수식 카드 PNG(그림 + 조판 수식 + 출처), Script/LaTeX 텍스트, `ShareLink`.
- [ ] T4.6 시뮬레이터에서 Metal 경로 실제 실행 확인(MathSketch 교훈: Mac 호스트 GPU에서 되는 것과 별개).

## Phase 5 — 그림 → 수식 Tier A (FR-5)

- [ ] T5.1 입력: `PhotosPicker`, `fileImporter`(PNG/JPEG/HEIC/PDF 1쪽), PencilKit 캔버스(`PKCanvasView` 래핑, 스트로크 → 폴리라인). 카메라는 should(`AVCapturePhotoOutput`, 권한 문자열).
- [ ] T5.2 `ContourExtractor`: `VNDetectContoursRequest`(contrast·darkOnLight 토글, 1024px 다운샘플), 면적 순 상위 12개, 좌표 정규화, RDP 단순화(ε 슬라이더).
- [ ] T5.3 윤곽 선택 UI: 색 구분 오버레이, 탭 선택/다중 선택, 기본 최대 윤곽.
- [ ] T5.4 `FourierFitter`: 호 길이 재매개변수화 → M 샘플 → 실수 DFT → `(a₀, aₙ, bₙ)`(N 1~64), 유효숫자 4자리 반올림.
- [ ] T5.5 `FamilySynthesizer` 4종: `curve` / 현 가족(δ) / 원 가족(붓 r₀, r₁, m, p) / 해칭 가족 → Script 문자열(`where`에 `x_i(t), y_i(t)`).
- [ ] T5.6 `Metrics`: 평균/최대 거리(정규화 %), 수식 길이(문자·항 수). 오버레이 3모드(원본/결과/겹침).
- [ ] T5.7 `ReadTab` 완성: 입력 → 윤곽 선택 → 변환 종류·슬라이더 → 지표 → "스크립트로 열기"/저장.
- [ ] T5.8 테스트: 합성 도형(원·별·하트 폴리라인)의 푸리에 재구성 오차 < 0.5%, 현 가족 Script가 파서로 다시 읽히고 요소 수 일치, 1024px 사진 전체 파이프라인 ≤ 1.5s(실기기).

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

- [ ] T8.1 SwiftData `Artwork` 모델(script 진실, 썸네일 externalStorage, sourceImage 옵션·동의), 드래프트 1개 자동 저장(0.8s `Task` 디바운스).
- [ ] T8.2 `GalleryTab`(`@Query` 그리드), 상세(수식 전문·지표·출처), 열기/복제/삭제, 썸네일 `ImageRenderer`(+픽셀 배경 합성).
- [ ] T8.3 재실행 복원(드래프트) 시뮬레이터 QA(앱 스와이프 종료 → 콜드 스타트).

## Phase 9 — FoundationModels 보조 (FR-9, 선택)

- [ ] T9.1 가용성 게이트(`SystemLanguageModel.default.availability`), 비가용 시 UI 숨김.
- [ ] T9.2 설명/제목 제안(`LanguageModelSession`, 한국어 지시문), Script 수정 초안(`@Generable` 구조 → 파서 검증 → 미리보기 → 수락).
- [ ] T9.3 실기기(Apple Intelligence 지원 기기)에서 응답 확인, 시뮬레이터 비가용 경로 확인.

## Phase 10 — 접근성·현지화·아이콘 (FR-10)

- [ ] T10.1 `accessibilityLabel/Value/Hint` 전수(에디터 토큰·슬라이더·윤곽 선택·갤러리), 미리보기 가족 요약 라벨.
- [ ] T10.2 Dynamic Type(에디터 모노스페이스 스케일), 모션 감소, 고대비 먹색 확인.
- [ ] T10.3 String Catalog(ko 기본, en), 오류 메시지 포함.
- [ ] T10.4 앱 아이콘: 앱 자신의 렌더러로 "학" 또는 "달항아리" 선분 가족을 1024px로 렌더(MathSketch 방식: `RunCodeSnippet` + `ImageRenderer`), iOS 기본·다크·틴티드, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

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

- **Script가 진실**: 스크러빙·슬라이더·FoundationModels 초안·임포터는 모두 "텍스트를 바꾸는 행위"다. 모델이 텍스트와 별도의 상태를 갖지 않게 해 undo·저장·공유가 한 경로로 모인다.
- **스타일 ≠ 수학**: `ink`/`canvas`는 Script에 있지만 수식 카드와 LaTeX 내보내기에서는 제외한다(MathSketch "색상 ≠ 수식" 원칙 계승).
- **Combine 미사용**: 프로젝트 지침에 따라 디바운스는 `Task` + `Task.sleep` 취소 패턴, 스트림은 `AsyncStream`. MathSketch의 Combine 디바운스는 이식하지 않는다.
- **Metal 교훈 이식**: `dispatchThreads` 대신 `dispatchThreadgroups`(시뮬레이터 비균일 스레드그룹 미지원), 밴드 분할로 GPU 워치독 회피, 시뮬레이터에서 반드시 1회 실행.
- **외부 이미지·공식 미사용(2026-10-17 사용자 결정)**: 웹에서 가져온 이미지와 타인 작품의 공식 전사본은 저장소·앱·문서 어디에도 싣지 않는다. Yeganeh는 기법의 영감으로 이름과 링크만 언급. 새 프리셋은 Python 생성기로 먼저 설계·렌더해 확인한 뒤 Script로 옮긴다.
- **이름**: 수묵(水墨/數墨) — 먹의 농담 = 원 반지름·선 밀도의 변조. 번들 원작 샘플은 의도적으로 수묵 모티프(달항아리·은행잎·매화·잉어·학)로 설계해 앱 정체성을 만든다.
