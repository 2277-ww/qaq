const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
  });
  const page = await ctx.newPage();

  const shot = async (name) => {
    await page.waitForTimeout(1200);
    await page.screenshot({ path: `${OUT}/${name}.png` });
    console.log('shot', name);
  };

  // 1. Home
  await page.goto(BASE + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  await shot('01_home');

  // 2. Course list (AJAX pager)
  await page.goto(BASE + '/course/list', { waitUntil: 'networkidle' });
  await page.waitForSelector('#course-list .layui-card, #course-list a[href^="/course/"]', { timeout: 15000 }).catch(() => {});
  await shot('02_course_list');

  // 3. Course detail
  await page.goto(BASE + '/course/1', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  await shot('03_course_detail');

  // 4. Front login
  await page.goto(BASE + '/account/login', { waitUntil: 'networkidle' });
  await shot('04_login_form');
  await page.fill('form[action="/account/password/login"] input[name=account]', '10000@163.com');
  await page.fill('form[action="/account/password/login"] input[name=password]', '123456');
  await page.click('form[action="/account/password/login"] button[type=submit], form[action="/account/password/login"] .layui-btn');
  await page.waitForTimeout(3000);
  const afterLogin = page.url();
  console.log('after login url:', afterLogin);
  await shot('05_after_login');

  // verify logged-in state by profile link
  const loggedIn = await page.evaluate(() => document.body.innerText.includes('退出'));
  console.log('logged in marker:', loggedIn);

  // 5. Admin login
  await page.goto(BASE + '/admin/login', { waitUntil: 'networkidle' });
  await page.fill('form[action="/admin/login"] input[name=account]', '10000@163.com');
  await page.fill('form[action="/admin/login"] input[name=password]', '123456');
  await page.click('form[action="/admin/login"] button[type=submit], form[action="/admin/login"] .layui-btn');
  await page.waitForTimeout(3500);
  console.log('admin url:', page.url());
  await shot('06_admin_dashboard');

  // 6. Admin course list
  await page.goto(BASE + '/admin/course/list', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await shot('07_admin_course_list');

  // 7. Admin category
  await page.goto(BASE + '/admin/category/list', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  await shot('08_admin_category');

  await browser.close();
})();
