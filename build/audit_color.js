// 色相审计：找出所有明显偏离「藏蓝(200-235°) / 金(32-52°) / 中性低饱和」的颜色
const { chromium } = require('playwright');
const PAGES = process.env.SCAN_PAGES
  ? process.env.SCAN_PAGES.split(',')
  : ['/', '/course/list', '/course/1', '/article/list', '/question/list', '/teacher/list', '/search?query=%E5%AE%89%E5%85%A8', '/uc'];

function parseRGB(s) {
  const m = s && s.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/);
  if (!m) return null;
  return { r: +m[1], g: +m[2], b: +m[3], a: m[4] === undefined ? 1 : +m[4] };
}
function hsl(c) {
  const r = c.r / 255, g = c.g / 255, b = c.b / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0, s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0));
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
  }
  return { h, s, l };
}
function offTheme(c) {
  if (!c || c.a < 0.5) return false;
  const { h, s, l } = hsl(c);
  if (s < 0.22) return false;            // 中性灰
  if (l < 0.06 || l > 0.97) return false; // 近黑近白
  const inNavy = h >= 195 && h <= 245;
  const inGold = h >= 28 && h <= 55;
  return !(inNavy || inGold);
}

(async () => {
  const b = await chromium.launch({ channel: 'msedge' });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } });
  const p = await ctx.newPage();
  const seen = new Map();
  for (const path of PAGES) {
    await p.goto('https://8.138.34.151' + path, { waitUntil: 'networkidle', timeout: 45000 }).catch(e => console.log('ERR', path, e.message));
    await p.waitForTimeout(400);
    const hits = await p.evaluate(() => {
      const out = [];
      const grab = (el) => {
        const cs = getComputedStyle(el);
        const cls = (el.className && typeof el.className === 'string') ? el.className.trim().split(/\s+/).slice(0, 3).join('.') : '';
        const r = el.getBoundingClientRect();
        if (r.width <= 0 || r.height <= 0) return;
        out.push({
          tag: el.tagName.toLowerCase(), cls,
          color: cs.color, bg: cs.backgroundColor,
          bt: cs.borderTopColor, bb: cs.borderBottomColor,
          text: (el.textContent || '').trim().slice(0, 14),
        });
      };
      document.querySelectorAll('body *').forEach(el => {
        const t = el.tagName;
        if (t === 'svg' || t === 'IMG' || t === 'svg' ) return;
        grab(el);
      });
      return out;
    });
    for (const h of hits) {
      const bad = ['color', 'bg', 'bt', 'bb'].filter(k => offTheme(parseRGB(h[k])));
      if (!bad.length) continue;
      const key = h.tag + (h.cls ? '.' + h.cls : '') + ' [' + bad.join(',') + ']';
      const prev = seen.get(key);
      const detail = bad.map(k => k + '=' + h[k]).join(' ');
      if (!prev) seen.set(key, { pages: new Set([path]), detail, text: h.text });
      else prev.pages.add(path);
    }
  }
  const rows = [...seen.entries()].sort((a, b) => b[1].pages.size - a[1].pages.size);
  for (const [k, v] of rows) console.log(k, '|', v.detail, '| x' + v.pages.size, v.text ? '| "' + v.text + '"' : '');
  console.log('total', rows.length);
  await b.close();
})();
