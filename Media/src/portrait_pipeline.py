#!/usr/bin/env python3
"""Portrait sample — classical (numpy) image→formula pipeline, prototype of the app's Tier A/B.

Methods applied to ../Portrait/input/portrait.jpg (not committed):
  M1 isoline chords   : luminance level sets → Fourier curves → chord (string-art) families
  M2 spiral halftone  : circles on a Vogel spiral, radius = DCT darkness series (closed form)
  M3 wave hatching    : row curves whose sine amplitude = DCT darkness series
  M4 pixel formula    : truncated 2D DCT per channel, several term counts, PSNR
  M5 short template   : Tier B — CEM fit of Σ c·sin^p(ωθ+φ) families to the silhouette
Outputs → ../Portrait/out/*.png, metrics.json, portrait.sumuk (full script), pixel-T256.sumuk
"""
import os, json, time, math, sys
import numpy as np
from PIL import Image
from sumuk_core import *

HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, "..", "Portrait", "input", "portrait.jpg")
OUT = os.path.join(HERE, "..", "Portrait", "out")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(0)

L = load_gray(IN); H, W = L.shape; xs, ys, a = norm_coords(H, W)
D = 1 - L
metrics = {"image": {"W": W, "H": H, "aspect": a}}
edges = edge_points(L)
print(f"image {W}x{H} aspect {a:.3f}, edge pts {len(edges)}")

def render_save(name, draw, ss=3, size=None):
    R = Raster(H if size is None else size[1], W if size is None else size[0], a, ss=ss); draw(R)
    img = R.result(); save(img, os.path.join(OUT, name + ".png")); return R.array()

# ------------------------------------------------------------------ M1 isoline chord families
t0 = time.time()
levels = [0.22, 0.38, 0.54, 0.70, 0.86]
iso = isolines(L, levels, sigma=1.6, min_len=90)
curves = []
for lv, pts in iso:
    pts = rdp(pts, 0.004)
    fc = FourierCurve(pts, N=min(40, max(6, len(pts)//6)))
    curves.append((lv, fc, len(pts)))
metrics["M1"] = {"levels": levels, "contours": len(curves), "fourier_harmonics": [c[1].N for c in curves],
                 "fit_err_mean": float(np.mean([c[1].error() for c in curves])), "seconds": time.time() - t0}
print("M1 contours", len(curves), "fit err", metrics["M1"]["fit_err_mean"])

def draw_m1(R, delta_frac=0.06, Ns_per_len=900):
    for lv, fc, n in curves:
        Ns = int(np.clip(n * 1.5, 120, Ns_per_len)); delta = max(2, int(Ns * delta_frac))
        P, Q = chord_family(fc, Ns, delta)
        R.segments(P, Q, width=0.5, ink=int(40 + 150 * lv))
m1 = render_save("m1-isoline-chords", draw_m1)
metrics["M1"]["tone_loss"] = tone_loss(m1, L); metrics["M1"]["chamfer_to_edges"] = chamfer(edge_points(m1), edges)

# ------------------------------------------------------------------ DCT darkness series (shared by M2/M3)
t0 = time.time()
dct = DCTSeries(D, grid=(64, 48), terms=160)
metrics["DCT"] = {"grid": [64, 48], "terms": 160, "psnr_vs_small": psnr(dct.reconstruct(), dct.small), "seconds": time.time() - t0}
Image.fromarray((255 * (1 - dct.reconstruct())).astype(np.uint8)).resize((W, H), Image.BICUBIC).save(os.path.join(OUT, "dct-160-reconstruction.png"))

# ------------------------------------------------------------------ M2 spiral halftone circles
def draw_m2(R, N=7000, s=0.0185, rmax=0.016, gamma=1.3):
    C, Rr = vogel_halftone(dct, a, N, s, rmax, gamma)
    R.circles(C, Rr, fill=True, ink=15)
t0 = time.time(); m2 = render_save("m2-spiral-halftone", draw_m2)
metrics["M2"] = {"N": 7000, "s": 0.0185, "rmax": 0.016, "gamma": 1.3, "tone_loss": tone_loss(m2, L), "seconds": time.time() - t0}

# ------------------------------------------------------------------ M3 wave hatching
def draw_m3(R, rows=72, amp=0.011, freq=110):
    for P in wave_rows(dct, a, rows, amp, freq, samples=1400, gain=1.25):
        R.polyline(P, width=0.55, ink=20)
t0 = time.time(); m3 = render_save("m3-wave-hatching", draw_m3)
metrics["M3"] = {"rows": 72, "amp": 0.011, "freq": 110, "tone_loss": tone_loss(m3, L), "seconds": time.time() - t0}

# ------------------------------------------------------------------ M4 pixel formula (DCT per channel)
rgb = np.asarray(Image.open(IN).convert("RGB"), dtype=np.float64) / 255
m4 = {}
for T in (32, 128, 512, 2048):
    t0 = time.time(); recon = np.zeros_like(rgb)
    for c in range(3):
        d = DCTSeries(rgb[..., c], grid=(96, 72), terms=T)
        recon[..., c] = np.asarray(Image.fromarray((255 * d.reconstruct()).astype(np.uint8)).resize((W, H), Image.BICUBIC)) / 255
    Image.fromarray((255 * recon).astype(np.uint8)).save(os.path.join(OUT, f"m4-pixel-T{T}.png"))
    m4[str(T)] = {"psnr": psnr(recon, rgb), "seconds": time.time() - t0}
    if T == 512:
        with open(os.path.join(OUT, "pixel-T512.sumuk"), "w") as f:
            f.write(f"// 픽셀 수식 — 채널별 2D DCT 상위 512항 (grid 96×72). m,n 은 연속 행/열 좌표.\npixel {W} × {H} {{\n  rgb( 255·R(x,y), 255·G(x,y), 255·B(x,y) )\n}}\nwhere\n")
            for c, nm in enumerate("RGB"):
                d = DCTSeries(rgb[..., c], grid=(96, 72), terms=T); f.write(d.script(nm) + "\n")
metrics["M4"] = m4; print("M4", {k: round(v["psnr"], 2) for k, v in m4.items()})

# ------------------------------------------------------------------ M5 Tier B: short template fit (CEM)
# target: silhouette = largest contour at the lightest level (person vs white background)
sil = max([c for c in iso if c[0] == levels[-1]], key=lambda c: len(c[1]))[1]
sil_rs = resample_closed(sil, 600)
J = 4
def template_eval(theta, th):
    """theta: [J×(c,p,w,phi)] for x then y. x(θ)=Σ c·sign(sin)·|sin|^p(wθ+φ)."""
    th = th[:, None]
    def coord(T):
        c, p, w, ph = T[:, 0], T[:, 1], T[:, 2], T[:, 3]
        s = np.sin(np.round(w) * th + ph)
        return (c * np.sign(s) * np.abs(s) ** np.round(p)).sum(1)
    return np.stack([coord(theta[:J]), coord(theta[J:])], 1)
def template_loss(theta):
    th = np.linspace(0, 2 * pi, 400, endpoint=False)
    P = template_eval(theta, th)
    cen = P.mean(0); P = P - cen + sil_rs.mean(0)
    return chamfer(P, sil_rs)
t0 = time.time()
# initialise from the 1st-harmonic Fourier ellipse of the silhouette, then let CEM add 3 higher terms per axis
f1 = FourierCurve(sil, N=1)
def ell(a1, b1):  # a·cos t + b·sin t = c·sin(t + φ)
    return math.hypot(a1, b1), math.atan2(a1, b1)
cx, phx = ell(f1.ax[1], f1.bx[1]); cy, phy = ell(f1.ay[1], f1.by[1])
mu = np.tile([[0.05, 1, 2, 0]], (2 * J, 1)).astype(float)
mu[0] = [cx, 1, 1, phx]; mu[J] = [cy, 1, 1, phy]
mu[1:J, 2] = [2, 3, 5]; mu[J+1:, 2] = [2, 3, 5]
sd = np.tile([[0.08, 0.8, 0.6, 1.0]], (2 * J, 1)).astype(float); sd[0] = sd[J] = [0.03, 0.3, 0.1, 0.2]
best, best_loss = None, 1e9
for it in range(40):
    cands = mu + sd * rng.standard_normal((160,) + mu.shape)
    cands[..., 1] = np.clip(cands[..., 1], 1, 7); cands[..., 2] = np.clip(cands[..., 2], 1, 9)
    losses = np.array([template_loss(c) for c in cands])
    elite = cands[np.argsort(losses)[:16]]
    mu = elite.mean(0); sd = elite.std(0) * 0.95 + 0.01
    if losses.min() < best_loss: best_loss, best = losses.min(), cands[np.argmin(losses)]
metrics["M5"] = {"J": J, "chamfer": float(best_loss), "iters": 40, "pop": 160, "seconds": time.time() - t0,
                 "theta": best.tolist()}
print("M5 CEM chamfer", best_loss, "in", round(time.time() - t0, 1), "s")
def draw_m5(R):
    th = np.linspace(0, 2 * pi, 1200, endpoint=False); P = template_eval(best, th); P = P - P.mean(0) + sil_rs.mean(0)
    k = np.arange(1200); d = 90
    R.segments(P, P[(k + d) % 1200], width=0.5, ink=30)
    R.polyline(sil_rs, width=1.0, ink=170, closed=True)
m5 = render_save("m5-template-fit", draw_m5)

# ------------------------------------------------------------------ composite "초상" + script
def draw_final(R):
    # tone: light halftone
    C, Rr = vogel_halftone(dct, a, 7000, 0.0185, 0.012, 1.6); R.circles(C, Rr, fill=True, ink=120)
    # structure: isoline chords, darker for darker levels
    draw_m1(R, delta_frac=0.05)
final = render_save("portrait-composite", draw_final)
metrics["composite"] = {"tone_loss": tone_loss(final, L), "chamfer_to_edges": chamfer(edge_points(final), edges)}

with open(os.path.join(OUT, "portrait.sumuk"), "w") as f:
    f.write(f"// 초상 (portrait) — 고전 파이프라인 결과. canvas 비율 a = {a:.4f}\n")
    f.write(f"canvas {W} × {H}\nink #141414 width 0.5\n\n// 톤: Vogel 나선 하프톤 (원 7,000개, 반지름 = DCT 농담 급수)\n")
    f.write("circles k = 1 ... 7000 {\n  center ( 0.0185·√k·cos(φk), 0.0185·√k·sin(φk) )\n  radius  0.012 · D(0.0185·√k·cos(φk), 0.0185·√k·sin(φk))^1.6\n}\nwhere φ = π(3 − √5)\n\n")
    for i, (lv, fc, n) in enumerate(curves, 1):
        Ns = int(np.clip(n * 1.5, 120, 900)); delta = max(2, int(Ns * 0.05))
        f.write(f"// 등고선 {i} (명도 {lv}) — 현 가족, 조화 {fc.N}개\nsegments k = 1 ... {Ns} {{\n  from ( x{i}(2πk/{Ns}), y{i}(2πk/{Ns}) )\n  to   ( x{i}(2π(k+{delta})/{Ns}), y{i}(2π(k+{delta})/{Ns}) )\n}}\n")
    f.write("\nwhere\n")
    for i, (lv, fc, n) in enumerate(curves, 1):
        f.write(fc.script_defs(f"x{i}", f"y{i}") + "\n")
    f.write(dct.script("D") + "\n")
metrics["script_chars"] = os.path.getsize(os.path.join(OUT, "portrait.sumuk"))

with open(os.path.join(OUT, "metrics.json"), "w") as f: json.dump(metrics, f, indent=2, ensure_ascii=False)
print(json.dumps({k: v for k, v in metrics.items() if k not in ("M5",)}, indent=1, ensure_ascii=False)[:1500])
