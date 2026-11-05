const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const FFMPEG = 'C:/Users/paradox/PYthon/lib/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe';
const ROOT = path.resolve(__dirname, '..');
const SRC = 'file:///' + path.resolve(ROOT, 'src/index.html').replace(/\\/g, '/');
const TL = require(path.join(ROOT, 'timeline.json'));
const OUT = path.join(ROOT, 'out');
fs.mkdirSync(OUT, { recursive: true });

const FPS = TL.fps || 25;
const TOTAL = Math.round(TL.duration * FPS);
const MAX = process.argv[2] ? parseInt(process.argv[2], 10) : TOTAL;
const target = path.join(OUT, process.argv[3] || 'video.mp4');

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--force-device-scale-factor=1'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.addInitScript(`window.TIMELINE = ${JSON.stringify(TL)};`);
  await page.goto(SRC, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);

  const ff = spawn(FFMPEG, [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'image2pipe', '-vcodec', 'mjpeg', '-framerate', String(FPS), '-i', '-',
    '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
    '-pix_fmt', 'yuv420p', '-r', String(FPS), '-movflags', '+faststart', target
  ], { stdio: ['pipe', 'inherit', 'inherit'] });

  const done = new Promise((res, rej) => ff.on('close', c => c === 0 ? res() : rej(new Error('ffmpeg exit ' + c))));

  const t0 = Date.now();
  for (let i = 0; i < MAX; i++) {
    const t = i * 1000 / FPS;
    await page.evaluate(ms => window.__render(ms), t);
    const buf = await page.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 250 === 0) {
      const el = (Date.now() - t0) / 1000;
      process.stdout.write(`frame ${i}/${MAX}  ${(i / el || 0).toFixed(1)} fps  eta ${((MAX - i) / (i / el || 1)).toFixed(0)}s\n`);
    }
  }
  ff.stdin.end();
  await done;
  await browser.close();
  console.log('video ->', target, ((Date.now() - t0) / 1000).toFixed(0) + 's');
})();
