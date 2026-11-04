const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://demo.playedu.xyz/login', { waitUntil: 'networkidle' });
  await page.fill('input[type=text]', '1@playedu.xyz');
  await page.fill('input[type=password]', '123123');
  await page.click('button:has-text("立即登录")');
  await page.waitForTimeout(4000);
  console.log('after login URL:', page.url());
  await page.screenshot({ path: OUT + '/pe_00_home.png', fullPage: false });
  const links = await page.$$eval('a', els => els.map(e => ({ t: e.innerText.trim().slice(0, 20), h: e.getAttribute('href') })).filter(x => x.h));
  console.log(JSON.stringify(links.slice(0, 40), null, 0));
  const text = await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | ').slice(0, 800));
  console.log('TEXT:', text);
  await browser.close();
})();
