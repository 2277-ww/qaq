const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();

  await page.goto('https://ctc.koogua.com/course/list', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + '/kg_02_list.png' });
  console.log('list ok', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0,300));

  await page.goto('https://ctc.koogua.com/course/1404', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + '/kg_03_detail.png' });
  console.log('detail ok', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0,500));

  // try open a lesson
  const lessonLink = await page.$$eval('a', els => els.map(e=>e.getAttribute('href')).filter(h => h && /\/lesson\/|\/study\//.test(h)));
  console.log('lesson links:', JSON.stringify([...new Set(lessonLink)].slice(0,5)));
  await browser.close();
})();
