const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://ctc.koogua.com/', { waitUntil: 'networkidle', timeout: 60000 }).catch(e=>console.log('goto',e.message));
  await page.waitForTimeout(3000);
  console.log('URL:', page.url());
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 700));
  await page.screenshot({ path: OUT + '/kg_01_home.png' });
  const links = await page.$$eval('a', els => els.map(e => e.innerText.trim().slice(0,16) + '|' + e.getAttribute('href')).filter(x => x.split('|')[1] && !x.startsWith('|')));
  console.log('LINKS:', JSON.stringify([...new Set(links)].slice(0, 40)));
  await browser.close();
})();
