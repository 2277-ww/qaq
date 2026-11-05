// 巡检/对比截图：抓取前台主要页面（桌面 + 移动）
const { chromium } = require('playwright');

const BASE = process.env.SHOT_BASE || 'https://8.138.34.151';
const OUT = process.env.SHOT_OUT || 'theme_src/shots';
const TAG = process.env.SHOT_TAG || 'before';

const pages = [
  ['home', '/'],
  ['course', '/course/list'],
  ['course-detail', '/course/1'],
  ['article', '/article/list'],
  ['question', '/question/list'],
  ['search', '/search?query=%E8%AF%BE%E7%A8%8B'],
  ['uc', '/uc'],
];

(async () => {
  const fs = require('fs');
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge' });

  for (const [vp, size] of [['desk', { width: 1440, height: 900 }], ['mob', { width: 390, height: 844 }]]) {
    const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: size, deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    for (const [name, path] of pages) {
      await page.goto(BASE + path, { waitUntil: 'networkidle', timeout: 45000 }).catch(e => console.log('ERR', path, e.message));
      await page.waitForTimeout(600);
      const file = `${OUT}/${TAG}-${name}-${vp}.png`;
      await page.screenshot({ path: file, fullPage: vp === 'desk' });
      console.log('saved', file);
    }
    await ctx.close();
  }
  await browser.close();
})();
