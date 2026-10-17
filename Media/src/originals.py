#!/usr/bin/env python3
"""Original SuMuk sample artworks (designed for this project, not transcriptions).
Each artwork is one or more *families*: segment families P(k)->Q(k) or circle families (C(k), R(k))."""
import math, sys
import numpy as np
from render_samples import render_segments, render_circles, pi, sin, cos

def _cat(fams):
    return np.concatenate([a for a, b in fams]), np.concatenate([b for a, b in fams])

def moon_jar():
    """달항아리: 3,600 circles whose centres ride along the jar's outline; radius = brush pressure."""
    k = np.arange(1, 1801, dtype=float); u = k/1800
    y = -0.86 + 1.72*u                                            # belly spans y in [-0.86, 0.86]
    belly = 0.98*(1 - np.abs(y/0.86)**2.4)**(1/2.1)                # rounded superellipse profile
    belly = belly*(1 + 0.06*np.exp(-((y-0.15)/0.35)**2))           # slightly fuller shoulder
    foot = 0.34*np.exp(-((u)/0.035)**2)
    neck = 0.40*np.exp(-((u-1)/0.03)**2)
    r = np.maximum(belly, np.maximum(foot, neck))*(1 + 0.008*sin(26*pi*u))
    sway = 0.02*sin(pi*u)**2*sin(2*pi*u)
    brush = 0.022 + 0.03*sin(pi*u)**1.5*np.abs(cos(4*pi*u + 0.4))**0.6
    left = np.stack([-r + sway, y], 1); right = np.stack([r + sway, y], 1)
    m = np.arange(1, 401, dtype=float); a = 2*pi*m/400
    mouth = np.stack([0.40*cos(a), 0.88 + 0.07*sin(a)], 1); mr = 0.012 + 0.006*cos(a)**2
    footr = np.stack([0.34*cos(a), -0.88 + 0.05*sin(a)], 1); fr = 0.01 + 0.004*sin(a)**2
    C = np.concatenate([left, right, mouth, footr]); R = np.concatenate([brush, brush, mr, fr])
    render_circles("sumuk-moon-jar", C, R, width=1)
def ginkgo():
    """은행잎: 700 segments fanning from the petiole to a notched, rippled edge."""
    k = np.arange(1, 701, dtype=float); s = k/700
    th = pi/2 + (s - 0.5)*1.3
    notch = 1 - 0.24*np.exp(-((th - pi/2)/0.08)**2)
    ripple = 1 + 0.03*sin(22*th)*sin(pi*s)
    rr = 1.15*notch*ripple
    Q = np.stack([rr*cos(th), rr*sin(th) - 0.25], 1)
    P = np.stack([0.05*sin(2*pi*s)*sin(pi*s)**2, -1.0 + 0.22*sin(pi*s)**6], 1)
    # petiole: a thin bundle downwards
    m = np.arange(1, 121, dtype=float); v = m/120
    S1 = np.stack([0.012*cos(6*pi*v) + 0.08*v**2, -1.0 - 0.55*v], 1)
    S2 = np.stack([-0.012*cos(6*pi*v) + 0.08*v**2 + 0.02, -1.0 - 0.55*v + 0.02], 1)
    Pa, Qa = _cat([(P, Q), (S1, S2)])
    render_segments("sumuk-ginkgo", Pa, Qa, width=1)

def plum_blossom():
    """매화: 5 petals × 700 circles sliding along each petal axis + 60 stamens + pistil."""
    Cs, Rs = [], []
    for j in range(5):
        phi = pi/2 + 2*pi*j/5
        k = np.arange(1, 701, dtype=float); u = k/700
        rho = 0.18 + 0.72*u
        width = 0.30*sin(pi*u)**0.8*(1 - 0.35*np.exp(-((u-1)/0.12)**2))
        wob = 0.02*sin(9*pi*u)
        Cs.append(np.stack([rho*cos(phi) + wob*cos(phi+pi/2), rho*sin(phi) + wob*sin(phi+pi/2)], 1))
        Rs.append(width)
    m = np.arange(1, 61, dtype=float); ang = 2*pi*m/60; L = 0.28 + 0.1*sin(5*ang)**2
    Cs.append(np.stack([L*cos(ang), L*sin(ang)], 1)); Rs.append(0.012 + 0.01*cos(3*ang)**2)
    Cs.append(np.zeros((1, 2))); Rs.append(np.array([0.06]))
    render_circles("sumuk-plum-blossom", np.concatenate(Cs), np.concatenate(Rs), width=1)

def carp():
    """잉어: woven body (two crossing segment families), fan tail, fins, eye — 2,900 elements."""
    n = 900
    k = np.arange(1, n+1, dtype=float); x = -0.7 + 1.7*k/n
    def top(x):  return 0.34*np.sqrt(np.clip(1 - x**2, 0, 1))*(1 + 0.25*x)
    def bot(x):  return -0.26*np.sqrt(np.clip(1 - x**2, 0, 1))*(1 + 0.25*x)
    sh = 0.22
    f1 = (np.stack([x, top(x)], 1), np.stack([np.clip(x + sh, -0.7, 1), bot(np.clip(x + sh, -0.7, 1))], 1))
    f2 = (np.stack([x, top(x)], 1), np.stack([np.clip(x - sh, -0.7, 1), bot(np.clip(x - sh, -0.7, 1))], 1))
    # tail: fan from the caudal peduncle to a forked edge
    m = np.arange(1, 501, dtype=float); v = -1 + 2*m/500
    T1 = np.stack([-0.68 + 0.03*v, 0.05*v], 1)
    T2 = np.stack([-1.15 - 0.18*np.abs(v) + 0.08*(1 - v**2)*cos(6*pi*v), 0.5*v*(1 + 0.1*cos(10*pi*v))], 1)
    # dorsal fin + pelvic fin: short fans
    d = np.arange(1, 201, dtype=float); w = d/200
    D1 = np.stack([-0.2 + 0.6*w, top(-0.2 + 0.6*w)], 1)
    D2 = np.stack([-0.35 + 0.6*w, top(-0.2 + 0.6*w) + 0.16*sin(pi*w)**0.7*(1 + 0.15*cos(14*pi*w))], 1)
    V1 = np.stack([0.1 + 0.3*w, bot(0.1 + 0.3*w)], 1)
    V2 = np.stack([0.0 + 0.3*w, bot(0.1 + 0.3*w) - 0.13*sin(pi*w)**0.7], 1)
    P, Q = _cat([f1, f2, (T1, T2), (D1, D2), (V1, V2)])
    # eye: 60 tiny segments around a point -> drawn as part of segment art (chords of a small circle)
    e = np.arange(1, 61, dtype=float); a = 2*pi*e/60
    E1 = np.stack([0.78 + 0.035*cos(a), 0.06 + 0.035*sin(a)], 1)
    E2 = np.stack([0.78 + 0.035*cos(a + 2.4), 0.06 + 0.035*sin(a + 2.4)], 1)
    P = np.concatenate([P, E1]); Q = np.concatenate([Q, E2])
    render_segments("sumuk-carp", P, Q, width=1, size=(1600, 1100))

def crane():
    """학: spread wings (segment family), S-curved neck, head and beak, trailing legs — 2,500 segments."""
    k = np.arange(1, 1601, dtype=float); u = 2*pi*k/1600
    P = np.stack([1.7*sin(u + pi/3)**7, 0.20*cos(3*u)**2 + 0.05], 1)
    Q = np.stack([0.15*sin(3*u + pi/5), -0.55*sin(u - pi/3)**2], 1)
    fams = [(P, Q)]
    n = np.arange(1, 501, dtype=float); s = n/500
    nx = 0.1 + 0.95*s; ny = 0.02 + 0.30*s**2 + 0.05*sin(pi*s)     # gentle S-curve
    dx = np.gradient(nx); dy = np.gradient(ny); L = np.hypot(dx, dy); nxn, nyn = -dy/L, dx/L
    thick = 0.07*(1 - s)**0.7 + 0.02
    N1 = np.stack([nx + thick*nxn, ny + thick*nyn], 1)
    N2 = np.stack([nx - thick*nxn + 0.02, ny - thick*nyn], 1)
    fams.append((N1, N2))
    h = np.arange(1, 241, dtype=float); a = 2*pi*h/240
    H1 = np.stack([1.08 + 0.075*cos(a), 0.37 + 0.05*sin(a)], 1)                # head: chords of an oval
    H2 = np.stack([1.08 + 0.075*cos(a + 2.2), 0.37 + 0.05*sin(a + 2.2)], 1)
    fams.append((H1, H2))
    b = np.arange(1, 121, dtype=float); v = b/120
    B1 = np.stack([1.15 + 0.0*v, 0.385 - 0.02*v], 1); B2 = np.stack([1.15 + 0.3*v**0.6, 0.36 + 0.005*v], 1)
    fams.append((B1, B2))
    for off in (0.0, 0.06):
        m = np.arange(1, 151, dtype=float); s2 = m/150
        lx = -0.12 - 0.95*s2 + off; ly = -0.04 - 0.1*s2
        L1 = np.stack([lx, ly + 0.01], 1); L2 = np.stack([lx - 0.03, ly - 0.01], 1)
        fams.append((L1, L2))
    Pa, Qa = _cat(fams)
    render_segments("sumuk-crane", Pa, Qa, width=2, size=(1600, 1000))
ORIG = dict(moon_jar=moon_jar, ginkgo=ginkgo, plum_blossom=plum_blossom, carp=carp, crane=crane)

if __name__ == "__main__":
    names = sys.argv[1:] or list(ORIG)
    for n in names: ORIG[n]()
