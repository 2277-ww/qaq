const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext()).newPage();
  await page.goto('https://www.koogua.com/page/ctc-demo', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  const links = await page.$$eval('a', els => els.map(e => e.innerText.trim().slice(0,12) + '|' + e.href).filter(x => /演示|前台|后台|手机/.test(x)));
  console.log(JSON.stringify([...new Set(links)], null, 0));
  await browser.close();
})();
