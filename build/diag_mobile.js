// 诊断移动端布局盒子
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge' });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 } });
  const p = await ctx.newPage();
  await p.goto('https://8.138.34.151/', { waitUntil: 'networkidle', timeout: 45000 });
  await p.waitForTimeout(400);
  const data = await p.evaluate(() => {
    const out = {};
    const pick = (sel) => {
      const el = document.querySelector(sel);
      if (!el) return null;
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      return { w: Math.round(r.width), h: Math.round(r.height), l: Math.round(r.left), t: Math.round(r.top), width: cs.width, float: cs.float, ar: cs.aspectRatio, mw: cs.maxWidth };
    };
    out.viewport = window.innerWidth;
    out.row = pick('.index-course-list .layui-row');
    out.col = pick('.layui-col-md3');
    out.card = pick('.course-card');
    out.cover = pick('.course-card .cover');
    out.img = pick('.course-card .cover img');
    out.main = pick('#main');
    out.header = pick('#header');
    out.bodyScrollW = document.body.scrollWidth;
    return out;
  });
  console.log(JSON.stringify(data, null, 2));
  await b.close();
})();
