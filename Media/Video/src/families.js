// SuMuk presets, transcribed 1:1 from SuMuk/Presets/Presets.swift (SuMuk Script → JS).
// Every coordinate is a closed-form expression of the family variable k.
// Segment families → Float64Array [x1, y1, x2, y2, …]; circle families → [cx, cy, r, …].
(function () {
  const { PI, sin, cos, exp, abs, sqrt, pow, max, min, floor } = Math;
  const sq = (x) => x * x;
  const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
  const mod = (a, b) => a - b * Math.floor(a / b);

  function segFamily(n, f) {
    const out = new Float64Array(n * 4);
    for (let k = 1; k <= n; k++) {
      const s = f(k);
      out.set(s, (k - 1) * 4);
    }
    return { kind: 'seg', n, data: out };
  }
  function circFamily(n, f) {
    const out = new Float64Array(n * 3);
    for (let k = 1; k <= n; k++) {
      const c = f(k);
      out.set(c, (k - 1) * 3);
    }
    return { kind: 'circ', n, data: out };
  }

  // 은행잎 — ink #141414 width 0.3 alpha 0.14 · let notch = 0.24 in [0, 0.5] · let ripple = 0.03 in [0, 0.1]
  function ginkgo(notch = 0.24, ripple = 0.03) {
    const s = (k) => k / 700, v = (k) => k / 120;
    const th = (k) => PI / 2 + 1.3 * (s(k) - 1 / 2);
    const r = (k) => 1.15 * (1 - notch * exp(-sq((th(k) - PI / 2) / 0.08))) * (1 + ripple * sin(22 * th(k)) * sin(PI * s(k)));
    return [
      segFamily(700, (k) => [
        0.05 * sin(2 * PI * s(k)) * sq(sin(PI * s(k))), -1 + 0.22 * pow(sin(PI * s(k)), 6),
        r(k) * cos(th(k)), r(k) * sin(th(k)) - 0.25,
      ]),
      segFamily(120, (k) => [
        0.012 * cos(6 * PI * v(k)) + 0.08 * sq(v(k)), -1 - 0.55 * v(k),
        -0.012 * cos(6 * PI * v(k)) + 0.08 * sq(v(k)) + 0.02, -0.98 - 0.55 * v(k),
      ]),
    ];
  }

  // 달항아리 — ink #1c1c1e width 0.35 alpha 0.5 · let brush = 0.03 in [0.005, 0.08]
  function moonJar(brush = 0.03) {
    const u = (k) => k / 1800;
    const y = (k) => -0.86 + 1.72 * u(k);
    const belly = (k) => 0.98 * pow(1 - pow(abs(y(k) / 0.86), 2.4), 1 / 2.1) * (1 + 0.06 * exp(-sq((y(k) - 0.15) / 0.35)));
    const foot = (k) => 0.34 * exp(-sq(u(k) / 0.035));
    const neck = (k) => 0.40 * exp(-sq((u(k) - 1) / 0.03));
    const r = (k) => max(belly(k), max(foot(k), neck(k))) * (1 + 0.008 * sin(26 * PI * u(k)));
    const sway = (k) => 0.02 * sq(sin(PI * u(k))) * sin(2 * PI * u(k));
    const w = (k) => 0.022 + brush * pow(max(0, sin(PI * u(k))), 1.5) * pow(abs(cos(4 * PI * u(k) + 0.4)), 0.6);
    return [
      circFamily(1800, (k) => [-r(k) + sway(k), y(k), w(k)]),
      circFamily(1800, (k) => [r(k) + sway(k), y(k), w(k)]),
      circFamily(400, (k) => [0.40 * cos(2 * PI * k / 400), 0.88 + 0.07 * sin(2 * PI * k / 400), 0.012 + 0.006 * sq(cos(2 * PI * k / 400))]),
      circFamily(400, (k) => [0.34 * cos(2 * PI * k / 400), -0.88 + 0.05 * sin(2 * PI * k / 400), 0.01 + 0.004 * sq(sin(2 * PI * k / 400))]),
    ];
  }

  // 매화 — ink #1c1c1e width 0.3 alpha 0.4 · let petal = 0.30 in [0.1, 0.5]
  function plum(petal = 0.30) {
    const j = (k) => floor((k - 1) / 700);
    const u = (k) => (k - 700 * j(k)) / 700;
    const phi = (k) => PI / 2 + 2 * PI * j(k) / 5;
    const rho = (k) => 0.18 + 0.72 * u(k);
    const w = (k) => 0.02 * sin(9 * PI * u(k));
    const L = (k) => 0.28 + 0.1 * sq(sin(5 * 2 * PI * k / 60));
    return [
      circFamily(3500, (k) => [
        rho(k) * cos(phi(k)) + w(k) * cos(phi(k) + PI / 2),
        rho(k) * sin(phi(k)) + w(k) * sin(phi(k) + PI / 2),
        petal * pow(max(0, sin(PI * u(k))), 0.8) * (1 - 0.35 * exp(-sq((u(k) - 1) / 0.12))),
      ]),
      circFamily(60, (k) => [L(k) * cos(2 * PI * k / 60), L(k) * sin(2 * PI * k / 60), 0.012 + 0.01 * sq(cos(3 * 2 * PI * k / 60))]),
      circFamily(1, () => [0, 0, 0.06]),
    ];
  }

  // 잉어 — ink #141414 width 0.4 alpha 0.5 · let shift = 0.22 in [0.05, 0.5]
  function carp(shift = 0.22) {
    const px = (k) => -0.7 + 1.7 * k / 900;
    const v = (k) => -1 + 2 * k / 500;
    const w = (k) => k / 200;
    const top = (x) => 0.34 * sqrt(max(1 - x * x, 0)) * (1 + 0.25 * x);
    const bot = (x) => -0.26 * sqrt(max(1 - x * x, 0)) * (1 + 0.25 * x);
    return [
      segFamily(900, (k) => { const q = clamp(px(k) + shift, -0.7, 1); return [px(k), top(px(k)), q, bot(q)]; }),
      segFamily(900, (k) => { const q = clamp(px(k) - shift, -0.7, 1); return [px(k), top(px(k)), q, bot(q)]; }),
      segFamily(500, (k) => [
        -0.68 + 0.03 * v(k), 0.05 * v(k),
        -1.15 - 0.18 * abs(v(k)) + 0.08 * (1 - sq(v(k))) * cos(6 * PI * v(k)), 0.5 * v(k) * (1 + 0.1 * cos(10 * PI * v(k))),
      ]),
      segFamily(200, (k) => [
        -0.2 + 0.6 * w(k), top(-0.2 + 0.6 * w(k)),
        -0.35 + 0.6 * w(k), top(-0.2 + 0.6 * w(k)) + 0.16 * pow(max(0, sin(PI * w(k))), 0.7) * (1 + 0.15 * cos(14 * PI * w(k))),
      ]),
      segFamily(200, (k) => [
        0.1 + 0.3 * w(k), bot(0.1 + 0.3 * w(k)),
        0.3 * w(k), bot(0.1 + 0.3 * w(k)) - 0.13 * pow(max(0, sin(PI * w(k))), 0.7),
      ]),
      segFamily(60, (k) => [
        0.78 + 0.035 * cos(2 * PI * k / 60), 0.06 + 0.035 * sin(2 * PI * k / 60),
        0.78 + 0.035 * cos(2 * PI * k / 60 + 2.4), 0.06 + 0.035 * sin(2 * PI * k / 60 + 2.4),
      ]),
    ];
  }

  // 학 — ink #141414 width 0.45 alpha 0.5 · let wing = 7 in [1, 11]
  function crane(wing = 7) {
    const u = (k) => 2 * PI * k / 1600;
    const s = (k) => k / 500;
    const nx = (k) => 0.1 + 0.95 * s(k);
    const ny = (k) => 0.02 + 0.30 * sq(s(k)) + 0.05 * sin(PI * s(k));
    const dy = (k) => 0.6 * s(k) + 0.05 * PI * cos(PI * s(k));
    const len = (k) => sqrt(sq(0.95) + sq(dy(k)));
    const nnx = (k) => -dy(k) / len(k);
    const nny = (k) => 0.95 / len(k);
    const th = (k) => 0.07 * pow(1 - s(k), 0.7) + 0.02;
    const b = (k) => k / 120;
    const leg = (k) => mod(k - 1, 150) + 1;
    const side = (k) => floor((k - 1) / 150);
    const lx = (k) => -0.12 - 0.95 * leg(k) / 150 + 0.06 * side(k);
    const ly = (k) => -0.04 - 0.1 * leg(k) / 150;
    return [
      segFamily(1600, (k) => [
        1.7 * pow(sin(u(k) + PI / 3), wing), 0.20 * sq(cos(3 * u(k))) + 0.05,
        0.15 * sin(3 * u(k) + PI / 5), -0.55 * sq(sin(u(k) - PI / 3)),
      ]),
      segFamily(500, (k) => [
        nx(k) + th(k) * nnx(k), ny(k) + th(k) * nny(k),
        nx(k) - th(k) * nnx(k) + 0.02, ny(k) - th(k) * nny(k),
      ]),
      segFamily(240, (k) => [
        1.08 + 0.075 * cos(2 * PI * k / 240), 0.37 + 0.05 * sin(2 * PI * k / 240),
        1.08 + 0.075 * cos(2 * PI * k / 240 + 2.2), 0.37 + 0.05 * sin(2 * PI * k / 240 + 2.2),
      ]),
      segFamily(120, (k) => [1.15, 0.385 - 0.02 * b(k), 1.15 + 0.3 * pow(b(k), 0.6), 0.36 + 0.005 * b(k)]),
      segFamily(300, (k) => [lx(k), ly(k) + 0.01, lx(k) - 0.03, ly(k) - 0.01]),
    ];
  }

  function bounds(fams) {
    let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    for (const f of fams) {
      const d = f.data;
      if (f.kind === 'seg') {
        for (let i = 0; i < d.length; i += 4) {
          for (const [x, y] of [[d[i], d[i + 1]], [d[i + 2], d[i + 3]]]) {
            if (!isFinite(x) || !isFinite(y)) continue;
            x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
          }
        }
      } else {
        for (let i = 0; i < d.length; i += 3) {
          const x = d[i], y = d[i + 1], r = d[i + 2];
          if (!isFinite(x) || !isFinite(y)) continue;
          x0 = Math.min(x0, x - r); x1 = Math.max(x1, x + r); y0 = Math.min(y0, y - r); y1 = Math.max(y1, y + r);
        }
      }
    }
    return { x0, x1, y0, y1 };
  }

  const count = (fams) => fams.reduce((a, f) => a + f.n, 0);

  window.SUMUK = { ginkgo, moonJar, plum, carp, crane, bounds, count };
})();
