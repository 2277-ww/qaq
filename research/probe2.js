const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const url = process.argv[2];
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 }).catch(e => console.log('goto', e.message));
  await page.waitForTimeout(3500);
  console.log('URL:', page.url(), '| TITLE:', await page.title());
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 700));
  const ins = await page.$$eval('input', els => els.map(e => e.type + ':' + (e.placeholder||e.name)));
  console.log('INPUTS:', JSON.stringify(ins.slice(0,8)));
  await page.screenshot({ path: OUT + '/probe.png' });
  await browser.close();
})();
