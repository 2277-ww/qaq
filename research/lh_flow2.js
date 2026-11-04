const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();

  await page.goto('https://university.learnhouse.io/courses', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/lh_02_courses.png' });
  console.log('courses:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));

  await page.goto('https://university.learnhouse.io/course/be89716c-9992-44bb-81df-ef3d76e355ba', { waitUntil: 'networkidle' });
  await page.waitForTimeout(4000);
  await page.screenshot({ path: OUT + '/lh_03_detail.png' });
  console.log('detail:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 500));
  const acts = await page.$$eval('a', els => [...new Set(els.map(e => (e.getAttribute('href')||'')).filter(h => /activity|lesson|chapter/.test(h)))]);
  console.log('ACT LINKS:', JSON.stringify(acts.slice(0, 6)));
  await browser.close();
})();
