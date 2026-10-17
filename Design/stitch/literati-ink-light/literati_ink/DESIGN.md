---
name: Literati Ink
colors:
  surface: '#fcf9f2'
  surface-dim: '#dcdad3'
  surface-bright: '#fcf9f2'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3ec'
  surface-container: '#f0eee7'
  surface-container-high: '#ebe8e1'
  surface-container-highest: '#e5e2db'
  on-surface: '#1c1c18'
  on-surface-variant: '#444748'
  inverse-surface: '#31312c'
  inverse-on-surface: '#f3f0ea'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c8c6c5'
  secondary: '#ad321e'
  on-secondary: '#ffffff'
  secondary-container: '#ff6d53'
  on-secondary-container: '#6a0900'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1a1b1f'
  on-tertiary-container: '#848388'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c8c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474646'
  secondary-fixed: '#ffdad3'
  secondary-fixed-dim: '#ffb4a6'
  on-secondary-fixed: '#3f0300'
  on-secondary-fixed-variant: '#8b1908'
  tertiary-fixed: '#e3e2e7'
  tertiary-fixed-dim: '#c7c6cb'
  on-tertiary-fixed: '#1a1b1f'
  on-tertiary-fixed-variant: '#46464b'
  background: '#fcf9f2'
  on-background: '#1c1c18'
  surface-variant: '#e5e2db'
typography:
  display-lg:
    fontFamily: Public Sans
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Public Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Public Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 25px
    letterSpacing: -0.005em
  headline-sm:
    fontFamily: Public Sans
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Public Sans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Public Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 21px
  body-sm:
    fontFamily: Public Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-code:
    fontFamily: Space Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0em
  label-math:
    fontFamily: Space Mono
    fontSize: 15px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: -0.01em
  label-chip:
    fontFamily: Space Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

The design system marries East-Asian literati painting (*sumuk-hwa*) with computational rigor. It targets creators, mathematicians, and scholars working at the intersection of generative art, parametric design, and East Asian aesthetic traditions. The experience evokes the serenity of a sunlit studio desk: raw textured rice paper (*hanji*), unhurried brush strokes, concentrated ink sticks ground with water, and an authentic vermilion seal (*dojang*) serving as an authorial signature.

The design movement synthesizes **East-Asian Classical Minimalism** with **iOS System Pragmatism**. Surface treatment honors the paper plane: content spaces avoid frosted glass, artificial multi-color gradients, or synthetic neon lighting. Depth is derived strictly through ink density, dry-brush textures, dilution ratios, and hairline margins. Ambient iOS 26/27 system chrome remains quiet and liquid-thin around the perimeter, yielding entirely to the warmth of the tactile workspace.

## Colors

The palette operates on the logic of dilution and density rather than chromatic range:

- **Ink (Primary - `#141414`)**: Pure, unthinned calligraphy ink. Reserved for primary mathematical renderings, terminal vectors, active strokes, and primary text glyphs.
- **Vermilion (Secondary Accent - `#C2412B`)**: The seal-ink paste (*injeol*) stamp. Used sparingly for critical confirmations, primary CTA actions, selected node states, and authoritative accents.
- **Diluted Ink Soft (Tertiary - `#6E6E73`)**: Secondary annotations, parameters, variable indices, and quiet structural guidance.
- **Rice Paper (Canvas Base - `#FAF7F0`)**: An organic, warm off-white that acts as an immutable physical medium. The primary canvas does not invert to deep black; instead, it retains warm luminance to preserve ink calibration.
- **Paper Deep (`#EFE9DC`)**: Shadow tone of overlapping deckle edges, subtle card elevations, and sheet separators.
- **InkWash (`#D9D4C8`)**: Faint hairline partitions, inactive guide rulers, and passive boundary grids.
- **Error Note (`#D32F2F`)**: Traditional corrector's ink for parsing faults and syntax errors.

## Typography

The typography couples Apple SD Gothic Neo / Public Sans clarity for Korean and Latin structural UI with monospaced Space Mono glyph fidelity for algorithmic definitions.

All Korean headings and paragraph lines leverage relaxed tracking and deliberate vertical pacing to prevent glyph crowding. Numerical parameters, matrix coefficients, coordinates, and math tokens ($\pi, \sqrt{}, \theta, \delta$) utilize monospaced rendering with tabular figures enabled. This guarantees column stability during real-time value scrubbing.

## Layout & Spacing

The structural layout is tuned to the iPhone 16 form factor (393 × 852 pt):

- **Grid Model**: A vertical 4-column layout on mobile with 16pt margins and 16pt gutters. Safe areas are strictly observed at the top dynamic island corridor (59pt) and bottom home indicator zone (34pt).
- **Rhythm**: Spacing enforces a strict 4pt baseline module (4pt, 8pt, 12pt, 16pt, 24pt, 32pt). Mathematical formula chips and status indicators use compact 4pt/8pt increments; canvas margins and structural sheets step into 16pt/24pt allocations.
- **Reflow & Docking**: Inspection drawers snap into bottom-sheet configurations at 32%, 58%, and 92% screen height, allowing continuous access to the underlying ink canvas.

## Elevation & Depth

Visual hierarchy abandons traditional drop shadows, relying on physical substrate layering:

- **Tonal Substrates**: Overlays use `paperDeep` (`#EFE9DC`) stacked atop the primary `paper` (`#FAF7F0`) background. 
- **Hairline Ink Boundaries**: Dividers and sheet perimeters use 0.5pt rules colored with `inkWash` (`#D9D4C8`) to mimic precise edge scoring on pressed paper.
- **System Peripheral Chrome**: Floating top toolbars and dock controls utilize iOS Liquid Glass material over external edges without leaking blur or saturation filters into the drawing canvas itself.
- **Active Sealing**: Vermilion accents register as pressed stamps directly on paper, completely devoid of blur, specular highlights, or interior bevels.

## Shapes

Corner logic balances mechanical precision with the subtle softening of cut paper:

- Structural panels, modular formula sheets, and inspector drawers use smooth continuous squircle corners (`rounded-lg` / 16pt).
- Inline inputs, buttons, and coordinate panels utilize standard 8pt to 12pt radii.
- Parameter chips, state monitors, and formula tags use complete capsule profiles (999pt) to distinguish floating metadata from content containers.

## Components

- **Buttons**: Primary actions mirror red seal stamps (`vermilion` fill with pure `#FAF7F0` Korean typography). Secondary buttons use an unbordered paper-deep tone with `ink` text. Destructive actions rely on thin line work with `errorInk`.
- **Chips & Status Pills**: Encapsulated metadata tags rendered in `label-chip`. Inactive chips rest in an `inkWash` boundary; active parameters fill with `vermilion` or `ink` with inverted mono characters.
- **Input Fields & Formula Editors**: Inlined within `paperDeep` troughs. Monospaced formula inputs exhibit a persistent blinking hairline cursor in `ink`.
- **Drawing Canvas & Grid**: Rulers and axis marks are drawn in `inkWash`. Origin points are defined by a discrete 3pt Vermilion crosshair stamp.
- **Card Elements**: Content containers sit flat with subtle 0.5pt `inkWash` borders, differentiating workspaces without artificial cast shadows.