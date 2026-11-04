const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  await page.goto('https://demos.learnhouse.app', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  const links = await page.$$eval('a', els => els.map(e => e.innerText.trim().slice(0,24) + ' -> ' + e.getAttribute('href')));
  console.log(JSON.stringify([...new Set(links)], null, 0));
  await browser.close();
})();
