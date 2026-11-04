const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://admin.playedu.xyz', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  console.log('URL:', page.url());
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 400));
  const inputs = await page.$$eval('input', els => els.map(e => e.type + ':' + e.placeholder));
  console.log('INPUTS:', JSON.stringify(inputs));
  await page.screenshot({ path: OUT + '/pe_admin_login.png' });
  await browser.close();
})();
