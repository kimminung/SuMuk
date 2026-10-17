#!/usr/bin/env python3
"""Portrait sample — on-device variant. Consumes ../Portrait/out/vision.json produced by
vision_ondevice.swift (Apple Vision: face landmarks, person segmentation, contours — the same
requests the iPhone app will call) and converts the structures into the same SuMuk families.
Then compares with the classical pipeline (metrics.json)."""
import os, json, time, base64, io, math
import numpy as np
from PIL import Image
from sumuk_core import *

HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, "..", "Portrait", "input", "portrait.jpg")
OUT = os.path.join(HERE, "..", "Portrait", "out")
V = json.load(open(os.path.join(OUT, "vision.json")))
L = load_gray(IN); H, W = L.shape; xs, ys, a = norm_coords(H, W)
edges = edge_points(L)
classical = json.load(open(os.path.join(OUT, "metrics.json")))

def vis2math(pts):  # Vision normalized (origin bottom-left) -> math coords
    P = np.asarray(pts, float); return np.stack([(P[:, 0]*2 - 1)*a, P[:, 1]*2 - 1], 1)

t0 = time.time()
fams = []   # (name, kind, FourierCurve, params)
# 1) person silhouette from the segmentation mask
mask = None
if V.get("personMaskPNGBase64"):
    m = Image.open(io.BytesIO(base64.b64decode(V["personMaskPNGBase64"]))).convert("L").resize((W, H), Image.BILINEAR)
    mask = np.asarray(m, float)/255 > 0.5
    lab, n = label_components(mask)
    big = max(range(1, n+1), key=lambda c: (lab == c).sum())
    bd = trace_boundary(lab == big)
    sil = rdp(np.array([(xs[x], ys[y]) for (y, x) in bd]), 0.004)
    fams.append(("silhouette", "chord", FourierCurve(sil, N=28), dict(Ns=900, delta=40, ink=40, w=0.5)))
# 2) face landmarks
styles = {"faceContour": ("brush", dict(Nc=500, r0=0.004, r1=0.006, m=9, ink=60)),
          "leftEyebrow": ("curve", dict(ink=30, w=1.2)), "rightEyebrow": ("curve", dict(ink=30, w=1.2)),
          "leftEye": ("chord", dict(Ns=160, delta=14, ink=20, w=0.5)), "rightEye": ("chord", dict(Ns=160, delta=14, ink=20, w=0.5)),
          "nose": ("curve", dict(ink=70, w=0.8)), "noseCrest": ("curve", dict(ink=110, w=0.6)),
          "outerLips": ("chord", dict(Ns=220, delta=18, ink=40, w=0.5)), "innerLips": ("curve", dict(ink=90, w=0.6)),
          "leftPupil": ("brush", dict(Nc=60, r0=0.006, r1=0.004, m=4, ink=10)), "rightPupil": ("brush", dict(Nc=60, r0=0.006, r1=0.004, m=4, ink=10))}
for poly in V["faceLandmarks"]:
    if poly["name"] not in styles: continue
    kind, prm = styles[poly["name"]]
    pts = vis2math(poly["points"])
    N = 6 if poly["closed"] else 8
    fams.append((poly["name"], kind, FourierCurve(pts, N=N, closed=poly["closed"]), prm))
# 3) Vision contours (dark-on-light): hair, jacket folds
for i, poly in enumerate(V["contours"][:6]):
    pts = vis2math(poly["points"])
    if len(pts) < 60: continue
    fams.append((f"contour{i}", "chord", FourierCurve(rdp(pts, 0.004), N=16), dict(Ns=500, delta=25, ink=90, w=0.4)))
t_convert = time.time() - t0

def draw_structure(R):
    for name, kind, fc, p in fams:
        if kind == "chord":
            P, Q = chord_family(fc, p["Ns"], p["delta"]); R.segments(P, Q, width=p["w"], ink=p["ink"])
        elif kind == "brush":
            C, Rr = brush_circles(fc, p["Nc"], p["r0"], p["r1"], p["m"]); R.circles(C, Rr, width=0.4, ink=p["ink"])
        else:
            t = np.linspace(0, pi, 300); R.polyline(fc.eval(t), width=p["w"], ink=p["ink"])  # open: first half of the mirrored loop

R = Raster(H, W, a); draw_structure(R); img = R.result(); save(img, os.path.join(OUT, "ondevice-structure.png")); od = R.array()
# composite with the same DCT halftone tone layer as the classical composite (so only the structure differs)
D = 1 - L; dct = DCTSeries(D, grid=(64, 48), terms=160)
R2 = Raster(H, W, a)
C, Rr = vogel_halftone(dct, a, 7000, 0.0185, 0.012, 1.6); R2.circles(C, Rr, fill=True, ink=120); draw_structure(R2)
save(R2.result(), os.path.join(OUT, "ondevice-composite.png")); odc = R2.array()

# landmark overlay for the report (on the photo)
ov = Image.open(IN).convert("RGB"); Rov = Raster(H, W, a, ss=2, bg=255); draw_structure(Rov)
layer = Rov.result().convert("L"); ov = Image.composite(Image.new("RGB", ov.size, (200, 30, 30)), ov, Image.eval(layer, lambda v: 255 - v))
ov.save(os.path.join(OUT, "ondevice-overlay.png"))

coeffs = sum(2*(2*fc.N + 1) for _, _, fc, _ in fams)
res = {"families": len(fams), "names": [f[0] for f in fams], "fourier_coefficients": coeffs,
       "vision_ms": V["timingsMs"], "convert_seconds": t_convert,
       "structure": {"chamfer_to_edges": chamfer(edge_points(od), edges), "tone_loss": tone_loss(od, L)},
       "composite": {"chamfer_to_edges": chamfer(edge_points(odc), edges), "tone_loss": tone_loss(odc, L)}}
# classical structure-only numbers for the comparison table
cl_coeffs = sum(2*(2*n + 1) for n in classical["M1"]["fourier_harmonics"])
res["classical"] = {"families": classical["M1"]["contours"], "fourier_coefficients": cl_coeffs, "seconds": classical["M1"]["seconds"],
                    "structure": {"chamfer_to_edges": classical["M1"]["chamfer_to_edges"], "tone_loss": classical["M1"]["tone_loss"]},
                    "composite": classical["composite"]}
json.dump(res, open(os.path.join(OUT, "ondevice-metrics.json"), "w"), indent=2, ensure_ascii=False)

with open(os.path.join(OUT, "portrait-ondevice.sumuk"), "w") as f:
    f.write(f"// 초상 — 온디바이스(Vision) 구조 + DCT 하프톤 톤. canvas 비율 a = {a:.4f}\ncanvas {W} × {H}\nink #141414 width 0.5\n\n")
    f.write("circles k = 1 ... 7000 {\n  center ( 0.0185·√k·cos(φk), 0.0185·√k·sin(φk) )\n  radius  0.012 · D(0.0185·√k·cos(φk), 0.0185·√k·sin(φk))^1.6\n}\nwhere φ = π(3 − √5)\n\n")
    for i, (name, kind, fc, p) in enumerate(fams, 1):
        if kind == "chord":
            f.write(f"// {name} — 현 가족\nsegments k = 1 ... {p['Ns']} {{\n  from ( x{i}(2πk/{p['Ns']}), y{i}(2πk/{p['Ns']}) )\n  to   ( x{i}(2π(k+{p['delta']})/{p['Ns']}), y{i}(2π(k+{p['delta']})/{p['Ns']}) )\n}}\n")
        elif kind == "brush":
            f.write(f"// {name} — 붓 원 가족\ncircles k = 1 ... {p['Nc']} {{\n  center ( x{i}(2πk/{p['Nc']}), y{i}(2πk/{p['Nc']}) )\n  radius  {p['r0']} + {p['r1']}·|sin({p['m']}·2πk/{p['Nc']})|\n}}\n")
        else:
            f.write(f"// {name} — 곡선\ncurve t ∈ [0, π] samples 300 {{ x = x{i}(t)  y = y{i}(t) }}\n")
    f.write("\nwhere\n")
    for i, (name, kind, fc, p) in enumerate(fams, 1): f.write(fc.script_defs(f"x{i}", f"y{i}") + "\n")
    f.write(dct.script("D") + "\n")
print(json.dumps(res, indent=1, ensure_ascii=False))
