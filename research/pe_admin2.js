const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://admin.playedu.xyz/login', { waitUntil: 'networkidle' });
  await page.fill('input[type=text]', 'admin@playedu.xyz');
  await page.fill('input[type=password]', '123123');
  await page.click('button:has-text("立即登录")');
  await page.waitForTimeout(4500);
  console.log('URL:', page.url());
  await page.screenshot({ path: OUT + '/pe_05_admin_home.png' });
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 700));
  const menu = await page.$$eval('a,li', els => els.map(e => e.innerText.trim()).filter(t => t && t.length < 10).slice(0, 40));
  console.log('MENU:', JSON.stringify([...new Set(menu)]));
  await browser.close();
})();
