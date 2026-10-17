#!/usr/bin/env python3
"""Compose README images (banner, sample grid, formula card) from ../Samples renders."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = os.path.dirname(__file__); S = os.path.join(HERE, "..", "Samples"); OUT = os.path.join(HERE, "..")
KO = "/System/Library/Fonts/Supplemental/AppleMyungjo.ttf"
KO_SANS = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
MATH = "/System/Library/Fonts/Supplemental/STIXTwoText-Italic.ttf"
MATH_R = "/System/Library/Fonts/Supplemental/STIXTwoText.ttf"
INK = (28, 28, 30); PAPER = (250, 247, 240); GRAY = (110, 110, 115)

def img(name): return Image.open(os.path.join(S, name + ".png")).convert("RGB")
def fit(im, box):
    im = im.copy(); im.thumbnail(box, Image.LANCZOS); return im
def paste_center(dst, im, cx, cy):
    dst.paste(im, (int(cx - im.width/2), int(cy - im.height/2)))

def banner():
    W, H = 1800, 640
    b = Image.new("RGB", (W, H), PAPER); d = ImageDraw.Draw(b)
    crane = fit(img("sumuk-crane"), (820, 520)); jar = fit(img("sumuk-moon-jar"), (250, 250))
    # make renders paper-toned
    def tone(im):
        g = ImageOps.grayscale(im); return ImageOps.colorize(g, black=INK, white=PAPER)
    paste_center(b, tone(crane), 1330, 330)
    paste_center(b, tone(jar), 640, 490)
    title = ImageFont.truetype(KO, 150); sub = ImageFont.truetype(KO_SANS, 40); small = ImageFont.truetype(KO_SANS, 28)
    d.text((110, 90), "수묵", font=title, fill=INK)
    d.text((440, 160), "SuMuk", font=ImageFont.truetype(MATH_R, 60), fill=GRAY)
    d.text((640, 150), "· 數墨", font=ImageFont.truetype(KO, 60), fill=GRAY)
    d.text((112, 270), "수식은 그림으로, 그림은 수식으로", font=sub, fill=INK)
    d.text((112, 325), "선분과 원의 가족(family)으로 그리는 iPhone 수학 화첩", font=small, fill=GRAY)
    b.save(os.path.join(OUT, "banner.png"), optimize=True); print("banner.png")

def grid():
    rows = [
        ("수묵 원작 샘플 — 모두 k의 닫힌형 식으로 정의된 선분·원 가족 (원 3,600 · 선분 820 · 원 3,561 · 선분 2,760 · 선분 2,760)",
         [("sumuk-moon-jar", "달항아리"), ("sumuk-ginkgo", "은행잎"), ("sumuk-plum-blossom", "매화"),
          ("sumuk-carp", "잉어"), ("sumuk-crane", "학")]),
    ]
    cell, pad, cap = 340, 24, 70
    W = 5*cell + 6*pad; H = len(rows)*(cell + cap + 60) + pad
    g = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(g)
    f_cap = ImageFont.truetype(KO_SANS, 26); f_head = ImageFont.truetype(KO_SANS, 30)
    y = pad
    for head, items in rows:
        d.text((pad, y), head, font=f_head, fill=INK); y += 50
        for i, (name, label) in enumerate(items):
            im = fit(img(name), (cell - 20, cell - 20))
            x = pad + i*(cell + pad)
            d.rounded_rectangle([x, y, x + cell, y + cell], radius=18, outline=(225, 225, 228), width=2, fill=(252, 252, 252))
            paste_center(g, im, x + cell/2, y + cell/2)
            tw = d.textlength(label, font=f_cap)
            d.text((x + cell/2 - tw/2, y + cell + 12), label, font=f_cap, fill=GRAY)
        y += cell + cap + 10
    g.save(os.path.join(OUT, "samples-grid.png"), optimize=True); print("samples-grid.png")

def formula_card():
    W, H = 1900, 800
    c = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(c)
    leaf = fit(img("sumuk-ginkgo"), (640, 640)); paste_center(c, leaf, 360, 400)
    fi = ImageFont.truetype(MATH, 30); fr = ImageFont.truetype(MATH_R, 38); fk = ImageFont.truetype(KO_SANS, 30); fs = ImageFont.truetype(KO_SANS, 24)
    x0 = 740
    d.text((x0, 70), "segments  k = 1 … 700,   s = k/700,   θ = π/2 + 1.3·(s − 1/2)", font=fr, fill=INK)
    lines = [
        ("from", "( 0.05 · sin(2πs) · sin²(πs),   −1 + 0.22 · sin⁶(πs) )"),
        ("to", "( r(θ) · cos θ,   r(θ) · sin θ − 0.25 )"),
        ("where", "r(θ) = 1.15 · (1 − 0.24 · exp(−((θ − π/2)/0.08)²)) · (1 + 0.03 · sin(22θ) · sin(πs))"),
    ]
    y = 160
    for key, expr in lines:
        d.text((x0 + 20, y), key, font=fr, fill=GRAY); d.text((x0 + 130, y), expr, font=fi, fill=INK); y += 84
    d.text((x0, 440), "700개의 선분. 한쪽 끝은 잎자루, 다른 끝은 가장자리 곡선 위를 달린다.", font=fk, fill=INK)
    d.text((x0, 485), "가운데 홈은 exp(-x²) 한 항, 물결은 sin(22θ) 한 항이 만든다.", font=fk, fill=INK)
    d.text((x0, 580), "수묵은 이런 '가족 수식'을 파싱해 즉시 그리고,", font=fs, fill=GRAY)
    d.text((x0, 615), "사진·드로잉의 윤곽을 다시 이런 수식으로 구조화한다.", font=fs, fill=GRAY)
    d.text((x0, 710), "은행잎 — 수묵 원작 샘플 (Media/src/originals.py)", font=ImageFont.truetype(KO_SANS, 20), fill=GRAY)
    c.save(os.path.join(OUT, "formula-card.png"), optimize=True); print("formula-card.png")

if __name__ == "__main__":
    banner(); grid(); formula_card()
