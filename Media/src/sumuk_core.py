#!/usr/bin/env python3
"""Shared numerics for the portrait sample: image I/O, 2D DCT series, contour tracing,
Fourier curve fitting, family synthesis (chord / circle / wave), rasterisation and metrics.
Pure numpy + Pillow so the same math can be ported 1:1 to Swift (vDSP / Metal)."""
import math, os, json, time
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

pi = math.pi

# ----------------------------------------------------------------------------- image
def load_gray(path, max_side=None):
    im = Image.open(path).convert("L")
    if max_side and max(im.size) > max_side:
        im.thumbnail((max_side, max_side), Image.LANCZOS)
    L = np.asarray(im, dtype=np.float64) / 255.0
    return L  # rows = y (top->bottom), cols = x

def norm_coords(H, W):
    """Map pixel grid to math coords: y in [-1,1] (up), x in [-a,a], a = W/H."""
    a = W / H
    xs = (np.arange(W) + 0.5) / W * 2 * a - a
    ys = 1 - (np.arange(H) + 0.5) / H * 2
    return xs, ys, a

def gaussian_blur(L, sigma):
    if sigma <= 0: return L
    im = Image.fromarray((np.clip(L, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float64) / 255.0

# ----------------------------------------------------------------------------- 2D DCT series
def dct_matrix(n):
    k = np.arange(n)[:, None]; m = np.arange(n)[None, :]
    M = np.cos(pi * (2 * m + 1) * k / (2 * n)) * np.sqrt(2 / n)
    M[0, :] /= np.sqrt(2)
    return M  # orthonormal DCT-II

class DCTSeries:
    """Truncated 2D DCT of a field F (H×W, downsampled to h×w): F(x,y) ≈ Σ_t c_t · C_u(m) · C_v(n)."""
    def __init__(self, F, grid=(48, 64), terms=64):
        H, W = F.shape
        h, w = grid
        small = np.asarray(Image.fromarray((np.clip(F, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), dtype=np.float64) / 255
        Dh, Dw = dct_matrix(h), dct_matrix(w)
        C = Dh @ small @ Dw.T
        flat = np.abs(C).ravel()
        idx = np.argsort(flat)[::-1][:terms]
        self.h, self.w, self.H, self.W = h, w, H, W
        self.u = idx // w; self.v = idx % w; self.c = C.ravel()[idx]
        self.terms = terms
        self.small = small

    def eval_xy(self, x, y, a):
        """Evaluate at math coords (x,y) with aspect a (x∈[-a,a], y∈[-1,1]). Closed form:
        m = (1−y)/2·h − 1/2 (continuous row), n = (x+a)/(2a)·w − 1/2 (continuous col)."""
        x = np.asarray(x, float); y = np.asarray(y, float)
        mc = (1 - y) / 2 * self.h - 0.5
        nc = (x + a) / (2 * a) * self.w - 0.5
        Cu = np.cos(pi * (2 * mc[..., None] + 1) * self.u / (2 * self.h)) * np.where(self.u == 0, 1 / np.sqrt(2), 1) * np.sqrt(2 / self.h)
        Cv = np.cos(pi * (2 * nc[..., None] + 1) * self.v / (2 * self.w)) * np.where(self.v == 0, 1 / np.sqrt(2), 1) * np.sqrt(2 / self.w)
        return np.clip((Cu * Cv * self.c).sum(-1), 0, 1)

    def reconstruct(self):
        Dh, Dw = dct_matrix(self.h), dct_matrix(self.w)
        C = np.zeros((self.h, self.w)); C[self.u, self.v] = self.c
        return np.clip(Dh.T @ C @ Dw, 0, 1)

    def script(self, name="D", digits=4):
        """Emit the closed-form definition as SuMuk Script `where` text (row m, col n continuous)."""
        terms = []
        for u, v, c in zip(self.u, self.v, self.c):
            cu = f"cos(π·{int(u)}·(2m+1)/{2*self.h})" if u else "1"
            cv = f"cos(π·{int(v)}·(2n+1)/{2*self.w})" if v else "1"
            coef = c * (1/np.sqrt(2) if u == 0 else 1) * np.sqrt(2/self.h) * (1/np.sqrt(2) if v == 0 else 1) * np.sqrt(2/self.w)
            terms.append(f"{coef:+.{digits}g}·{cu}·{cv}")
        body = " ".join(terms)
        return (f"{name}(x,y) = clamp( {body} , 0, 1 )\n"
                f"  // m = (1−y)/2·{self.h} − 1/2,  n = (x+a)/(2a)·{self.w} − 1/2,  a = {self.W/self.H:.4f}")

# ----------------------------------------------------------------------------- contour tracing
def label_components(B):
    """4-connected components of a boolean mask via iterative flood fill (numpy, small images)."""
    H, W = B.shape
    lab = np.zeros((H, W), dtype=np.int32); cur = 0
    for y0, x0 in zip(*np.nonzero(B)):
        if lab[y0, x0]: continue
        cur += 1; stack = [(y0, x0)]; lab[y0, x0] = cur
        while stack:
            y, x = stack.pop()
            for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                yy, xx = y+dy, x+dx
                if 0 <= yy < H and 0 <= xx < W and B[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = cur; stack.append((yy, xx))
    return lab, cur

def trace_boundary(B):
    """Moore-neighbour boundary tracing of the (single) component in B. Returns ordered (row, col) list."""
    H, W = B.shape
    P = np.zeros((H+2, W+2), dtype=bool); P[1:-1, 1:-1] = B
    ys, xs = np.nonzero(P)
    if len(ys) == 0: return []
    i = np.argmin(ys * (W+2) + xs); start = (int(ys[i]), int(xs[i]))
    nbrs = [(-1,0),(-1,1),(0,1),(1,1),(1,0),(1,-1),(0,-1),(-1,-1)]  # clockwise from N
    index = {v: k for k, v in enumerate(nbrs)}
    cur = start; back = 6  # the pixel west of the start is background (we "came" from there)
    out = [cur]
    for _ in range(4 * (H*W)):
        found = False
        for s in range(1, 9):
            d = (back + s) % 8
            ny, nx = cur[0] + nbrs[d][0], cur[1] + nbrs[d][1]
            if P[ny, nx]:
                # backtrack for the next step = direction from the new pixel to the last background pixel checked
                py, px = cur[0] + nbrs[(d-1) % 8][0], cur[1] + nbrs[(d-1) % 8][1]
                back = index[(py-ny, px-nx)]
                cur = (ny, nx); out.append(cur); found = True; break
        if not found: break
        if cur == start and len(out) > 2: break
    return [(y-1, x-1) for (y, x) in out[:-1]]

def isolines(L, levels, sigma=1.5, min_len=80):
    """Level-set boundaries of blurred luminance. Returns list of (level, polyline Nx2 array of (x,y) math coords)."""
    Lb = gaussian_blur(L, sigma); H, W = L.shape
    xs, ys, a = norm_coords(H, W)
    out = []
    for lv in levels:
        B = Lb < lv
        lab, n = label_components(B)
        for c in range(1, n+1):
            comp = lab == c
            if comp.sum() < min_len: continue
            bd = trace_boundary(comp)
            if len(bd) < min_len: continue
            pts = np.array([(xs[x], ys[y]) for (y, x) in bd])
            out.append((lv, pts))
    return out

def rdp(points, eps):
    """Ramer–Douglas–Peucker simplification for a polyline (N×2)."""
    if len(points) < 3: return points
    p0, p1 = points[0], points[-1]
    d = p1 - p0; n = np.hypot(*d)
    if n == 0: dist = np.hypot(*(points - p0).T)
    else: dist = np.abs(np.cross(d, points - p0)) / n
    i = int(np.argmax(dist))
    if dist[i] > eps:
        return np.vstack([rdp(points[:i+1], eps)[:-1], rdp(points[i:], eps)])
    return np.vstack([p0, p1])

# ----------------------------------------------------------------------------- Fourier curves
def resample_closed(pts, M):
    P = np.vstack([pts, pts[:1]])
    seg = np.hypot(*np.diff(P, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, s[-1], M, endpoint=False)
    return np.stack([np.interp(t, s, P[:, 0]), np.interp(t, s, P[:, 1])], 1)

class FourierCurve:
    """Closed curve x(t), y(t) = a0 + Σ_{n=1}^{N} a_n cos(nt) + b_n sin(nt), t∈[0,2π]."""
    def __init__(self, pts, N=16, M=512, closed=True):
        if not closed:  # open polyline: go and come back so the loop is closed
            pts = np.vstack([pts, pts[::-1][1:-1]])
        P = resample_closed(np.asarray(pts, float), M)
        Z = np.fft.fft(P[:, 0] + 1j * P[:, 1]) / M
        self.N = N
        self.ax = np.zeros(N+1); self.bx = np.zeros(N+1); self.ay = np.zeros(N+1); self.by = np.zeros(N+1)
        self.ax[0], self.ay[0] = Z[0].real, Z[0].imag
        for n in range(1, N+1):
            zp, zm = Z[n], Z[-n]  # e^{int}, e^{-int}
            # x(t) = Re(z), y(t) = Im(z); z(t) = Σ Z_n e^{int}
            self.ax[n] = (zp + zm).real; self.bx[n] = (-(zp - zm)).imag
            self.ay[n] = (zp + zm).imag; self.by[n] = (zp - zm).real
        self.src = P

    def eval(self, t):
        t = np.asarray(t, float)[..., None]; n = np.arange(1, self.N+1)
        c, s = np.cos(n*t), np.sin(n*t)
        x = self.ax[0] + (c*self.ax[1:]).sum(-1) + (s*self.bx[1:]).sum(-1)
        y = self.ay[0] + (c*self.ay[1:]).sum(-1) + (s*self.by[1:]).sum(-1)
        return np.stack([x, y], -1)

    def error(self):
        """Mean distance from source samples to the reconstruction (same t), normalised to [-1,1] height=2."""
        t = np.linspace(0, 2*pi, len(self.src), endpoint=False)
        return float(np.hypot(*(self.eval(t) - self.src).T).mean())

    def script_defs(self, xname="x", yname="y", digits=4):
        def series(a, b):
            terms = [f"{a[0]:.{digits}g}"]
            for n in range(1, self.N+1):
                if abs(a[n]) > 10**-digits: terms.append(f"{a[n]:+.{digits}g}·cos({n if n>1 else ''}t)")
                if abs(b[n]) > 10**-digits: terms.append(f"{b[n]:+.{digits}g}·sin({n if n>1 else ''}t)")
            return " ".join(terms)
        return f"{xname}(t) = {series(self.ax, self.bx)}\n{yname}(t) = {series(self.ay, self.by)}"

# ----------------------------------------------------------------------------- family synthesis
def chord_family(curve, Ns, delta):
    k = np.arange(1, Ns+1); t1 = 2*pi*k/Ns; t2 = 2*pi*(k+delta)/Ns
    return curve.eval(t1), curve.eval(t2)

def brush_circles(curve, Nc, r0, r1, m, p=1.0):
    th = 2*pi*np.arange(1, Nc+1)/Nc
    C = curve.eval(th); R = r0 + r1*np.abs(np.sin(m*th))**p
    return C, R

def vogel_halftone(dct, a, N, s, rmax, gamma=1.0, rmin=0.0, floor=0.04):
    """Circles on a Fermat/Vogel spiral: center_k = s√k (cos φk, sin φk), φ = golden angle;
    radius_k = rmax · D(center_k)^gamma where D is the DCT darkness series (closed form)."""
    k = np.arange(1, N+1, dtype=float); phi = pi*(3 - np.sqrt(5))
    r = s*np.sqrt(k); C = np.stack([r*np.cos(phi*k), r*np.sin(phi*k)], 1)
    inside = (np.abs(C[:, 0]) < a) & (np.abs(C[:, 1]) < 1)
    D = np.zeros(N); D[inside] = dct.eval_xy(C[inside, 0], C[inside, 1], a)
    R = np.where(inside & (D > floor), rmin + rmax*D**gamma, 0.0)
    return C, R

def wave_rows(dct, a, rows, amp, freq, samples=1200, gain=1.0):
    """Row curves y = y_j + amp·D(x, y_j)·sin(2π·freq·(x+a)/(2a)). Returns list of polylines."""
    polys = []
    for j in range(rows):
        yj = 1 - (j + 0.5)/rows*2
        x = np.linspace(-a, a, samples)
        D = dct.eval_xy(x, np.full_like(x, yj), a)
        y = yj + amp*np.clip(gain*D, 0, 1)*np.sin(2*pi*freq*(x + a)/(2*a))
        polys.append(np.stack([x, y], 1))
    return polys

# ----------------------------------------------------------------------------- raster
class Raster:
    """Simple antialiased rasteriser into an H×W canvas in math coords (y up), supersampled."""
    def __init__(self, H, W, a, ss=3, bg=255):
        self.H, self.W, self.a, self.ss = H, W, a, ss
        self.img = Image.new("L", (W*ss, H*ss), bg); self.d = ImageDraw.Draw(self.img)
    def to_px(self, P):
        P = np.asarray(P); x = (P[..., 0] + self.a)/(2*self.a)*self.W*self.ss; y = (1 - P[..., 1])/2*self.H*self.ss
        return x, y
    def segments(self, P, Q, width=1.0, ink=0):
        x1, y1 = self.to_px(P); x2, y2 = self.to_px(Q); w = max(1, int(round(width*self.ss)))
        for i in range(len(x1)): self.d.line([(x1[i], y1[i]), (x2[i], y2[i])], fill=ink, width=w)
    def polyline(self, P, width=1.0, ink=0, closed=False):
        x, y = self.to_px(P); pts = list(zip(x, y))
        if closed: pts.append(pts[0])
        self.d.line(pts, fill=ink, width=max(1, int(round(width*self.ss))), joint="curve")
    def circles(self, C, R, width=1.0, ink=0, fill=False):
        x, y = self.to_px(C); rr = np.asarray(R)/(2*self.a)*self.W*self.ss
        for i in range(len(x)):
            if rr[i] <= 0.2: continue
            box = [x[i]-rr[i], y[i]-rr[i], x[i]+rr[i], y[i]+rr[i]]
            if fill: self.d.ellipse(box, fill=ink)
            else: self.d.ellipse(box, outline=ink, width=max(1, int(round(width*self.ss))))
    def result(self):
        return self.img.resize((self.W, self.H), Image.LANCZOS)
    def array(self):
        return np.asarray(self.result(), dtype=np.float64)/255

# ----------------------------------------------------------------------------- metrics
def psnr(A, B):
    mse = float(np.mean((A - B)**2)); return 99.0 if mse == 0 else 10*math.log10(1/mse)

def tone_loss(render, target, sigma=4):
    """Mean abs difference of blurred luminance (how well the tones match), in [0,1]."""
    return float(np.abs(gaussian_blur(render, sigma) - gaussian_blur(target, sigma)).mean())

def chamfer(A, B):
    """Symmetric mean nearest-neighbour distance between point sets A, B (N×2), chunked brute force.
    An empty set (e.g. a blank render) scores a fixed large distance of 1.0 (half the canvas height)."""
    if len(A) == 0 or len(B) == 0: return 1.0
    def nn(P, Q):
        out = np.empty(len(P))
        for i in range(0, len(P), 2048):
            d = np.hypot(P[i:i+2048, None, 0] - Q[None, :, 0], P[i:i+2048, None, 1] - Q[None, :, 1])
            out[i:i+2048] = d.min(1)
        return out.mean()
    return float(0.5*(nn(A, B) + nn(B, A)))

def edge_points(L, sigma=1.2, thresh=0.12, max_pts=6000, seed=0):
    """Gradient-magnitude edge sample points in math coords (for Chamfer against structure)."""
    Lb = gaussian_blur(L, sigma); gy, gx = np.gradient(Lb); g = np.hypot(gx, gy)
    H, W = L.shape; xs, ys, a = norm_coords(H, W)
    yy, xx = np.nonzero(g > thresh)
    P = np.stack([xs[xx], ys[yy]], 1)
    if len(P) > max_pts:
        rng = np.random.default_rng(seed); P = P[rng.choice(len(P), max_pts, replace=False)]
    return P

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True); img.save(path, optimize=True); return path
