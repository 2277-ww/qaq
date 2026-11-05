// 局部截图：页头、页脚、首屏
const { chromium } = require('playwright');
const BASE = process.env.SHOT_BASE || 'https://8.138.34.151';
(async () => {
  const fs = require('fs');
  fs.mkdirSync('theme_src/shots', { recursive: true });
  const b = await chromium.launch({ channel: 'msedge' });
  for (const [tag, w] of [['desk', 1440], ['mob', 390]]) {
    const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: w, height: 900 }, deviceScaleFactor: 2 });
    const p = await ctx.newPage();
    await p.goto(BASE + '/', { waitUntil: 'networkidle', timeout: 45000 });
    await p.waitForTimeout(500);
    await p.locator('#header').screenshot({ path: `theme_src/shots/part-header-${tag}.png` });
    await p.locator('#footer').screenshot({ path: `theme_src/shots/part-footer-${tag}.png` });
    await p.locator('.course-card').first().screenshot({ path: `theme_src/shots/part-card-${tag}.png` });
    await ctx.close();
  }
  await b.close();
  console.log('done');
})();
