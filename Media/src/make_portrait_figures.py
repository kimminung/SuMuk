#!/usr/bin/env python3
"""Compose README figures for the portrait sample from ../Portrait/out renders (source photo excluded)."""
import os, json
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "..", "Portrait", "out"); FIG = os.path.join(HERE, "..", "Portrait")
KO = "/System/Library/Fonts/AppleSDGothicNeo.ttc"; INK = (28, 28, 30); GRAY = (110, 110, 115)
def img(n): return Image.open(os.path.join(OUT, n + ".png")).convert("RGB")
def sheet(items, name, cell=(354, 472), head=None, cols=None):
    cols = cols or len(items); rows = (len(items) + cols - 1)//cols
    pad, cap, top = 18, 56, (60 if head else 0)
    W = cols*cell[0] + (cols+1)*pad; H = top + rows*(cell[1] + cap + pad) + pad
    s = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(s)
    f = ImageFont.truetype(KO, 22); fh = ImageFont.truetype(KO, 26); fs = ImageFont.truetype(KO, 17)
    if head: d.text((pad, 18), head, font=fh, fill=INK)
    for i, (n, label, sub) in enumerate(items):
        x = pad + (i % cols)*(cell[0] + pad); y = top + pad + (i//cols)*(cell[1] + cap + pad)
        im = img(n).resize(cell, Image.LANCZOS); s.paste(im, (x, y))
        d.rectangle([x, y, x + cell[0], y + cell[1]], outline=(225, 225, 228))
        d.text((x, y + cell[1] + 8), label, font=f, fill=INK); d.text((x, y + cell[1] + 34), sub, font=fs, fill=GRAY)
    s.save(os.path.join(FIG, name)); print(name)
m = json.load(open(os.path.join(OUT, "metrics.json"))); od = json.load(open(os.path.join(OUT, "ondevice-metrics.json"))); rl = json.load(open(os.path.join(OUT, "rl-result.json")))
sheet([("m1-isoline-chords", "M1 등고선 현 가족", f"등고선 {m['M1']['contours']}개 · 푸리에 · Chamfer {m['M1']['chamfer_to_edges']:.3f}"),
       ("m2-spiral-halftone", "M2 나선 하프톤 원 가족", f"원 7,000 · 반지름 = DCT 160항 · 톤손실 {m['M2']['tone_loss']:.3f}"),
       ("m3-wave-hatching", "M3 파형 해칭 곡선 가족", f"행 72 · 진폭 = DCT 급수 · 톤손실 {m['M3']['tone_loss']:.3f}"),
       ("m4-pixel-T512", "M4 픽셀 수식 (DCT 512항)", f"PSNR {m['M4']['512']['psnr']:.1f} dB · 수식 87 KB"),
       ("m5-template-fit", "M5 짧은 템플릿 적합 (Tier B)", f"Σ c·sin^p(ωθ+φ), 항 8 · CEM · Chamfer {m['M5']['chamfer']:.3f}"),
       ("portrait-composite", "합성: M2 톤 + M1 구조", f"portrait.sumuk {m['script_chars']//1000} KB · 톤손실 {m['composite']['tone_loss']:.3f}")],
      "portrait-methods.png", head="고전(numpy) 파이프라인 — 사진 한 장에 적용한 다섯 가지 수식화 방법", cols=3)
sheet([("portrait-composite", "고전 파이프라인 (등고선)", f"가족 {od['classical']['families']} · 계수 {od['classical']['fourier_coefficients']} · Chamfer {od['classical']['composite']['chamfer_to_edges']:.3f}"),
       ("ondevice-composite", "온디바이스 (Apple Vision)", f"가족 {od['families']} · 계수 {od['fourier_coefficients']} · Chamfer {od['composite']['chamfer_to_edges']:.3f}"),
       ("ondevice-structure", "온디바이스 구조만", f"랜드마크 12부위 + 인물 마스크 + 윤곽 6 · {od['vision_ms']['faceLandmarks']/1000:.1f}s + {od['vision_ms']['personSegmentation']/1000:.1f}s"),
       ("rl-after", "RL 단계 결과 (MLX REINFORCE)", f"보상 {rl['initial']['reward']:.2f} → {rl['final']['reward']:.2f} · 요소 {int(rl['final']['elements'])}")],
      "portrait-compare.png", head="같은 사진, 세 경로 — 고전 · 온디바이스 · 강화학습 미세조정")
Image.open(os.path.join(OUT, "rl-reward-curve.png")).save(os.path.join(FIG, "rl-reward-curve.png"))
