const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  await page.goto('https://www.koogua.com/', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  const links = await page.$$eval('a', els => els.map(e => e.innerText.trim().slice(0,14) + '|' + e.getAttribute('href')).filter(x => /演示|demo|试用/i.test(x)));
  console.log(JSON.stringify([...new Set(links)], null, 0));
  await browser.close();
})();
