// 批量扫描多个页面残留的 layui 青色元素
const { chromium } = require('playwright');
const TARGETS = ['rgb(22, 183, 119)', 'rgb(22, 186, 170)', 'rgb(30, 159, 255)', 'rgb(1, 170, 237)'];
const PAGES = process.env.SCAN_PAGES
  ? process.env.SCAN_PAGES.split(',')
  : ['/', '/course/list', '/course/1', '/article/list', '/question/list', '/teacher/list', '/search?query=%E8%AF%BE%E7%A8%8B', '/uc'];
(async () => {
  const b = await chromium.launch({ channel: 'msedge' });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } });
  const p = await ctx.newPage();
  const seen = new Map();
  for (const path of PAGES) {
    await p.goto('https://8.138.34.151' + path, { waitUntil: 'networkidle', timeout: 45000 }).catch(e => console.log('ERR', path, e.message));
    await p.waitForTimeout(400);
    const hits = await p.evaluate((targets) => {
      const out = [];
      document.querySelectorAll('*').forEach(el => {
        const cs = getComputedStyle(el);
        const props = [];
        if (targets.includes(cs.color)) props.push('color');
        if (targets.includes(cs.backgroundColor)) props.push('bg');
        if (targets.includes(cs.borderTopColor)) props.push('borderTop');
        if (targets.includes(cs.borderBottomColor)) props.push('borderBottom');
        if (!props.length) return;
        const r = el.getBoundingClientRect();
        if (r.width <= 0 || r.height <= 0) return;
        const cls = (el.className && typeof el.className === 'string') ? el.className.trim().split(/\s+/).slice(0, 3).join('.') : '';
        out.push(el.tagName.toLowerCase() + (cls ? '.' + cls : '') + ' [' + props.join(',') + ']');
      });
      return out;
    }, TARGETS);
    hits.forEach(h => seen.set(h, (seen.get(h) || []).concat(path)));
  }
  for (const [k, v] of seen) console.log(k, '<-', v.join(' '));
  console.log('unique selectors:', seen.size);
  await b.close();
})();
