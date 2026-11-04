const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://university.learnhouse.io/course/be89716c-9992-44bb-81df-ef3d76e355ba/activity/b7a95ae7-0518-42a4-9112-9cf62cde6ad1', { waitUntil: 'networkidle' });
  await page.waitForTimeout(5000);
  await page.screenshot({ path: OUT + '/lh_04_activity.png' });
  console.log('act:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));
  const v = await page.evaluate(() => { const el = document.querySelector('video'); return el ? { rs: el.readyState, w: el.videoWidth } : 'none'; });
  console.log('video:', JSON.stringify(v));

  await page.goto('https://university.learnhouse.io/paths', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/lh_05_paths.png' });
  console.log('paths:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 300));
  await browser.close();
})();
