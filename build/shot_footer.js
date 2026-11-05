// 页脚上下文截图（含绶带上方区域）
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge' });
  for (const [tag, w] of [['desk', 1440], ['mob', 390]]) {
    const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: w, height: 900 }, deviceScaleFactor: 2 });
    const p = await ctx.newPage();
    await p.goto('https://8.138.34.151/', { waitUntil: 'networkidle', timeout: 45000 });
    await p.waitForTimeout(400);
    const box = await p.locator('#footer').boundingBox();
    await p.evaluate(y => window.scrollTo(0, y), Math.max(0, box.y - 500));
    await p.waitForTimeout(400);
    const bb = await p.locator('#footer').boundingBox();
    const vp = p.viewportSize();
    await p.screenshot({ path: `theme_src/shots/part-footer-ctx-${tag}.png`, clip: { x: 0, y: Math.max(0, bb.y - 40), width: vp.width, height: Math.min(160, bb.height + 40) } });
    await ctx.close();
  }
  await b.close();
  console.log('ok');
})();
