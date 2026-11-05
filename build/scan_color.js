// 扫描页面残留的 layui 青色（#16b777 / #16baaa / #1e9fff）
const { chromium } = require('playwright');
const PATH = process.env.SCAN_PATH || '/course/1';
const TARGETS = ['rgb(22, 183, 119)', 'rgb(22, 186, 170)', 'rgb(30, 159, 255)', 'rgb(1, 170, 237)'];
(async () => {
  const b = await chromium.launch({ channel: 'msedge' });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } });
  const p = await ctx.newPage();
  await p.goto('https://8.138.34.151' + PATH, { waitUntil: 'networkidle', timeout: 45000 });
  await p.waitForTimeout(500);
  const hits = await p.evaluate((targets) => {
    const cssPath = (el) => {
      const parts = [];
      let n = el;
      while (n && n.nodeType === 1 && parts.length < 5) {
        let s = n.tagName.toLowerCase();
        if (n.id) { s += '#' + n.id; parts.unshift(s); break; }
        if (n.className && typeof n.className === 'string') {
          s += '.' + n.className.trim().split(/\s+/).slice(0, 3).join('.');
        }
        parts.unshift(s);
        n = n.parentElement;
      }
      return parts.join(' > ');
    };
    const out = [];
    document.querySelectorAll('*').forEach(el => {
      const cs = getComputedStyle(el);
      const props = [];
      if (targets.includes(cs.color)) props.push('color=' + cs.color);
      if (targets.includes(cs.backgroundColor)) props.push('bg=' + cs.backgroundColor);
      if (targets.includes(cs.borderTopColor)) props.push('borderTop=' + cs.borderTopColor);
      if (targets.includes(cs.borderBottomColor)) props.push('borderBottom=' + cs.borderBottomColor);
      if (props.length) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.height > 0) out.push({ sel: cssPath(el), props: props.join(','), text: (el.textContent || '').trim().slice(0, 18) });
      }
    });
    return out;
  }, TARGETS);
  console.log(JSON.stringify(hits.slice(0, 40), null, 1));
  console.log('total', hits.length);
  await b.close();
})();
