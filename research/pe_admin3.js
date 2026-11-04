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
  await page.waitForTimeout(4000);

  await page.click('text=课程中心', { timeout: 10000 });
  await page.waitForTimeout(3500);
  console.log('course URL:', page.url());
  await page.screenshot({ path: OUT + '/pe_04_admin_course.png' });
  console.log('COURSE TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 600));

  await page.click('text=分类管理', { timeout: 10000 });
  await page.waitForTimeout(3000);
  console.log('cat URL:', page.url());
  await page.screenshot({ path: OUT + '/pe_05_admin_category.png' });
  console.log('CAT TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 500));
  await browser.close();
})();
