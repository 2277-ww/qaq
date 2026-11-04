const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext()).newPage();
  await page.goto('https://frappe.io/learning', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  const links = await page.$$eval('a', els => [...new Set(els.map(e => e.innerText.trim().slice(0,20) + '|' + e.href).filter(x => /demo|try|cloud|github/i.test(x)))]);
  console.log(JSON.stringify(links.slice(0, 15), null, 0));
  await browser.close();
})();
