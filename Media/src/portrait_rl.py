#!/usr/bin/env python3
"""Portrait sample — RL stage (prototype of the app's on-device RL refinement).

Environment : one episode = choose the 7 continuous parameters of the composite artwork
              (halftone spiral pitch s, max dot radius, gamma, dot count N, chord offset fraction,
              chord ink, tone ink) → render at half resolution → reward.
Reward      : −3·tone_loss − 2·chamfer_to_edges − λ·(elements / 10 000)   (fidelity vs. formula size)
Policy      : diagonal Gaussian in a squashed parameter space, REINFORCE with a moving baseline,
              parameters and Adam step in MLX (Apple-silicon on-device ML framework).
Outputs     : rl-before.png, rl-after.png, rl-reward-curve.png, rl-result.json
"""
import os, json, time, math
import numpy as np
import mlx.core as mx
import mlx.optimizers as optim
from PIL import Image, ImageDraw, ImageFont
from sumuk_core import *

HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, "..", "Portrait", "input", "portrait.jpg")
OUT = os.path.join(HERE, "..", "Portrait", "out")
rng = np.random.default_rng(1)

Lfull = load_gray(IN); Hf, Wf = Lfull.shape
L = load_gray(IN, max_side=240); H, W = L.shape; xs, ys, a = norm_coords(H, W)
edges = edge_points(L, max_pts=2500)
dct = DCTSeries(1 - Lfull, grid=(64, 48), terms=160)

# isoline curves once (structure comes from the classical M1 pipeline)
iso = isolines(Lfull, [0.22, 0.38, 0.54, 0.70, 0.86], sigma=1.6, min_len=90)
curves = [(lv, FourierCurve(rdp(p, 0.004), N=min(40, max(6, len(rdp(p, 0.004))//6))), len(rdp(p, 0.004))) for lv, p in iso]

RANGES = {"s": (0.012, 0.030), "rmax": (0.006, 0.030), "gamma": (0.6, 2.5), "N": (1500, 9000),
          "delta_frac": (0.01, 0.15), "chord_ink": (0.0, 0.8), "tone_ink": (0.1, 1.0)}
KEYS = list(RANGES)
LAMBDA = 0.6

def decode(u):  # u in (0,1)^7 -> physical params
    return {k: lo + (hi - lo)*float(u[i]) for i, (k, (lo, hi)) in enumerate(RANGES.items())}

def render(p, size=(W, H), ss=2):
    R = Raster(size[1], size[0], a, ss=ss)
    N = int(p["N"]); C, Rr = vogel_halftone(dct, a, N, p["s"], p["rmax"], p["gamma"])
    R.circles(C, Rr, fill=True, ink=int(255*(1 - p["tone_ink"])))
    for lv, fc, n in curves:
        Ns = int(np.clip(n*1.5, 120, 900)); d = max(2, int(Ns*p["delta_frac"]))
        P, Q = chord_family(fc, Ns, d); R.segments(P, Q, width=0.5, ink=int(255*(1 - p["chord_ink"]*(1.2 - lv))))
    return R

def reward_of(p):
    img = render(p).array()
    tl = tone_loss(img, L); ch = chamfer(edge_points(img, max_pts=2500), edges)
    elements = p["N"] + sum(int(np.clip(n*1.5, 120, 900)) for _, _, n in curves)
    r = -3*tl - 2*ch - LAMBDA*elements/10000
    return r, tl, ch, elements

# ------------------------------------------------------------------ policy (MLX)
mu = mx.zeros((7,)); log_sigma = mx.full((7,), math.log(0.6))
params = {"mu": mu, "log_sigma": log_sigma}
opt = optim.Adam(learning_rate=0.05)

def logprob(params, z):  # z: pre-squash actions (B,7)
    s = mx.exp(params["log_sigma"])
    return (-0.5*((z - params["mu"])/s)**2 - params["log_sigma"]).sum(-1)

def loss_fn(params, z, adv):
    return -(logprob(params, z) * adv).mean()

grad_fn = mx.value_and_grad(loss_fn)

ITERS, BATCH = 60, 12
history = []; baseline = None; best = (-1e9, None)
t_start = time.time()
p0 = decode(1/(1 + np.exp(-np.zeros(7)))); r0 = reward_of(p0)
print("initial", {k: round(v, 4) for k, v in p0.items()}, "reward", round(r0[0], 4))
for it in range(ITERS):
    m = np.array(params["mu"]); s = np.exp(np.array(params["log_sigma"]))
    z = m + s*rng.standard_normal((BATCH, 7))
    u = 1/(1 + np.exp(-z))
    rs = []
    for b in range(BATCH):
        p = decode(u[b]); r, tl, ch, el = reward_of(p); rs.append(r)
        if r > best[0]: best = (r, p, tl, ch, el)
    rs = np.array(rs)
    baseline = rs.mean() if baseline is None else 0.8*baseline + 0.2*rs.mean()
    adv = (rs - baseline); adv = adv/(adv.std() + 1e-6)
    loss, grads = grad_fn(params, mx.array(z, dtype=mx.float32), mx.array(adv, dtype=mx.float32))
    opt.update(params, grads); mx.eval(params["mu"], params["log_sigma"])
    params["log_sigma"] = mx.clip(params["log_sigma"], math.log(0.05), math.log(0.8))  # keep exploration bounded
    history.append({"iter": it, "mean": float(rs.mean()), "max": float(rs.max()), "best": float(best[0]),
                    "sigma": float(np.exp(np.array(params["log_sigma"])).mean())})
    print(f"it {it:02d} mean {rs.mean():.4f} max {rs.max():.4f} best {best[0]:.4f} sigma {history[-1]['sigma']:.3f}")
t_total = time.time() - t_start

# ------------------------------------------------------------------ outputs
pm = decode(1/(1 + np.exp(-np.array(params["mu"]))))   # policy mean after training
rm = reward_of(pm)
final_p = best[1] if best[0] > rm[0] else pm
final_r = best if best[0] > rm[0] else (rm[0], pm, rm[1], rm[2], rm[3])
save(render(p0, (Wf, Hf), ss=3).result(), os.path.join(OUT, "rl-before.png"))
save(render(final_p, (Wf, Hf), ss=3).result(), os.path.join(OUT, "rl-after.png"))

# reward curve (PIL plot, no matplotlib)
Wp, Hp = 1200, 520; img = Image.new("RGB", (Wp, Hp), "white"); d = ImageDraw.Draw(img)
f = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 22); fs = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 16)
vals = [h["mean"] for h in history] + [h["max"] for h in history] + [r0[0]]
lo, hi = min(vals), max(vals); pad = (hi - lo)*0.1 + 1e-6; lo -= pad; hi += pad
X0, Y0, X1, Y1 = 90, 60, Wp - 40, Hp - 70
def px(i): return X0 + (X1 - X0)*i/max(1, ITERS - 1)
def py(v): return Y1 - (Y1 - Y0)*(v - lo)/(hi - lo)
d.rectangle([X0, Y0, X1, Y1], outline=(200, 200, 200))
for g in range(5):
    v = lo + (hi - lo)*g/4; d.line([(X0, py(v)), (X1, py(v))], fill=(235, 235, 235)); d.text((10, py(v) - 10), f"{v:.3f}", font=fs, fill=(90, 90, 90))
d.line([(X0, py(r0[0])), (X1, py(r0[0]))], fill=(180, 60, 60), width=2)
for key, col, wdt in (("mean", (120, 120, 120), 2), ("max", (28, 28, 30), 3)):
    pts = [(px(h["iter"]), py(h[key])) for h in history]; d.line(pts, fill=col, width=wdt)
d.text((X0, 14), "RL 단계 보상 곡선 — REINFORCE(가우시안 정책, MLX)  검정: 배치 최대  회색: 배치 평균  빨강: 초기 매개변수", font=f, fill=(28, 28, 30))
d.text((X0, Hp - 50), f"반복 {ITERS} x 배치 {BATCH} = {ITERS*BATCH} 렌더, {t_total:.0f}s · 보상 = -3·톤손실 - 2·Chamfer - {LAMBDA}·요소수/10^4 · 초기 {r0[0]:.3f} → 최종 {final_r[0]:.3f}", font=fs, fill=(90, 90, 90))
img.save(os.path.join(OUT, "rl-reward-curve.png"))

result = {"iters": ITERS, "batch": BATCH, "seconds": t_total, "lambda": LAMBDA, "ranges": RANGES,
          "initial": {"params": p0, "reward": r0[0], "tone_loss": r0[1], "chamfer": r0[2], "elements": r0[3]},
          "final": {"params": final_p, "reward": final_r[0], "tone_loss": final_r[2], "chamfer": final_r[3], "elements": final_r[4]},
          "policy_mean_params": pm, "history": history}
json.dump(result, open(os.path.join(OUT, "rl-result.json"), "w"), indent=2)
print("final", {k: round(v, 4) for k, v in final_p.items()}, "reward", round(final_r[0], 4), "tone", round(final_r[2], 4), "chamfer", round(final_r[3], 4), "elements", final_r[4])
