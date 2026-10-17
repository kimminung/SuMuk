#!/usr/bin/env python3
"""Rendering helpers for segment / circle family artworks (numpy + Pillow).

Used by originals.py. Output: ../Samples/<name>.png
"""
import math, sys, os
import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "Samples")
SS = 4  # supersampling factor

def _fit(xs, ys, size, pad=0.06):
    xmin, xmax, ymin, ymax = xs.min(), xs.max(), ys.min(), ys.max()
    w, h = xmax - xmin, ymax - ymin
    w = w if w > 1e-9 else 1.0
    h = h if h > 1e-9 else 1.0
    W, H = size
    s = min(W * (1 - 2 * pad) / w, H * (1 - 2 * pad) / h)
    cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2
    def tx(x): return (x - cx) * s + W / 2
    def ty(y): return H / 2 - (y - cy) * s
    return tx, ty, s

def render_segments(name, P, Q, size=(1600, 1600), width=3, color=(20, 20, 20), bg=(255, 255, 255)):
    """P, Q: (N,2) arrays of segment endpoints."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    xs = np.concatenate([P[:, 0], Q[:, 0]]); ys = np.concatenate([P[:, 1], Q[:, 1]])
    tx, ty, _ = _fit(xs, ys, (W, H))
    for (x1, y1), (x2, y2) in zip(P, Q):
        d.line([(tx(x1), ty(y1)), (tx(x2), ty(y2))], fill=color, width=width)
    _save(img, name, size)

def render_circles(name, C, R, size=(1600, 1600), width=2, color=(20, 20, 20), bg=(255, 255, 255), fill=None):
    """C: (N,2) centers, R: (N,) radii."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    xs = np.concatenate([C[:, 0] - R, C[:, 0] + R]); ys = np.concatenate([C[:, 1] - R, C[:, 1] + R])
    tx, ty, s = _fit(xs, ys, (W, H))
    for (x, y), r in zip(C, R):
        rr = r * s
        if rr < 0.3: continue
        cx, cy = tx(x), ty(y)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=color, width=width, fill=fill)
    _save(img, name, size)

def _save(img, name, size):
    os.makedirs(OUT, exist_ok=True)
    img = img.resize(size, Image.LANCZOS)
    path = os.path.join(OUT, f"{name}.png")
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path))

pi = math.pi
sin, cos = np.sin, np.cos
