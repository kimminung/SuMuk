#!/usr/bin/env python3
"""App icons for iOS (light/dark/tinted), macOS (16–1024) and visionOS (3-layer solid image stack).
Motif: the crane preset drawn as ink segments on rice paper, with a vermilion 墨 seal.
Writes PNGs into ../AppIcon/ and an asset catalog into the Xcode project (path given as argv[1])."""
import os, sys, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "..", "AppIcon"); os.makedirs(OUT, exist_ok=True)
PAPER = (250, 247, 240); INK = (20, 20, 20); VERMILION = (194, 65, 43); DARKBG = (19, 19, 19)
S = 1024; SS = 4
pi, sin, cos = math.pi, np.sin, np.cos

def crane_segments():
    """Same families as originals.crane(), returned as (P, Q) arrays in math coords."""
    fams = []
    k = np.arange(1, 1601, dtype=float); u = 2*pi*k/1600
    fams.append((np.stack([1.7*sin(u + pi/3)**7, 0.20*cos(3*u)**2 + 0.05], 1), np.stack([0.15*sin(3*u + pi/5), -0.55*sin(u - pi/3)**2], 1)))
    n = np.arange(1, 501, dtype=float); s = n/500
    nx = 0.1 + 0.95*s; ny = 0.02 + 0.30*s**2 + 0.05*sin(pi*s)
    dy = 0.6*s + 0.05*pi*cos(pi*s); L = np.hypot(0.95, dy); nnx, nny = -dy/L, 0.95/L
    th = 0.07*(1 - s)**0.7 + 0.02
    fams.append((np.stack([nx + th*nnx, ny + th*nny], 1), np.stack([nx - th*nnx + 0.02, ny - th*nny], 1)))
    h = np.arange(1, 241, dtype=float); a = 2*pi*h/240
    fams.append((np.stack([1.08 + 0.075*cos(a), 0.37 + 0.05*sin(a)], 1), np.stack([1.08 + 0.075*cos(a + 2.2), 0.37 + 0.05*sin(a + 2.2)], 1)))
    b = np.arange(1, 121, dtype=float); v = b/120
    fams.append((np.stack([1.15 + 0*v, 0.385 - 0.02*v], 1), np.stack([1.15 + 0.3*v**0.6, 0.36 + 0.005*v], 1)))
    for off in (0.0, 0.06):
        m = np.arange(1, 151, dtype=float); s2 = m/150
        lx = -0.12 - 0.95*s2 + off; ly = -0.04 - 0.1*s2
        fams.append((np.stack([lx, ly + 0.01], 1), np.stack([lx - 0.03, ly - 0.01], 1)))
    return np.concatenate([a for a, b in fams]), np.concatenate([b for a, b in fams])

def ink_layer(color, alpha=200, width=3):
    """Crane strokes on a transparent 1024² RGBA layer."""
    P, Q = crane_segments()
    xs = np.concatenate([P[:, 0], Q[:, 0]]); ys = np.concatenate([P[:, 1], Q[:, 1]])
    cx, cy = (xs.min() + xs.max())/2, (ys.min() + ys.max())/2
    scale = S*SS*0.72/max(xs.max() - xs.min(), (ys.max() - ys.min())*1.6)
    def tx(x): return (x - cx)*scale + S*SS/2
    def ty(y): return S*SS*0.46 - (y - cy)*scale
    layer = Image.new("RGBA", (S*SS, S*SS), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for (x1, y1), (x2, y2) in zip(P, Q):
        d.line([(tx(x1), ty(y1)), (tx(x2), ty(y2))], fill=color + (alpha,), width=width)
    return layer.resize((S, S), Image.LANCZOS)

def seal(size=200, text="墨", color=VERMILION):
    img = Image.new("RGBA", (size*SS, size*SS), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    r = size*SS*0.1
    d.rounded_rectangle([0, 0, size*SS - 1, size*SS - 1], radius=r, fill=color + (255,))
    pad = size*SS*0.12
    d.rounded_rectangle([pad, pad, size*SS - pad, size*SS - pad], radius=r*0.5, outline=(255, 255, 255, 230), width=int(size*SS*0.035))
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/AppleMyungjo.ttf", int(size*SS*0.52))
    bbox = d.textbbox((0, 0), text, font=font); w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((size*SS - w)/2 - bbox[0], (size*SS - h)/2 - bbox[1]), text, font=font, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)

def paper_bg(color=PAPER, grain=True):
    bg = Image.new("RGBA", (S, S), color + (255,))
    if grain:
        d = ImageDraw.Draw(bg)
        for y in range(18, S, 36):
            for x in range(18, S, 36):
                d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=INK + (14,))
    return bg

def compose(bg, ink, with_seal=True, seal_color=VERMILION):
    img = bg.copy()
    shadow = ink.copy(); shadow.putalpha(shadow.split()[3].point(lambda a: int(a*0.25)))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)), (6, 8))
    img.alpha_composite(ink)
    if with_seal: img.alpha_composite(seal(color=seal_color), (S - 200 - 96, S - 200 - 96))
    return img

# --- iOS: light / dark / tinted
light = compose(paper_bg(), ink_layer(INK))
dark = compose(paper_bg(DARKBG, grain=False), ink_layer((235, 232, 226), alpha=210), seal_color=(217, 78, 54))
dark_t = dark.copy(); dark_t.putalpha(Image.new("L", (S, S), 255))        # dark icons may be transparent; keep opaque here
tint_ink = ink_layer((255, 255, 255), alpha=235)
tinted = Image.new("RGBA", (S, S), (0, 0, 0, 0)); tinted.alpha_composite(tint_ink)
# tinted seal: white square with the glyph cut out (alpha 0) so it stays legible once the system tints it
white_seal = seal(color=(255, 255, 255)).convert("RGBA")
glyph = seal(color=(0, 0, 0)).convert("RGBA")                                # black square, white glyph
glyph_mask = glyph.split()[0].point(lambda v: 255 if v > 128 else 0)          # glyph pixels
a = white_seal.split()[3].copy(); a.paste(0, mask=glyph_mask); white_seal.putalpha(a)
tinted.alpha_composite(white_seal, (S - 200 - 96, S - 200 - 96))
tinted = tinted.convert("LA").convert("RGBA")                                # grayscale with alpha, system applies the tint
light.convert("RGB").save(os.path.join(OUT, "AppIcon-iOS-1024.png")); dark.convert("RGB").save(os.path.join(OUT, "AppIcon-iOS-Dark-1024.png")); tinted.save(os.path.join(OUT, "AppIcon-iOS-Tinted-1024.png"))
# --- macOS: same artwork, 16…1024 (icons on macOS get the system squircle mask)
mac = light.convert("RGB")
for sz in (16, 32, 64, 128, 256, 512, 1024):
    mac.resize((sz, sz), Image.LANCZOS).save(os.path.join(OUT, f"AppIcon-mac-{sz}.png"))
# --- visionOS layers: Back (paper), Middle (soft shadow of the crane), Front (crane + seal)
back = paper_bg()
mid = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh = ink_layer(INK, alpha=120, width=7).filter(ImageFilter.GaussianBlur(10)); mid.alpha_composite(sh, (10, 14))
front = Image.new("RGBA", (S, S), (0, 0, 0, 0)); front.alpha_composite(ink_layer(INK)); front.alpha_composite(seal(), (S - 200 - 96, S - 200 - 96))
back.convert("RGB").save(os.path.join(OUT, "visionOS-Back.png")); mid.save(os.path.join(OUT, "visionOS-Middle.png")); front.save(os.path.join(OUT, "visionOS-Front.png"))
print("icons written to", os.path.relpath(OUT))

# --- asset catalog
if len(sys.argv) > 1:
    xc = sys.argv[1]
    appicon = os.path.join(xc, "AppIcon.appiconset"); os.makedirs(appicon, exist_ok=True)
    images = [
        {"filename": "AppIcon-iOS-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-iOS-Dark-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-iOS-Tinted-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
    ]
    for pt, files in ((16, ("16", "32")), (32, ("32", "64")), (128, ("128", "256")), (256, ("256", "512")), (512, ("512", "1024"))):
        images.append({"filename": f"AppIcon-mac-{files[0]}.png", "idiom": "mac", "scale": "1x", "size": f"{pt}x{pt}"})
        images.append({"filename": f"AppIcon-mac-{files[1]}.png", "idiom": "mac", "scale": "2x", "size": f"{pt}x{pt}"})
    for img in images:
        src = os.path.join(OUT, img["filename"]); Image.open(src).save(os.path.join(appicon, img["filename"]))
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, open(os.path.join(appicon, "Contents.json"), "w"), indent=2)
    stack = os.path.join(xc, "AppIcon.solidimagestack"); os.makedirs(stack, exist_ok=True)
    json.dump({"info": {"author": "xcode", "version": 1}, "layers": [{"filename": "Front.solidimagestacklayer"}, {"filename": "Middle.solidimagestacklayer"}, {"filename": "Back.solidimagestacklayer"}]},
              open(os.path.join(stack, "Contents.json"), "w"), indent=2)
    for name in ("Front", "Middle", "Back"):
        layer = os.path.join(stack, f"{name}.solidimagestacklayer"); imgset = os.path.join(layer, "Content.imageset"); os.makedirs(imgset, exist_ok=True)
        json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(layer, "Contents.json"), "w"), indent=2)
        Image.open(os.path.join(OUT, f"visionOS-{name}.png")).save(os.path.join(imgset, f"{name}.png"))
        json.dump({"images": [{"filename": f"{name}.png", "idiom": "vision", "scale": "2x"}], "info": {"author": "xcode", "version": 1}}, open(os.path.join(imgset, "Contents.json"), "w"), indent=2)
    print("asset catalog written to", xc)
