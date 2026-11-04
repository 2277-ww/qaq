const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://university.learnhouse.io/', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/lh_01_home.png' });
  const links = await page.$$eval('a', els => [...new Set(els.map(e => e.innerText.trim().slice(0,18) + '|' + (e.getAttribute('href')||'')).filter(x => /course|path/.test(x)))]);
  console.log('COURSE LINKS:', JSON.stringify(links.slice(0, 12)));
  await browser.close();
})();
