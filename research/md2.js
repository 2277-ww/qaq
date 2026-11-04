const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://school.moodledemo.net/', { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(e=>console.log('goto', e.message.slice(0,50)));
  await page.waitForTimeout(3000);
  console.log('URL:', page.url(), '|', await page.title());
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 600));
  await page.screenshot({ path: OUT + '/md_school.png' });
  await browser.close();
})();
