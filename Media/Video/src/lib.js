// Small deterministic animation toolkit: every frame is a pure function of time t (seconds).
(function () {
  const W = 1920, H = 1080;
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const E = {
    lin: (t) => t,
    in2: (t) => t * t,
    out2: (t) => 1 - (1 - t) * (1 - t),
    in3: (t) => t * t * t,
    out3: (t) => 1 - Math.pow(1 - t, 3),
    io2: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
    io3: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    out5: (t) => 1 - Math.pow(1 - t, 5),
    outBack: (t) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
    sine: (t) => -(Math.cos(Math.PI * t) - 1) / 2,
  };
  // eased progress of t through [a, b]
  const P = (t, a, b, e = E.io3) => e(clamp((t - a) / (b - a)));
  // visibility window: fades in over [a, a+fi], out over [b-fo, b]
  const win = (t, a, b, fi = 0.35, fo = 0.35) => {
    if (t < a || t > b) return 0;
    const i = fi > 0 ? E.out2(clamp((t - a) / fi)) : 1;
    const o = fo > 0 ? E.out2(clamp((b - t) / fo)) : 1;
    return Math.min(i, o);
  };
  // piecewise keyframes: [[t0, v0], [t1, v1], …] with easing between consecutive keys
  const keys = (t, ks, e = E.io3) => {
    if (t <= ks[0][0]) return ks[0][1];
    for (let i = 1; i < ks.length; i++) {
      if (t <= ks[i][0]) {
        const [t0, v0] = ks[i - 1], [t1, v1] = ks[i];
        return lerp(v0, v1, e(clamp((t - t0) / (t1 - t0))));
      }
    }
    return ks[ks.length - 1][1];
  };

  function el(tag, cls, parent, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    if (parent) parent.appendChild(e);
    return e;
  }
  function place(e, x, y) { e.style.left = x + 'px'; e.style.top = y + 'px'; return e; }
  function size(e, w, h) { if (w != null) e.style.width = w + 'px'; if (h != null) e.style.height = h + 'px'; return e; }
  // opacity + translate (dx, dy) + scale
  function show(e, o, dx = 0, dy = 0, s = 1) {
    if (o <= 0.001) { e.style.visibility = 'hidden'; return; }
    e.style.visibility = 'visible';
    e.style.opacity = o >= 0.999 ? '' : o.toFixed(4);
    e.style.transform = dx || dy || s !== 1 ? `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${s.toFixed(4)})` : '';
  }

  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // math → px mapping (MathSketch/SuMuk FitContext: uniform scale, centred, padding fraction)
  function fit(b, rect, pad = 0.06) {
    const w = Math.max(b.x1 - b.x0, 1e-9), h = Math.max(b.y1 - b.y0, 1e-9);
    const s = Math.min((rect.w * (1 - 2 * pad)) / w, (rect.h * (1 - 2 * pad)) / h);
    const cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2;
    const vx = rect.x + rect.w / 2, vy = rect.y + rect.h / 2;
    return { s, cx, cy, vx, vy, x: (x) => vx + (x - cx) * s, y: (y) => vy - (y - cy) * s };
  }

  // ---- ink drawing (one stroke per element so overlapping ink accumulates like real wash)
  function segs(ctx, fam, i0, i1, T, color, width, alpha) {
    const d = fam.data;
    i0 = Math.max(0, Math.floor(i0)); i1 = Math.min(fam.n, Math.floor(i1));
    if (i1 <= i0 || alpha <= 0) return;
    ctx.strokeStyle = color; ctx.lineWidth = width; ctx.globalAlpha = alpha; ctx.lineCap = 'round';
    for (let i = i0; i < i1; i++) {
      const j = i * 4;
      const x1 = d[j], y1 = d[j + 1], x2 = d[j + 2], y2 = d[j + 3];
      if (!(isFinite(x1) && isFinite(y1) && isFinite(x2) && isFinite(y2))) continue;
      ctx.beginPath(); ctx.moveTo(T.x(x1), T.y(y1)); ctx.lineTo(T.x(x2), T.y(y2)); ctx.stroke();
    }
  }
  function circs(ctx, fam, i0, i1, T, color, width, alpha) {
    const d = fam.data;
    i0 = Math.max(0, Math.floor(i0)); i1 = Math.min(fam.n, Math.floor(i1));
    if (i1 <= i0 || alpha <= 0) return;
    ctx.strokeStyle = color; ctx.lineWidth = width; ctx.globalAlpha = alpha;
    for (let i = i0; i < i1; i++) {
      const j = i * 3;
      const x = d[j], y = d[j + 1], r = d[j + 2] * T.s;
      if (!(isFinite(x) && isFinite(y) && isFinite(r)) || r < 0.15) continue;
      ctx.beginPath(); ctx.arc(T.x(x), T.y(y), r, 0, Math.PI * 2); ctx.stroke();
    }
  }
  // draw a whole artwork with per-family progress fractions; style = { color, width, alpha }
  function art(ctx, fams, T, prog, style) {
    fams.forEach((f, i) => {
      const p = Array.isArray(prog) ? prog[i] : prog;
      const n = f.n * clamp(p);
      if (f.kind === 'seg') segs(ctx, f, 0, n, T, style.color, style.width, style.alpha);
      else circs(ctx, f, 0, n, T, style.color, style.width, style.alpha);
    });
    ctx.globalAlpha = 1;
  }
  // element endpoints in px (for highlight / labels)
  function segAt(f, i, T) { const d = f.data, j = i * 4; return [T.x(d[j]), T.y(d[j + 1]), T.x(d[j + 2]), T.y(d[j + 3])]; }
  function circAt(f, i, T) { const d = f.data, j = i * 3; return [T.x(d[j]), T.y(d[j + 1]), d[j + 2] * T.s]; }

  // vermilion "brush tip": the newest m elements glow and settle into ink
  function tip(ctx, f, n, m, T, width, alpha = 1) {
    const last = Math.min(f.n, Math.floor(n));
    for (let q = 0; q < m; q++) {
      const i = last - 1 - q;
      if (i < 0) break;
      const a = alpha * Math.pow(1 - q / m, 1.6);
      ctx.globalAlpha = a; ctx.strokeStyle = '#C2412B'; ctx.lineWidth = q === 0 ? width * 1.6 : width;
      ctx.beginPath();
      if (f.kind === 'seg') { const [x1, y1, x2, y2] = segAt(f, i, T); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); }
      else { const [x, y, r] = circAt(f, i, T); ctx.arc(x, y, Math.max(r, 0.5), 0, Math.PI * 2); }
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  function dot(ctx, x, y, r, color, alpha = 1) {
    ctx.globalAlpha = alpha; ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
  }

  // rice paper: warm base, soft mottling, short fibres, faint vignette (static → cheap for GIF/H.264)
  function paintPaper(ctx) {
    ctx.fillStyle = '#FAF7F0'; ctx.fillRect(0, 0, W, H);
    if (/[?&]flat=1/.test(location.search)) return;   // flat paper for the GIF master (no dither crawl)
    const rnd = mulberry32(20261017);
    for (let i = 0; i < 80; i++) {
      const x = rnd() * W, y = rnd() * H, r = 90 + rnd() * 300;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      const a = 0.010 + rnd() * 0.016, warm = rnd() < 0.55;
      g.addColorStop(0, warm ? `rgba(206,186,148,${a})` : `rgba(255,255,255,${a * 1.6})`);
      g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g; ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
    }
    for (let i = 0; i < 2200; i++) {
      const x = rnd() * W, y = rnd() * H, l = 5 + rnd() * 24, a = rnd() * Math.PI * 2;
      ctx.strokeStyle = `rgba(130,110,80,${0.02 + rnd() * 0.03})`; ctx.lineWidth = 0.5 + rnd() * 0.5;
      ctx.beginPath(); ctx.moveTo(x, y);
      ctx.quadraticCurveTo(x + Math.cos(a + 0.7) * l * 0.5, y + Math.sin(a + 0.7) * l * 0.5, x + Math.cos(a) * l, y + Math.sin(a) * l);
      ctx.stroke();
    }
    const v = ctx.createRadialGradient(W / 2, H / 2, H * 0.32, W / 2, H / 2, H * 1.08);
    v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(110,85,50,0.075)');
    ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
  }

  const fmtInt = (n) => Math.round(n).toLocaleString('en-US');
  const fmtNum = (v, d = 2) => {
    let s = v.toFixed(d);
    if (s.indexOf('.') >= 0) { s = s.replace(/0+$/, ''); s = s.replace(/\.$/, ''); }
    return s.replace('-', '−');
  };

  // small inline SVG icons (drawn here, not SF Symbols)
  const ICON = {
    terminal: `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="#C2412B" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4" width="19" height="16" rx="3.5"/><path d="M7 9.5l3 2.5-3 2.5M12.5 15h4.5"/></svg>`,
    sliders: `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="#C2412B" stroke-width="1.8" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/><circle cx="9" cy="7" r="2.2" fill="#EFE9DC"/><circle cx="15" cy="12" r="2.2" fill="#EFE9DC"/><circle cx="7" cy="17" r="2.2" fill="#EFE9DC"/></svg>`,
    list: `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="#C2412B" stroke-width="1.8" stroke-linecap="round"><path d="M10 6h10M10 12h10M10 18h10"/><path d="M4 5.2l1.4-.9V8M3.8 11.4c.4-.6 1-.9 1.6-.6.8.4.6 1.3-.1 1.9L3.8 14h2.4M3.9 16.6h2.2l-1.1 1.2c.8 0 1.3.4 1.2 1-.1.8-1.3 1-2.2.4"/></svg>`,
    play: `<svg width="13" height="14" viewBox="0 0 13 14"><path d="M1.5 1.2v11.6L11.8 7z" fill="#C2412B"/></svg>`,
  };

  window.L = { W, H, clamp, lerp, E, P, win, keys, el, place, size, show, mulberry32, fit, segs, circs, art, segAt, circAt, tip, dot, paintPaper, fmtInt, fmtNum, ICON };
})();
