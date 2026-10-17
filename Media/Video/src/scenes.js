// 수묵 SuMuk — README 소개 영상 (50 s). Every frame = seek(t), a pure function of time.
(function () {
  const { el, place, size, show, P, win, keys, E, clamp, lerp, fit, art, tip, segAt, dot, fmtInt, fmtNum, ICON } = L;
  const S = window.SUMUK, D4 = window.S4;
  const DURATION = 50.0;
  const VERM = '#C2412B', INK = '#141414';

  const paperCtx = document.getElementById('paper').getContext('2d');
  const ctx = document.getElementById('ink').getContext('2d');
  const UNDER = document.getElementById('under'), OVER = document.getElementById('over');
  L.paintPaper(paperCtx);

  // scene windows (seconds). Neighbouring scenes dip through the paper instead of cross-fading.
  const T0 = { open: [0, 5.5], seg: [5.5, 15.0], circ: [15.0, 21.3], presets: [21.3, 26.6], read: [26.6, 38.0], app: [38.0, 45.9], outro: [45.9, 50.01] };

  // ink per artwork, tuned so the 1080p frame reads like the app canvas (ink lines of Presets.swift)
  const STYLE = {
    crane: { color: INK, width: 0.7, alpha: 0.42 },
    ginkgo: { color: INK, width: 0.85, alpha: 0.18 },
    moonJar: { color: '#1c1c1e', width: 0.75, alpha: 0.3 },
  };

  // ------------------------------------------------------------------ shared builders
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  // [[id|text]] → highlightable span
  function markup(src) {
    let out = '', i = 0;
    const re = /\[\[([\w-]+)\|([^\]]*)\]\]/g; let m;
    while ((m = re.exec(src))) { out += esc(src.slice(i, m.index)) + `<span class="hl" data-id="${m[1]}">${esc(m[2])}</span>`; i = m.index + m[0].length; }
    return out + esc(src.slice(i));
  }
  function codeCard(parent, o) {
    const root = el('div', 'card code-card', parent);
    place(root, o.x, o.y); size(root, o.w, o.h);
    root.innerHTML = `<div class="hd">${ICON.terminal}<span class="fn">${esc(o.file)}</span><span class="sp"></span><span class="st"><i></i>수렴 연산됨</span><span class="rc">${ICON.play}재계산</span></div>`;
    const body = el('div', 'code', root);
    body.style.fontSize = o.font + 'px'; body.style.lineHeight = o.lh + 'px';
    if (o.pad) body.style.padding = o.pad;
    const lines = o.lines.map((src) => { const ln = el('div', 'ln', body, markup(src)); ln.style.height = o.lh + 'px'; return ln; });
    const spans = {}; root.querySelectorAll('[data-id]').forEach((s) => (spans[s.dataset.id] = s));
    return { root, body, lines, spans, cw: o.font * 0.6 };
  }
  function badge(card, line, col, text) {
    const b = el('span', 'tag', card.lines[line], text);
    b.style.left = 22 + col * card.cw + 'px';
    return b;
  }
  function hlSpan(s, on, text) {
    if (text != null && s.textContent !== text) s.textContent = text;
    const a = clamp(on);
    s.style.background = a > 0.01 ? `rgba(194,65,43,${(0.16 * a).toFixed(3)})` : '';
    s.style.color = a > 0.5 ? VERM : '';
    s.style.fontWeight = a > 0.5 ? '700' : '';
  }
  function sliderPanel(parent, o) {
    const root = el('div', 'card sliders', parent);
    place(root, o.x, o.y); size(root, o.w);
    root.innerHTML = `<div class="hd">${ICON.sliders}<span class="t">동적 매개변수</span><span class="sp"></span><span class="r">${o.rows.length} 변수 연결됨</span></div>`;
    const rows = o.rows.map((r) => {
      const row = el('div', 'srow', root);
      row.innerHTML = `<span class="n">${r.name}</span><span class="tr"><span class="f"></span><span class="touch"></span><span class="k"></span></span><span class="v"></span>`;
      return { ...r, f: row.querySelector('.f'), k: row.querySelector('.k'), touch: row.querySelector('.touch'), v: row.querySelector('.v') };
    });
    function set(i, value, touch = 0) {
      const r = rows[i], u = clamp((value - r.min) / (r.max - r.min));
      r.f.style.width = (u * 100).toFixed(3) + '%';
      r.k.style.left = (u * 100).toFixed(3) + '%';
      r.touch.style.left = (u * 100).toFixed(3) + '%';
      r.touch.style.opacity = touch.toFixed(3);
      r.touch.style.transform = `scale(${(0.8 + 0.2 * touch).toFixed(3)})`;
      r.v.textContent = fmtNum(value, r.digits);
    }
    return { root, rows, set };
  }
  function chapter(parent, han, title, sub) {
    return el('div', 'chapter', parent, `<span class="seal">${han}</span><span class="t">${title}</span><span class="s">${sub}</span>`);
  }
  function caption(parent, main, sub) {
    return el('div', 'caption', parent, `<div class="m">${main}</div><div class="s">${sub}</div>`);
  }
  function seal(parent, text, px) {
    const s = el('div', 'seal', parent, text);
    size(s, px, px);
    s.style.fontSize = (text.length > 1 ? px * 0.3 : px * 0.5) + 'px';
    if (text.length > 1) { s.style.writingMode = 'vertical-rl'; s.style.letterSpacing = '0.02em'; }
    return s;
  }
  function sceneRoots() { return { u: el('div', 'scene', UNDER), o: el('div', 'scene', OVER) }; }
  function rootShow(R, a) {
    const vis = a > 0.001;
    R.u.style.display = vis ? '' : 'none'; R.o.style.display = vis ? '' : 'none';
    const op = a >= 0.999 ? '' : a.toFixed(4);
    R.u.style.opacity = op; R.o.style.opacity = op;
  }
  const rise = (e, τ, a0, a1, d = 10) => { const p = P(τ, a0, a1, E.out3); show(e, p, 0, d * (1 - p)); };
  function capShow(c, τ, a0, a1, last) {
    show(c, win(τ, a0, a1, 0.35, last ? 0.0001 : 0.3), 0, 10 * (1 - P(τ, a0, a0 + 0.35, E.out3)));
  }

  // ------------------------------------------------------------------ title block (opening + outro)
  const crane = S.crane(7);
  const CRANE_T = fit(S.bounds(crane), { x: 640, y: 190, w: 1190, h: 560 }, 0.04);
  function titleBlock(R) {
    const t = {};
    t.ko = place(el('div', 'title-ko', R.o, '수묵'), 124, 236); t.ko.style.fontSize = '212px';
    t.sub = place(el('div', '', R.o, `<span class="title-sub" style="font-size:60px">SuMuk</span><span class="title-han" style="font-size:52px;margin-left:22px">· 數墨</span>`), 134, 486);
    t.tag = place(el('div', 'tagline', R.o, '수식은 그림으로, 그림은 수식으로'), 132, 588); t.tag.style.fontSize = '50px';
    t.subl = place(el('div', 'subline', R.o, '선분과 원의 계열로 그리는 iPhone 수학 화첩'), 134, 668); t.subl.style.fontSize = '29px';
    t.seal = place(seal(R.o, '數墨', 92), 1690, 590);
    return t;
  }
  function drawCrane(p, a, tipOn) {
    // wings 1600 · neck 500 · head 240 · beak 120 · legs 300 — drawn together, the wings lead
    const pr = [P(p, 0, 0.82, E.io2), P(p, 0.30, 0.86, E.io2), P(p, 0.66, 0.93, E.io2), P(p, 0.76, 0.98, E.io2), P(p, 0.42, 0.9, E.io2)];
    const st = STYLE.crane;
    art(ctx, crane, CRANE_T, pr, { ...st, alpha: st.alpha * a });
    if (tipOn > 0) crane.forEach((f, i) => { if (pr[i] > 0 && pr[i] < 1) tip(ctx, f, f.n * pr[i], i === 0 ? 16 : 8, CRANE_T, 1.4, tipOn * a); });
    return pr.reduce((acc, v, i) => acc + Math.floor(crane[i].n * clamp(v)), 0);
  }
  function stamp(e, τ, t0) {
    const sp = P(τ, t0, t0 + 0.4, E.lin);
    show(e, clamp(sp * 3), 0, 0, 1.4 - 0.4 * E.outBack(sp));
  }

  const scenes = [];

  // ================================================================== 0 · opening
  {
    const [A, B] = T0.open;
    const R = sceneRoots();
    const T = titleBlock(R);
    const kc = place(el('div', 'kcount', R.o), 1040, 690);
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const n = drawCrane(P(t, 0.25, 3.35, E.lin), a, 1 - P(t, 3.2, 3.6));
        kc.innerHTML = `선분 <b>${fmtInt(Math.max(1, n))}</b> / 2,760`;
        show(kc, win(t, 0.3, 4.4, 0.3, 0.6));
        [T.ko, T.sub, T.tag, T.subl].forEach((e) => show(e, 1));   // on the paper from frame 0 (poster + loop seam)
        stamp(T.seal, t, 3.35);
      },
    });
  }

  // ================================================================== 壹 · segment family — ginkgo
  {
    const [A, B] = T0.seg;
    const R = sceneRoots();
    const ch = chapter(R.o, '壹', '선분 계열', 'segments');
    const card = codeCard(R.u, {
      x: 96, y: 160, w: 840, h: 516, file: '은행잎.smk', font: 18, lh: 28,
      lines: [
        '// 은행잎 — 잎자루에서 가장자리로 펼쳐지는 부채',
        'ink #141414 width 0.3 alpha 0.14',
        'let notch = [[notch|0.24]] in [0, 0.5]',
        'let ripple = [[ripple|0.03]] in [0, 0.1]',
        '',
        'segments k = 1 ... 700 {',
        '  [[from|from]] ( 0.05·sin(2π·s(k))·sin^2(π·s(k)),  −1 + 0.22·sin^6(π·s(k)) )',
        '  [[to|to]]   ( r(k)·cos(θ(k)),  r(k)·sin(θ(k)) − 0.25 )',
        '}',
        'segments k = 1 ... 120 { … }   // 잎자루',
        'where',
        '  s(k) = k/700',
        '  θ(k) = π/2 + 1.3·(s(k) − 1/2)',
        '  r(k) = 1.15·(1 − [[notch2|notch]]·exp(−((θ(k) − π/2)/0.08)^2))',
        '             ·(1 + [[ripple2|ripple]]·sin(22·θ(k))·sin(π·s(k)))',
      ],
    });
    const kb = badge(card, 5, 25, 'k = 1');
    const sl = sliderPanel(R.u, { x: 96, y: 694, w: 840, rows: [
      { name: 'notch', min: 0, max: 0.5, digits: 2 },
      { name: 'ripple', min: 0, max: 0.1, digits: 2 },
    ] });
    const capA = caption(R.o, '선분 계열 — 두 끝점을 모두 <em>k</em>의 식으로', 'k = 1 … 700. 선분이 쌓이면 포락선(envelope)이 곡선처럼 떠오른다');
    const capB = caption(R.o, '<code>let</code> 슬라이더 — 숫자를 바꾸면 그림이 바로 따라온다', '슬라이더는 스크립트 속 숫자를 고쳐 쓴다 · 스크립트가 유일한 진실');
    const lab = { from: el('div', 'kcount', R.o, 'from'), to: el('div', 'kcount', R.o, 'to') };
    [lab.from, lab.to].forEach((e) => { e.style.color = VERM; e.style.fontWeight = '700'; e.style.fontSize = '22px'; });
    // fixed framing over the whole slider range
    const bb = [S.ginkgo(0, 0.1), S.ginkgo(0.5, 0.1), S.ginkgo(0.24, 0.03)].map(S.bounds);
    const gb = { x0: Math.min(...bb.map((b) => b.x0)), x1: Math.max(...bb.map((b) => b.x1)), y0: Math.min(...bb.map((b) => b.y0)), y1: Math.max(...bb.map((b) => b.y1)) };
    const GT = fit(gb, { x: 990, y: 110, w: 830, h: 800 }, 0.03);
    const g0 = S.ginkgo(0.24, 0.03);
    const cnt = el('div', 'kcount', R.o);
    const RAYS = 20, rayK = (j) => 35 * (j + 1), rayT = (j) => 0.6 + 0.1 * j;
    function trail(f, jEnd, which, alpha) {
      // path of one endpoint (from / to) as k runs 1 … k_j
      const kEnd = rayK(jEnd);
      ctx.globalAlpha = alpha; ctx.strokeStyle = VERM; ctx.lineWidth = 1.6; ctx.lineJoin = 'round';
      ctx.beginPath();
      for (let k = 1; k <= kEnd; k += 3) {
        const [x1, y1, x2, y2] = segAt(f, k - 1, GT);
        const x = which ? x2 : x1, y = which ? y2 : y1;
        if (k === 1) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke(); ctx.globalAlpha = 1;
    }
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0.4, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        show(ch, 1); show(card.root, 1, -24 * (1 - P(τ, 0, 0.5, E.out3)));
        const notch = keys(τ, [[5.3, 0.24], [6.3, 0.48], [7.35, 0.02], [8.05, 0.24]]);
        const ripple = keys(τ, [[8.05, 0.03], [8.6, 0.1], [9.1, 0.03]]);
        const fams = τ > 5.25 ? S.ginkgo(notch, ripple) : g0;
        const st = STYLE.ginkgo;
        // phase 1 · sample rays k = 35, 70, … 700, one every 0.1 s
        let jCur = -1;
        for (let j = 0; j < RAYS; j++) if (τ >= rayT(j)) jCur = j;
        const rayA = (1 - P(τ, 3.3, 4.3)) * a;
        if (jCur >= 0 && rayA > 0) {
          trail(fams[0], jCur, 1, 0.6 * rayA); trail(fams[0], jCur, 0, 0.6 * rayA);
          for (let j = 0; j <= jCur; j++) L.segs(ctx, fams[0], rayK(j) - 1, rayK(j), GT, INK, 1.1, 0.72 * rayA);
        }
        // phase 2 · every k
        const kFill = 700 * P(τ, 2.8, 4.6, E.io2);
        L.segs(ctx, fams[0], 0, kFill, GT, st.color, st.width, st.alpha * a);
        const pet = 120 * P(τ, 4.45, 4.95, E.io2);
        L.segs(ctx, fams[1], 0, pet, GT, st.color, st.width, st.alpha * a);
        ctx.globalAlpha = 1;
        if (kFill > 0 && kFill < 700) tip(ctx, fams[0], kFill, 12, GT, 1.6, a);
        // current sample ray with its two endpoints
        const slow = win(τ, 0.6, 2.95, 0.12, 0.35);
        if (jCur >= 0 && slow > 0) {
          const [x1, y1, x2, y2] = segAt(fams[0], rayK(jCur) - 1, GT);
          ctx.globalAlpha = slow * a; ctx.strokeStyle = VERM; ctx.lineWidth = 2.6; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); ctx.globalAlpha = 1;
          dot(ctx, x1, y1, 5.5, VERM, slow * a); dot(ctx, x2, y2, 5.5, VERM, slow * a);
          place(lab.from, x1 - 80, y1 + 4); place(lab.to, x2 - 14, y2 - 40);
        }
        show(lab.from, slow); show(lab.to, slow);
        hlSpan(card.spans.from, slow); hlSpan(card.spans.to, slow);
        const kShown = τ < 2.8 ? (jCur >= 0 ? rayK(jCur) : 1) : Math.max(1, Math.round(kFill));
        show(kb, win(τ, 0.6, 5.1, 0.2, 0.3)); kb.textContent = 'k = ' + kShown;
        place(cnt, GT.x(0) - 120, GT.y(gb.y0) + 18);
        const drawn = τ < 2.8 ? jCur + 1 : Math.floor(kFill) + Math.floor(pet);
        cnt.innerHTML = `선분 <b>${fmtInt(Math.max(0, drawn))}</b> / 820`;
        show(cnt, win(τ, 0.6, 9.55, 0.3, 0.3));
        // sliders
        rise(sl.root, τ, 4.85, 5.3, 18);
        sl.set(0, notch, win(τ, 5.15, 8.2, 0.15, 0.2));
        sl.set(1, ripple, win(τ, 7.95, 9.25, 0.15, 0.2));
        const nOn = win(τ, 5.2, 8.2, 0.2, 0.2), rOn = win(τ, 7.95, 9.25, 0.2, 0.2);
        hlSpan(card.spans.notch, nOn, fmtNum(notch, 2)); hlSpan(card.spans.notch2, nOn);
        hlSpan(card.spans.ripple, rOn, fmtNum(ripple, 2)); hlSpan(card.spans.ripple2, rOn);
        capShow(capA, τ, 0.45, 5.05); capShow(capB, τ, 5.05, 9.55, true);
      },
    });
  }

  // ================================================================== 貳 · circle family — moon jar
  {
    const [A, B] = T0.circ;
    const R = sceneRoots();
    const ch = chapter(R.o, '貳', '원 계열', 'circles');
    const card = codeCard(R.u, {
      x: 984, y: 160, w: 840, h: 488, file: '달항아리.smk', font: 18, lh: 28,
      lines: [
        '// 달항아리 — 중심은 항아리 윤곽, 반지름은 붓 압력',
        'ink #1c1c1e width 0.35 alpha 0.5',
        'let brush = [[brush|0.03]] in [0.005, 0.08]',
        '',
        'circles k = 1 ... 1800 {',
        '  [[center|center]] ( −r(k) + sway(k),  y(k) )',
        '  [[radius|radius]]  w(k)',
        '}',
        'circles k = 1 ... 1800 { … }   // 오른쪽 벽',
        'circles k = 1 ... 400 { … }    // 입구 · 굽',
        'where',
        '  u(k) = k/1800',
        '  y(k) = −0.86 + 1.72·u(k)',
        '  w(k) = 0.022 + [[brush2|brush]]·sin(π·u(k))^1.5·|cos(4π·u(k) + 0.4)|^0.6',
      ],
    });
    const kb = badge(card, 4, 24, 'k = 1');
    const sl = sliderPanel(R.u, { x: 984, y: 666, w: 840, rows: [{ name: 'brush', min: 0.005, max: 0.08, digits: 3 }] });
    const capA = caption(R.o, '원 계열 — 중심은 항아리 윤곽을, 반지름은 붓 압력을', '원 4,400개. 중심 (X(k), Y(k))와 반지름 R(k)가 모두 k의 식');
    const capB = caption(R.o, '<code>brush</code> 하나로 붓 압력과 먹의 농담이 바뀐다', '값을 움직일 때마다 원 4,400개를 다시 계산해 그린다');
    const bb = [S.moonJar(0.08), S.moonJar(0.005)].map(S.bounds);
    const mb = { x0: Math.min(...bb.map((b) => b.x0)), x1: Math.max(...bb.map((b) => b.x1)), y0: Math.min(...bb.map((b) => b.y0)), y1: Math.max(...bb.map((b) => b.y1)) };
    const MT = fit(mb, { x: 96, y: 150, w: 820, h: 740 }, 0.03);
    const m0 = S.moonJar(0.03);
    const cnt = el('div', 'kcount', R.o);
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0.4, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        show(ch, 1); show(card.root, 1, 24 * (1 - P(τ, 0, 0.5, E.out3)));
        const pw = P(τ, 0.5, 2.9, E.io2), pr = P(τ, 2.55, 3.35, E.io2);
        const brush = keys(τ, [[3.7, 0.03], [4.45, 0.075], [5.3, 0.008], [5.9, 0.03]]);
        const fams = τ > 3.65 ? S.moonJar(brush) : m0;
        art(ctx, fams, MT, [pw, pw, pr, pr], { ...STYLE.moonJar, alpha: STYLE.moonJar.alpha * a });
        const tipA = a * (1 - P(τ, 3.2, 3.6));
        if (pw > 0 && pw < 1) { tip(ctx, fams[0], 1800 * pw, 10, MT, 1.3, tipA); tip(ctx, fams[1], 1800 * pw, 10, MT, 1.3, tipA); }
        if (pr > 0 && pr < 1) { tip(ctx, fams[2], 400 * pr, 8, MT, 1.2, tipA); tip(ctx, fams[3], 400 * pr, 8, MT, 1.2, tipA); }
        show(kb, win(τ, 0.5, 3.6, 0.2, 0.3)); kb.textContent = 'k = ' + Math.max(1, Math.round(1800 * pw));
        const total = 2 * Math.round(1800 * pw) + 2 * Math.round(400 * pr);
        place(cnt, MT.x(0) - 92, MT.y(mb.y0) + 4);
        cnt.innerHTML = `원 <b>${fmtInt(total)}</b> / 4,400`;
        show(cnt, win(τ, 0.5, 6.35, 0.3, 0.3));
        const hc = win(τ, 0.6, 3.4, 0.2, 0.3);
        hlSpan(card.spans.center, hc); hlSpan(card.spans.radius, hc);
        rise(sl.root, τ, 3.25, 3.7, 18);
        const on = win(τ, 3.6, 6.0, 0.15, 0.2);
        sl.set(0, brush, on);
        hlSpan(card.spans.brush, on, fmtNum(brush, 3)); hlSpan(card.spans.brush2, on);
        capShow(capA, τ, 0.4, 3.6); capShow(capB, τ, 3.6, 6.35, true);
      },
    });
  }

  // ================================================================== 參 · five original presets
  {
    const [A, B] = T0.presets;
    const R = sceneRoots();
    const ch = chapter(R.o, '參', '원작 프리셋 5종', 'presets');
    const items = [
      { name: '달항아리', count: '원 4,400', v: 'let brush', fams: S.moonJar(0.03), st: { color: '#1c1c1e', width: 0.5, alpha: 0.3 } },
      { name: '은행잎', count: '선분 820', v: 'let notch · ripple', fams: S.ginkgo(0.24, 0.03), st: { color: INK, width: 0.6, alpha: 0.2 } },
      { name: '매화', count: '원 3,561', v: 'let petal', fams: S.plum(0.30), st: { color: '#1c1c1e', width: 0.42, alpha: 0.22 } },
      { name: '잉어', count: '선분 2,760', v: 'let shift', fams: S.carp(0.22), st: { color: INK, width: 0.5, alpha: 0.3 } },
      { name: '학', count: '선분 2,760', v: 'let wing', fams: S.crane(7), st: { color: INK, width: 0.5, alpha: 0.36 } },
    ];
    const CW = 320, GAP = 32, X0 = (1920 - (5 * CW + 4 * GAP)) / 2, Y0 = 268;
    items.forEach((it, i) => {
      const x = X0 + i * (CW + GAP);
      it.card = place(el('div', 'paper-card pcard', R.u), x, Y0); size(it.card, CW, CW);
      el('div', 'grain', it.card);
      const s = seal(it.card, '墨', 28); s.style.position = 'absolute'; s.style.right = '12px'; s.style.bottom = '12px';
      it.lab = place(el('div', 'plabel', R.o, `<div class="n">${it.name}</div><div class="c">${it.count}</div><div class="c" style="color:${VERM};font-size:16px;margin-top:4px">${it.v}</div>`), x, Y0 + CW + 24);
      size(it.lab, CW);
      it.T = fit(S.bounds(it.fams), { x, y: Y0, w: CW, h: CW }, 0.1);
    });
    const cap = caption(R.o, '원작 프리셋 5종 — 모든 좌표가 <em>k</em>의 닫힌형 식', '달항아리 · 은행잎 · 매화 · 잉어 · 학 — 외부 이미지 없이, 이 프로젝트에서 설계한 수식만으로');
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0.4, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        show(ch, 1);
        items.forEach((it, i) => {
          const c = P(τ, 0.05 + 0.08 * i, 0.55 + 0.08 * i, E.out3);
          show(it.card, c, 0, 20 * (1 - c)); show(it.lab, c, 0, 20 * (1 - c));
          const p = P(τ, 0.45 + 0.2 * i, 2.85 + 0.2 * i, E.io2);
          art(ctx, it.fams, it.T, p, { ...it.st, alpha: it.st.alpha * a * c });
          if (p > 0 && p < 1) it.fams.forEach((f) => tip(ctx, f, f.n * p, 6, it.T, 1.1, a));
        });
        capShow(cap, τ, 0.4, 5.35, true);
      },
    });
  }

  // ================================================================== 肆 · picture → formula
  {
    const [A, B] = T0.read;
    const R = sceneRoots();
    const ch = chapter(R.o, '肆', '그림 → 수식', 'read · picture → formula');
    const CX = 96, CY = 150, CS = 740, IMG = { x: CX + 10, y: CY + 10, s: 720 };
    const cardEl = place(el('div', 'paper-card', R.u), CX, CY); size(cardEl, CS, CS);
    el('div', 'grain', cardEl);
    const img = place(el('img', '', R.u), IMG.x, IMG.y); img.src = '../../Samples/sumuk-plum-blossom.png'; size(img, IMG.s, IMG.s);
    img.style.mixBlendMode = 'multiply';
    const cap1 = place(el('div', 'capsule', R.o), CX + 18, CY + 18);
    const cardSeal = place(seal(R.o, '數墨', 58), CX + CS - 76, CY + CS - 76);
    const X = (x) => IMG.x + (x + D4.aspect) / (2 * D4.aspect) * IMG.s;
    const Y = (y) => IMG.y + (1 - y) / 2 * IMG.s;
    const SC = IMG.s / 2;
    // pipeline stepper (app's "수식 변환 파이프라인" card)
    const stp = place(el('div', 'card stepper', R.u), 900, CY); size(stp, 924, 246);
    stp.style.padding = '16px 24px 8px';
    stp.innerHTML = `<div class="hd">${ICON.list}<span class="t">수식 변환 파이프라인</span><span class="sp"></span><span class="r">온디바이스</span></div>`;
    const steps = [
      ['윤곽', 'Vision 윤곽 · 피사체 실루엣 1개', '512점'],
      ['푸리에', 'x(t), y(t) 삼각급수', '조화 16'],
      ['농담', '36×36 격자 → DCT 220항 → 점', `${fmtInt(D4.dots.length)} / 6,000점`],
      ['스크립트', '곡선 계열 + 점 계열', 'SuMuk Script'],
    ].map(([a, b, v], i) => {
      const s = el('div', 'step', stp);
      s.style.height = '44px';
      s.innerHTML = `<div class="rail"><div class="num">${i + 1}</div>${i < 3 ? '<div class="line"></div>' : ''}</div><div class="tx" style="display:flex;align-items:baseline;gap:14px"><div class="a">${a}</div><div class="b">${b}</div></div><div class="val">${v}</div>`;
      return s;
    });
    const harmVal = steps[1].querySelector('.val');
    const xs = D4.xdef.split(' '), ys = D4.ydef.split(' ');
    const script = codeCard(R.u, {
      x: 900, y: 412, w: 924, h: 478, file: '사진 → 수식.smk', font: 16.5, lh: 25, pad: '10px 22px',
      lines: [
        '// 사진 → 수식 (Vision 윤곽 → 푸리에 16조화 → 곡선 + 농담 점)',
        'canvas 1000 × 1000',
        'let gamma = 1 in [0.3, 3]   // 작을수록 점이 많아진다',
        'curve t ∈ [0, 2π] samples 800 {',
        '  x = x1(t)',
        '  y = y1(t)',
        '}',
        'points k = 1 ... 6000 {',
        '  at   ( X(k), Y(k) )',
        '  size 0.0025 + 0.004·Dk(k)',
        '  when (Dk(k)^gamma > mod(0.7548777·k, 1))·(Dk(k) > 0.08)·…',
        '}',
        'where',
        '  ' + xs.slice(0, 7).join(' ') + ' …',
        '  ' + ys.slice(0, 7).join(' ') + ' …',
        '  D(x,y) = clamp( ' + D4.dfirst.slice(0, 2).join(' ') + ' … , 0, 1)',
      ],
    });
    // when each line of the generated script appears (seconds into the scene)
    const lineAt = [0.95, 1.05, 8.05, 4.4, 4.47, 4.54, 4.61, 8.12, 8.19, 8.26, 8.33, 8.4, 4.68, 4.75, 4.82, 8.47];
    const caps = [
      caption(R.o, '그림 → 수식 — 윤곽을 푸리에 급수로 다시 쓴다', '회전하는 원 32개(조화 16쌍)의 합이 꽃잎 윤곽을 따라 그린다'),
      caption(R.o, '조화 수 — 줄이면 둥글고 짧은 수식, 늘리면 윤곽에 가까워진다', 'x(t) = a₀ + Σ (aₙ cos nt + bₙ sin nt),  y(t)도 같은 꼴'),
      caption(R.o, '농담은 점으로 — 어두운 곳일수록 점이 빽빽하다', '36×36 농담 격자 → DCT 220항 D(x, y) → Vogel 나선 위의 점 6,000개'),
      caption(R.o, '결과는 다시 그릴 수 있는 SuMuk Script', '‘스크립트로 열기’를 누르면 그리기 탭에서 이어서 편집한다'),
    ];
    const capT = [[0.4, 4.45], [4.45, 6.55], [6.55, 8.75], [8.75, 11.45]];

    const NH = D4.harmonics;
    function curvePt(t, N) {
      let x = D4.ax[0], y = D4.ay[0];
      for (let h = 1; h <= NH; h++) {
        const w = clamp(N - h + 1);
        if (w <= 0) break;
        const c = Math.cos(h * t), s = Math.sin(h * t);
        x += w * (D4.ax[h] * c + D4.bx[h] * s); y += w * (D4.ay[h] * c + D4.by[h] * s);
      }
      return [x, y];
    }
    function strokeCurve(N, t1, color, width, alpha) {
      const steps = 720, n = Math.max(2, Math.ceil(steps * t1 / (2 * Math.PI)));
      ctx.globalAlpha = alpha; ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
      ctx.beginPath();
      for (let i = 0; i <= n; i++) {
        const [x, y] = curvePt(Math.min(t1, (i / steps) * 2 * Math.PI), N);
        if (i === 0) ctx.moveTo(X(x), Y(y)); else ctx.lineTo(X(x), Y(y));
      }
      ctx.stroke(); ctx.globalAlpha = 1;
    }
    function epicycles(t, alpha) {
      let x = D4.c0[0], y = D4.c0[1];
      ctx.lineWidth = 1.1;
      for (const [h, re, im] of D4.epicycles) {
        const r = Math.hypot(re, im);
        const c = Math.cos(h * t), s = Math.sin(h * t);
        const nx = x + re * c - im * s, ny = y + re * s + im * c;
        if (r * SC > 1.2) {
          ctx.globalAlpha = 0.28 * alpha; ctx.strokeStyle = INK;
          ctx.beginPath(); ctx.arc(X(x), Y(y), r * SC, 0, 2 * Math.PI); ctx.stroke();
          ctx.globalAlpha = 0.7 * alpha;
          ctx.beginPath(); ctx.moveTo(X(x), Y(y)); ctx.lineTo(X(nx), Y(ny)); ctx.stroke();
        }
        x = nx; y = ny;
      }
      dot(ctx, X(x), Y(y), 6, VERM, alpha);
      ctx.globalAlpha = 1;
    }
    function contour(p, color, width, alpha) {
      const c = D4.contour, n = Math.floor(c.length * p);
      if (n < 2) return null;
      ctx.globalAlpha = alpha; ctx.strokeStyle = color; ctx.lineWidth = width; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
      ctx.beginPath();
      for (let i = 0; i <= Math.min(n, c.length); i++) { const q = c[i % c.length]; if (i === 0) ctx.moveTo(X(q[0]), Y(q[1])); else ctx.lineTo(X(q[0]), Y(q[1])); }
      ctx.stroke(); ctx.globalAlpha = 1;
      const q = c[Math.min(n, c.length - 1)]; return [X(q[0]), Y(q[1])];
    }
    const grid = D4.smooth, GH = grid.length, GW = grid[0].length;
    function gridOverlay(alpha) {
      const cw = IMG.s / GW, chh = IMG.s / GH;
      for (let r = 0; r < GH; r++) for (let c = 0; c < GW; c++) {
        const v = grid[r][c];
        if (v < 0.02) continue;
        ctx.globalAlpha = alpha * v * 0.62; ctx.fillStyle = INK;
        ctx.fillRect(IMG.x + c * cw + 0.5, IMG.y + r * chh + 0.5, cw - 1, chh - 1);
      }
      ctx.globalAlpha = 1;
    }
    function dots(kmax, alpha) {
      ctx.fillStyle = INK; ctx.globalAlpha = 0.8 * alpha;
      let n = 0;
      for (const [k, x, y, s] of D4.dots) {
        if (k > kmax) break;
        ctx.beginPath(); ctx.arc(X(x), Y(y), Math.max(0.9, s * SC * 1.25), 0, 2 * Math.PI); ctx.fill(); n++;
      }
      ctx.globalAlpha = 1;
      return n;
    }
    const bounds = [[0.8, 2.0], [2.0, 6.5], [6.5, 8.65], [8.65, 99]];
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0.4, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        show(ch, 1);
        steps.forEach((s, i) => {
          const on = τ >= bounds[i][0] && τ < bounds[i][1], done = τ >= bounds[i][1];
          s.classList.toggle('on', on); s.classList.toggle('done', done);
        });
        // the picture dims while it is analysed, and leaves when the result is complete
        show(img, (τ < 0.8 ? 1 : lerp(1, 0.3, P(τ, 0.8, 1.3))) * (1 - P(τ, 6.6, 7.4)));
        // 1 · contour
        const pc = P(τ, 0.85, 1.95, E.io2);
        const guide = τ < 2.0 ? 1 : lerp(1, 0.32, P(τ, 2.0, 2.5)) * (1 - P(τ, 6.0, 6.6));
        if (pc > 0 && guide > 0) {
          const tipPt = contour(pc, VERM, τ < 2.0 ? 3 : 1.6, guide * a);
          if (tipPt && τ < 2.05) dot(ctx, tipPt[0], tipPt[1], 6, VERM, a);
        }
        // 2 · epicycles (one turn at N = 16), then the harmonics slider 16 → 3 → 16
        const pe = P(τ, 2.15, 4.35, E.io2);
        const N = τ >= 4.55 ? keys(τ, [[4.6, 16], [5.35, 3], [5.75, 3], [6.45, 16]], E.io2) : 16;
        if (τ >= 2.15) strokeCurve(N, τ < 4.4 ? 2 * Math.PI * pe : 2 * Math.PI, INK, 2.1, 0.92 * a);
        const epA = win(τ, 2.1, 4.75, 0.25, 0.35);
        if (epA > 0) epicycles(2 * Math.PI * pe, epA * a);
        harmVal.textContent = '조화 ' + Math.round(N);
        // 3 · darkness grid → stipple dots
        const gA = win(τ, 6.55, 7.75, 0.3, 0.55);
        if (gA > 0) gridOverlay(gA * a);
        const kmax = 6000 * P(τ, 7.0, 8.6, E.io2);
        const nd = kmax > 0 ? dots(kmax, a) : 0;
        let ct;
        if (τ < 0.8) ct = '<i></i>매화.png · 그림 한 장';
        else if (τ < 2.0) ct = '<i></i>윤곽 추출 중…';
        else if (τ < 6.5) ct = `<i></i>푸리에 · 조화 ${Math.round(N)}`;
        else if (τ < 8.65) ct = `<i></i>농담 · 점 ${fmtInt(nd)}`;
        else ct = `<i class="ok"></i>분석 완료 · 윤곽 1개 · ${fmtInt(D4.dots.length)}점`;
        if (cap1.innerHTML !== ct) cap1.innerHTML = ct;
        show(cap1, 1);
        stamp(cardSeal, τ, 8.7);
        // 4 · the script fills in as each step finishes
        script.lines.forEach((ln, i) => {
          const t0 = lineAt[i];
          const p = P(τ, t0, t0 + 0.22, E.out2);
          ln.style.opacity = p.toFixed(3);
          ln.style.clipPath = p < 1 ? `inset(0 ${(100 * (1 - p)).toFixed(1)}% 0 0)` : '';
          const flash = win(τ, t0, t0 + 1.0, 0.05, 0.7);
          ln.style.background = flash > 0.01 ? `rgba(194,65,43,${(0.10 * flash).toFixed(3)})` : '';
        });
        caps.forEach((c, i) => capShow(c, τ, capT[i][0], capT[i][1], i === caps.length - 1));
      },
    });
  }

  // ================================================================== 伍 · the app
  {
    const [A, B] = T0.app;
    const R = sceneRoots();
    const ch = chapter(R.o, '伍', '앱', 'SwiftUI · iPhone');
    const SCL = 0.75, SW = Math.round(392 * SCL), SH = Math.round(852 * SCL), BZ = 10;
    const PW = SW + 2 * BZ, PH = SH + 2 * BZ, GAP = 70;
    const X0 = (1920 - (4 * PW + 3 * GAP)) / 2, Y0 = 138;
    const shots = [
      ['ui-light-draw', 'ui-dark-draw', '그리기', '수식 → 그림 · 동적 매개변수'],
      ['ui-light-read', 'ui-dark-read', '읽기', '사진 → 윤곽 → 곡선 · 점'],
      ['ui-light-gallery', 'ui-dark-gallery', '갤러리', 'SwiftData · 스크립트 원문 저장'],
      ['ui-light-detail', 'ui-dark-detail', '작품 상세', '제원 · 스크립트로 열기'],
    ];
    const phones = shots.map(([lt, dk, n, d], i) => {
      const x = X0 + i * (PW + GAP);
      const ph = place(el('div', 'phone', R.u), x, Y0);
      size(ph, PW, PH); ph.style.borderRadius = '50px'; ph.style.padding = BZ + 'px';
      const scr = el('div', 'scr', ph); size(scr, SW, SH); scr.style.borderRadius = '41px';
      const l = el('img', '', scr); l.src = `../../Screenshots/${lt}.png`; size(l, SW, SH);
      const dkI = el('img', '', scr); dkI.src = `../../Screenshots/${dk}.png`; size(dkI, SW, SH);
      const isl = el('div', 'island', scr);
      size(isl, 92, 27); isl.style.marginLeft = '-46px'; isl.style.top = '8px';
      const lab = place(el('div', 'plab', R.o, `<div class="n">${n}</div><div class="d">${d}</div>`), x, Y0 + PH + 18);
      size(lab, PW);
      return { ph, dkI, lab };
    });
    const capA = caption(R.o, '세 개의 탭 — 그리기 · 읽기 · 갤러리', 'SwiftUI · Vision · SwiftData — 사진은 기기를 떠나지 않는다 (iPhone 16 시뮬레이터 화면)');
    const capB = caption(R.o, '다크 모드 — 크롬만 어두워지고, 화선지와 먹은 그대로', '강조색은 낙관의 주홍 한 가지');
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0.4, 0.4);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        show(ch, 1);
        phones.forEach((p, i) => {
          const c = P(τ, 0.1 + 0.1 * i, 0.75 + 0.1 * i, E.out3);
          show(p.ph, c, 0, 46 * (1 - c)); show(p.lab, c, 0, 46 * (1 - c));
          const w = P(τ, 4.25 + 0.1 * i, 4.95 + 0.1 * i, E.io2);
          p.dkI.style.clipPath = `inset(0 ${(100 * (1 - w)).toFixed(2)}% 0 0)`;
          p.dkI.style.visibility = w > 0 ? 'visible' : 'hidden';
        });
        capShow(capA, τ, 0.4, 4.25); capShow(capB, τ, 4.25, 7.95, true);
      },
    });
  }

  // ================================================================== outro → back to blank paper (loop)
  {
    const [A, B] = T0.outro;
    const R = sceneRoots();
    const T = titleBlock(R);
    const chips = place(el('div', 'chips', R.o, ['Swift 6', 'SwiftUI', 'Vision', 'SwiftData', 'iOS 27+', '온디바이스'].map((c) => `<span class="chip">${c}</span>`).join('')), 134, 760);
    const url = place(el('div', 'url', R.o, 'github.com/kimminung/SuMuk'), 134, 836);
    scenes.push({
      A, B, update(t) {
        const a = win(t, A, B, 0, 0);
        rootShow(R, a);
        if (a <= 0) return;
        const τ = t - A;
        const out = 1 - P(τ, 3.0, 3.75, E.io2);   // crane, chips, url and seal leave; the title block stays = frame 0
        drawCrane(P(τ, 0.05, 1.55, E.lin), a * out, 1 - P(τ, 1.45, 1.8));
        rise(T.ko, τ, 0.0, 0.6, 14); rise(T.sub, τ, 0.12, 0.7, 12); rise(T.tag, τ, 0.24, 0.85, 12); rise(T.subl, τ, 0.36, 0.95, 10);
        const pc = P(τ, 0.8, 1.35, E.out3), pu = P(τ, 1.05, 1.6, E.out3);
        show(chips, pc * out, 0, 12 * (1 - pc)); show(url, pu * out, 0, 12 * (1 - pu));
        if (τ < 3.0) stamp(T.seal, τ, 1.6); else show(T.seal, out);
      },
    });
  }

  // ------------------------------------------------------------------ driver
  function seek(t) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, L.W, L.H);
    for (const s of scenes) s.update(t >= s.A - 0.01 && t <= s.B + 0.01 ? t : -1e9);
  }
  scenes.forEach((s) => s.update(-1e9));

  const imgs = Array.from(document.images);
  // fonts are only fetched for laid-out text and inactive scenes are display:none → preload every face/subset
  const dynamic = '0123456789,./=−·… k선분원윤곽추출중푸리에조화농담점분석완료개매화.png그림한장';
  const allText = document.getElementById('stage').textContent + dynamic;
  const faces = ['800 100px "Nanum Myeongjo"', '400 40px "Noto Serif KR"', '500 40px "Noto Serif KR"', '700 40px "Noto Serif KR"',
    '400 20px "JetBrains Mono"', '600 20px "JetBrains Mono"', '700 20px "JetBrains Mono"', 'italic 400 20px "STIX Two Text"', '400 20px "STIX Two Text"',
    '450 20px Pretendard', '650 20px Pretendard', '700 20px Pretendard'];
  window.READY = Promise.all([...faces.map((f) => document.fonts.load(f, allText)), document.fonts.ready,
    ...imgs.map((i) => (i.complete ? Promise.resolve() : new Promise((r) => { i.onload = i.onerror = r; })))])
    .then(() => Promise.all(imgs.map((i) => i.decode().catch(() => {}))))
    .then(() => { seek(0); return true; });
  window.seek = seek;
  window.DURATION = DURATION;
})();
