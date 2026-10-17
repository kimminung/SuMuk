---
name: SuMuk Ink & Glass
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#e1bfb8'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#a88a84'
  outline-variant: '#59413c'
  surface-tint: '#ffb4a6'
  primary: '#ffb4a6'
  on-primary: '#660900'
  primary-container: '#f36147'
  on-primary-container: '#590700'
  inverse-primary: '#af301b'
  secondary: '#c9c6c0'
  on-secondary: '#31312c'
  secondary-container: '#474742'
  on-secondary-container: '#b7b5af'
  tertiary: '#c6c6cb'
  on-tertiary: '#2f3034'
  tertiary-container: '#909095'
  on-tertiary-container: '#282a2e'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad3'
  primary-fixed-dim: '#ffb4a6'
  on-primary-fixed: '#3f0300'
  on-primary-fixed-variant: '#8d1705'
  secondary-fixed: '#e5e2db'
  secondary-fixed-dim: '#c9c6c0'
  on-secondary-fixed: '#1c1c18'
  on-secondary-fixed-variant: '#474742'
  tertiary-fixed: '#e3e2e7'
  tertiary-fixed-dim: '#c6c6cb'
  on-tertiary-fixed: '#1a1b1f'
  on-tertiary-fixed-variant: '#46474b'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  display-lg:
    fontFamily: Epilogue
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
  display-lg-mobile:
    fontFamily: Epilogue
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-lg:
    fontFamily: Epilogue
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Epilogue
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Geist
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Geist
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 13px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-desktop: 1rem
  margin: 1rem
  margin-desktop: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system synthesizes traditional East Asian sumi ink wash aesthetics (*sumuk-hwa*) with forward-looking liquid glass human-interface mechanics. The interface treats digital creation as an organic physical medium suspended within an engineered, cinematic environment.

The core visual metaphor revolves around **The Ink Stone and The Hanji Canvas**:
- The workspace (the canvas) remains a sacred physical surface: unlit, fibrous, light-absorbent, and warm. 
- The instrument cluster and operational framing (toolbars, script console, inspector, status elements) act as dark, polished obsidian stone and frosted liquid crystal floating seamlessly above and around the work.

The aesthetic fuses **Tactile Skeuomorphism** (ink bleed dynamics, Xuan/Hanji paper absorption, stone-ground mineral seal textures) with **Dark Liquid Glassmorphism** (translucent frosted depth, spectral edge highlights, anisotropic blurs, high-precision typography). The emotional resonance is monastic focus, tactile intimacy, and hyper-modern precision.

## Colors

The color architecture is built around an intentional contrast between the warm, tactile light-mode canvas and the surrounding dark liquid glass chrome.

### Canvas Palette (The Paper Substrate)
- **Canvas Ground (`#FAF7F0`)**: Warm Hanji/Xuan rice-paper off-white. Preserved universally across dark and light modes to maintain drawing integrity.
- **Ink Primary (`#141414`)**: Dense, carbon-black stroke color. Mimics soot-and-glue ink stick deposit.
- **InkWash Dilution (`#7A7771`)**: Half-density wash for wet-in-wet tonal transitions and secondary vector indicators on the canvas.

### Chrome & System Palette (Obsidian & Liquid Glass)
- **Obsidian Base (`#121212`)**: Ultra-deep structural background for sheets, canvas gutters, and system backing.
- **Glass Ground (`#1C1C1E`)**: Primary surface for frosted dark chrome navigation bars, bottom sheets, and floating tool palettes with 78% opacity.
- **PaperDeep Elevated (`#2C2C2E`)**: Higher elevation card and well backgrounds within inspectors and editors.
- **InkWash Hairline (`#3A3A3C`)**: Specular edge stroke, 1px/0.5pt glass boundary, and divider lines.
- **Chrome Ink Primary (`#F5F5F7`)**: High-contrast, optical white text and active tool glyphs.
- **InkSoft Secondary (`#98989D`)**: Subdued secondary text, inactive tool states, and non-focused iconography.

### Accents & Signifiers
- **Vermilion Seal (`#D94E36`)**: Traditional carved cinnabar stamp tone. Used sparingly for active system states, primary action execution, run buttons, and destructive confirmations.
- **Celadon Jade (`#4E8B7C`)**: Functional confirmation, clean status indicators, and syntax tokens within the script engine.

## Typography

The typographic hierarchy balances modern computational tools with calligraphic structure. 

- **Display & Headlines (`Epilogue`)**: Provides geometric precision with distinct humanist angles, echoing carved seals and chiseled strokes while maintaining contemporary interface clarity.
- **Body & Controls (`Geist`)**: Neutral, highly legible sans-serif with tight apertures and high horizontal compactness. Handles operational metadata, documentation, and dynamic UI panels without visual fatigue.
- **Monospace, Labels & Scripting (`JetBrains Mono`)**: Strict, geometric proportions for script editors, coordinate readout chips, brush parameters, and numerical telemetry.

### Editorial Rhythm
- Use uppercase styling exclusively on `label-sm` when designating physical properties (e.g., `VISCOSITY`, `GRAIN`, `WETNESS`, `ALPHA`).
- Tabular figures must be enabled by default for all coordinate, zoom, and brush diameter parameters to avoid visual jitter during manipulation.

## Layout & Spacing

Layout structures are split into two discrete behavioral layers: the **Infinite Paper Viewport** and the **Floating Chrome Overlay**.

### Surface Construction & Safe Margins
- **Canvas Viewport**: Positioned as a centered, hardware-accelerated fluid substrate. On mobile viewports, it bleeds edge-to-edge behind translucent chrome. On tablet/desktop viewports, the canvas floats as an unbound physical sheet surrounded by an obsidian workspace gutter (`#121212`).
- **Floating Chrome Layer**: Suspended above the canvas using iOS dynamic safe areas. Floating islands and pill bars detach from device edges by `space-lg` (16px), maintaining continuous fluid backdrops.

### Grid Rhythm & Reflow
- **Compact Viewport (Mobile)**: Primary tools condense into a bottom-docked liquid glass bar. Flyout panels anchor to bottom sheets with half-height and full-height snap points. Outer margins remain `margin` (16px).
- **Expanded Viewport (Tablet/Desktop)**: Bifurcated workspace. A dedicated liquid glass sidebar houses the script editor and layer hierarchy on the leading edge (320px fixed width), while brush dynamics and the seal inspector float on the trailing edge (280px fixed width). Central canvas maintains responsive margins with `gutter-desktop` (16px).

## Elevation & Depth

Visual hierarchy uses **Dark Liquid Glassmorphism** paired with specular refractive edging, rather than standard opaque shadow drops.

### Elevation Architecture
- **Layer 0 (Canvas Surface)**: Physical `#FAF7F0`. Completely opaque, flat, and non-reflective. Uses an ambient inner lip stroke (`rgba(20, 20, 20, 0.06)`) to signify paper depth within the application boundary.
- **Layer 1 (Recessed Wells & Editors)**: `#121212` with subtle inward depth. Used for code console inputs and terminal backdrops.
- **Layer 2 (Floating Islands & Toolbars)**: Backdrop blur of 30px with 78% opacity `#1C1C1E`. Surfaces are bordered by a 0.5pt specular hairline of `#3A3A3C` at 80% opacity, fading to 20% on the shadow-facing side.
- **Layer 3 (Overlays, Flyouts & Modals)**: Backdrop blur of 45px with 85% opacity `#2C2C2E`. Elevated by an ambient, deep-tinted shadow: `0 12px 32px -4px rgba(0, 0, 0, 0.65), 0 4px 12px 0 rgba(0, 0, 0, 0.45)`.
- **Layer 4 (Tactile Draggables & Active Brush Pickers)**: Augmented with a top specular highlight rim (`inset 0 0.5px 0 0 rgba(255, 255, 255, 0.18)`), creating physical proximity to the user's fingertip or pencil.

## Shapes

The interface embraces continuous Apple-standard squircle curves (continuous curvature) with structured, organic corners.

- **Micro Shapes (Chips, Status Indicators, Controls)**: Governed by `rounded` (8px continuous), preserving a precise instrument look.
- **Containers, Flyouts & Floating Pods**: Governed by `rounded-lg` (16px continuous), blending the perimeter into surrounding frosted glass blurs.
- **Primary Shells & Dynamic Islands**: Governed by `rounded-xl` (24px continuous) or full pill rounding for tool docks and action triggers.
- **The Vermilion Seal**: Square proportions with an imperceptible 3px rounding, referencing hand-carved stone chop stamps.

## Components

### Buttons & Interactive Controls
- **Primary Action (Vermilion Seal Button)**: Solid `#D94E36` fill with crisp `#F5F5F7` iconography or text. Features an inset 0.5pt rim (`rgba(255, 255, 255, 0.25)`) and a subtle dark shadow. On press, scales down smoothly to 0.96 with increased vermilion saturation.
- **Secondary Chrome Buttons**: Frosted `#2C2C2E` background, 0.5pt border of `#3A3A3C`, and `#F5F5F7` content. In hover/active states, surface opacity climbs to 95%.
- **Ghost/Tool Icons**: Unfilled, translucent circular touch targets. Inactive icons sit at `#98989D`; active selection illuminates to `#F5F5F7` resting over a localized liquid glow.

### Toolbars & The Floating Brush Dock
- Translucent horizontal pill (`rounded-xl`) suspended above the bottom edge.
- Features integrated haptic sliders for brush size and ink dilution (water ratio).
- Segmented dividers between brush categories rendered as 1px hairlines using `#3A3A3C` running 50% vertical height.

### Status Chips & Telemetry Readouts
- Encased in ultra-compact pill capsules using `JetBrains Mono` (`label-sm`).
- Background: `#1C1C1E` with 70% opacity and `#3A3A3C` hair-border.
- Content format: `[ZOOM 100%]`, `[FLOW 42%]`, `[WET]`. A glowing 4px circular LED dot shifts between Vermilion (active recording/simulation) and Celadon Jade (ready/idle).

### Script Console & Code Panel
- Dark-mode developer environment anchored in `#121212`.
- Active code line highlights with a soft `#2C2C2E` wash.
- Syntax highlighting uses the ink-wash hierarchy: Primary methods in `#F5F5F7`, variables in `#98989D`, parameters and numeric constants in `#4E8B7C`, and executable triggers in `#D94E36`.

### Cards & Inspector Lists
- Groups are enclosed within `#1C1C1E` containers with `rounded-lg` borders.
- Row separators use single-pixel `#3A3A3C` insets that terminate 16px short of card boundaries.
- Form controls (switches and check toggles) utilize the vermilion accent color for active states, set against a `#2C2C2E` inactive track.

### Selection & Canvas Indicators
- When vectors, strokes, or layers are targeted directly on the off-white canvas, bounding boxes reject typical corporate blues in favor of an ultra-crisp 1pt `#141414` line with `#D94E36` vermilion corner pips.