const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const SRC = 'file:///' + path.resolve(__dirname, '../src/index.html').replace(/\\/g, '/');
const OUT = path.resolve(__dirname, '../shots');
const TL = require(path.resolve(__dirname, '../timeline.json'));
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.addInitScript(`window.TIMELINE = ${JSON.stringify(TL)};`);
  const list = JSON.parse(process.argv[2] || '[]');
  for (const [scene, p] of list) {
    await page.goto(`${SRC}?scene=${scene}&p=${p}`, { waitUntil: 'load' });
    await page.waitForTimeout(180);
    const file = path.join(OUT, `${scene}_${String(p).replace('.', '')}.png`);
    await page.screenshot({ path: file });
    console.log('shot', file);
  }
  await browser.close();
})();
