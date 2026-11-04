const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1.5, locale: 'zh-CN' })).newPage();
  await page.goto('https://university.learnhouse.io/courses', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(9000);
  await page.screenshot({ path: OUT + '/lh_test1920.png' });
  console.log('done');
  await browser.close();
})();
