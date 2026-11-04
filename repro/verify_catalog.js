const { chromium } = require('playwright');
const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots';

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();

  // login first so the detail page shows learning state
  await page.goto(BASE + '/account/login', { waitUntil: 'networkidle' });
  await page.fill('form[action="/account/password/login"] input[name=account]', '10000@163.com');
  await page.fill('form[action="/account/password/login"] input[name=password]', '123456');
  await page.click('form[action="/account/password/login"] button[type=submit], form[action="/account/password/login"] .layui-btn');
  await page.waitForTimeout(2500);

  await page.goto(BASE + '/course/1', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);

  // switch to catalog tab
  const tab = page.locator('text=目录').first();
  await tab.click().catch(() => {});
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + '/09_course_catalog.png' });
  console.log('catalog shot done');

  const txt = await page.evaluate(() => document.body.innerText);
  console.log('has chapter1:', txt.includes('第一章'));
  console.log('has lesson:', txt.includes('页面骨架'));
  await browser.close();
})();
