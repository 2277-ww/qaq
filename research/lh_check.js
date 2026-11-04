const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  const fails = [];
  page.on('requestfailed', r => fails.push('FAIL ' + r.url().slice(0, 90)));
  page.on('response', r => { if (r.status() >= 400) fails.push(r.status() + ' ' + r.url().slice(0, 90)); });
  await page.goto('https://university.learnhouse.io/courses', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(4000);
  const sheets = await page.evaluate(() => [...document.styleSheets].map(s => (s.href || 'inline').slice(0, 80)));
  console.log('STYLESHEETS:', JSON.stringify(sheets, null, 0));
  console.log('FAILS:', JSON.stringify([...new Set(fails)].slice(0, 15), null, 0));
  await browser.close();
})();
