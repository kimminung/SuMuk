// 수묵 소개 영상 렌더러 — 각 프레임은 seek(t)의 순수 함수이므로 결과가 매번 같다.
// Usage: node render.js stills <dir> <t1> <t2> …              → PNG stills (seconds)
//        FLAT=1 node render.js video <out.mkv>                → GIF master on plain paper
//        node render.js video <out.mkv> [fps=30] [from] [to]   → lossless RGB master via ffmpeg
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
(async () => {
  const [mode, out, ...rest] = process.argv.slice(2);
  if (!mode || !out) { console.log('usage: node render.js stills <dir> t… | video <out.mkv> [fps] [from] [to]'); process.exit(1); }
  const browser = await chromium.launch({ args: ['--font-render-hinting=none', '--disable-lcd-text', '--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.log('[pageerror]', e.message));
  // FLAT=1 → plain paper without fibres (used for the GIF master: error-diffusion dither stays still)
  await page.goto('file://' + path.resolve(__dirname, 'index.html') + (process.env.FLAT ? '?flat=1' : ''));
  await page.evaluate(() => window.READY);
  if (mode === 'stills') {
    fs.mkdirSync(out, { recursive: true });
    for (const ts of rest) {
      const t = parseFloat(ts);
      await page.evaluate((t) => window.seek(t), t);
      await page.screenshot({ path: path.join(out, `t${t.toFixed(2).padStart(6, '0')}.png`) });
    }
  } else {
    const fps = parseFloat(rest[0] || '30');
    const dur = await page.evaluate(() => window.DURATION);
    const from = parseFloat(rest[1] || '0'), to = parseFloat(rest[2] || String(dur));
    const i0 = Math.round(from * fps), i1 = Math.round(to * fps);
    const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-',
      '-c:v', 'libx264rgb', '-crf', '0', '-preset', 'ultrafast', '-pix_fmt', 'rgb24', out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const t0 = Date.now();
    for (let i = i0; i < i1; i++) {
      await page.evaluate((t) => window.seek(t), i / fps);
      const buf = await page.screenshot({ type: 'png' });
      if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
      if ((i - i0) % 150 === 0) console.log(`frame ${i}/${i1}  ${((Date.now() - t0) / 1000).toFixed(1)}s`);
    }
    ff.stdin.end();
    await new Promise((r) => ff.on('close', r));
    console.log('done', ((Date.now() - t0) / 1000).toFixed(1) + 's');
  }
  await browser.close();
})();
