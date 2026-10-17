#!/usr/bin/env python3
"""Data for the 'picture -> formula' scene, computed with the app's own algorithm:
silhouette contour -> real Fourier series (16 harmonics, 512 arc-length samples),
36-row darkness grid -> 3x3 blur -> contrast stretch -> truncated DCT (220 terms) ->
Vogel-spiral stipple (6000 dots, keep k when D^gamma > mod(THRESH·k, 1) and D > 0.08 — see THRESH below).
Mirrors SuMuk/Structuring/ContourStructurer.swift. Output: data_s4.js (next to this script)"""
import sys, os, math, json
import numpy as np
from PIL import Image, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'src'))   # Media/src/sumuk_core.py
from sumuk_core import FourierCurve, trace_boundary, label_components

SRC = os.path.join(HERE, '..', '..', 'Samples', 'sumuk-plum-blossom.png')
HARM, TERMS, NDOTS, GAMMA = 16, 220, 6000, 1.0
# Stipple threshold. The app currently uses mod(0.618034·k, 1), but 0.618034 is the golden-angle step of the
# Vogel spiral itself (φ = 2π(1 − 0.618034)), so the threshold equals 1 − angle/2π and dots survive only in a
# wedge. The plastic-number step 0.7548777 is independent of the spiral angle, so density really follows D^γ.
THRESH = 0.7548777

im0 = Image.open(SRC).convert('L')
W0, H0 = im0.size
a = W0 / H0

# ---- silhouette contour (stand-in for VNDetectContoursRequest on the subject)
side = 640
im = im0.resize((side, int(side * H0 / W0)), Image.LANCZOS)
D = 1 - np.asarray(im, float) / 255
Db = np.asarray(Image.fromarray((D * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), float) / 255
B = Db > 0.06
lab, n = label_components(~B)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
inside = B.copy()
for c in range(1, n + 1):
    if c not in border: inside |= (lab == c)
lab2, n2 = label_components(inside)
sizes = [(lab2 == c).sum() for c in range(1, n2 + 1)]
big = lab2 == (1 + int(np.argmax(sizes)))
bd = trace_boundary(big)
H, W = big.shape
xs = (np.array([p[1] for p in bd]) + 0.5) / W * 2 * a - a
ys = 1 - (np.array([p[0] for p in bd]) + 0.5) / H * 2
P = np.stack([xs, ys], 1)
# light smoothing of the pixel staircase (circular moving average)
k = 5
Ps = np.stack([np.convolve(np.r_[P[-k:, i], P[:, i], P[:k, i]], np.ones(2 * k + 1) / (2 * k + 1), 'valid') for i in range(2)], 1)
# start the trace at the top of the flower so the vermilion pen begins at 12 o'clock
i0 = int(np.argmax(Ps[:, 1] - 0.3 * np.abs(Ps[:, 0])))
Ps = np.roll(Ps, -i0, axis=0)
# make orientation counter-clockwise (math coords)
area = 0.5 * np.sum(Ps[:, 0] * np.roll(Ps[:, 1], -1) - np.roll(Ps[:, 0], -1) * Ps[:, 1])
if area < 0: Ps = np.r_[Ps[:1], Ps[1:][::-1]]

fc = FourierCurve(Ps, N=HARM, M=512)
err = fc.error()
contour = fc.src  # 512 arc-length samples actually fitted

# complex coefficients for epicycles: z(t) = sum c_n e^{int}
cpx = []
for h in range(1, HARM + 1):
    A = complex(fc.ax[h], fc.ay[h]); Bc = complex(fc.bx[h], fc.by[h])
    cp = (A - 1j * Bc) / 2; cm = (A + 1j * Bc) / 2
    cpx.append((h, cp.real, cp.imag)); cpx.append((-h, cm.real, cm.imag))
cpx.sort(key=lambda e: -math.hypot(e[1], e[2]))
# sanity: complex sum equals real form
t = 0.7
z = complex(fc.ax[0], fc.ay[0]) + sum(complex(re, im_) * np.exp(1j * h * t) for h, re, im_ in cpx)
q = fc.eval(t)
assert abs(z.real - q[0]) < 1e-9 and abs(z.imag - q[1]) < 1e-9, (z, q)

# ---- tone: 36-row darkness grid exactly like ContourStructurer
gh = 36; gw = max(8, int(round(gh * a)))
g = np.asarray(im0.resize((gw, gh), Image.LANCZOS), float)
gray = 1 - g / 255
smooth = np.zeros_like(gray)
for r in range(gh):
    for c in range(gw):
        s = 0.0; nw = 0.0
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr, cc = r + dr, c + dc
                if 0 <= rr < gh and 0 <= cc < gw:
                    wgt = 4.0 if (dr == 0 and dc == 0) else (2.0 if (dr == 0 or dc == 0) else 1.0)
                    s += gray[rr, cc] * wgt; nw += wgt
        smooth[r, c] = s / nw
srt = np.sort(smooth.ravel()); p98 = srt[min(len(srt) - 1, int(len(srt) * 0.98))]
if p98 > 0.02:
    gain = min(1 / p98, 3); smooth = np.minimum(1, smooth * gain)
def dctm(nn):
    kk = np.arange(nn)[:, None]; mm = np.arange(nn)[None, :]
    M = np.cos(np.pi * (2 * mm + 1) * kk / (2 * nn)) * np.sqrt(2 / nn); M[0] /= np.sqrt(2); return M
Dh, Dw = dctm(gh), dctm(gw)
C = Dh @ smooth @ Dw.T
flat = [(i, j, C[i, j]) for i in range(gh) for j in range(gw)]
flat.sort(key=lambda e: -abs(e[2]))
top = flat[:TERMS]
U = np.array([e[0] for e in top]); V = np.array([e[1] for e in top])
coef = np.array([e[2] * ((1 / np.sqrt(2) if e[0] == 0 else 1) * np.sqrt(2 / gh)) * ((1 / np.sqrt(2) if e[1] == 0 else 1) * np.sqrt(2 / gw)) for e in top])
def Dxy(x, y):
    m = (1 - y) / 2 * gh - 0.5; nn = (x + a) / (2 * a) * gw - 0.5
    val = (coef * np.cos(np.pi * U * (2 * m[..., None] + 1) / (2 * gh)) * np.cos(np.pi * V * (2 * nn[..., None] + 1) / (2 * gw))).sum(-1)
    return np.clip(val, 0, 1)
kk = np.arange(1, NDOTS + 1, dtype=float)
phi = np.pi * (3 - np.sqrt(5)); s = math.hypot(a, 1) / math.sqrt(NDOTS)
X = s * np.sqrt(kk) * np.cos(phi * kk); Y = s * np.sqrt(kk) * np.sin(phi * kk)
Dk = Dxy(X, Y)
keep = (Dk ** GAMMA > np.mod(THRESH * kk, 1)) & (Dk > 0.08) & (np.abs(X) < a) & (np.abs(Y) < 1)
size = 0.0025 + 0.004 * Dk
dots = [[int(kk[i]), round(float(X[i]), 5), round(float(Y[i]), 5), round(float(size[i]), 5)] for i in np.nonzero(keep)[0]]

# ---- script text in the app's format (ContourStructurer.script + FourierCurve.definitions)
def fmt(v, signed, digits=4):
    s_ = (f"{v:+.{digits}f}" if signed else f"{v:.{digits}f}")
    while s_.endswith('0'): s_ = s_[:-1]
    if s_.endswith('.'): s_ = s_[:-1]
    return s_.replace('-', '−')
def series(A_, B_):
    parts = [fmt(A_[0], False)]
    for h in range(1, len(A_)):
        nm = 't' if h == 1 else f'{h}t'
        if abs(A_[h]) >= 0.00005: parts.append(f"{fmt(A_[h], True)}·cos({nm})")
        if abs(B_[h]) >= 0.00005: parts.append(f"{fmt(B_[h], True)}·sin({nm})")
    return ' '.join(parts)
xdef = 'x1(t) = ' + series(fc.ax, fc.bx)
ydef = 'y1(t) = ' + series(fc.ay, fc.by)
dterms = []
for i in range(TERMS):
    cu = '' if U[i] == 0 else f"·cos(π·{U[i]}·(2·m(y) + 1)/{2 * gh})"
    cv = '' if V[i] == 0 else f"·cos(π·{V[i]}·(2·n(x) + 1)/{2 * gw})"
    dterms.append(f"{fmt(coef[i], True)}{cu}{cv}")

data = dict(
    aspect=a, harmonics=HARM, fitError=err,
    contour=[[round(float(x), 5), round(float(y), 5)] for x, y in contour],
    c0=[fc.ax[0], fc.ay[0]],
    ax=fc.ax.tolist(), bx=fc.bx.tolist(), ay=fc.ay.tolist(), by=fc.by.tolist(),
    epicycles=[[h, re, im_] for h, re, im_ in cpx],
    dots=dots, nDots=NDOTS, gamma=GAMMA, toneTerms=TERMS, grid=[gh, gw],
    xdef=xdef, ydef=ydef, dfirst=dterms[:6], thresh=THRESH,
    smooth=[[round(float(v), 3) for v in row] for row in smooth],
)
with open(os.path.join(HERE, 'data_s4.js'), 'w') as f:
    f.write('window.S4 = ' + json.dumps(data, ensure_ascii=False) + ';\n')
print('contour pts', len(contour), 'fit err', round(err, 5), 'dots kept', len(dots), 'of', NDOTS)
print(xdef[:160]); print(ydef[:160]); print(dterms[:3])
